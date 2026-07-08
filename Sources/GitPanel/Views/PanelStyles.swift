import SwiftUI

// MARK: - Diff summary view (CodexBar-style)

struct DiffSummaryView: View {
    let diff: DiffStats

    var body: some View {
        HStack(spacing: 8) {
            if diff.isClean {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 13))
                Text("No changes")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                if diff.totalAdded > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 13))
                        Text("\(diff.totalAdded)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                }
                if diff.totalDeleted > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 13))
                        Text("\(diff.totalDeleted)")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.red)
                    }
                }
                Text("\(diff.filesChanged) file\(diff.filesChanged == 1 ? "" : "s")")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - File stats chips

struct FileStatsView: View {
    let diff: DiffStats

    var body: some View {
        HStack(spacing: 6) {
            if diff.stagedFiles > 0 {
                statChip(count: diff.stagedFiles, label: "staged", color: .blue)
            }
            if diff.unstagedFiles > 0 {
                statChip(count: diff.unstagedFiles, label: "modified", color: .orange)
            }
            if diff.untrackedFiles > 0 {
                statChip(count: diff.untrackedFiles, label: "new", color: .green)
            }
            if diff.conflicts > 0 {
                statChip(count: diff.conflicts, label: "conflicts", color: .red)
            }
        }
    }

    private func statChip(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
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
    let ahead: Int
    let behind: Int

    var body: some View {
        HStack(spacing: 6) {
            if ahead > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(ahead)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
                .foregroundStyle(.orange)
            }
            if behind > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(behind)")
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
            Circle()
                .fill(state.accentColor)
                .frame(width: 6, height: 6)
            Text(state.label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(state.accentColor.opacity(0.12))
        )
        .foregroundStyle(state.accentColor)
    }
}

// MARK: - Footer actions view

struct FooterActionsView: View {
    let onSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSettings) {
                HStack(spacing: 3) {
                    Image(systemName: "gear")
                        .font(.system(size: 11))
                    Text("Settings")
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
            .hoverable(radius: 4)

            Spacer()

            Button(action: onQuit) {
                Text("Quit")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .hoverable(radius: 4)
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

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .tracking(1)
            .foregroundStyle(.secondary)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .secondary

    var body: some View {
        HStack(spacing: 12) {
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
    }
}

struct DropdownRow: View {
    let icon: String
    let title: String
    let value: String
    var valueFont: Font = .system(size: 13, design: .monospaced)
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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
