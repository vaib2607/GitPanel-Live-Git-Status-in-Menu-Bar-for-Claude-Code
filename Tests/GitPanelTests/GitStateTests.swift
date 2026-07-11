import XCTest
import SwiftUI
@testable import GitPanelCore

@MainActor
final class GitStateTests: XCTestCase {

    // MARK: - Initial State

    func testInit_defaultValues() {
        let state = GitState()
        XCTAssertEqual(state.repoName, "")
        XCTAssertEqual(state.branchName, "")
        XCTAssertEqual(state.commitCount, 0)
        XCTAssertEqual(state.linesAdded, 0)
        XCTAssertEqual(state.linesDeleted, 0)
        XCTAssertFalse(state.hasChanges)
        XCTAssertFalse(state.isAheadOfRemote)
        XCTAssertFalse(state.isBehindRemote)
        XCTAssertEqual(state.lastCommitHash, "")
        XCTAssertEqual(state.lastCommitMessage, "")
        XCTAssertEqual(state.lastCommitDate, .distantPast)
        XCTAssertEqual(state.remoteName, "")
        XCTAssertFalse(state.isRebaseInProgress)
        XCTAssertFalse(state.isMergeInProgress)
        XCTAssertFalse(state.isCherryPickInProgress)
        XCTAssertFalse(state.isRevertInProgress)
        XCTAssertEqual(state.repoState, .clean)
        XCTAssertTrue(state.remotes.isEmpty)
        XCTAssertTrue(state.submodules.isEmpty)
        XCTAssertTrue(state.branches.isEmpty)
        XCTAssertNil(state.usageData)
        XCTAssertEqual(state.environmentMode, .production)
        XCTAssertNil(state.bannerMessage)
        XCTAssertFalse(state.isGitRepo)
        XCTAssertEqual(state.lastUpdated, .distantPast)
        XCTAssertEqual(state.stagedCount, 0)
        XCTAssertEqual(state.unstagedCount, 0)
        XCTAssertEqual(state.untrackedCount, 0)
        XCTAssertEqual(state.conflictCount, 0)
    }

    // MARK: - syncStatus Computed Property

    func testSyncStatus_synced() {
        let state = GitState()
        state.isAheadOfRemote = false
        state.isBehindRemote = false
        XCTAssertEqual(state.syncStatus, "Synced")
    }

    func testSyncStatus_aheadOnly() {
        let state = GitState()
        state.isAheadOfRemote = true
        state.isBehindRemote = false
        XCTAssertEqual(state.syncStatus, "ahead")
    }

    func testSyncStatus_behindOnly() {
        let state = GitState()
        state.isAheadOfRemote = false
        state.isBehindRemote = true
        XCTAssertEqual(state.syncStatus, "behind")
    }

    func testSyncStatus_aheadAndBehind() {
        let state = GitState()
        state.isAheadOfRemote = true
        state.isBehindRemote = true
        XCTAssertEqual(state.syncStatus, "ahead · behind")
    }

    // MARK: - Snapshot Application

    func testApply_snapshotUpdatesAllFields() {
        let state = GitState()
        let snapshot = GitStateSnapshot(
            isGitRepo: true,
            repoName: "TestRepo",
            branchName: "feature-branch",
            isAheadOfRemote: true,
            isBehindRemote: false,
            hasChanges: true,
            stagedCount: 2,
            unstagedCount: 3,
            untrackedCount: 1,
            conflictCount: 0,
            linesAdded: 50,
            linesDeleted: 10,
            lastCommitHash: "abc123",
            lastCommitMessage: "feat: add feature",
            lastCommitDate: Date(timeIntervalSince1970: 1_000_000),
            remotes: [Remote(name: "origin", url: "https://github.com/test/repo")],
            remoteName: "origin",
            submodules: [Submodule(name: "sub", path: "sub", url: "https://example.com")],
            branches: [GitBranch(name: "feature-branch", isCurrent: true)],
            repoState: .dirty
        )

        state.apply(snapshot)

        XCTAssertTrue(state.isGitRepo)
        XCTAssertEqual(state.repoName, "TestRepo")
        XCTAssertEqual(state.branchName, "feature-branch")
        XCTAssertTrue(state.isAheadOfRemote)
        XCTAssertFalse(state.isBehindRemote)
        XCTAssertTrue(state.hasChanges)
        XCTAssertEqual(state.stagedCount, 2)
        XCTAssertEqual(state.unstagedCount, 3)
        XCTAssertEqual(state.untrackedCount, 1)
        XCTAssertEqual(state.conflictCount, 0)
        XCTAssertEqual(state.linesAdded, 50)
        XCTAssertEqual(state.linesDeleted, 10)
        XCTAssertEqual(state.lastCommitHash, "abc123")
        XCTAssertEqual(state.lastCommitMessage, "feat: add feature")
        XCTAssertEqual(state.lastCommitDate, Date(timeIntervalSince1970: 1_000_000))
        XCTAssertEqual(state.remotes.count, 1)
        XCTAssertEqual(state.remoteName, "origin")
        XCTAssertEqual(state.submodules.count, 1)
        XCTAssertEqual(state.branches.count, 1)
        XCTAssertEqual(state.repoState, .dirty)
    }

    func testApply_snapshotSetsLastUpdated() {
        let state = GitState()
        let before = Date()
        let snapshot = GitStateSnapshot(
            isGitRepo: true, repoName: "r", branchName: "main",
            isAheadOfRemote: false, isBehindRemote: false, hasChanges: false,
            stagedCount: 0, unstagedCount: 0, untrackedCount: 0, conflictCount: 0,
            linesAdded: 0, linesDeleted: 0, lastCommitHash: "", lastCommitMessage: "",
            lastCommitDate: .distantPast, remotes: [], remoteName: "",
            submodules: [], branches: [], repoState: .clean
        )
        state.apply(snapshot)
        let after = Date()
        XCTAssertGreaterThanOrEqual(state.lastUpdated, before)
        XCTAssertLessThanOrEqual(state.lastUpdated, after)
    }

    func testApply_snapshotOverwritesPreviousValues() {
        let state = GitState()
        state.isGitRepo = true
        state.repoName = "OldRepo"
        state.branchName = "old-branch"
        state.stagedCount = 10

        let snapshot = GitStateSnapshot(
            isGitRepo: false, repoName: "NewRepo", branchName: "new-branch",
            isAheadOfRemote: false, isBehindRemote: false, hasChanges: false,
            stagedCount: 0, unstagedCount: 0, untrackedCount: 0, conflictCount: 0,
            linesAdded: 0, linesDeleted: 0, lastCommitHash: "", lastCommitMessage: "",
            lastCommitDate: .distantPast, remotes: [], remoteName: "",
            submodules: [], branches: [], repoState: .clean
        )
        state.apply(snapshot)

        XCTAssertFalse(state.isGitRepo)
        XCTAssertEqual(state.repoName, "NewRepo")
        XCTAssertEqual(state.branchName, "new-branch")
        XCTAssertEqual(state.stagedCount, 0)
    }

    func testApply_multipleSnapshots() {
        let state = GitState()

        let snap1 = GitStateSnapshot(
            isGitRepo: true, repoName: "R1", branchName: "main",
            isAheadOfRemote: false, isBehindRemote: false, hasChanges: false,
            stagedCount: 0, unstagedCount: 0, untrackedCount: 0, conflictCount: 0,
            linesAdded: 0, linesDeleted: 0, lastCommitHash: "", lastCommitMessage: "",
            lastCommitDate: .distantPast, remotes: [], remoteName: "",
            submodules: [], branches: [], repoState: .clean
        )
        state.apply(snap1)
        XCTAssertEqual(state.repoName, "R1")

        let snap2 = GitStateSnapshot(
            isGitRepo: true, repoName: "R2", branchName: "dev",
            isAheadOfRemote: true, isBehindRemote: true, hasChanges: true,
            stagedCount: 5, unstagedCount: 3, untrackedCount: 2, conflictCount: 1,
            linesAdded: 100, linesDeleted: 50, lastCommitHash: "hash", lastCommitMessage: "msg",
            lastCommitDate: Date.distantFuture, remotes: [], remoteName: "origin",
            submodules: [], branches: [], repoState: .mergeConflict
        )
        state.apply(snap2)
        XCTAssertEqual(state.repoName, "R2")
        XCTAssertEqual(state.branchName, "dev")
        XCTAssertEqual(state.conflictCount, 1)
        XCTAssertEqual(state.repoState, .mergeConflict)
    }

    // MARK: - State Transitions via apply

    func testApply_transitionCleanToDirty() {
        let state = GitState()
        XCTAssertEqual(state.repoState, .clean)

        let snapshot = GitStateSnapshot(
            isGitRepo: true, repoName: "r", branchName: "main",
            isAheadOfRemote: false, isBehindRemote: false, hasChanges: true,
            stagedCount: 0, unstagedCount: 1, untrackedCount: 0, conflictCount: 0,
            linesAdded: 0, linesDeleted: 0, lastCommitHash: "", lastCommitMessage: "",
            lastCommitDate: .distantPast, remotes: [], remoteName: "",
            submodules: [], branches: [], repoState: .dirty
        )
        state.apply(snapshot)
        XCTAssertEqual(state.repoState, .dirty)
    }

    func testApply_transitionDirtyToMergeConflict() {
        let state = GitState()
        state.repoState = .dirty

        let snapshot = GitStateSnapshot(
            isGitRepo: true, repoName: "r", branchName: "main",
            isAheadOfRemote: false, isBehindRemote: false, hasChanges: true,
            stagedCount: 0, unstagedCount: 0, untrackedCount: 0, conflictCount: 3,
            linesAdded: 0, linesDeleted: 0, lastCommitHash: "", lastCommitMessage: "",
            lastCommitDate: .distantPast, remotes: [], remoteName: "",
            submodules: [], branches: [], repoState: .mergeConflict
        )
        state.apply(snapshot)
        XCTAssertEqual(state.repoState, .mergeConflict)
    }

    func testApply_transitionMergeConflictToClean() {
        let state = GitState()
        state.repoState = .mergeConflict
        state.conflictCount = 3

        let snapshot = GitStateSnapshot(
            isGitRepo: true, repoName: "r", branchName: "main",
            isAheadOfRemote: false, isBehindRemote: false, hasChanges: false,
            stagedCount: 0, unstagedCount: 0, untrackedCount: 0, conflictCount: 0,
            linesAdded: 0, linesDeleted: 0, lastCommitHash: "", lastCommitMessage: "",
            lastCommitDate: .distantPast, remotes: [], remoteName: "",
            submodules: [], branches: [], repoState: .clean
        )
        state.apply(snapshot)
        XCTAssertEqual(state.repoState, .clean)
        XCTAssertEqual(state.conflictCount, 0)
    }

    func testApply_transitionToRebasing() {
        let state = GitState()
        let snapshot = GitStateSnapshot(
            isGitRepo: true, repoName: "r", branchName: "main",
            isAheadOfRemote: false, isBehindRemote: false, hasChanges: false,
            stagedCount: 0, unstagedCount: 0, untrackedCount: 0, conflictCount: 0,
            linesAdded: 0, linesDeleted: 0, lastCommitHash: "", lastCommitMessage: "",
            lastCommitDate: .distantPast, remotes: [], remoteName: "",
            submodules: [], branches: [], repoState: .rebasing
        )
        state.apply(snapshot)
        XCTAssertEqual(state.repoState, .rebasing)
    }

    func testApply_transitionToDetachedHEAD() {
        let state = GitState()
        let snapshot = GitStateSnapshot(
            isGitRepo: true, repoName: "r", branchName: "",
            isAheadOfRemote: false, isBehindRemote: false, hasChanges: false,
            stagedCount: 0, unstagedCount: 0, untrackedCount: 0, conflictCount: 0,
            linesAdded: 0, linesDeleted: 0, lastCommitHash: "abc123", lastCommitMessage: "",
            lastCommitDate: .distantPast, remotes: [], remoteName: "",
            submodules: [], branches: [], repoState: .detachedHEAD
        )
        state.apply(snapshot)
        XCTAssertEqual(state.repoState, .detachedHEAD)
        XCTAssertEqual(state.lastCommitHash, "abc123")
    }

    // MARK: - RepoState Enum

    func testRepoState_allRawValues() {
        let expected = [
            "clean", "dirty", "mergeConflict", "rebasing", "cherryPicking",
            "detachedHEAD", "reverting", "bisecting", "staging", "pushing",
            "pulling", "merging", "resolving"
        ]
        for raw in expected {
            XCTAssertNotNil(RepoState(rawValue: raw), "Missing RepoState for: \(raw)")
        }
        XCTAssertEqual(RepoState.allCases.count, expected.count)
    }

    func testRepoState_labels() {
        XCTAssertEqual(RepoState.clean.label, "Clean")
        XCTAssertEqual(RepoState.dirty.label, "Dirty")
        XCTAssertEqual(RepoState.mergeConflict.label, "Merge Conflict")
        XCTAssertEqual(RepoState.rebasing.label, "Rebasing")
        XCTAssertEqual(RepoState.cherryPicking.label, "Cherry Picking")
        XCTAssertEqual(RepoState.detachedHEAD.label, "Detached HEAD")
        XCTAssertEqual(RepoState.reverting.label, "Reverting")
        XCTAssertEqual(RepoState.bisecting.label, "Bisecting")
        XCTAssertEqual(RepoState.staging.label, "Staging")
        XCTAssertEqual(RepoState.pushing.label, "Pushing")
        XCTAssertEqual(RepoState.pulling.label, "Pulling")
        XCTAssertEqual(RepoState.merging.label, "Merging")
        XCTAssertEqual(RepoState.resolving.label, "Resolving")
    }

    func testRepoState_icons() {
        XCTAssertFalse(RepoState.clean.icon.isEmpty)
        XCTAssertFalse(RepoState.dirty.icon.isEmpty)
        XCTAssertFalse(RepoState.mergeConflict.icon.isEmpty)
        XCTAssertFalse(RepoState.rebasing.icon.isEmpty)
        XCTAssertFalse(RepoState.staging.icon.isEmpty)
        XCTAssertFalse(RepoState.pushing.icon.isEmpty)
        XCTAssertFalse(RepoState.pulling.icon.isEmpty)
        XCTAssertFalse(RepoState.detachedHEAD.icon.isEmpty)
    }

    func testRepoState_colors() {
        // All states should have a color assigned
        for state in RepoState.allCases {
            XCTAssertNotNil(state.color, "Missing color for \(state)")
        }
    }

    // MARK: - BannerMessage

    func testBannerMessage_uniqueIds() {
        let a = BannerMessage(title: "A", kind: .success)
        let b = BannerMessage(title: "B", kind: .success)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testBannerMessage_withDetail() {
        let msg = BannerMessage(title: "Title", detail: "Detail text", kind: .error)
        XCTAssertEqual(msg.title, "Title")
        XCTAssertEqual(msg.detail, "Detail text")
        XCTAssertEqual(msg.kind, .error)
    }

    func testBannerMessage_withoutDetail() {
        let msg = BannerMessage(title: "Title", kind: .warning)
        XCTAssertNil(msg.detail)
    }

    func testBannerMessage_kindCases() {
        let success = BannerMessage(title: "", kind: .success)
        let error = BannerMessage(title: "", kind: .error)
        let warning = BannerMessage(title: "", kind: .warning)
        // Verify kind property works
        switch success.kind {
        case .success: break
        case .error: XCTFail("Wrong kind")
        case .warning: XCTFail("Wrong kind")
        }
        switch error.kind {
        case .error: break
        case .success: XCTFail("Wrong kind")
        case .warning: XCTFail("Wrong kind")
        }
        switch warning.kind {
        case .warning: break
        case .success: XCTFail("Wrong kind")
        case .error: XCTFail("Wrong kind")
        }
    }

    // MARK: - EnvironmentMode

    func testEnvironmentMode_allCases() {
        XCTAssertEqual(EnvironmentMode.allCases.count, 5)
    }

    func testEnvironmentMode_ids() {
        XCTAssertEqual(EnvironmentMode.local.id, "Work locally")
        XCTAssertEqual(EnvironmentMode.codex.id, "Connect Codex web")
        XCTAssertEqual(EnvironmentMode.cloud.id, "Send to cloud")
        XCTAssertEqual(EnvironmentMode.production.id, "production")
        XCTAssertEqual(EnvironmentMode.development.id, "development")
    }

    func testEnvironmentMode_rawValues() {
        XCTAssertEqual(EnvironmentMode.local.rawValue, "Work locally")
        XCTAssertEqual(EnvironmentMode.production.rawValue, "production")
        XCTAssertEqual(EnvironmentMode.development.rawValue, "development")
    }

    // MARK: - PRStatus

    func testPRStatus_noPRs() {
        let status = PRStatus.noPRs
        if case .noPRs = status {
            // OK
        } else {
            XCTFail("Expected noPRs")
        }
    }

    func testPRStatus_notInstalled() {
        let status = PRStatus.notInstalled
        if case .notInstalled = status {
            // OK
        } else {
            XCTFail("Expected notInstalled")
        }
    }

    func testPRStatus_pullRequests() {
        let prs = [
            PRInfo(number: 1, title: "PR #1", url: "http://url", state: "OPEN",
                   author: "user", branch: "feat", reviewDecision: nil, mergeable: true)
        ]
        let status = PRStatus.pullRequests(prs)
        if case .pullRequests(let list) = status {
            XCTAssertEqual(list.count, 1)
            XCTAssertEqual(list[0].number, 1)
        } else {
            XCTFail("Expected pullRequests")
        }
    }

    // MARK: - PRInfo

    func testPRInfo_idIsNumber() {
        let pr = PRInfo(number: 42, title: "T", url: "", state: "OPEN",
                        author: "a", branch: "b", reviewDecision: nil, mergeable: nil)
        XCTAssertEqual(pr.id, 42)
    }

    func testPRInfo_differentInstancesAreNotEqual() {
        let a = PRInfo(number: 1, title: "A", url: "", state: "OPEN",
                       author: "a", branch: "b", reviewDecision: nil, mergeable: nil)
        let b = PRInfo(number: 1, title: "B", url: "", state: "CLOSED",
                       author: "x", branch: "y", reviewDecision: nil, mergeable: nil)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - UsageData

    func testUsageData_init() {
        let data = UsageData(
            tokens: 1000, cost: 0.5, model: "claude-sonnet-5",
            plan: "Pro", isUsingPlan: true,
            modelBreakdown: ["claude-sonnet-5": 0.5]
        )
        XCTAssertEqual(data.tokens, 1000)
        XCTAssertEqual(data.cost, 0.5)
        XCTAssertEqual(data.model, "claude-sonnet-5")
        XCTAssertEqual(data.plan, "Pro")
        XCTAssertTrue(data.isUsingPlan)
        XCTAssertEqual(data.modelBreakdown["claude-sonnet-5"], 0.5)
    }

    func testUsageData_defaultValues() {
        let data = UsageData(tokens: 0, cost: 0, model: "", plan: "", isUsingPlan: false)
        XCTAssertEqual(data.tokens, 0)
        XCTAssertEqual(data.cost, 0)
        XCTAssertTrue(data.modelBreakdown.isEmpty)
    }

    // MARK: - Remote

    func testRemote_id() {
        let remote = Remote(name: "origin", url: "https://github.com")
        XCTAssertEqual(remote.id, "originhttps://github.com")
    }

    func testRemote_defaultIsDefault() {
        let remote = Remote(name: "origin", url: "https://github.com")
        XCTAssertFalse(remote.isDefault)
    }

    func testRemote_customIsDefault() {
        let remote = Remote(name: "origin", url: "https://github.com", isDefault: true)
        XCTAssertTrue(remote.isDefault)
    }

    func testRemote_hashable() {
        let a = Remote(name: "origin", url: "url")
        let b = Remote(name: "origin", url: "url")
        XCTAssertEqual(a, b)
        var set = Set<Remote>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Submodule

    func testSubmodule_id() {
        let sub = Submodule(name: "lib", path: "lib/vendor", url: "https://example.com")
        XCTAssertEqual(sub.id, "lib/vendor")
    }

    func testSubmodule_defaultBranch() {
        let sub = Submodule(name: "lib", path: "lib", url: "https://example.com")
        XCTAssertNil(sub.branch)
    }

    func testSubmodule_withBranch() {
        let sub = Submodule(name: "lib", path: "lib", url: "https://example.com", branch: "main")
        XCTAssertEqual(sub.branch, "main")
    }

    // MARK: - GitBranch

    func testGitBranch_defaults() {
        let branch = GitBranch(name: "main", isCurrent: true)
        XCTAssertFalse(branch.isRemote)
        XCTAssertNil(branch.remoteName)
        XCTAssertNil(branch.upstreamName)
        XCTAssertEqual(branch.ahead, 0)
        XCTAssertEqual(branch.behind, 0)
    }

    func testGitBranch_withUpstream() {
        let branch = GitBranch(
            name: "feature", isCurrent: true,
            upstreamName: "origin/feature", ahead: 3, behind: 1
        )
        XCTAssertEqual(branch.upstreamName, "origin/feature")
        XCTAssertEqual(branch.ahead, 3)
        XCTAssertEqual(branch.behind, 1)
    }

    func testGitBranch_remoteBranch() {
        let branch = GitBranch(name: "origin/main", isCurrent: false, isRemote: true)
        XCTAssertTrue(branch.isRemote)
    }

    // MARK: - GitWorktree

    func testGitWorktree_id() {
        let wt = GitWorktree(path: "/path", branch: "main", isCurrent: true)
        XCTAssertNotNil(wt.id)
    }

    func testGitWorktree_differentInstancesAreNotEqual() {
        let a = GitWorktree(path: "/a", branch: "main", isCurrent: true)
        let b = GitWorktree(path: "/a", branch: "main", isCurrent: false)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - GitStatus

    func testGitStatus_id() {
        let status = GitStatus(path: "file.swift", statusCode: "M", staged: true)
        XCTAssertNotNil(status.id)
        XCTAssertEqual(status.path, "file.swift")
        XCTAssertEqual(status.statusCode, "M")
        XCTAssertTrue(status.staged)
    }

    func testGitStatus_differentInstancesAreNotEqual() {
        let a = GitStatus(path: "a.swift", statusCode: "M", staged: true)
        let b = GitStatus(path: "a.swift", statusCode: "M", staged: false)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - GitStateSnapshot

    func testSnapshot_init() {
        let snapshot = GitStateSnapshot(
            isGitRepo: true, repoName: "R", branchName: "main",
            isAheadOfRemote: false, isBehindRemote: false, hasChanges: false,
            stagedCount: 0, unstagedCount: 0, untrackedCount: 0, conflictCount: 0,
            linesAdded: 0, linesDeleted: 0, lastCommitHash: "", lastCommitMessage: "",
            lastCommitDate: .distantPast, remotes: [], remoteName: "",
            submodules: [], branches: [], repoState: .clean
        )
        XCTAssertTrue(snapshot.isGitRepo)
        XCTAssertEqual(snapshot.repoName, "R")
        XCTAssertEqual(snapshot.repoState, .clean)
    }

    func testSnapshot_isSendable() {
        func assertSendable<T: Sendable>(_ value: T) {}
        let snapshot = GitStateSnapshot(
            isGitRepo: true, repoName: "R", branchName: "main",
            isAheadOfRemote: false, isBehindRemote: false, hasChanges: false,
            stagedCount: 0, unstagedCount: 0, untrackedCount: 0, conflictCount: 0,
            linesAdded: 0, linesDeleted: 0, lastCommitHash: "", lastCommitMessage: "",
            lastCommitDate: .distantPast, remotes: [], remoteName: "",
            submodules: [], branches: [], repoState: .clean
        )
        assertSendable(snapshot)
    }

    // MARK: - Mutable State Updates

    func testMutableState_commitCount() {
        let state = GitState()
        state.commitCount = 42
        XCTAssertEqual(state.commitCount, 42)
    }

    func testMutableState_linesAddedAndDeleted() {
        let state = GitState()
        state.linesAdded = 100
        state.linesDeleted = 25
        XCTAssertEqual(state.linesAdded, 100)
        XCTAssertEqual(state.linesDeleted, 25)
    }

    func testMutableState_repoFlags() {
        let state = GitState()
        state.isRebaseInProgress = true
        state.isMergeInProgress = true
        state.isCherryPickInProgress = true
        state.isRevertInProgress = true
        XCTAssertTrue(state.isRebaseInProgress)
        XCTAssertTrue(state.isMergeInProgress)
        XCTAssertTrue(state.isCherryPickInProgress)
        XCTAssertTrue(state.isRevertInProgress)
    }

    func testMutableState_usageData() {
        let state = GitState()
        XCTAssertNil(state.usageData)
        state.usageData = UsageData(
            tokens: 500, cost: 0.25, model: "gpt-4o",
            plan: "Free", isUsingPlan: false
        )
        XCTAssertNotNil(state.usageData)
        XCTAssertEqual(state.usageData?.tokens, 500)
    }

    func testMutableState_environmentMode() {
        let state = GitState()
        XCTAssertEqual(state.environmentMode, .production)
        state.environmentMode = .development
        XCTAssertEqual(state.environmentMode, .development)
    }

    func testMutableState_branches() {
        let state = GitState()
        XCTAssertTrue(state.branches.isEmpty)
        state.branches = [
            GitBranch(name: "main", isCurrent: true),
            GitBranch(name: "dev", isCurrent: false)
        ]
        XCTAssertEqual(state.branches.count, 2)
    }

    func testMutableState_remotes() {
        let state = GitState()
        XCTAssertTrue(state.remotes.isEmpty)
        state.remotes = [Remote(name: "origin", url: "https://github.com")]
        XCTAssertEqual(state.remotes.count, 1)
    }

    func testMutableState_submodules() {
        let state = GitState()
        XCTAssertTrue(state.submodules.isEmpty)
        state.submodules = [Submodule(name: "sub", path: "sub", url: "https://example.com")]
        XCTAssertEqual(state.submodules.count, 1)
    }

    func testMutableState_prStatus() {
        let state = GitState()
        state.prStatus = .pullRequests([
            PRInfo(number: 1, title: "PR", url: "", state: "OPEN",
                   author: "a", branch: "b", reviewDecision: nil, mergeable: nil)
        ])
        if case .pullRequests(let list) = state.prStatus {
            XCTAssertEqual(list.count, 1)
        } else {
            XCTFail("Expected pullRequests")
        }
    }
}
