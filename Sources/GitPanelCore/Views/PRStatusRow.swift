import SwiftUI

struct PRStatusRow: View {
    let viewModel: GitPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider().opacity(0.15)
            switch viewModel.prStatus {
            case .noPRs:
                emptyRow
            case .notInstalled:
                notInstalledRow
            case .pullRequests(let prs):
                ForEach(prs) { pr in
                    prRow(pr)
                    if pr.id != prs.last?.id {
                        Divider().opacity(0.1)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.pull")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Pull Requests")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: viewModel.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .rotationEffect(viewModel.isRefreshing ? .degrees(360) : .zero)
                    .animation(viewModel.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isRefreshing)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRefreshing)
            .accessibilityLabel("Refresh pull requests")
            .accessibilityHint("Reloads the list of pull requests from the remote")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Empty

    private var emptyRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(.green)
            Text("No open pull requests")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No open pull requests")
    }

    // MARK: - Not Installed

    private var notInstalledRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Install gh for PR status")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Link("brew install gh", destination: URL(string: "https://cli.github.com")!)
                    .font(.system(size: 11, design: .monospaced)) // Commands are fine as monospaced
                    .foregroundStyle(.blue)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("GitHub CLI is not installed. Install gh for PR status.")
        .accessibilityHint("Visit the GitHub CLI website to install")
    }

    // MARK: - PR Row

    private func prRow(_ pr: PRInfo) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("#\(pr.number)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced)) // Numbers can be monospaced
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(pr.title)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(pr.author)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(pr.state)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(pr.state == "OPEN" ? .green : .orange)
                    if let decision = pr.reviewDecision, !decision.isEmpty {
                        Text(decision)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                }
            }
            Spacer()
            if let url = URL(string: pr.url) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open PR #\(pr.number) in browser")
                .accessibilityHint("Opens pull request \(pr.title) in your web browser")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pull request #\(pr.number): \(pr.title), by \(pr.author), status \(pr.state)")
        .accessibilityHint("Contains PR details and a link to view on GitHub")
    }
}
