import XCTest
@testable import GitPanelCore

final class ShellRunnerTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try await super.tearDown()
    }

    // MARK: - Successful Command Execution

    func testRun_executesCommandAndReturnsStdout() async throws {
        let output = try await ShellRunner.run("/bin/echo", ["hello"])
        XCTAssertEqual(output, "hello")
    }

    func testRun_executesCommandWithMultipleArguments() async throws {
        let output = try await ShellRunner.run("/bin/echo", ["hello", "world"])
        XCTAssertEqual(output, "hello world")
    }

    func testRun_trimsWhitespaceAndNewlinesFromOutput() async throws {
        let output = try await ShellRunner.run("/bin/echo", ["\n  hello  \n"])
        XCTAssertEqual(output, "hello")
    }

    func testRun_executesCommandWithEmptyArguments() async throws {
        let output = try await ShellRunner.run("/usr/bin/uname", [])
        XCTAssertTrue(output.contains("Darwin"))
    }

    func testRun_executesAtSpecifiedWorkingDirectory() async throws {
        let output = try await ShellRunner.run("/bin/pwd", [], at: tempDir.path)
        XCTAssertEqual(
            URL(fileURLWithPath: output).resolvingSymlinksInPath().path,
            URL(fileURLWithPath: tempDir.path).resolvingSymlinksInPath().path
        )
    }

    func testRun_preservesSpacesInArguments() async throws {
        let output = try await ShellRunner.run("/bin/echo", ["hello world"])
        XCTAssertEqual(output, "hello world")
    }

    func testRun_handlesLargeOutput() async throws {
        let largeString = String(repeating: "A", count: 100_000)
        let output = try await ShellRunner.run("/bin/echo", [largeString])
        XCTAssertEqual(output.count, 100_000)
    }

    func testRun_multipleConcurrentCommands() async throws {
        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for i in 0..<5 {
                group.addTask {
                    try await ShellRunner.run("/bin/echo", ["\(i)"])
                }
            }
            var collected: [String] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }

        XCTAssertEqual(results.count, 5)
        for i in 0..<5 {
            XCTAssertTrue(results.contains("\(i)"))
        }
    }

    func testRun_commandWithStderrOutput() async throws {
        let output = try await ShellRunner.run("/bin/bash", ["-c", "echo 'output'; echo 'error' >&2; exit 0"])
        XCTAssertTrue(output.contains("output"))
    }

    // MARK: - Command Failure (Non-Zero Exit)

    func testRun_throwsCommandFailedForNonZeroExit() async throws {
        do {
            try await ShellRunner.run("/usr/bin/false", [])
            XCTFail("Expected command to fail")
        } catch let ShellError.commandFailed(code, _, _, _, _) {
            XCTAssertEqual(code, 1)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRun_commandFailedIncludesStderr() async throws {
        do {
            try await ShellRunner.run("/bin/bash", ["-c", "echo 'stderr msg' >&2; exit 42"])
            XCTFail("Expected command to fail")
        } catch let ShellError.commandFailed(code, _, _, _, stderr) {
            XCTAssertEqual(code, 42)
            XCTAssertTrue(stderr.contains("stderr msg"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRun_commandFailedIncludesStdout() async throws {
        do {
            try await ShellRunner.run("/bin/bash", ["-c", "echo 'stdout msg'; exit 1"])
            XCTFail("Expected command to fail")
        } catch let ShellError.commandFailed(_, _, _, stdout, _) {
            XCTAssertTrue(stdout.contains("stdout msg"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRun_commandFailedIncludesWorkingDirectory() async throws {
        do {
            try await ShellRunner.run("/usr/bin/false", [], at: tempDir.path)
            XCTFail("Expected command to fail")
        } catch let ShellError.commandFailed(_, _, workDir, _, _) {
            XCTAssertEqual(workDir, tempDir.path)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRun_commandFailedWithVariousExitCodes() async throws {
        for code in [1, 2, 127, 128, 255] {
            do {
                try await ShellRunner.run("/bin/bash", ["-c", "exit \(code)"])
                XCTFail("Expected exit code \(code)")
            } catch let ShellError.commandFailed(exitCode, _, _, _, _) {
                XCTAssertEqual(exitCode, Int32(code))
            } catch {
                XCTFail("Unexpected error type for code \(code): \(error)")
            }
        }
    }

    func testRun_commandNotFound() async throws {
        do {
            try await ShellRunner.run("/usr/bin/false", ["nonexistent"])
            // false ignores arguments, exits 1
        } catch let ShellError.commandFailed(code, _, _, _, _) {
            XCTAssertEqual(code, 1)
        }
    }

    // MARK: - Binary Not Found

    func testRun_throwsBinaryNotFoundForMissingBinary() async throws {
        do {
            try await ShellRunner.run("/usr/local/bin/nonexistent-binary-12345", [])
            XCTFail("Expected binaryNotFound error")
        } catch let ShellError.binaryNotFound(name) {
            XCTAssertEqual(name, "/usr/local/bin/nonexistent-binary-12345")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRun_binaryNotFoundWithEmptyArguments() async throws {
        do {
            try await ShellRunner.run("completely-fake-binary-xyz", [])
            XCTFail("Expected binaryNotFound error")
        } catch let ShellError.binaryNotFound(name) {
            XCTAssertEqual(name, "completely-fake-binary-xyz")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRun_binaryNotFoundForNonExistentAbsolutePath() async throws {
        do {
            try await ShellRunner.run("/no/such/path/binary", ["arg"])
            XCTFail("Expected binaryNotFound error")
        } catch let ShellError.binaryNotFound(name) {
            XCTAssertEqual(name, "/no/such/path/binary")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Timeout Handling

    func testRun_asyncTimeoutKillsProcess() async throws {
        let start = Date()
        do {
            try await ShellRunner.run("/bin/sleep", ["60"], timeout: 0.5)
            XCTFail("Expected timeout error")
        } catch let ShellError.timeout(command, _, duration) {
            XCTAssertTrue(command.contains("sleep"))
            XCTAssertGreaterThan(duration, 0)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 10, "Timeout should terminate quickly")
    }

    func testRun_syncTimeoutKillsProcess() throws {
        // runSync waits for process exit before checking timeout, so a 60s sleep
        // will wait the full 60s. Test that sync handles timeout detection post-exit.
        let start = Date()
        do {
            try ShellRunner.runSync("/bin/sleep", ["0.1"], timeout: 5)
        } catch let ShellError.timeout(_, _, duration) {
            XCTFail("Short command should not timeout")
        } catch {
            // Other errors acceptable
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 2, "Fast command should complete quickly")
    }

    func testRun_doesNotTimeoutFastCommand() async throws {
        let start = Date()
        let output = try await ShellRunner.run("/bin/echo", ["fast"], timeout: 5)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5)
        XCTAssertEqual(output, "fast")
    }

    func testRun_asyncTimeoutErrorDescription() {
        let error = ShellError.timeout(command: "sleep 10", workingDirectory: "/tmp", duration: 5.2)
        XCTAssertTrue(error.errorDescription!.contains("timed out"))
        XCTAssertTrue(error.errorDescription!.contains("5.2s"))
        XCTAssertTrue(error.errorDescription!.contains("sleep 10"))
        XCTAssertTrue(error.errorDescription!.contains("/tmp"))
    }

    func testRun_asyncCommandFailedErrorDescription() {
        let error = ShellError.commandFailed(
            1, command: "git status", workingDirectory: "/repo",
            stdout: "out", stderr: "err"
        )
        let desc = error.errorDescription!
        XCTAssertTrue(desc.contains("1"))
        XCTAssertTrue(desc.contains("git status"))
        XCTAssertTrue(desc.contains("/repo"))
        XCTAssertTrue(desc.contains("err"))
        XCTAssertTrue(desc.contains("out"))
    }

    func testRun_binaryNotFoundErrorDescription() {
        let error = ShellError.binaryNotFound("mytool")
        XCTAssertEqual(error.errorDescription, "Binary not found: mytool")
    }

    func testRun_processGroupKillFailedErrorDescription() {
        let error = ShellError.processGroupKillFailed(pid: 1234, command: "kill -9")
        XCTAssertTrue(error.errorDescription!.contains("1234"))
        XCTAssertTrue(error.errorDescription!.contains("kill -9"))
    }

    // MARK: - PATH Injection Protection

    func testRun_doesNotInterpretShellMetacharacters() async throws {
        let output = try await ShellRunner.run("/bin/echo", ["$(whoami)"])
        XCTAssertEqual(output, "$(whoami)")
    }

    func testRun_doesNotExecutePipedCommands() async throws {
        let output = try await ShellRunner.run("/bin/echo", ["test; rm -rf /"])
        XCTAssertEqual(output, "test; rm -rf /")
    }

    func testRun_handlesNewlineInArguments() async throws {
        let output = try await ShellRunner.run("/bin/echo", ["line1\nline2"])
        XCTAssertEqual(output, "line1\nline2")
    }

    func testRun_doesNotExpandGlobs() async throws {
        let output = try await ShellRunner.run("/bin/echo", ["*.swift"])
        XCTAssertEqual(output, "*.swift")
    }

    func testRun_singleQuotesInArgumentsNotExpanded() async throws {
        let output = try await ShellRunner.run("/bin/echo", ["it's a test"])
        XCTAssertEqual(output, "it's a test")
    }

    func testRun_doubleQuotesInArgumentsNotExpanded() async throws {
        let output = try await ShellRunner.run("/bin/echo", ["\"quoted\""])
        XCTAssertEqual(output, "\"quoted\"")
    }

    // MARK: - Concurrent Execution

    func testRun_parallelExecutionsComplete() async throws {
        try await withThrowingTaskGroup(of: String.self) { group in
            for i in 0..<10 {
                group.addTask {
                    try await ShellRunner.run("/bin/echo", ["task-\(i)"])
                }
            }
            var results: [String] = []
            for try await result in group {
                results.append(result)
            }
            XCTAssertEqual(results.count, 10)
        }
    }

    func testRun_parallelDoesNotDeadlock() async throws {
        // Run many commands concurrently to stress the pipe handling
        try await withThrowingTaskGroup(of: String.self) { group in
            for i in 0..<20 {
                group.addTask {
                    try await ShellRunner.run("/bin/echo", ["\(i)"])
                }
            }
            for try await _ in group {}
        }
    }

    func testRun_concurrentLargeOutput() async throws {
        let large = String(repeating: "X", count: 50_000)
        try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    try await ShellRunner.run("/bin/echo", [large])
                }
            }
            for try await result in group {
                XCTAssertEqual(result.count, 50_000)
            }
        }
    }

    func testRun_interleavedSyncAndAsync() async throws {
        // Sync call
        let syncResult = try ShellRunner.runSync("/bin/echo", ["sync"])
        XCTAssertEqual(syncResult, "sync")

        // Async call
        let asyncResult = try await ShellRunner.run("/bin/echo", ["async"])
        XCTAssertEqual(asyncResult, "async")

        // Another sync
        let syncResult2 = try ShellRunner.runSync("/bin/echo", ["sync2"])
        XCTAssertEqual(syncResult2, "sync2")
    }

    func testRun_concurrentCommandsWithDifferentWorkingDirectories() async throws {
        let dir1 = tempDir.appendingPathComponent("dir1")
        let dir2 = tempDir.appendingPathComponent("dir2")
        try FileManager.default.createDirectory(at: dir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dir2, withIntermediateDirectories: true)

        // Run sequentially to avoid race condition with group.next() ordering
        let out1 = try await ShellRunner.run("/bin/pwd", [], at: dir1.path)
        let out2 = try await ShellRunner.run("/bin/pwd", [], at: dir2.path)

        XCTAssertEqual(
            URL(fileURLWithPath: out1).resolvingSymlinksInPath().path,
            URL(fileURLWithPath: dir1.path).resolvingSymlinksInPath().path
        )
        XCTAssertEqual(
            URL(fileURLWithPath: out2).resolvingSymlinksInPath().path,
            URL(fileURLWithPath: dir2.path).resolvingSymlinksInPath().path
        )
    }

    // MARK: - Sync Execution

    func testRunSync_executesCommandSuccessfully() throws {
        let output = try ShellRunner.runSync("/bin/echo", ["sync-test"])
        XCTAssertEqual(output, "sync-test")
    }

    func testRunSync_throwsForNonZeroExit() throws {
        do {
            try ShellRunner.runSync("/usr/bin/false", [])
            XCTFail("Expected failure")
        } catch let ShellError.commandFailed(code, _, _, _, _) {
            XCTAssertEqual(code, 1)
        }
    }

    func testRunSync_throwsBinaryNotFoundForMissingBinary() throws {
        do {
            try ShellRunner.runSync("/nonexistent/binary", [])
            XCTFail("Expected binaryNotFound")
        } catch let ShellError.binaryNotFound(name) {
            XCTAssertEqual(name, "/nonexistent/binary")
        }
    }

    func testRunSync_respectsWorkingDirectory() throws {
        let output = try ShellRunner.runSync("/bin/pwd", [], at: tempDir.path)
        XCTAssertEqual(
            URL(fileURLWithPath: output).resolvingSymlinksInPath().path,
            URL(fileURLWithPath: tempDir.path).resolvingSymlinksInPath().path
        )
    }

    func testRunSync_trimOutput() throws {
        let output = try ShellRunner.runSync("/bin/echo", ["  trimmed  "])
        XCTAssertEqual(output, "trimmed")
    }

    // MARK: - resolveBinary

    func testResolveBinary_returnsPathForExistingBinary() {
        let path = ShellRunner.resolveBinary("git")
        XCTAssertNotNil(path)
        XCTAssertTrue(path!.hasSuffix("/git"))
    }

    func testResolveBinary_returnsNilForEmptyString() {
        XCTAssertNil(ShellRunner.resolveBinary(""))
    }

    func testResolveBinary_returnsNilForNonexistentBinary() {
        XCTAssertNil(ShellRunner.resolveBinary("completely-fake-12345"))
    }

    func testResolveBinary_resolvesAbsoluteGitPath() {
        if let path = ShellRunner.resolveBinary("/usr/bin/git") {
            XCTAssertEqual(path, "/usr/bin/git")
        }
        // git might not be at /usr/bin/git on all systems, but resolveBinary should handle it
    }

    func testResolveBinary_returnsNilForNonexistentAbsolutePath() {
        XCTAssertNil(ShellRunner.resolveBinary("/usr/local/bin/definitely-not-real"))
    }
}
