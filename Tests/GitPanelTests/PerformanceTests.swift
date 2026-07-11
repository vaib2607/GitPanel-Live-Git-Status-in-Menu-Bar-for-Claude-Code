import XCTest
@testable import GitPanelCore

final class PerformanceTests: XCTestCase {

    func testShellRunnerPerformance() async throws {
        for _ in 0..<100 {
            _ = try? await ShellRunner.run("/bin/echo", ["hello"])
        }
    }

    func testGitServicePorcelainParsingPerformance() {
        let sampleOutput = generatePorcelainOutput(fileCount: 1000)
        measure {
            for _ in 0..<100 {
                _ = GitService.parsePorcelainV2(sampleOutput)
            }
        }
    }

    func testUsageServiceJSONLParsingPerformance() async throws {
        let sampleJSONL = generateJSONL(lineCount: 10000)
        // Write to temp file and compute
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let projectsDir = tempDir.appendingPathComponent(".claude/projects")
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        let logFile = projectsDir.appendingPathComponent("perf-test.jsonl")
        try sampleJSONL.write(to: logFile, atomically: true, encoding: .utf8)
        setenv("HOME", tempDir.path, 1)
        _ = try? await UsageService.compute()
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Helpers

    private func generatePorcelainOutput(fileCount: Int) -> String {
        var lines = ["# branch.oid abc123", "# branch.head main", "# branch.upstream origin/main", "# branch.ab +5 -3"]
        for i in 0..<fileCount {
            lines.append("1 \\.\tM\ti00\(i).txt")
        }
        return lines.joined(separator: "\n")
    }

    private func generateJSONL(lineCount: Int) -> String {
        (0..<lineCount).map { i in
            "{\"timestamp\":\"2025-01-01T\(String(format: "%02d", i % 24)):00:00Z\",\"model\":\"claude-sonnet-4-20250514\",\"usage\":{\"input_tokens\":\(100 + i),\"output_tokens\":\(50 + i)}}"
        }.joined(separator: "\n")
    }
}
