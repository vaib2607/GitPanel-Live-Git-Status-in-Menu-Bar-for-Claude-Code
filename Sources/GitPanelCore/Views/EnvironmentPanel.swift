import SwiftUI

enum PanelRoute {
    case main, branch, environment, usage, repositoryInfo
}

struct EnvironmentPanel: View {
    var viewModel: GitPanelViewModel
    var repoManager: RepoManager
    @State private var route: PanelRoute = .main
    @State private var showRepoPicker = false
    @State private var isDragTargeted = false
    @State private var isHovered = false
    @State private var isRowHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            PanelDivider()

            switch route {
            case .main:
                mainContent
            case .branch:
                BranchListView(viewModel: viewModel, onBack: { route = .main })
            case .environment:
                EnvironmentMenuView(viewModel: viewModel, onBack: { route = .main }, onShowUsage: { route = .usage }, onShowRepoInfo: { route = .repositoryInfo })
            case .usage:
                UsageView(viewModel: viewModel)
            case .repositoryInfo:
                RepositoryInfoView(viewModel: viewModel)
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(
            Group {
                if isDragTargeted {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .padding(2)
                }
                Color(NSColor.windowBackgroundColor)
            }
        )
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
                BannerView(banner: banner)
                    .padding(12)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            if route != .main {
                Button {
                    route = .main
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
                .accessibilityHint("Returns to the main panel")
            }
            Image(systemName: "terminal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            Text(route == .main ? "Environment" : title(for: route))
                .font(.system(size: 13, weight: .medium))
            Spacer()
            if route == .main {
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

    private func title(for route: PanelRoute) -> String {
        switch route {
        case .branch: return "Branch"
        case .environment: return "Continue in"
        case .usage: return "Usage"
        case .repositoryInfo: return "Repository Info"
        default: return "Environment"
        }
    }

    // MARK: - Main content (CodexBar-style card)

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.isGitRepo {
                notAGitRepoView
            } else {
                // Header card: repo name + branch + state
                repoHeaderCard

                // Diff summary
                DiffSummaryView(state: viewModel.state)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                // File stats chips
                if viewModel.state.hasChanges {
                    FileStatsView(state: viewModel.state)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }

                // Ahead/behind badges
                if viewModel.ahead > 0 || viewModel.behind > 0 {
                    AheadBehindBadges(state: viewModel.state)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }

                PanelDivider()

                // Branch dropdown
                DropdownRow(icon: "arrow.branch", title: "Branch", value: viewModel.currentBranch) {
                    route = .branch
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
    }

    private var notAGitRepoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not a git repository")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(repoManager.repoURL.path)
                .font(.system(size: 11, design: .monospaced)) // Path is monospaced
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    private var repoHeaderCard: some View {
        HStack(spacing: 8) {
            // Repo icon
            Image(systemName: "folder.fill")
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.state.repoName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(viewModel.currentBranch)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    RepoStateBadge(state: viewModel.state.repoState)
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
            route = .environment
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Repository: \(viewModel.state.repoName), branch: \(viewModel.currentBranch)")
        .accessibilityHint("Tap to open environment options")
        .contextMenu {
            Button("Refresh") { Task { await viewModel.refresh() } }
            Divider()
            Button("Open in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([viewModel.repoManager.repoURL])
            }
            Button("Copy Branch Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(viewModel.currentBranch, forType: .string)
            }
            Divider()
            Button("Select Repository…") { showRepoPicker = true }
        }
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
