import SwiftUI

struct CommitSection: View {
    @ObservedObject var viewModel: EnvironmentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Message", text: $viewModel.commitMessage)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
            HStack(spacing: 8) {
                Button {
                    viewModel.commit()
                } label: {
                    Text("Commit")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.commitMessage.isEmpty || !viewModel.snapshot.diff.isClean.not)
                .help("Commit staged changes")

                Button {
                    viewModel.commitAndPush()
                } label: {
                    Text("Commit & Push")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.commitMessage.isEmpty || !viewModel.snapshot.diff.isClean.not)
                .help("Commit and push to remote")

                Button {
                    viewModel.push()
                } label: {
                    Text("Push")
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Push committed changes")
            }
        }
        .padding(.vertical, 4)
    }
}

private extension Bool {
    var not: Bool { !self }
}
