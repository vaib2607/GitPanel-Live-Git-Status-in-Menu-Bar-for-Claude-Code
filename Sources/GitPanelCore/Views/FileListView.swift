import SwiftUI

struct FileListView: View {
    var viewModel: GitPanelViewModel
    @State private var hoveredFile: GitFile?
    @State private var selectedFile: GitFile?
    @State private var isDragging = false

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                stagedSection
                unstagedSection
                untrackedSection
                if viewModel.stagedFiles.isEmpty && viewModel.unstagedFiles.isEmpty && viewModel.untrackedFiles.isEmpty {
                    emptyState
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)
            Text("No changes")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .contentShape(Rectangle())
    }

    // MARK: - Staged Section

    private var stagedSection: some View {
        Group {
            if !viewModel.stagedFiles.isEmpty {
                sectionHeader(title: "Staged Changes", count: viewModel.stagedFiles.count)
                ForEach(viewModel.stagedFiles) { file in
                    fileRow(file, isStaged: true)
                }
            }
        }
    }

    // MARK: - Unstaged Section

    private var unstagedSection: some View {
        Group {
            if !viewModel.unstagedFiles.isEmpty {
                sectionHeader(title: "Unstaged Changes", count: viewModel.unstagedFiles.count)
                ForEach(viewModel.unstagedFiles) { file in
                    fileRow(file, isStaged: false)
                }
            }
        }
    }

    // MARK: - Untracked Section

    private var untrackedSection: some View {
        Group {
            if !viewModel.untrackedFiles.isEmpty {
                sectionHeader(title: "Untracked Files", count: viewModel.untrackedFiles.count)
                ForEach(viewModel.untrackedFiles) { file in
                    fileRow(file, isStaged: false)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text("\(title) (\(count))")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, count == viewModel.stagedFiles.count ? 0 : 8)
        .padding(.bottom, 2)
    }

    // MARK: - File Row

    private func fileRow(_ file: GitFile, isStaged: Bool) -> some View {
        let isHovered = hoveredFile?.id == file.id

        return HStack(spacing: 6) {
            statusIcon(for: file.status)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(file.filename)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if file.status == .renamed, let oldName = file.oldFilename {
                        Text(oldName)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Spacer()

            if file.additions > 0 || file.deletions > 0 {
                HStack(spacing: 4) {
                    if file.additions > 0 {
                        Text("+\(file.additions)")
                            .foregroundStyle(.green)
                    }
                    if file.deletions > 0 {
                        Text("-\(file.deletions)")
                            .foregroundStyle(.red)
                    }
                }
                .font(.system(.caption2, design: .monospaced))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredFile = hovering ? file : nil
        }
        .onTapGesture {
            selectedFile = file
            viewModel.showDiff(for: file)
        }
        .contextMenu {
            fileContextMenu(file: file, isStaged: isStaged)
        }
        .onDrag {
            isDragging = true
            return NSItemProvider(object: file.filename as NSString)
        }
    }

    // MARK: - Status Icon

    private func statusIcon(for status: GitFileStatus) -> some View {
        let config: (name: String, color: Color) = {
            switch status {
            case .modified:
                return ("pencil.circle.fill", .orange)
            case .added:
                return ("plus.circle.fill", .green)
            case .deleted:
                return ("minus.circle.fill", .red)
            case .untracked:
                return ("questionmark.circle.fill", .gray)
            case .renamed:
                return ("arrow.right.circle.fill", .blue)
            case .copied:
                return ("doc.on.doc.fill", .purple)
            }
        }()

        return Image(systemName: config.name)
            .font(.system(size: 14))
            .foregroundStyle(config.color)
            .frame(width: 20)
    }

    // MARK: - Context Menu

    private func fileContextMenu(file: GitFile, isStaged: Bool) -> some View {
        Group {
            if isStaged {
                Button("Unstage") {
                    viewModel.unstage(file)
                }
            } else {
                Button("Stage") {
                    viewModel.stage(file)
                }
            }

            Button("Discard") {
                viewModel.discard(file)
            }

            Divider()

            Button("Show in Finder") {
                viewModel.showInFinder(file)
            }

            Button("Copy Path") {
                viewModel.copyPath(file)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FileListView(viewModel: GitPanelViewModel())
}
