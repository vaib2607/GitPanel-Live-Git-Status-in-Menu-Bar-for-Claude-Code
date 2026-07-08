import SwiftUI

struct RepositoryInfoView: View {
    @ObservedObject var viewModel: EnvironmentViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .hoverable(radius: 6)
                }
                .buttonStyle(.plain)
                .help("Back")

                Text("Repository Info")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                Spacer()
            }
            .frame(height: 28)

            PanelDivider()

            // Remotes
            if !viewModel.remotes.isEmpty {
                SectionHeader(title: "Remotes")
                ForEach(viewModel.remotes) { remote in
                    SourceRow(title: remote.name, subtitle: remote.url)
                }
            }

            // Submodules
            if !viewModel.submodules.isEmpty {
                SectionHeader(title: "Submodules")
                ForEach(viewModel.submodules) { sub in
                    SourceRow(title: sub.name, subtitle: sub.url)
                }
            }

            // Dependencies
            if !viewModel.dependencies.isEmpty {
                SectionHeader(title: "Dependencies")
                ForEach(viewModel.dependencies, id: \.self) { dep in
                    SourceRow(title: dep, subtitle: nil)
                }
            }

            if viewModel.remotes.isEmpty && viewModel.submodules.isEmpty && viewModel.dependencies.isEmpty {
                Text("No sources yet")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SourceRow: View {
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, design: .monospaced))
            Spacer()
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 12)
        .hoverable(radius: 8)
    }
}
