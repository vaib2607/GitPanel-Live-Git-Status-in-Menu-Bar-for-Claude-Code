import SwiftUI

enum PanelRoute {
    case main, branch, environment, usage, repositoryInfo
}

struct EnvironmentPanel: View {
    @ObservedObject var viewModel: EnvironmentViewModel
    @ObservedObject var repoManager: RepoManager
    @State private var route: PanelRoute = .main
    @State private var showRepoPicker = false
    @State private var isDragTargeted = false

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
                UsageView(settings: viewModel.settings, usage: viewModel.usage, onBack: { route = .main })
            case .repositoryInfo:
                RepositoryInfoView(viewModel: viewModel, onBack: { route = .main })
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
                repoManager.setRepo(url)
                viewModel.refresh()
                viewModel.startWatching()
            })
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
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .hoverable(radius: 6)
                }
                .buttonStyle(.plain)
                .help("Back")
            }
            Image(systemName: "terminal")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
            Text(route == .main ? "Environment" : title(for: route))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
            Spacer()
            if route == .main {
                Button {
                    showRepoPicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .hoverable(radius: 6)
                }
                .buttonStyle(.plain)
                .help("Select repository")
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
                // Banner
                if let banner = viewModel.banner {
                    BannerView(banner: banner)
                        .padding(.bottom, 8)
                }

                // Header card: repo name + branch + state
                repoHeaderCard

                // Diff summary
                DiffSummaryView(diff: viewModel.snapshot.diff)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                // File stats chips
                if !viewModel.snapshot.diff.isClean {
                    FileStatsView(diff: viewModel.snapshot.diff)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }

                // Ahead/behind badges
                if viewModel.ahead > 0 || viewModel.behind > 0 {
                    AheadBehindBadges(ahead: viewModel.ahead, behind: viewModel.behind)
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
                PRStatusRow(prStatus: viewModel.prStatus)

                // Footer actions
                PanelDivider()
                FooterActionsView(
                    onSettings: { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) },
                    onQuit: { NSApp.terminate(nil) }
                )
            }
        }
    }

    private var notAGitRepoView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not a git repository")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(repoManager.repoURL.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    private var repoHeaderCard: some View {
        HStack(spacing: 10) {
            // Repo icon
            Image(systemName: "folder.fill")
                .font(.system(size: 18, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.snapshot.name)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(viewModel.currentBranch)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    RepoStateBadge(state: viewModel.snapshot.state)
                }
            }
            Spacer()
            // Refresh indicator
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .padding(.bottom, 8)
        .contextMenu {
            Button("Refresh") { viewModel.refresh() }
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
    let viewModel: EnvironmentViewModel
    @Binding var isTargeted: Bool

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        guard let items = info.itemProviders(for: [.fileURL]).first else { return false }
        items.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                self.stageFile(at: url)
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

    private func stageFile(at url: URL) {
        let repo = viewModel.repoManager.repoURL
        let relativePath = url.path.replacingOccurrences(of: repo.path + "/", with: "")
        _ = ShellRunner.run(
            executable: GitService.gitPath,
            arguments: ["add", relativePath],
            workingDirectory: repo
        )
        viewModel.refresh()
    }
}

struct PanelDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
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
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                if let detail = banner.detail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
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
    }
}
