import Foundation
import SwiftUI

@MainActor
final class EnvironmentViewModel: ObservableObject {
    @Published var snapshot: RepositorySnapshot = .empty
    @Published var branches: [GitBranch] = []
    @Published var prStatus: PRStatus = .unavailable
    @Published var commitMessage = ""
    @Published var environmentMode: EnvironmentMode = .local
    @Published var banner: BannerMessage?
    @Published var isRefreshing = false
    @Published var usage: UsageData = UsageData(inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheCreationTokens: 0, estimatedCost: 0, cursorPlan: nil, source: .none)

    // Backward-compatible computed properties
    var status: GitStatus {
        GitStatus(
            added: snapshot.diff.stagedFiles,
            modified: snapshot.diff.unstagedFiles,
            deleted: 0,
            untracked: snapshot.diff.untrackedFiles
        )
    }
    var currentBranch: String { snapshot.branch }
    var ahead: Int { snapshot.ahead }
    var behind: Int { snapshot.behind }
    var isGitRepo: Bool { snapshot.isGitRepo }
    var submodules: [Submodule] { snapshot.submodules }
    var remotes: [Remote] { snapshot.remotes }
    var dependencies: [String] { snapshot.dependencies }

    let repoManager: RepoManager
    let settings: AppSettings
    private let git = GitService()
    private let github = GitHubService()
    private var lastUsage = Date.distantPast
    private var fileWatcher: FileWatcher?

    init(repoManager: RepoManager, settings: AppSettings) {
        self.repoManager = repoManager
        self.settings = settings
        refresh()
        startWatching()
    }

    // MARK: - Refresh (snapshot pattern)

    func refresh() {
        let repo = repoManager.repoURL
        let git = self.git
        let github = self.github
        let manual = settings.usageRemaining
        let shouldComputeUsage = Date().timeIntervalSince(lastUsage) > 30
        if shouldComputeUsage { lastUsage = Date() }

        isRefreshing = true

        DispatchQueue.global(qos: .userInitiated).async {
            let isRepo = git.isGitRepo(repo: repo)
            let porcelain = isRepo ? git.porcelainV2(repo: repo) : GitService.PorcelainV2Result(ahead: 0, behind: 0, staged: 0, unstaged: 0, untracked: 0, conflicts: 0)
            let numstat = isRepo ? git.diffNumstat(repo: repo) : GitService.NumstatResult(added: 0, deleted: 0)
            let cached = isRepo ? git.diffCachedNumstat(repo: repo) : GitService.NumstatResult(added: 0, deleted: 0)
            let state = isRepo ? git.detectRepoState(repo: repo) : .clean
            let branch = isRepo ? git.currentBranch(repo: repo) : ""
            let branches = isRepo ? git.branches(repo: repo) : []
            let pr = github.prStatus(repo: repo)
            let rems = isRepo ? git.remotes(repo: repo) : []
            let subs = isRepo ? git.submodules(repo: repo) : []
            let deps = isRepo ? git.dependencies(repo: repo) : []
            let usage = shouldComputeUsage ? UsageService.compute(manual: manual) : nil

            let diff = DiffStats(
                linesAdded: numstat.added,
                linesDeleted: numstat.deleted,
                stagedLinesAdded: cached.added,
                stagedLinesDeleted: cached.deleted,
                filesChanged: porcelain.staged + porcelain.untracked,
                stagedFiles: porcelain.staged,
                unstagedFiles: porcelain.unstaged,
                untrackedFiles: porcelain.untracked,
                conflicts: porcelain.conflicts
            )

            let snapshot = RepositorySnapshot(
                name: repo.lastPathComponent,
                branch: branch,
                isGitRepo: isRepo,
                state: state,
                diff: diff,
                ahead: porcelain.ahead,
                behind: porcelain.behind,
                lastUpdated: Date(),
                remotes: rems,
                submodules: subs,
                dependencies: deps
            )

            DispatchQueue.main.async {
                self.snapshot = snapshot
                self.branches = branches
                self.prStatus = pr
                if let usage = usage { self.usage = usage }
                self.isRefreshing = false
            }
        }
    }

    // MARK: - File watching

    func startWatching() {
        fileWatcher?.stop()
        fileWatcher = FileWatcher(repoURL: repoManager.repoURL) { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }
        fileWatcher?.start()
    }

    // MARK: - Git operations

    func commit() {
        guard !commitMessage.isEmpty else { return }
        let r = git.commit(repo: repoManager.repoURL, message: commitMessage)
        if !r.success {
            showBanner("Commit failed", detail: r.output, kind: .error)
        } else {
            showBanner("Committed", detail: nil, kind: .success)
        }
        commitMessage = ""
        refresh()
    }

    func push() {
        let r = git.push(repo: repoManager.repoURL)
        if !r.success {
            let detail = r.output.isEmpty ? "No upstream set for this branch." : r.output
            showBanner("Push failed", detail: detail, kind: .error)
        } else {
            showBanner("Pushed", detail: nil, kind: .success)
        }
        refresh()
    }

    func commitAndPush() {
        guard !commitMessage.isEmpty else { return }
        let c = git.commit(repo: repoManager.repoURL, message: commitMessage)
        if !c.success {
            showBanner("Commit failed", detail: c.output, kind: .error)
            return
        }
        commitMessage = ""
        let p = git.push(repo: repoManager.repoURL)
        if !p.success {
            let detail = p.output.isEmpty ? "No upstream set for this branch." : p.output
            showBanner("Committed but push failed", detail: detail, kind: .error)
        } else {
            showBanner("Committed & pushed", detail: nil, kind: .success)
        }
        refresh()
    }

    func checkout(_ branch: GitBranch) {
        git.checkout(repo: repoManager.repoURL, branch: branch.name)
        refresh()
    }

    func createBranch(_ name: String) {
        git.createBranch(repo: repoManager.repoURL, name: name)
        refresh()
    }

    private func showBanner(_ title: String, detail: String?, kind: BannerMessage.Kind) {
        banner = BannerMessage(title: title, detail: detail, kind: kind)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if self.banner?.title == title { self.banner = nil }
        }
    }
}

struct BannerMessage: Identifiable {
    let id = UUID()
    let title: String
    let detail: String?
    let kind: Kind
    enum Kind { case success, error }
}
