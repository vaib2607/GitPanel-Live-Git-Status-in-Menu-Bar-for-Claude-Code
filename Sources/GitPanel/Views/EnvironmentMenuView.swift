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
                            .font(.system(size: 13, design: .monospaced))
                            .frame(width: 16)
                        Text(mode.rawValue)
                            .font(.system(size: 13, design: .monospaced))
                        Spacer()
                        if mode == .codex {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        if viewModel.environmentMode == mode {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
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
            }

            Divider().padding(.vertical, 8)

            // Usage remaining
            Button {
                onShowUsage()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 16)
                    Text("Usage remaining")
                        .font(.system(size: 13, design: .monospaced))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .hoverable(radius: 8)

            // Repository Info (drill-down)
            Button {
                onShowRepoInfo()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 16)
                    Text("Repository Info")
                        .font(.system(size: 13, design: .monospaced))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .hoverable(radius: 8)
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
