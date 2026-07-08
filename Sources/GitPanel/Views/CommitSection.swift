import SwiftUI

struct CommitSection: View {
    @Bindable var viewModel: GitPanelViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Message", text: $viewModel.commitMessage)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))

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
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Commit staged changes")

                Button {
                    Task { await viewModel.commitAndPush() }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isCommitting || viewModel.isPushing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Commit & Push")
                            .font(.system(size: 12, design: .monospaced))
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

                Button {
                    Task { await viewModel.push() }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isPushing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Push")
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.state.isAheadOfRemote || viewModel.isPushing)
                .help("Push committed changes")
            }
        }
        .padding(.vertical, 4)
    }
}
