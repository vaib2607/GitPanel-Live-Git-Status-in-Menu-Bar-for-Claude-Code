import SwiftUI

struct RepositoryInfoView: View {
    var viewModel: GitPanelViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !viewModel.state.remotes.isEmpty {
                    remotesSection
                }

                if !viewModel.state.submodules.isEmpty {
                    submodulesSection
                }
            }
            .padding(12)
        }
        .font(.caption)
    }

    private var remotesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Remotes")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(viewModel.state.remotes) { remote in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(remote.name)
                            .font(.caption)
                            .fontWeight(.medium)
                        if remote.isDefault {
                            Text("default")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(.blue.opacity(0.2)))
                                .foregroundStyle(.blue)
                        }
                    }
                    Text(remote.url)
                        .font(.system(size: 10, design: .monospaced)) // URL is path-like, fine as monospaced
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Remote \(remote.name)\(remote.isDefault ? ", default" : ""), URL: \(remote.url)")
                .accessibilityHint("Double tap to copy the remote URL")
            }
        }
    }

    private var submodulesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Submodules")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(viewModel.state.submodules) { submodule in
                VStack(alignment: .leading, spacing: 2) {
                    Text(submodule.name)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(submodule.path)
                        .font(.system(size: 10, design: .monospaced)) // Path is monospaced
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(submodule.url)
                        .font(.system(size: 10, design: .monospaced)) // URL is monospaced
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    if let branch = submodule.branch {
                        Text("branch: \(branch)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Submodule \(submodule.name), path: \(submodule.path), URL: \(submodule.url)\(submodule.branch.map { ", branch: \($0)" } ?? "")")
                .accessibilityHint("Double tap to copy the submodule details")
            }
        }
    }
}
