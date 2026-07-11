import SwiftUI

struct CommitSection: View {
    @Bindable var viewModel: GitPanelViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                TextField("Message", text: $viewModel.commitMessage)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .accessibilityLabel("Commit message")
                    .accessibilityHint("Enter a message for your commit")
                
                Button {
                    Task {
                        viewModel.isPerformingGitOperation = true
                        defer { viewModel.isPerformingGitOperation = false }
                        let diff = await viewModel.fetchDiffCached(for: "")
                        let msg = try? await CommitAssistant.shared.generateCommitMessage(diff: diff)
                        if let msg = msg {
                            viewModel.commitMessage = msg
                        }
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                .help("Auto-generate commit message")
            }

            HStack(spacing: 6) {
                Button {
                    Task { await viewModel.commit() }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isCommitting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Commit")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Commit staged changes")
                .accessibilityLabel("Commit staged changes")
                .accessibilityHint("Commits your staged changes with the entered message")

                Button {
                    Task { await viewModel.commitAndPush() }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isCommitting || viewModel.isPushing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Commit & Push")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isCommitting
                        || viewModel.isPushing
                )
                .help("Commit and push to remote")
                .accessibilityLabel("Commit and push changes")
                .accessibilityHint("Commits staged changes and pushes them to the remote repository")

                Button {
                    Task { await viewModel.push() }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isPushing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Push")
                            .font(.system(size: 12))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.state.isAheadOfRemote || viewModel.isPushing)
                .help("Push committed changes")
                .accessibilityLabel("Push to remote")
                .accessibilityHint("Pushes committed changes to the remote repository")
            }
        }
        .padding(.vertical, 4)
    }
}
