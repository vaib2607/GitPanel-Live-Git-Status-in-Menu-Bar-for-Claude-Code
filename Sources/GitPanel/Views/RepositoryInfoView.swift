import SwiftUI

struct RepositoryInfoView: View {
    var viewModel: GitPanelViewModel
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Divider()

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
        }
        .font(.caption)
        .monospaced()
    }

    private var headerSection: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                    Text("Back")
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Repository Info")
                .font(.caption)
                .fontWeight(.semibold)
        }
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
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
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
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(submodule.url)
                        .font(.caption2)
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
            }
        }
    }
}
