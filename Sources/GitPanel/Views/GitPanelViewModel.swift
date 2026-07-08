import SwiftUI
import Combine

@MainActor
@Observable final class GitPanelViewModel {
    // MARK: - State
    var state = GitState()
    var branches: [GitBranch] = []
    var prStatus: PRStatus = .noPRs
    var usage: UsageData = .init(tokens: 0, cost: 0, model: "", plan: "", isUsingPlan: false)
    var commitMessage: String = ""
    var banner: BannerMessage? = nil
    var isRefreshing: Bool = false
    var isCommitting: Bool = false
    var isPushing: Bool = false
    var isCreatingBranch: Bool = false
    var branchSearchText: String = ""
    var branchNameInput: String = ""
    var environmentMode: EnvironmentMode = .production
    var isPerformingGitOperation: Bool = false

    // MARK: - Dependencies
    let gitService = GitService()
    let githubService = GitHubService()
    let usageService = UsageService()
    let repoManager: RepoManager
    let settings: AppSettings
    private let fileWatcher = FileWatcher()
    private var refreshTask: Task<Void, Never>? = nil
    private var debounceTask: Task<Void, Never>? = nil

    // MARK: - Init
    init(repoManager: RepoManager = .shared, settings: AppSettings = .shared) {
        self.repoManager = repoManager
        self.settings = settings
        fileWatcher.onIndexChange = { [weak self] in
            self?.debouncedRefresh()
        }
    }

    // MARK: - File Watching
    func startWatching() {
        let repo = repoManager.repoURL
        fileWatcher.startWatching(repo: repo)
    }

    func stopWatching() {
        fileWatcher.stop()
    }

    // MARK: - Refresh (0.5s debounce via Task)
    func debouncedRefresh() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    func refresh() async {
        let repo = repoManager.repoURL
        guard !isPerformingGitOperation else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            async let stateUpdate = gitService.updateState(state, repo: repo)
            async let branchesUpdate = gitService.branches(repo: repo)
            async let prUpdate = githubService.prStatus(repo: repo)
            async let usageUpdate = UsageService.compute()

            try await stateUpdate
            branches = try await branchesUpdate
            prStatus = try await prUpdate
            // Usage: only refresh every 30s or on first load
            if usage.tokens == 0 || usage.cost == 0 {
                usage = try await usageUpdate
            }
        } catch {
            showBanner("Refresh failed", detail: error.localizedDescription, kind: .error)
        }
    }

    // MARK: - Git Operations
    func commit() async {
        guard !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let repo = repoManager.repoURL

        isPerformingGitOperation = true
        isCommitting = true
        defer {
            isCommitting = false
            isPerformingGitOperation = false
        }

        do {
            try await gitService.commit(repo: repo, message: commitMessage)
            commitMessage = ""
            showBanner("Committed", kind: .success)
            await refresh()
        } catch {
            showBanner("Commit failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func push() async {
        let repo = repoManager.repoURL

        isPerformingGitOperation = true
        isPushing = true
        defer {
            isPushing = false
            isPerformingGitOperation = false
        }

        do {
            try await gitService.push(repo: repo)
            showBanner("Pushed to origin", kind: .success)
            await refresh()
        } catch {
            showBanner("Push failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func pull() async {
        let repo = repoManager.repoURL

        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await gitService.pull(repo: repo)
            showBanner("Pulled from origin", kind: .success)
            await refresh()
        } catch {
            showBanner("Pull failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func commitAndPush() async {
        await commit()
        if commitMessage.isEmpty {
            await push()
        }
    }

    func checkout(_ branch: GitBranch) async {
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await gitService.checkout(repo: repo, branch: branch.name)
            showBanner("Checked out \(branch.name)", kind: .success)
            await refresh()
        } catch {
            showBanner("Checkout failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func createBranch(_ name: String) async {
        let repo = repoManager.repoURL
        guard !name.isEmpty else { return }
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await gitService.createBranch(repo: repo, name: name)
            branchNameInput = ""
            showBanner("Created branch \(name)", kind: .success)
            await refresh()
        } catch {
            showBanner("Create branch failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func deleteBranch(_ branch: GitBranch) async {
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await gitService.deleteBranch(repo: repo, name: branch.name)
            showBanner("Deleted branch \(branch.name)", kind: .success)
            await refresh()
        } catch {
            showBanner("Delete branch failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func stageFile(_ path: String) async {
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await ShellRunner.run("git add \(shellEscape(path))", at: repo.path)
            await refresh()
        } catch {
            showBanner("Stage failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func unstageFile(_ path: String) async {
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await ShellRunner.run("git reset HEAD \(shellEscape(path))", at: repo.path)
            await refresh()
        } catch {
            showBanner("Unstage failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func discardChanges(_ path: String) async {
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await ShellRunner.run("git checkout -- \(shellEscape(path))", at: repo.path)
            showBanner("Discarded changes to \(path)", kind: .warning)
            await refresh()
        } catch {
            showBanner("Discard failed", detail: error.localizedDescription, kind: .error)
        }
    }

    // MARK: - Banner
    func showBanner(_ title: String, detail: String? = nil, kind: BannerMessage.Kind) {
        banner = BannerMessage(title: title, detail: detail, kind: kind)
        Task {
            try? await Task.sleep(for: .seconds(3))
            self.banner = nil
        }
    }

    // MARK: - Computed
    var filteredBranches: [GitBranch] {
        if branchSearchText.isEmpty { return branches }
        return branches.filter { $0.name.localizedCaseInsensitiveContains(branchSearchText) }
    }

    var repoState: RepoState {
        state.repoState
    }

    var stateLabel: String {
        state.repoState.label
    }

    var stateIcon: String {
        state.repoState.icon
    }

    var stateColor: Color {
        state.repoState.color
    }

    var isGitRepo: Bool {
        state.isGitRepo
    }

    var currentBranch: String {
        state.branchName
    }

    var ahead: Int {
        state.isAheadOfRemote ? 1 : 0
    }

    var behind: Int {
        state.isBehindRemote ? 1 : 0
    }

    var remotes: [Remote] {
        state.remotes
    }

    var submodules: [Submodule] {
        state.submodules
    }

    var dependencies: [String] {
        []
    }
}

// MARK: - Helpers
private func shellEscape(_ s: String) -> String {
    "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
}
