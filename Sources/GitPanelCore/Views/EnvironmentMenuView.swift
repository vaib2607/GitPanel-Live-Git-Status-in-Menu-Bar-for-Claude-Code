import SwiftUI

struct EnvironmentMenuView: View {
    @Bindable var viewModel: GitPanelViewModel
    let onBack: () -> Void
    let onShowUsage: () -> Void
    let onShowRepoInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(EnvironmentMode.allCases) { mode in
                Button {
                    viewModel.environmentMode = mode
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: icon(for: mode))
                            .font(.system(size: 13))
                            .frame(width: 16)
                        Text(mode.rawValue)
                            .font(.system(size: 13))
                        Spacer()
                        if mode == .codex {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        if viewModel.environmentMode == mode {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .disabled(mode == .cloud)
                .opacity(mode == .cloud ? 0.4 : 1)
                .hoverable(radius: 8)
                .accessibilityLabel("\(mode.rawValue)\(viewModel.environmentMode == mode ? ", currently selected" : "")")
                .accessibilityHint(mode == .cloud ? "This option is not available" : "Tap to switch to \(mode.rawValue) environment")
            }

            Divider().padding(.vertical, 8)

            // Usage remaining
            Button {
                onShowUsage()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .frame(width: 16)
                    Text("Usage remaining")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .hoverable(radius: 8)
            .accessibilityLabel("Usage remaining")
            .accessibilityHint("Shows token and cost usage details")

            Button {
                onShowRepoInfo()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .frame(width: 16)
                    Text("Repository Info")
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .hoverable(radius: 8)
            .accessibilityLabel("Repository Info")
            .accessibilityHint("Shows remotes and submodules for this repository")

            Divider().padding(.vertical, 8)

            SectionHeader(title: "Recent Repositories")
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            ForEach(viewModel.repoManager.history, id: \.self) { path in
                let url = URL(fileURLWithPath: path)
                HStack {
                    Button {
                        try? viewModel.repoManager.setRepo(url)
                        Task {
                            await viewModel.refresh()
                            viewModel.startWatching()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 13))
                                .frame(width: 16)
                            Text(url.lastPathComponent)
                                .font(.system(size: 13))
                            Spacer()
                            if url.path == viewModel.repoManager.repoURL.path {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(url.lastPathComponent)\(url.path == viewModel.repoManager.repoURL.path ? ", currently active" : "")")
                    .accessibilityHint("Switches to this repository")

                    Spacer()

                    Button {
                        viewModel.repoManager.removeRepoFromHistory(path)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(url.lastPathComponent) from history")
                    .accessibilityHint("Deletes this repository from your recent history")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .hoverable(radius: 8)
            }
        }
    }

    func icon(for mode: EnvironmentMode) -> String {
        switch mode {
        case .local: return "laptopcomputer"
        case .codex: return "globe"
        case .cloud: return "cloud"
        case .production: return "checkmark.circle"
        case .development: return "wrench.and.screwdriver"
        }
    }
}
