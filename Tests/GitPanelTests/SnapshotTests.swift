import XCTest
import SwiftUI
@testable import GitPanel

#if canImport(SnapshotTesting)
import SnapshotTesting
#endif

final class SnapshotTests: XCTestCase {

    func testCommitSectionEmpty() {
        #if canImport(SnapshotTesting)
        let view = CommitSection(viewModel: GitPanelViewModel())
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 360, height: 200)))
        #else
        return  // Skip: SnapshotTesting library not available
        #endif
    }

    func testUsageViewWithData() {
        #if canImport(SnapshotTesting)
        var vm = GitPanelViewModel()
        vm.usage = UsageData(
            tokens: 125_000,
            cost: 45.67,
            model: "claude-sonnet-4",
            plan: "Pro",
            isUsingPlan: true,
            modelBreakdown: [:],
            lastUpdated: Date()
        )
        let view = UsageView(viewModel: vm)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 360, height: 300)))
        #else
        return  // Skip: SnapshotTesting library not available
        #endif
    }

    func testRepoStateBadgeClean() {
        #if canImport(SnapshotTesting)
        let view = RepoStateBadge(state: .clean)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 120, height: 30)))
        #else
        return  // Skip: SnapshotTesting library not available
        #endif
    }

    func testRepoStateBadgeDirty() {
        #if canImport(SnapshotTesting)
        let view = RepoStateBadge(state: .dirty)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 120, height: 30)))
        #else
        return  // Skip: SnapshotTesting library not available
        #endif
    }

    func testDiffSummaryView() {
        #if canImport(SnapshotTesting)
        let state = GitState()
        state.linesAdded = 42
        state.linesDeleted = 7
        state.hasChanges = true
        let view = DiffSummaryView(state: state)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 360, height: 40)))
        #else
        return  // Skip: SnapshotTesting library not available
        #endif
    }
}
