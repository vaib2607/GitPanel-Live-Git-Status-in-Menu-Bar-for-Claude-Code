import SwiftUI

struct BranchListView: View {
    @ObservedObject var viewModel: EnvironmentViewModel
    let onBack: () -> Void

    @State private var search = ""
    @State private var newBranch = ""

    var filtered: [GitBranch] {
        if search.isEmpty { return viewModel.branches }
        return viewModel.branches.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                TextField("Search branches", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader(title: "Branches")
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ForEach(filtered) { branch in
                        Button {
                            viewModel.checkout(branch)
                            onBack()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.branch")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                Text(branch.name)
                                    .font(.system(size: 13, design: .monospaced))
                                    .lineLimit(1)
                                Spacer()
                                if branch.isCurrent {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .hoverable(radius: 8)
                        .contextMenu {
                            Button("Checkout") {
                                viewModel.checkout(branch)
                                onBack()
                            }
                            Button("Copy Name") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(branch.name, forType: .string)
                            }
                            if !branch.isCurrent {
                                Divider()
                                Button("Delete", role: .destructive) {
                                    _ = ShellRunner.run(
                                        executable: GitService.gitPath,
                                        arguments: ["branch", "-D", branch.name],
                                        workingDirectory: viewModel.repoManager.repoURL
                                    )
                                    viewModel.refresh()
                                }
                            }
                        }
                    }

                    Divider().padding(.vertical, 8)

                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        TextField("New branch name", text: $newBranch)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                        Button {
                            guard !newBranch.isEmpty else { return }
                            viewModel.createBranch(newBranch)
                            newBranch = ""
                            onBack()
                        } label: {
                            Text("Create")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(12)
                }
            }
            .frame(maxHeight: 380)
        }
    }
}
