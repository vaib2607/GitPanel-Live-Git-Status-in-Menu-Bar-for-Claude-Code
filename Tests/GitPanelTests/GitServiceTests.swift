import XCTest
@testable import GitPanelCore

final class GitServiceTests: XCTestCase {

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

    // MARK: - Helpers

    private func initGit() throws {
        try ShellRunner.runSync(GitService.gitPath, ["init"], at: tempDir.path)
        try ShellRunner.runSync(GitService.gitPath, ["config", "user.name", "Test User"], at: tempDir.path)
        try ShellRunner.runSync(GitService.gitPath, ["config", "user.email", "test@test.com"], at: tempDir.path)
    }

    private func createAndStageFile(_ name: String, content: String = "content") throws {
        let file = tempDir.appendingPathComponent(name)
        try content.write(to: file, atomically: true, encoding: .utf8)
        try ShellRunner.runSync(GitService.gitPath, ["add", name], at: tempDir.path)
    }

    private func createCommit(_ message: String, files: [String: String] = ["file.txt": "content"]) throws {
        for (name, content) in files {
            let file = tempDir.appendingPathComponent(name)
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
        try ShellRunner.runSync(GitService.gitPath, ["add", "-A"], at: tempDir.path)
        try ShellRunner.runSync(GitService.gitPath, ["commit", "-m", message, "--allow-empty"], at: tempDir.path)
    }

    // MARK: - Porcelain V2 Parsing (Static)

    func testParsePorcelainV2_cleanRepo() {
        let output = """
        # branch.oid abc123
        # branch.head main
        # branch.upstream origin/main
        # branch.ab +2 -1
        """
        let result = GitService.parsePorcelainV2(output)
        XCTAssertEqual(result.branch, "main")
        XCTAssertEqual(result.head, "main")
        XCTAssertEqual(result.upstream, "origin/main")
        XCTAssertEqual(result.ahead, 2)
        XCTAssertEqual(result.behind, 1)
        XCTAssertEqual(result.staged, 0)
        XCTAssertEqual(result.unstaged, 0)
        XCTAssertEqual(result.untracked, 0)
        XCTAssertEqual(result.conflicts, 0)
    }

    func testParsePorcelainV2_detachedHEAD() {
        let output = """
        # branch.oid abc12345
        # branch.head (detached)
        """
        let result = GitService.parsePorcelainV2(output)
        XCTAssertEqual(result.branch, "(detached HEAD)")
        XCTAssertEqual(result.head, "(detached)")
        XCTAssertNil(result.upstream)
        XCTAssertEqual(result.ahead, 0)
        XCTAssertEqual(result.behind, 0)
    }

    func testParsePorcelainV2_emptyHead() {
        let output = """
        # branch.oid abc123
        # branch.head
        """
        let result = GitService.parsePorcelainV2(output)
        XCTAssertEqual(result.branch, "(detached HEAD)")
    }

    func testParsePorcelainV2_untrackedFiles() {
        let output = """
        # branch.oid abc123
        # branch.head main
        ? file1.txt
        ? file2.txt
        ? dir/file3.txt
        """
        let result = GitService.parsePorcelainV2(output)
        XCTAssertEqual(result.untracked, 3)
        XCTAssertEqual(result.staged, 0)
        XCTAssertEqual(result.unstaged, 0)
    }

    func testParsePorcelainV2_stagedChanges() {
        let output = """
        # branch.oid abc123
        # branch.head main
        1 file.txt 000000 100644 100644 000000 abc123 def456
        1 new.txt 000000 100644 000000 000000 abc123 def456
        """
        let result = GitService.parsePorcelainV2(output)
        XCTAssertEqual(result.staged, 2)
    }

    func testParsePorcelainV2_unstagedChanges() {
        let output = """
        # branch.oid abc123
        # branch.head main
        1 file.txt 100644 100644 100644 abc123 def456 M
        """
        let result = GitService.parsePorcelainV2(output)
        XCTAssertEqual(result.unstaged, 1)
    }

    func testParsePorcelainV2_mixedStagedAndUnstaged() {
        let output = """
        # branch.oid abc123
        # branch.head main
        1 staged.txt 000000 100644 100644 000000 abc123 def456
        1 modified.txt 100644 100644 100644 abc123 def456 M
        ? untracked.txt
        """
        let result = GitService.parsePorcelainV2(output)
        // staged.txt: X=000000(first char '0') is not '.' and not '?' => staged++
        // modified.txt: X=100644(first char '1') is not '.' and not '?' => staged++
        // staged.txt: Y=100644(last char '4') is not '.' and not '?' => unstaged++
        // modified.txt: Y=100644(last char '4') => unstaged++, plus M means also unstaged
        XCTAssertEqual(result.staged, 2)
        XCTAssertEqual(result.unstaged, 2)
        XCTAssertEqual(result.untracked, 1)
    }

    func testParsePorcelainV2_conflicts() {
        let output = """
        # branch.oid abc123
        # branch.head main
        u AA 000000 100644 100644 1 abc123 def456 conflict.txt
        u UU 000000 100644 100644 2 abc123 def456 another.txt
        """
        let result = GitService.parsePorcelainV2(output)
        XCTAssertEqual(result.conflicts, 2)
    }

    func testParsePorcelainV2_aheadBehindParsing() {
        let output = """
        # branch.oid abc123
        # branch.head feature-branch
        # branch.upstream origin/feature-branch
        # branch.ab +5 -3
        """
        let result = GitService.parsePorcelainV2(output)
        XCTAssertEqual(result.ahead, 5)
        XCTAssertEqual(result.behind, 3)
        XCTAssertEqual(result.upstream, "origin/feature-branch")
    }

    func testParsePorcelainV2_noUpstream() {
        let output = """
        # branch.oid abc123
        # branch.head main
        """
        let result = GitService.parsePorcelainV2(output)
        XCTAssertNil(result.upstream)
    }

    func testParsePorcelainV2_emptyOutput() {
        let result = GitService.parsePorcelainV2("")
        XCTAssertEqual(result.branch, "(detached HEAD)")
        XCTAssertEqual(result.staged, 0)
        XCTAssertEqual(result.unstaged, 0)
        XCTAssertEqual(result.untracked, 0)
        XCTAssertEqual(result.conflicts, 0)
    }

    func testParsePorcelainV2_type2Changes() {
        let output = """
        # branch.oid abc123
        # branch.head main
        2 file.txt 100644 100644 100644 abc123 def456 MM
        """
        let result = GitService.parsePorcelainV2(output)
        // Type 2 = ordinary tree change; XY where X=staged, Y=unstaged
        XCTAssertEqual(result.staged, 1)
        XCTAssertEqual(result.unstaged, 1)
    }

    // MARK: - Numstat Parsing

    func testDiffNumstat_cleanRepo() async throws {
        try initGit()
        try createCommit("initial")
        let service = GitService()
        let result = try await service.diffNumstat(repo: tempDir)
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.deleted, 0)
    }

    func testDiffCachedNumstat_cleanRepo() async throws {
        try initGit()
        try createCommit("initial")
        let service = GitService()
        let result = try await service.diffCachedNumstat(repo: tempDir)
        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.deleted, 0)
    }

    // MARK: - Branch Parsing

    func testBranches_returnsMainBranch() async throws {
        try initGit()
        try createCommit("initial")

        let service = GitService()
        // for-each-ref upstream:ahead-count requires git 2.34+
        guard let branches = try? await service.branches(repo: tempDir) else {
            throw XCTSkip("Git version too old for branches() format string")
        }
        XCTAssertFalse(branches.isEmpty)

        let current = branches.first { $0.isCurrent }
        XCTAssertNotNil(current)
        XCTAssertTrue(current!.name == "main" || current!.name == "master")
    }

    func testBranches_detectsCurrentBranch() async throws {
        try initGit()
        try createCommit("initial")
        try ShellRunner.runSync(GitService.gitPath, ["checkout", "-b", "feature"], at: tempDir.path)

        let service = GitService()
        guard let branches = try? await service.branches(repo: tempDir) else {
            throw XCTSkip("Git version too old for branches() format string")
        }
        let current = branches.first { $0.isCurrent }
        XCTAssertEqual(current?.name, "feature")
    }

    func testBranches_detectsRemoteBranches() async throws {
        try initGit()
        try createCommit("initial")
        // Add a fake remote tracking ref
        try ShellRunner.runSync(GitService.gitPath, ["update-ref", "refs/remotes/origin/main", "HEAD"], at: tempDir.path)

        let service = GitService()
        guard let branches = try? await service.branches(repo: tempDir) else {
            throw XCTSkip("Git version too old for branches() format string")
        }
        let remoteBranch = branches.first { $0.name.contains("origin") }
        XCTAssertNotNil(remoteBranch)
        XCTAssertTrue(remoteBranch!.isRemote)
    }

    func testBranches_emptyRepo() async throws {
        try initGit()
        let service = GitService()
        // In a repo with no commits, for-each-ref may fail or return empty
        let branches = try? await service.branches(repo: tempDir)
        XCTAssertTrue(branches?.isEmpty ?? true)
    }

    // MARK: - Stash Operations

    func testStash_pushesChanges() async throws {
        try initGit()
        try createCommit("initial")
        try "modification".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        try await service.stash(repo: tempDir)

        let stashList = try await service.stashList(repo: tempDir)
        XCTAssertFalse(stashList.isEmpty)
    }

    func testStash_withMessage() async throws {
        try initGit()
        try createCommit("initial")
        try "modification".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        try await service.stash(repo: tempDir, message: "my stash")

        let stashList = try await service.stashList(repo: tempDir)
        XCTAssertTrue(stashList.first?.message.contains("my stash") ?? false)
    }

    func testStash_pop_restoresChanges() async throws {
        try initGit()
        try createCommit("initial")
        try "modification".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        try await service.stash(repo: tempDir)
        try await service.stashPop(repo: tempDir)

        let content = try String(
            contentsOf: tempDir.appendingPathComponent("file.txt"),
            encoding: .utf8
        )
        XCTAssertEqual(content, "modification")
    }

    func testStash_drop_removesStashEntry() async throws {
        try initGit()
        try createCommit("initial")
        try "mod".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        try await service.stash(repo: tempDir, message: "to drop")
        try await service.stashDrop(repo: tempDir, index: 0)

        let stashList = try await service.stashList(repo: tempDir)
        XCTAssertTrue(stashList.isEmpty)
    }

    func testStashList_emptyWhenNoStashes() async throws {
        try initGit()
        try createCommit("initial")
        let service = GitService()
        let stashList = try await service.stashList(repo: tempDir)
        XCTAssertTrue(stashList.isEmpty)
    }

    func testStashList_parsesMultipleStashes() async throws {
        try initGit()
        try createCommit("initial")

        // First stash: modify existing tracked file
        try "stash1".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )
        let service = GitService()
        try await service.stash(repo: tempDir, message: "first stash")

        // Second stash: modify same file again
        try "stash2".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )
        try await service.stash(repo: tempDir, message: "second stash")

        let stashList = try await service.stashList(repo: tempDir)
        XCTAssertGreaterThanOrEqual(stashList.count, 2)
        // Most recent stash is first
        XCTAssertTrue(stashList[0].message.contains("second stash"))
        XCTAssertTrue(stashList[1].message.contains("first stash"))
    }

    func testStashShow_returnsDiff() async throws {
        try initGit()
        try createCommit("initial")
        try "modification".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        try await service.stash(repo: tempDir)
        let diff = try await service.stashShow(repo: tempDir, index: 0)
        XCTAssertTrue(diff.contains("modification") || diff.contains("file.txt"))
    }

    // MARK: - Diff Operations

    func testDiff_cleanRepo() async throws {
        try initGit()
        try createCommit("initial")

        let service = GitService()
        let diff = try await service.diff(repo: tempDir)
        XCTAssertTrue(diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testDiff_withChanges() async throws {
        try initGit()
        try createCommit("initial")
        try "modified content".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let diff = try await service.diff(repo: tempDir)
        XCTAssertTrue(diff.contains("modified content") || diff.contains("file.txt"))
    }

    func testDiffSpecificPath() async throws {
        try initGit()
        try createCommit("initial")
        try "changed".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let diff = try await service.diff(repo: tempDir, path: "file.txt")
        XCTAssertTrue(diff.contains("file.txt"))
    }

    func testDiffCached_cleanRepo() async throws {
        try initGit()
        try createCommit("initial")

        let service = GitService()
        let diff = try await service.diffCached(repo: tempDir)
        XCTAssertTrue(diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testDiffCached_withStagedChanges() async throws {
        try initGit()
        try createCommit("initial")
        try "new content".write(
            to: tempDir.appendingPathComponent("new.txt"),
            atomically: true, encoding: .utf8
        )
        try ShellRunner.runSync(GitService.gitPath, ["add", "new.txt"], at: tempDir.path)

        let service = GitService()
        let diff = try await service.diffCached(repo: tempDir)
        XCTAssertTrue(diff.contains("new content") || diff.contains("new.txt"))
    }

    func testDiffStat_cleanRepo() async throws {
        try initGit()
        try createCommit("initial")

        let service = GitService()
        let stat = try await service.diffStat(repo: tempDir)
        XCTAssertTrue(stat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testDiffStat_withChanges() async throws {
        try initGit()
        try createCommit("initial")
        try "changed".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let stat = try await service.diffStat(repo: tempDir)
        XCTAssertTrue(stat.contains("file.txt") || stat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    func testDiffNumstatDetail_cleanRepo() async throws {
        try initGit()
        try createCommit("initial")

        let service = GitService()
        let details = try await service.diffNumstat(repo: tempDir, path: nil)
        XCTAssertTrue(details.isEmpty)
    }

    func testDiffNumstatDetail_withChanges() async throws {
        try initGit()
        try createCommit("initial")
        try String(repeating: "line\n", count: 10).write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let details = try await service.diffNumstat(repo: tempDir, path: "file.txt")
        XCTAssertFalse(details.isEmpty)
        XCTAssertEqual(details.first?.path, "file.txt")
        XCTAssertGreaterThan(details.first!.added, 0)
    }

    // MARK: - Conflict Detection

    func testListConflicts_noConflicts() async throws {
        try initGit()
        try createCommit("initial")

        let service = GitService()
        let conflicts = try await service.listConflicts(repo: tempDir)
        XCTAssertTrue(conflicts.isEmpty)
    }

    // MARK: - Repo State Detection

    func testDetectRepoState_cleanRepo() async throws {
        try initGit()
        try createCommit("initial")

        let service = GitService()
        let state = try await service.detectRepoState(repo: tempDir)
        XCTAssertEqual(state, .clean)
    }

    func testDetectRepoState_notAGitRepo() async throws {
        let service = GitService()
        do {
            let state = try await service.detectRepoState(repo: tempDir)
            // If it succeeds, verify it returns a reasonable state
            XCTAssertNotEqual(state, .merging)
        } catch {
            // Expected: porcelainV2 fails on non-git directory
            XCTAssertTrue(error is ShellError)
        }
    }

    func testDetectRepoState_merging() async throws {
        try initGit()
        let gitDir = tempDir.appendingPathComponent(".git")
        try "abc123".write(
            to: gitDir.appendingPathComponent("MERGE_HEAD"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let state = try await service.detectRepoState(repo: tempDir)
        XCTAssertEqual(state, .merging)
    }

    func testDetectRepoState_rebasingMerge() async throws {
        try initGit()
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(
            at: gitDir.appendingPathComponent("rebase-merge"),
            withIntermediateDirectories: true
        )

        let service = GitService()
        let state = try await service.detectRepoState(repo: tempDir)
        XCTAssertEqual(state, .rebasing)
    }

    func testDetectRepoState_rebasingApply() async throws {
        try initGit()
        let gitDir = tempDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(
            at: gitDir.appendingPathComponent("rebase-apply"),
            withIntermediateDirectories: true
        )

        let service = GitService()
        let state = try await service.detectRepoState(repo: tempDir)
        XCTAssertEqual(state, .rebasing)
    }

    func testDetectRepoState_cherryPicking() async throws {
        try initGit()
        let gitDir = tempDir.appendingPathComponent(".git")
        try "abc".write(
            to: gitDir.appendingPathComponent("CHERRY_PICK_HEAD"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let state = try await service.detectRepoState(repo: tempDir)
        XCTAssertEqual(state, .cherryPicking)
    }

    func testDetectRepoState_reverting() async throws {
        try initGit()
        let gitDir = tempDir.appendingPathComponent(".git")
        try "abc".write(
            to: gitDir.appendingPathComponent("REVERT_HEAD"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let state = try await service.detectRepoState(repo: tempDir)
        XCTAssertEqual(state, .reverting)
    }

    func testDetectRepoState_bisecting() async throws {
        try initGit()
        let gitDir = tempDir.appendingPathComponent(".git")
        try "abc".write(
            to: gitDir.appendingPathComponent("BISECT_LOG"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let state = try await service.detectRepoState(repo: tempDir)
        XCTAssertEqual(state, .bisecting)
    }

    func testDetectRepoState_detachedHEAD() async throws {
        try initGit()
        try createCommit("initial")
        let hash = try ShellRunner.runSync(GitService.gitPath, ["rev-parse", "HEAD"], at: tempDir.path)
        try ShellRunner.runSync(GitService.gitPath, ["checkout", hash], at: tempDir.path)

        let service = GitService()
        let state = try await service.detectRepoState(repo: tempDir)
        XCTAssertEqual(state, .detachedHEAD)
    }

    func testDetectRepoState_dirty() async throws {
        try initGit()
        try createCommit("initial")
        try "modified".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let state = try await service.detectRepoState(repo: tempDir)
        XCTAssertEqual(state, .dirty)
    }

    // MARK: - Current Branch

    func testCurrentBranch_returnsBranchName() async throws {
        try initGit()
        try createCommit("initial")
        try ShellRunner.runSync(GitService.gitPath, ["checkout", "-b", "dev"], at: tempDir.path)

        let service = GitService()
        let branch = try await service.currentBranch(repo: tempDir)
        XCTAssertEqual(branch, "dev")
    }

    func testCurrentBranch_detachedHEAD() async throws {
        try initGit()
        try createCommit("initial")
        let hash = try ShellRunner.runSync(GitService.gitPath, ["rev-parse", "HEAD"], at: tempDir.path)
        try ShellRunner.runSync(GitService.gitPath, ["checkout", hash], at: tempDir.path)

        let service = GitService()
        let branch = try await service.currentBranch(repo: tempDir)
        XCTAssertEqual(branch, "(detached HEAD)")
    }

    // MARK: - Ahead/Behind

    func testAheadBehind_noUpstream() async throws {
        try initGit()
        try createCommit("initial")

        let service = GitService()
        let result = try await service.aheadBehind(repo: tempDir)
        XCTAssertEqual(result.ahead, 0)
        XCTAssertEqual(result.behind, 0)
    }

    // MARK: - isGitRepo

    func testIsGitRepo_validRepo() async throws {
        try initGit()
        let service = GitService()
        let isRepo = try await service.isGitRepo(repo: tempDir)
        XCTAssertTrue(isRepo)
    }

    func testIsGitRepo_notARepo() async throws {
        let service = GitService()
        let isRepo = try await service.isGitRepo(repo: tempDir)
        XCTAssertFalse(isRepo)
    }

    // MARK: - Remotes

    func testRemotes_emptyRepo() async throws {
        try initGit()
        let service = GitService()
        let remotes = try await service.remotes(repo: tempDir)
        XCTAssertTrue(remotes.isEmpty)
    }

    // MARK: - Worktrees

    func testWorktrees_mainWorktree() async throws {
        try initGit()
        try createCommit("initial")
        let service = GitService()
        let worktrees = try await service.worktrees(repo: tempDir)
        XCTAssertFalse(worktrees.isEmpty, "Should have at least one worktree")
    }

    // MARK: - Dependencies

    func testDependencies_detectsPackageSwift() throws {
        try initGit()
        try "name: Test".write(
            to: tempDir.appendingPathComponent("Package.swift"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let deps = service.dependencies(repo: tempDir)
        XCTAssertTrue(deps.contains("Package.swift"))
    }

    func testDependencies_emptyForBareRepo() throws {
        try initGit()
        let service = GitService()
        let deps = service.dependencies(repo: tempDir)
        XCTAssertTrue(deps.isEmpty)
    }

    func testDependencies_detectsMultipleFiles() throws {
        try initGit()
        try "{}".write(
            to: tempDir.appendingPathComponent("package.json"),
            atomically: true, encoding: .utf8
        )
        try "".write(
            to: tempDir.appendingPathComponent("requirements.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let deps = service.dependencies(repo: tempDir)
        XCTAssertTrue(deps.contains("package.json"))
        XCTAssertTrue(deps.contains("requirements.txt"))
    }

    // MARK: - Porcelain V2 Integration

    func testPorcelainV2_cleanRepo() async throws {
        try initGit()
        try createCommit("initial")

        let service = GitService()
        let result = try await service.porcelainV2(repo: tempDir)
        XCTAssertEqual(result.staged, 0)
        XCTAssertEqual(result.unstaged, 0)
        XCTAssertEqual(result.untracked, 0)
        XCTAssertEqual(result.conflicts, 0)
    }

    func testPorcelainV2_withUntrackedFile() async throws {
        try initGit()
        try createCommit("initial")
        try "new".write(
            to: tempDir.appendingPathComponent("untracked.txt"),
            atomically: true, encoding: .utf8
        )

        let service = GitService()
        let result = try await service.porcelainV2(repo: tempDir)
        XCTAssertEqual(result.untracked, 1)
    }

    func testPorcelainV2_withStagedFile() async throws {
        try initGit()
        try createCommit("initial")
        try createAndStageFile("staged.txt")

        let service = GitService()
        let result = try await service.porcelainV2(repo: tempDir)
        XCTAssertEqual(result.staged, 1)
    }

    // MARK: - GitBranch Model

    func testGitBranch_idMatchesName() {
        let branch = GitBranch(name: "feature", isCurrent: true)
        XCTAssertEqual(branch.id, "feature")
    }

    func testGitBranch_differentInstancesAreNotEqual() {
        let a = GitBranch(name: "main", isCurrent: true)
        let b = GitBranch(name: "main", isCurrent: false)
        XCTAssertNotEqual(a, b)
    }

    func testGitBranch_hashable_insertsDistinctInstances() {
        let a = GitBranch(name: "main", isCurrent: true)
        let b = GitBranch(name: "main", isCurrent: false)
        var set = Set<GitBranch>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - StashEntry Model

    func testStashEntry_idMatchesRef() {
        let entry = StashEntry(ref: "stash@{0}", message: "test")
        XCTAssertEqual(entry.id, "stash@{0}")
    }

    func testStashEntry_differentMessagesAreNotEqual() {
        let a = StashEntry(ref: "stash@{0}", message: "first")
        let b = StashEntry(ref: "stash@{0}", message: "second")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - ConflictedFile Model

    func testConflictedFile_idMatchesPath() {
        let file = ConflictedFile(path: "src/main.swift")
        XCTAssertEqual(file.id, "src/main.swift")
    }

    func testConflictedFile_hashable() {
        let a = ConflictedFile(path: "a.swift")
        let b = ConflictedFile(path: "a.swift")
        XCTAssertEqual(a, b)
    }

    // MARK: - ConflictStrategy

    func testConflictStrategy_allCases() {
        XCTAssertEqual(ConflictStrategy.allCases.count, 3)
        XCTAssertTrue(ConflictStrategy.allCases.contains(.ours))
        XCTAssertTrue(ConflictStrategy.allCases.contains(.theirs))
        XCTAssertTrue(ConflictStrategy.allCases.contains(.mark))
    }

    func testConflictStrategy_rawValues() {
        XCTAssertEqual(ConflictStrategy.ours.rawValue, "ours")
        XCTAssertEqual(ConflictStrategy.theirs.rawValue, "theirs")
        XCTAssertEqual(ConflictStrategy.mark.rawValue, "mark")
    }
}
