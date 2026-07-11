import SwiftUI
import Combine

@MainActor
@Observable final class GitPanelViewModel {
    // MARK: - State
    var state = GitState()
    var branchesState: DataState<[GitBranch]> = .idle
    var branches: [GitBranch] { branchesState.value ?? [] }
    var prStatus: PRStatus = .noPRs
    var usage: UsageData = .init(tokens: 0, cost: 0, model: "", plan: "", isUsingPlan: false, modelBreakdown: [:], lastUpdated: Date())
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
    var currentDiff: String = ""
    var stagedFiles: [GitFile] = []
    var unstagedFiles: [GitFile] = []
    var untrackedFiles: [GitFile] = []

    // MARK: - Dependencies
    let gitService = GitService()
    let githubService = GitHubService()
    let usageService = UsageService()
    let repoManager: RepoManager
    let settings: AppSettings
    private let fileWatcher = FileWatcher()
    private var refreshTask: Task<Void, Never>? = nil
    private var debounceTask: Task<Void, Never>? = nil
    private var lastUsageRefresh: Date = .distantPast

    // MARK: - Init
    init(repoManager: RepoManager, settings: AppSettings) {
        self.repoManager = repoManager
        self.settings = settings
        fileWatcher.onIndexChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.debouncedRefresh()
            }
        }
    }

    convenience init() {
        self.init(repoManager: .shared, settings: .shared)
    }

    // MARK: - File Watching
    func startWatching() {
        let repo = repoManager.repoURL
        fileWatcher.startWatching(repo: repo)
        Task { await AIEngine.shared.start() }
    }

    func stopWatching() {
        fileWatcher.stop()
        Task { await AIEngine.shared.stop() }
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
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        // Core Git state update
        do {
            let snapshot = try await gitService.updateState(repo: repo)
            state.apply(snapshot)
        } catch {
            showBanner("Git Refresh Failed", detail: error.localizedDescription, kind: .error)
            return
        }

        // Fetch changed files
        do {
            let files = try await gitService.fetchChangedFiles(repo: repo)
            self.stagedFiles = files.staged
            self.unstagedFiles = files.unstaged
            self.untrackedFiles = files.untracked
        } catch {
            showBanner("Failed to load changes list", detail: error.localizedDescription, kind: .warning)
        }

        // Optional Git branches in Task
        self.branchesState = .loading
        let service = self.gitService
        Task { [weak self, service] in
            do {
                let fetched = try await service.branches(repo: repo)
                guard !Task.isCancelled else { return }
                self?.branchesState = .loaded(fetched, DataMetadata(source: .localGit))
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let userError = UserFacingError(
                    title: "Couldn't Load Branches",
                    message: "Git could not read branches for this repository: \(error.localizedDescription)",
                    recoveryAction: RecoveryAction(title: "Retry", type: .retry),
                    technicalDiagnosticsID: "GIT_BRANCH",
                    severity: .error
                )
                self?.branchesState = .failed(userError)
            }
        }

        // Optional GitHub status in detached background Task
        Task.detached { [weak self, githubService] in
            do {
                let pr = try await githubService.prStatus(repo: repo)
                await self?.updatePRStatus(pr)
            } catch {
                await self?.showBanner("GitHub Sync Failed", detail: error.localizedDescription, kind: .warning)
            }
        }

        // Optional Usage metrics (refresh when empty or every 30s) in detached background Task
        let currentUsageTokens = self.usage.tokens
        let currentUsageCost = self.usage.cost
        let lastRefresh = self.lastUsageRefresh
        let shouldRefreshUsage = currentUsageTokens == 0 || currentUsageCost == 0 ||
            Date().timeIntervalSince(lastRefresh) > 30

        if shouldRefreshUsage {
            Task.detached { [weak self] in
                do {
                    let u = try await UsageService.compute()
                    await self?.updateUsage(u)
                } catch {
                    await self?.showBanner("Usage Sync Failed", detail: error.localizedDescription, kind: .warning)
                }
            }
        }

        // Load stashes in detached background Task
        Task.detached { [weak self] in
            await self?.loadStashes()
        }

        // Load conflicts in detached background Task
        Task.detached { [weak self] in
            await self?.loadConflicts()
        }
    }

    func updateBranches(_ fetchedBranches: [GitBranch]) {
        self.branchesState = .loaded(fetchedBranches, DataMetadata(source: .localGit))
    }

    func updatePRStatus(_ fetchedPRStatus: PRStatus) {
        self.prStatus = fetchedPRStatus
    }

    func updateUsage(_ fetchedUsage: UsageData) {
        self.usage = fetchedUsage
        self.lastUsageRefresh = Date()
    }

    // MARK: - Git Operations
    func commit() async {
        guard !isPerformingGitOperation else { return }
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
            await refreshAfterOperation()
        } catch {
            showBanner("Commit failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func push() async {
        guard !isPerformingGitOperation else { return }
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
            await refreshAfterOperation()
        } catch {
            showBanner("Push failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func pull() async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL

        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await gitService.pull(repo: repo)
            showBanner("Pulled from origin", kind: .success)
            await refreshAfterOperation()
        } catch {
            showBanner("Pull failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func commitAndPush() async {
        guard !isPerformingGitOperation else { return }
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        let msg = commitMessage
        guard !msg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Just push if message empty
            let repo = repoManager.repoURL
            isPushing = true
            defer { isPushing = false }
            do {
                try await gitService.push(repo: repo)
                showBanner("Pushed to origin", kind: .success)
                await refreshAfterOperation()
            } catch {
                showBanner("Push failed", detail: error.localizedDescription, kind: .error)
            }
            return
        }

        let repo = repoManager.repoURL
        isCommitting = true
        do {
            try await gitService.commit(repo: repo, message: msg)
            commitMessage = ""
            showBanner("Committed", kind: .success)
            isCommitting = false

            isPushing = true
            try await gitService.push(repo: repo)
            showBanner("Pushed to origin", kind: .success)
            isPushing = false

            await refreshAfterOperation()
        } catch {
            isCommitting = false
            isPushing = false
            showBanner("Commit & Push failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func checkout(_ branch: GitBranch) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await gitService.checkout(repo: repo, branch: branch.name)
            showBanner("Checked out \(branch.name)", kind: .success)
            await refreshAfterOperation()
        } catch {
            showBanner("Checkout failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func createBranch(_ name: String) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        guard !name.isEmpty else { return }
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await gitService.createBranch(repo: repo, name: name)
            branchNameInput = ""
            showBanner("Created branch \(name)", kind: .success)
            await refreshAfterOperation()
        } catch {
            showBanner("Create branch failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func deleteBranch(_ branch: GitBranch) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await gitService.deleteBranch(repo: repo, name: branch.name)
            showBanner("Deleted branch \(branch.name)", kind: .success)
            await refreshAfterOperation()
        } catch {
            showBanner("Delete branch failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func fetchDiff(for filePath: String) {
        let repo = repoManager.repoURL
        Task {
            do {
                let output = try await ShellRunner.run(
                    GitService.gitPath, ["diff", "--", filePath], at: repo.path
                )
                currentDiff = output
            } catch {
                currentDiff = ""
                showBanner("Diff Failed", detail: error.localizedDescription, kind: .error)
            }
        }
    }

    func stageFile(_ path: String) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await ShellRunner.run(GitService.gitPath, ["add", path], at: repo.path)
            await refreshAfterOperation()
        } catch {
            showBanner("Stage failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func unstageFile(_ path: String) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await ShellRunner.run(GitService.gitPath, ["reset", "HEAD", path], at: repo.path)
            await refreshAfterOperation()
        } catch {
            showBanner("Unstage failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func discardChanges(_ path: String) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }

        do {
            try await ShellRunner.run(GitService.gitPath, ["checkout", "--", path], at: repo.path)
            showBanner("Discarded changes to \(path)", kind: .warning)
            await refreshAfterOperation()
        } catch {
            showBanner("Discard failed", detail: error.localizedDescription, kind: .error)
        }
    }

    private func refreshAfterOperation() async {
        isPerformingGitOperation = false
        await refresh()
    }

    // MARK: - Banner
    func showBanner(_ title: String, detail: String? = nil, kind: BannerMessage.Kind) {
        banner = BannerMessage(title: title, detail: detail, kind: kind)
        if NSClassFromString("XCTest") == nil {
            Task {
                try? await Task.sleep(for: .seconds(3))
                self.banner = nil
            }
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

    // MARK: - Diff Operations

    func fetchDiff(for filePath: String) async -> String {
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return "" }
        do {
            return try await gitService.diff(repo: repo, path: filePath)
        } catch {
            return "Error loading diff: \(error.localizedDescription)"
        }
    }

    func fetchDiffCached(for filePath: String) async -> String {
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return "" }
        do {
            return try await gitService.diffCached(repo: repo, path: filePath)
        } catch {
            return "Error loading diff: \(error.localizedDescription)"
        }
    }

    // MARK: - Stash Operations

    var stashEntries: [StashEntry] = []

    func loadStashes() async {
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return }
        do {
            stashEntries = try await gitService.stashList(repo: repo)
        } catch {
            showBanner("Failed to load stashes", detail: error.localizedDescription, kind: .error)
        }
    }

    func stashChanges(message: String? = nil) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return }
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }
        do {
            try await gitService.stash(repo: repo, message: message)
            showBanner("Changes stashed", kind: .success)
            await refresh()
            await loadStashes()
        } catch {
            showBanner("Stash failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func popStash(index: Int = 0) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }
        do {
            try await gitService.stashPop(repo: repo, index: index)
            showBanner("Stash popped", kind: .success)
            await refreshAfterOperation()
            await loadStashes()
        } catch {
            showBanner("Stash pop failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func dropStash(index: Int = 0) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return }
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }
        do {
            try await gitService.stashDrop(repo: repo, index: index)
            showBanner("Stash dropped", kind: .success)
            await loadStashes()
        } catch {
            showBanner("Stash drop failed", detail: error.localizedDescription, kind: .error)
        }
    }

    func stashDiff(index: Int = 0) async -> String {
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return "" }
        do {
            return try await gitService.stashShow(repo: repo, index: index)
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - Conflict Operations

    var conflictedFiles: [ConflictedFile] = []

    func loadConflicts() async {
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return }
        do {
            conflictedFiles = try await gitService.listConflicts(repo: repo)
        } catch {
            showBanner("Failed to load conflicts", detail: error.localizedDescription, kind: .error)
        }
    }

    func acceptOurs(file: String) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return }
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }
        do {
            try await gitService.resolveConflict(repo: repo, path: file, strategy: .ours)
            showBanner("Accepted ours for \(file)", kind: .success)
            await refresh()
            await loadConflicts()
        } catch {
            showBanner("Failed to resolve", detail: error.localizedDescription, kind: .error)
        }
    }

    func acceptTheirs(file: String) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return }
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }
        do {
            try await gitService.resolveConflict(repo: repo, path: file, strategy: .theirs)
            showBanner("Accepted theirs for \(file)", kind: .success)
            await refresh()
            await loadConflicts()
        } catch {
            showBanner("Failed to resolve", detail: error.localizedDescription, kind: .error)
        }
    }

    func markResolved(file: String) async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return }
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }
        do {
            try await gitService.resolveConflict(repo: repo, path: file, strategy: .mark)
            showBanner("Marked \(file) as resolved", kind: .success)
            await refresh()
            await loadConflicts()
        } catch {
            showBanner("Failed to mark resolved", detail: error.localizedDescription, kind: .error)
        }
    }

    func resolveAllConflictsAcceptOurs() async {
        guard !isPerformingGitOperation else { return }
        let repo = repoManager.repoURL
        guard !repo.path.isEmpty else { return }
        isPerformingGitOperation = true
        defer { isPerformingGitOperation = false }
        for file in conflictedFiles {
            do {
                try await gitService.resolveConflict(repo: repo, path: file.path, strategy: .ours)
            } catch {
                showBanner("Failed to resolve \(file.path)", detail: error.localizedDescription, kind: .error)
                return
            }
        }
        showBanner("All conflicts resolved (ours)", kind: .success)
        await refresh()
        await loadConflicts()
    }

    // MARK: - Navigation

    var showingDiffFor: String? = nil

    func conflictCount(for path: String) -> Int {
        let repo = repoManager.repoURL
        let fileUrl = repo.appendingPathComponent(path)
        guard let content = try? String(contentsOf: fileUrl, encoding: .utf8) else { return 0 }
        let markers = content.components(separatedBy: "<<<<<<<").count - 1
        return max(1, markers)
    }

    func stage(_ file: GitFile) {
        Task { await stageFile(file.filename) }
    }
    
    func unstage(_ file: GitFile) {
        Task { await unstageFile(file.filename) }
    }
    
    func discard(_ file: GitFile) {
        Task { await discardChanges(file.filename) }
    }
    
    func showInFinder(_ file: GitFile) {
        let repo = repoManager.repoURL
        let fileUrl = repo.appendingPathComponent(file.filename)
        NSWorkspace.shared.activateFileViewerSelecting([fileUrl])
    }
    
    func copyPath(_ file: GitFile) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(file.filename, forType: .string)
    }

    func showDiff(for file: GitFile) {
        showingDiffFor = file.filename
    }
}
