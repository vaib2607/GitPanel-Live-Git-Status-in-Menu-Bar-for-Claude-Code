import SwiftUI

// PanelRoute removed, using AppRouter and GitPanelRoute from AppRouter.swift

enum AppTab {
    case overview, codex, claude
}

struct EnvironmentPanel: View {
    var viewModel: GitPanelViewModel
    var repoManager: RepoManager
    @State private var selectedTab: AppTab = .overview
    @State private var router = AppRouter()
    @State private var showRepoPicker = false
    @State private var isDragTargeted = false
    @State private var isHovered = false
    @State private var isRowHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if router.currentRoute.isMain {
                topTabBar
                PanelDivider()
            }
            
            VStack(alignment: .leading, spacing: 0) {
                header
                PanelDivider()
                routerView
            }
        }
        .frame(width: 360)
        .background(backgroundView)
        .onDrop(of: [.fileURL], delegate: DropHandler(viewModel: viewModel, isTargeted: $isDragTargeted))
        .sheet(isPresented: $showRepoPicker) {
            RepoPicker(onPicked: { url in
                try? repoManager.setRepo(url)
                Task { await viewModel.refresh() }
                viewModel.startWatching()
            })
        }
        .overlay(alignment: .top) {
            if let banner = viewModel.banner {
                BannerView(banner: banner).padding(12)
            }
        }
        .onChange(of: viewModel.showingDiffFor) { _, newValue in
            if let path = newValue {
                let repoID = RepositoryID(path: repoManager.repoURL.path)
                router.push(.diffViewer(repo: repoID, path: path))
            }
        }
    }
    
    private var topTabBar: some View {
        HStack(spacing: 0) {
            TabButton(title: "Overview", icon: "square.grid.2x2", isSelected: selectedTab == .overview, color: .primary) { selectedTab = .overview }
            TabButton(title: "Codex", icon: "bolt.fill", isSelected: selectedTab == .codex, color: .blue) { selectedTab = .codex }
            TabButton(title: "Claude", icon: "sparkles", isSelected: selectedTab == .claude, color: .orange) { selectedTab = .claude }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
    
    @ViewBuilder private var routerView: some View {
        switch router.currentRoute {
        case .main(_):
            if selectedTab == .overview {
                mainContent
            } else if selectedTab == .codex {
                AgentDashboardView(providerName: "Codex", isPro: false, color: .blue, viewModel: viewModel)
                    .environment(router)
            } else if selectedTab == .claude {
                AgentDashboardView(providerName: "Claude", isPro: true, color: .orange, viewModel: viewModel)
                    .environment(router)
            }
        case .branch(_):
            BranchListView(viewModel: viewModel, onBack: { router.pop() })
        case .environment:
            EnvironmentMenuView(
                viewModel: viewModel,
                onBack: { router.pop() },
                onShowUsage: { router.push(.usage) },
                onShowRepoInfo: {
                    let repoID = RepositoryID(path: repoManager.repoURL.path)
                    router.push(.repositoryInfo(repoID))
                }
            )
        case .usage:
            UsageView(viewModel: viewModel)
        case .usageDetail(_):
            UsageDetailView(viewModel: viewModel, onBack: { router.pop() })
        case .costDetail(_):
            CostDetailView(viewModel: viewModel, onBack: { router.pop() })
        case .repositoryInfo(_):
            RepositoryInfoView(viewModel: viewModel)
        case .fileList(_):
            FileListView(viewModel: viewModel)
        case .diffViewer(_, let path):
            DiffViewerView(viewModel: viewModel, filePath: path, onBack: {
                viewModel.showingDiffFor = nil
                router.pop()
            })
        case .stash(_):
            StashView(viewModel: viewModel, onBack: { router.pop() })
        case .conflicts(_):
            ConflictResolverView(viewModel: viewModel, onBack: { router.pop() })
        case .settings:
            Text("Not implemented")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    @ViewBuilder private var backgroundView: some View {
        Group {
            if isDragTargeted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .padding(2)
            }
            Color(NSColor.windowBackgroundColor)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            if !router.currentRoute.isMain {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .hoverable(radius: 6)
                }
                .buttonStyle(.plain)
                .help("Back")
                .accessibilityLabel("Go back")
                .accessibilityHint("Returns to the previous panel")
            }
            if let activeIcon = AIEngine.shared.activeProviderIcon {
                Text(activeIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            } else {
                Image(systemName: "terminal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Text(router.currentRoute.isMain ? (AIEngine.shared.activeProviderName ?? "Environment") : title(for: router.currentRoute))
                .font(.system(size: 13, weight: .medium))
            Spacer()
            if router.currentRoute.isMain {
                Button {
                    showRepoPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .hoverable(radius: 6)
                }
                .buttonStyle(.plain)
                .help("Select repository")
                .accessibilityLabel("Add repository")
                .accessibilityHint("Opens the repository picker to select a repository")
            }
        }
        .frame(height: 28)
    }

    private func title(for route: GitPanelRoute) -> String {
        switch route {
        case .branch(_): return "Branch"
        case .environment: return "Continue in"
        case .usage: return "Usage"
        case .usageDetail(_): return "Plan Usage"
        case .costDetail(_): return "Cost"
        case .repositoryInfo(_): return "Repository Info"
        case .fileList(_): return "Changed Files"
        case .diffViewer(_, _): return "Diff"
        case .stash(_): return "Stash"
        case .conflicts(_): return "Conflicts"
        default: return "Environment"
        }
    }

    // MARK: - Main content (CodexBar-style card)

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch viewModel.repositoryState {
            case .idle:
                Color.clear.onAppear { Task { await viewModel.refresh() } }
            case .loading:
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.regular)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            case .failed(let error):
                ErrorRecoveryView(
                    error: error,
                    retryAction: { Task { await viewModel.refresh() } }
                )
            case .loaded(let snapshot, _):
                if !snapshot.status.isGitRepo {
                    notAGitRepoView
                } else {
                    loadedRepoContent(snapshot: snapshot)
                }
            case .empty(_), .unavailable(_):
                notAGitRepoView
            }
        }
    }

    private func loadedRepoContent(snapshot: RepositorySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header card: repo name + branch + state
            repoHeaderCard(snapshot: snapshot)

            // Diff summary
            DiffSummaryView(state: snapshot.status)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // File stats chips
            if snapshot.status.hasChanges {
                FileStatsView(state: snapshot.status)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            // Ahead/behind badges
            if snapshot.status.isAheadOfRemote || snapshot.status.isBehindRemote {
                AheadBehindBadges(state: snapshot.status)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

                PanelDivider()

            let repoID = RepositoryID(path: repoManager.repoURL.path)

            NavigationRow(icon: "doc.on.doc", title: "Changed Files", count: snapshot.changes.staged.count + snapshot.changes.unstaged.count + snapshot.changes.untracked.count) {
                router.push(.fileList(repoID))
            }
            NavigationRow(icon: "tray", title: "Stash", count: viewModel.stashEntries.count) {
                router.push(.stash(repoID))
            }
            NavigationRow(icon: "exclamationmark.triangle", title: "Conflicts", count: viewModel.conflictedFiles.count) {
                router.push(.conflicts(repoID))
            }

            PanelDivider()

            // Branch dropdown
            DropdownRow(icon: "arrow.branch", title: "Branch", value: snapshot.status.branchName) {
                router.push(.branch(repoID))
            }

            // Commit section
            CommitSection(viewModel: viewModel)

            PanelDivider()

            // PR status
            PRStatusRow(viewModel: viewModel)

            // Footer actions
            PanelDivider()
            FooterActionsView(viewModel: viewModel)
        }
    }

    private var notAGitRepoView: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("No Repository Selected")
                .font(.system(size: 14, weight: .medium))
            
            Text("Select a valid Git repository to view its status.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Choose Repository...") {
                showRepoPicker = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }

    private func repoHeaderCard(snapshot: RepositorySnapshot) -> some View {
        HStack(spacing: 8) {
            // Repo icon
            Image(systemName: "folder.fill")
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.status.repoName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(snapshot.status.branchName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    RepoStateBadge(state: snapshot.status.repoState)
                }
            }
            Spacer()
            // Refresh indicator
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Refreshing repository")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: isRowHovered ? .selectedControlColor : .controlBackgroundColor))
        )
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onHover { hovering in isRowHovered = hovering }
        .onTapGesture {
            router.push(.environment)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Repository: \(snapshot.status.repoName), branch: \(snapshot.status.branchName)")
        .accessibilityHint("Tap to open environment options")
        .contextMenu {
            Button("Refresh") { Task { await viewModel.refresh() } }
            Divider()
            Button("Open in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([viewModel.repoManager.repoURL])
            }
            Button("Copy Branch Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(snapshot.status.branchName, forType: .string)
            }
            Divider()
            Button("Select Repository…") { showRepoPicker = true }
        }
    }
}

struct ErrorRecoveryView: View {
    let error: UserFacingError
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.red)
            
            Text(error.title)
                .font(.system(size: 14, weight: .medium))
            
            Text(error.message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            if let action = error.recoveryAction {
                Button(action.title, action: retryAction)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
}

// MARK: - Drag & Drop

struct DropHandler: DropDelegate {
    let viewModel: GitPanelViewModel
    @Binding var isTargeted: Bool

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        guard let items = info.itemProviders(for: [.fileURL]).first else { return false }
        items.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                Task { await self.viewModel.stageFile(url.path) }
            }
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }
}

struct BannerView: View {
    let banner: BannerMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: banner.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(banner.kind == .success ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(banner.title)
                    .font(.system(size: 12, weight: .medium))
                if let detail = banner.detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(banner.title): \(banner.detail ?? "")")
    }
}

struct NavigationRow: View {
    let icon: String
    let title: String
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 32)
        .padding(.horizontal, 8)
        .hoverable(radius: 6)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(isSelected ? color : .secondary)
                Text(title)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(color.opacity(0.15))
                    }
                }
            )
            .overlay(
                Group {
                    if isSelected {
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(color)
                                .frame(height: 2)
                        }
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

