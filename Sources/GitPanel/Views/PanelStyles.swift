import SwiftUI

// MARK: - Diff summary view (CodexBar-style)

struct DiffSummaryView: View {
    let state: GitState

    var body: some View {
        HStack(spacing: 4) {
            if !state.hasChanges {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 13))
                Text("No changes")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                if state.linesAdded > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 13))
                        Text("\(state.linesAdded)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    }
                }
                if state.linesDeleted > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 13))
                        Text("\(state.linesDeleted)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}

// MARK: - File stats chips

struct FileStatsView: View {
    let state: GitState

    var body: some View {
        HStack(spacing: 4) {
            if state.hasChanges {
                if state.stagedCount > 0 {
                    statChip(count: state.stagedCount, label: "staged", color: .blue)
                }
                if state.unstagedCount > 0 {
                    statChip(count: state.unstagedCount, label: "modified", color: .orange)
                }
                if state.untrackedCount > 0 {
                    statChip(count: state.untrackedCount, label: "new", color: .green)
                }
                if state.conflictCount > 0 {
                    statChip(count: state.conflictCount, label: "conflicts", color: .red)
                }
            }
        }
    }

    private func statChip(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .foregroundStyle(color)
    }
}

// MARK: - Ahead/behind badges

struct AheadBehindBadges: View {
    let state: GitState

    var body: some View {
        HStack(spacing: 4) {
            if state.isAheadOfRemote {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                    Text("ahead")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
                .foregroundStyle(.orange)
            }
            if state.isBehindRemote {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text("behind")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.blue.opacity(0.15)))
                .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Repo state badge

struct RepoStateBadge: View {
    let state: RepoState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(state.color)
            Text(state.label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(state.color.opacity(0.12))
        )
        .foregroundStyle(state.color)
    }
}

// MARK: - Footer actions view

struct FooterActionsView: View {
    let viewModel: GitPanelViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("Refresh")
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
            .hoverable(radius: 4)
            .contentShape(Rectangle())

            Spacer()

            Button {
                Task { await viewModel.push() }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11))
                    Text("Push")
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
            .hoverable(radius: 4)
            .contentShape(Rectangle())

            Button {
                Task { await viewModel.pull() }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 11))
                    Text("Pull")
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
            .hoverable(radius: 4)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Hoverable modifier

struct Hoverable: ViewModifier {
    var radius: CGFloat = 8
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(hovered ? Color(nsColor: .controlAccentColor).opacity(0.12) : Color.clear)
            )
            .onHover { hovered = $0 }
    }
}

extension View {
    func hoverable(radius: CGFloat = 8) -> some View {
        self.modifier(Hoverable(radius: radius))
    }
}

// MARK: - Panel divider

struct PanelDivider: View {
    var body: some View {
        Divider()
            .foregroundStyle(.quaternary)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(1)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Info row

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13, design: .monospaced))
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(valueColor)
        }
        .frame(minHeight: 32)
        .contentShape(Rectangle())
    }
}

// MARK: - Dropdown row

struct DropdownRow: View {
    let icon: String
    let title: String
    let value: String
    var valueFont: Font = .system(size: 13, design: .monospaced)
    let action: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13, design: .monospaced))
            Spacer()
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(value)
                        .font(valueFont)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 32)
        .padding(.horizontal, 8)
        .hoverable()
        .contentShape(Rectangle())
    }
}
