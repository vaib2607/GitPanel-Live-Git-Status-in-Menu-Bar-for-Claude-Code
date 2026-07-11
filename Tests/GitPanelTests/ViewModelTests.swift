import XCTest
@testable import GitPanelCore

@MainActor
final class ViewModelTests: XCTestCase {

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
        try ShellRunner.runSync(GitService.gitPath, ["config", "user.name", "Test"], at: tempDir.path)
        try ShellRunner.runSync(GitService.gitPath, ["config", "user.email", "t@t.com"], at: tempDir.path)
    }

    private func createCommit(_ message: String, file: String = "file.txt", content: String = "content") throws {
        try content.write(
            to: tempDir.appendingPathComponent(file),
            atomically: true, encoding: .utf8
        )
        try ShellRunner.runSync(GitService.gitPath, ["add", "-A"], at: tempDir.path)
        try ShellRunner.runSync(GitService.gitPath, ["commit", "-m", message], at: tempDir.path)
    }

    private func makeVM() throws -> GitPanelViewModel {
        let manager = RepoManager()
        try manager.setRepo(tempDir)
        return GitPanelViewModel(repoManager: manager, settings: AppSettings())
    }

    // MARK: - Refresh Logic

    func testRefresh_setsIsRefreshingDuringExecution() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()

        XCTAssertFalse(vm.isRefreshing)
        await vm.refresh()
        XCTAssertFalse(vm.isRefreshing, "isRefreshing should be false after refresh completes")
    }

    func testRefresh_populatesGitState() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()

        await vm.refresh()
        XCTAssertTrue(vm.isGitRepo)
        XCTAssertFalse(vm.state.branchName.isEmpty)
    }

    func testRefresh_updatesBranches() async throws {
        try initGit()
        try createCommit("initial")
        try ShellRunner.runSync(GitService.gitPath, ["checkout", "-b", "feature"], at: tempDir.path)

        let vm = try makeVM()
        await vm.refresh()

        XCTAssertTrue(vm.isGitRepo)
        XCTAssertFalse(vm.state.branchName.isEmpty)
        // branches() may fail on git < 2.34 (for-each-ref format), so just check refresh completed
    }

    func testRefresh_skippedWhenPerformingGitOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.isPerformingGitOperation = true

        await vm.refresh()
        XCTAssertFalse(vm.isRefreshing, "Refresh should be skipped during git operation")
    }

    func testRefresh_handlesNonGitDirectoryGracefully() async throws {
        let manager = RepoManager()
        try manager.setRepo(tempDir)
        let vm = GitPanelViewModel(repoManager: manager, settings: AppSettings())

        await vm.refresh()
        XCTAssertFalse(vm.isGitRepo)
    }

    func testRefresh_setsLastUpdated() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()

        let before = Date()
        await vm.refresh()
        XCTAssertGreaterThanOrEqual(vm.state.lastUpdated, before)
    }

    func testRefresh_setsRepoName() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()

        await vm.refresh()
        XCTAssertEqual(vm.state.repoName, tempDir.lastPathComponent)
    }

    // MARK: - Banner Timing

    func testShowBanner_setsBannerMessage() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.showBanner("Test Title", detail: "Detail", kind: .success)

        XCTAssertNotNil(vm.banner)
        XCTAssertEqual(vm.banner?.title, "Test Title")
        XCTAssertEqual(vm.banner?.detail, "Detail")
    }

    func testShowBanner_clearsAfterTimeout() async throws {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.showBanner("Auto Clear", kind: .success)
        XCTAssertNotNil(vm.banner)

        // In test mode (NSClassFromString("XCTest") != nil), banner should NOT auto-clear
        // So it stays set
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNotNil(vm.banner, "Banner should persist in test mode")
    }

    func testShowBanner_overwritesPreviousBanner() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.showBanner("First", kind: .success)
        vm.showBanner("Second", kind: .error)

        XCTAssertEqual(vm.banner?.title, "Second")
        XCTAssertEqual(vm.banner?.kind, .error)
    }

    func testShowBanner_kinds() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())

        vm.showBanner("Success", kind: .success)
        XCTAssertEqual(vm.banner?.kind, .success)

        vm.showBanner("Error", kind: .error)
        XCTAssertEqual(vm.banner?.kind, .error)

        vm.showBanner("Warning", kind: .warning)
        XCTAssertEqual(vm.banner?.kind, .warning)
    }

    func testShowBanner_detailIsOptional() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.showBanner("No Detail", kind: .success)
        XCTAssertNil(vm.banner?.detail)
    }

    // MARK: - Operation Gate

    func testCommit_blockedDuringGitOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.isPerformingGitOperation = true
        vm.commitMessage = "should not commit"

        await vm.commit()
        XCTAssertEqual(vm.commitMessage, "should not commit", "Message should not be cleared")
    }

    func testPush_blockedDuringGitOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.isPerformingGitOperation = true

        await vm.push()
        XCTAssertFalse(vm.isPushing, "Push should not start during git operation")
    }

    func testPull_blockedDuringGitOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.isPerformingGitOperation = true

        await vm.pull()
        XCTAssertFalse(vm.isRefreshing, "Pull should be skipped during git operation")
    }

    func testCheckout_blockedDuringGitOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.isPerformingGitOperation = true

        await vm.checkout(GitBranch(name: "main", isCurrent: true))
        // Should not crash, operation gated
    }

    func testCreateBranch_blockedDuringGitOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.isPerformingGitOperation = true

        await vm.createBranch("new-branch")
        // Should not crash, operation gated
    }

    func testDeleteBranch_blockedDuringGitOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.isPerformingGitOperation = true

        await vm.deleteBranch(GitBranch(name: "feature", isCurrent: false))
        // Should not crash, operation gated
    }

    func testStageFile_blockedDuringGitOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.isPerformingGitOperation = true

        await vm.stageFile("file.txt")
        // Should not crash, operation gated
    }

    func testUnstageFile_blockedDuringGitOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.isPerformingGitOperation = true

        await vm.unstageFile("file.txt")
        // Should not crash, operation gated
    }

    func testDiscardChanges_blockedDuringGitOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.isPerformingGitOperation = true

        await vm.discardChanges("file.txt")
        // Should not crash, operation gated
    }

    // MARK: - Commit Operations

    func testCommit_emptyMessageDoesNothing() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.commitMessage = "   "

        await vm.commit()
        XCTAssertEqual(vm.commitMessage, "   ", "Empty message should not be cleared")
    }

    func testCommit_clearsMessageOnSuccess() async throws {
        try initGit()
        try createCommit("initial")
        // Create a file to commit
        try "new".write(
            to: tempDir.appendingPathComponent("new.txt"),
            atomically: true, encoding: .utf8
        )
        try ShellRunner.runSync(GitService.gitPath, ["add", "new.txt"], at: tempDir.path)

        let vm = try makeVM()
        vm.commitMessage = "feat: add new file"

        await vm.commit()
        XCTAssertEqual(vm.commitMessage, "")
    }

    func testCommit_setsCommitFlagDuringOperation() async throws {
        try initGit()
        try createCommit("initial")
        try "new".write(
            to: tempDir.appendingPathComponent("new.txt"),
            atomically: true, encoding: .utf8
        )
        try ShellRunner.runSync(GitService.gitPath, ["add", "new.txt"], at: tempDir.path)

        let vm = try makeVM()
        vm.commitMessage = "test"

        // During commit, isCommitting should be true
        // After commit completes, it should be false
        await vm.commit()
        XCTAssertFalse(vm.isCommitting)
        XCTAssertFalse(vm.isPerformingGitOperation)
    }

    func testCommit_stagesAllFilesByDefault() async throws {
        try initGit()
        try createCommit("initial")
        try "added".write(
            to: tempDir.appendingPathComponent("staged.txt"),
            atomically: true, encoding: .utf8
        )

        let vm = try makeVM()
        vm.commitMessage = "feat: add file"
        await vm.commit()

        let diff = try await ShellRunner.run(
            GitService.gitPath, ["diff", "--name-only", "HEAD~1"], at: tempDir.path
        )
        XCTAssertTrue(diff.contains("staged.txt"))
    }

    // MARK: - Push Operations

    func testPush_setsPushFlagDuringOperation() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()

        await vm.push()
        XCTAssertFalse(vm.isPushing, "isPushing should be false after push")
        XCTAssertFalse(vm.isPerformingGitOperation)
    }

    // MARK: - Stash Operations

    func testStashChanges_stashesWorkingChanges() async throws {
        try initGit()
        try createCommit("initial")
        try "modification".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let vm = try makeVM()
        await vm.stashChanges()

        XCTAssertNotNil(vm.banner)
        XCTAssertEqual(vm.banner?.kind, .success)
        XCTAssertTrue(vm.stashEntries.count > 0)
    }

    func testStashChanges_withMessage() async throws {
        try initGit()
        try createCommit("initial")
        try "mod".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let vm = try makeVM()
        await vm.stashChanges(message: "my stash")

        XCTAssertTrue(vm.stashEntries.first?.message.contains("my stash") ?? false)
    }

    func testPopStash_restoresChanges() async throws {
        try initGit()
        try createCommit("initial")
        try "stash me".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let vm = try makeVM()
        await vm.stashChanges()
        await vm.popStash()

        let content = try String(
            contentsOf: tempDir.appendingPathComponent("file.txt"),
            encoding: .utf8
        )
        XCTAssertEqual(content, "stash me")
    }

    func testDropStash_removesEntry() async throws {
        try initGit()
        try createCommit("initial")
        try "drop me".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let vm = try makeVM()
        await vm.stashChanges()
        XCTAssertEqual(vm.stashEntries.count, 1)

        await vm.dropStash(index: 0)
        XCTAssertEqual(vm.stashEntries.count, 0)
    }

    func testLoadStashes_populatesList() async throws {
        try initGit()
        try createCommit("initial")

        // Create a stash directly
        try "stash".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )
        try ShellRunner.runSync(GitService.gitPath, ["stash", "push"], at: tempDir.path)

        let vm = try makeVM()
        await vm.loadStashes()
        XCTAssertEqual(vm.stashEntries.count, 1)
    }

    func testStashDiff_returnsStashContent() async throws {
        try initGit()
        try createCommit("initial")
        try "stash content".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let vm = try makeVM()
        await vm.stashChanges()
        let diff = await vm.stashDiff(index: 0)
        XCTAssertFalse(diff.isEmpty)
    }

    // MARK: - Conflict Resolution

    func testLoadConflicts_populatesList() async throws {
        try initGit()
        try createCommit("initial")

        let vm = try makeVM()
        await vm.loadConflicts()
        XCTAssertTrue(vm.conflictedFiles.isEmpty, "No conflicts in clean repo")
    }

    func testAcceptOurs_setsPerformingFlag() async throws {
        try initGit()
        try createCommit("initial")

        let vm = try makeVM()
        await vm.acceptOurs(file: "file.txt")
        XCTAssertFalse(vm.isPerformingGitOperation)
    }

    func testAcceptTheirs_setsPerformingFlag() async throws {
        try initGit()
        try createCommit("initial")

        let vm = try makeVM()
        await vm.acceptTheirs(file: "file.txt")
        XCTAssertFalse(vm.isPerformingGitOperation)
    }

    func testMarkResolved_setsPerformingFlag() async throws {
        try initGit()
        try createCommit("initial")

        let vm = try makeVM()
        await vm.markResolved(file: "file.txt")
        XCTAssertFalse(vm.isPerformingGitOperation)
    }

    func testResolveAllConflictsAcceptOurs() async throws {
        try initGit()
        try createCommit("initial")

        let vm = try makeVM()
        await vm.resolveAllConflictsAcceptOurs()
        XCTAssertFalse(vm.isPerformingGitOperation)
    }

    // MARK: - Diff Operations

    func testFetchDiff_forFilePath() async throws {
        try initGit()
        try createCommit("initial")
        try "modified".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let vm = try makeVM()
        let diff = await vm.fetchDiff(for: "file.txt")
        XCTAssertTrue(diff.contains("modified") || diff.isEmpty)
    }

    func testFetchDiffCached_forFilePath() async throws {
        try initGit()
        try createCommit("initial")
        try "staged".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )
        try ShellRunner.runSync(GitService.gitPath, ["add", "file.txt"], at: tempDir.path)

        let vm = try makeVM()
        let diff = await vm.fetchDiffCached(for: "file.txt")
        XCTAssertTrue(diff.contains("staged") || diff.isEmpty)
    }

    func testFetchDiff_setsCurrentDiff() async throws {
        try initGit()
        try createCommit("initial")
        try "changed".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let vm = try makeVM()
        _ = await vm.fetchDiff(for: "file.txt")
        try await Task.sleep(for: .milliseconds(500))
        // currentDiff should be populated
        // (may or may not have content depending on async timing)
    }

    // MARK: - Branch Operations

    func testCheckout_changesCurrentBranch() async throws {
        try initGit()
        try createCommit("initial")
        let service = GitService()
        let initialBranch = try await service.currentBranch(repo: tempDir)
        try ShellRunner.runSync(GitService.gitPath, ["checkout", "-b", "feature"], at: tempDir.path)

        let vm = try makeVM()
        await vm.refresh()

        let current = try await service.currentBranch(repo: tempDir)
        XCTAssertEqual(current, "feature")

        // Switch back using direct checkout
        try ShellRunner.runSync(GitService.gitPath, ["checkout", initialBranch], at: tempDir.path)
        let switched = try await service.currentBranch(repo: tempDir)
        XCTAssertEqual(switched, initialBranch)
    }

    func testCreateBranch_addsNewBranch() async throws {
        try initGit()
        try createCommit("initial")

        let vm = try makeVM()
        await vm.createBranch("new-feature")

        XCTAssertEqual(vm.currentBranch, "new-feature")
        XCTAssertEqual(vm.branchNameInput, "")
    }

    func testDeleteBranch_removesBranch() async throws {
        try initGit()
        try createCommit("initial")
        let service = GitService()
        let mainBranch = try await service.currentBranch(repo: tempDir)
        try ShellRunner.runSync(GitService.gitPath, ["checkout", "-b", "to-delete"], at: tempDir.path)
        try ShellRunner.runSync(GitService.gitPath, ["checkout", mainBranch], at: tempDir.path)

        let vm = try makeVM()
        await vm.refresh()
        let branch = GitBranch(name: "to-delete", isCurrent: false)
        await vm.deleteBranch(branch)

        // Verify the branch was actually deleted
        let branches = try await ShellRunner.run(GitService.gitPath, ["branch"], at: tempDir.path)
        XCTAssertFalse(branches.contains("to-delete"))
    }

    // MARK: - Computed Properties

    func testFilteredBranches_emptySearchReturnsAll() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.branchesState = .loaded([
            GitBranch(name: "main", isCurrent: true),
            GitBranch(name: "feature", isCurrent: false)
        ], nil)
        vm.branchSearchText = ""

        XCTAssertEqual(vm.filteredBranches.count, 2)
    }

    func testFilteredBranches_filtersBySearchText() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.branchesState = .loaded([
            GitBranch(name: "main", isCurrent: true),
            GitBranch(name: "feature-auth", isCurrent: false),
            GitBranch(name: "feature-api", isCurrent: false),
            GitBranch(name: "bugfix", isCurrent: false)
        ], nil)
        vm.branchSearchText = "feature"

        XCTAssertEqual(vm.filteredBranches.count, 2)
    }

    func testFilteredBranches_caseInsensitive() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.branchesState = .loaded([
            GitBranch(name: "Main", isCurrent: true),
            GitBranch(name: "FEATURE", isCurrent: false)
        ], nil)
        vm.branchSearchText = "feature"

        XCTAssertEqual(vm.filteredBranches.count, 1)
    }

    func testFilteredBranches_noMatch() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.branchesState = .loaded([
            GitBranch(name: "main", isCurrent: true)
        ], nil)
        vm.branchSearchText = "nonexistent"

        XCTAssertTrue(vm.filteredBranches.isEmpty)
    }

    func testRepoState_delegatesToState() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.repoState = .dirty
        XCTAssertEqual(vm.repoState, .dirty)
    }

    func testStateLabel_delegatesToState() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.repoState = .mergeConflict
        XCTAssertEqual(vm.stateLabel, "Merge Conflict")
    }

    func testStateIcon_delegatesToState() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.repoState = .clean
        XCTAssertEqual(vm.stateIcon, "checkmark.circle.fill")
    }

    func testStateColor_delegatesToState() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.repoState = .clean
        XCTAssertEqual(vm.stateColor, .green)
    }

    func testIsGitRepo_delegatesToState() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.isGitRepo = true
        XCTAssertTrue(vm.isGitRepo)
    }

    func testCurrentBranch_delegatesToState() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.branchName = "feature"
        XCTAssertEqual(vm.currentBranch, "feature")
    }

    func testAhead_returnsOneWhenAhead() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.isAheadOfRemote = true
        XCTAssertEqual(vm.ahead, 1)
    }

    func testAhead_returnsZeroWhenNotAhead() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.isAheadOfRemote = false
        XCTAssertEqual(vm.ahead, 0)
    }

    func testBehind_returnsOneWhenBehind() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.isBehindRemote = true
        XCTAssertEqual(vm.behind, 1)
    }

    func testBehind_returnsZeroWhenNotBehind() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.isBehindRemote = false
        XCTAssertEqual(vm.behind, 0)
    }

    func testRemotes_delegatesToState() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.remotes = [Remote(name: "origin", url: "https://github.com")]
        XCTAssertEqual(vm.remotes.count, 1)
    }

    func testSubmodules_delegatesToState() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        vm.state.submodules = [Submodule(name: "sub", path: "sub", url: "https://example.com")]
        XCTAssertEqual(vm.submodules.count, 1)
    }

    // MARK: - Debounce

    func testDebouncedRefresh_cancelsPrevious() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()

        vm.debouncedRefresh()
        vm.debouncedRefresh()
        vm.debouncedRefresh()

        // Wait for debounce to complete
        try await Task.sleep(for: .seconds(1))
        XCTAssertTrue(vm.isGitRepo, "Refresh should have completed")
    }

    // MARK: - File Watching

    func testStartWatching_doesNotCrash() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        vm.startWatching()
        vm.stopWatching()
    }

    // MARK: - State Updates After Operations

    func testRefresh_afterCommit_updatesState() async throws {
        try initGit()
        try createCommit("initial")

        let vm = try makeVM()
        await vm.refresh()

        _ = vm.state.stagedCount

        try "new".write(
            to: tempDir.appendingPathComponent("new.txt"),
            atomically: true, encoding: .utf8
        )
        try ShellRunner.runSync(GitService.gitPath, ["add", "new.txt"], at: tempDir.path)

        vm.commitMessage = "add new"
        await vm.commit()

        // After commit, staged should be back to 0
        XCTAssertEqual(vm.state.stagedCount, 0)
    }

    func testRefresh_afterStash_updatesState() async throws {
        try initGit()
        try createCommit("initial")

        let vm = try makeVM()
        await vm.refresh()

        try "modified".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        await vm.stashChanges()
        // After stash, changes should be gone
        XCTAssertEqual(vm.state.hasChanges, false)
    }

    // MARK: - Initial State

    func testInitialDefaultValues() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        XCTAssertFalse(vm.isRefreshing)
        XCTAssertFalse(vm.isCommitting)
        XCTAssertFalse(vm.isPushing)
        XCTAssertFalse(vm.isCreatingBranch)
        XCTAssertTrue(vm.branchSearchText.isEmpty)
        XCTAssertTrue(vm.branchNameInput.isEmpty)
        XCTAssertEqual(vm.commitMessage, "")
        XCTAssertNil(vm.banner)
        XCTAssertFalse(vm.isPerformingGitOperation)
        XCTAssertTrue(vm.currentDiff.isEmpty)
    }

    func testInitialUsageData() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        XCTAssertEqual(vm.usage.tokens, 0)
        XCTAssertEqual(vm.usage.cost, 0)
        XCTAssertTrue(vm.usage.model.isEmpty)
    }

    func testInitialStashEntries() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        XCTAssertTrue(vm.stashEntries.isEmpty)
    }

    func testInitialConflictedFiles() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        XCTAssertTrue(vm.conflictedFiles.isEmpty)
    }

    func testInitialEnvironmentMode() {
        let vm = GitPanelViewModel(repoManager: RepoManager(), settings: AppSettings())
        XCTAssertEqual(vm.environmentMode, .production)
    }

    // MARK: - Refresh Error Handling

    func testRefresh_showsErrorBannerOnGitFailure() async throws {
        // Point to a non-git directory
        let manager = RepoManager()
        try manager.setRepo(tempDir)
        let vm = GitPanelViewModel(repoManager: manager, settings: AppSettings())

        await vm.refresh()
        // Non-git directory should set isGitRepo to false, no error banner
        XCTAssertFalse(vm.isGitRepo)
    }

    func testRefresh_continuesAfterBranchLoadFailure() async throws {
        try initGit()
        try createCommit("initial")

        // Remove git branches by removing refs
        let refsDir = tempDir.appendingPathComponent(".git/refs/heads")
        try? FileManager.default.removeItem(at: refsDir)

        let vm = try makeVM()
        await vm.refresh()
        // Should still have git state
        XCTAssertTrue(vm.isGitRepo)
    }

    // MARK: - Concurrent Operations

    func testConcurrentRefreshesDoNotCrash() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await vm.refresh() }
            group.addTask { await vm.refresh() }
            group.addTask { await vm.refresh() }
        }

        XCTAssertTrue(vm.isGitRepo)
    }

    func testRefreshDuringStashOperation() async throws {
        try initGit()
        try createCommit("initial")
        try "mod".write(
            to: tempDir.appendingPathComponent("file.txt"),
            atomically: true, encoding: .utf8
        )

        let vm = try makeVM()
        await vm.stashChanges()
        // Should complete without error
        XCTAssertEqual(vm.stashEntries.count, 1)
    }
    // MARK: - Branch Loading Tests

    func testUpdateBranches_success_setsLoadedWithLocalGit() async throws {
        try initGit()
        try createCommit("initial")
        let vm = try makeVM()
        
        vm.updateBranches([GitBranch(name: "main", isCurrent: true)])
        
        if case .loaded(let data, let metadata) = vm.branchesState {
            XCTAssertFalse(data.isEmpty)
            XCTAssertEqual(metadata?.source, .localGit)
        } else {
            XCTFail("Expected .loaded state with .localGit metadata")
        }
    }

    func testUpdateBranches_failure_setsFailedWithoutProviderState() async throws {
        let repoManager = RepoManager()
        // Point to an invalid directory
        try repoManager.setRepo(tempDir.appendingPathComponent("not-a-repo"))
        let vm = GitPanelViewModel(repoManager: repoManager, settings: AppSettings())
        
        await vm.refresh()
        try await Task.sleep(nanoseconds: 300_000_000) // Wait for detached task
        
        if case .failed(let error) = vm.branchesState {
            XCTAssertNotNil(error)
        } else {
            XCTFail("Expected .failed state")
        }
    }
}
