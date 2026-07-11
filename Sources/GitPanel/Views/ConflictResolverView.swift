import SwiftUI

struct ConflictResolverView: View {
    var viewModel: GitPanelViewModel
    var onBack: () -> Void

    @State private var hoveredFile: String?
    @State private var showResolveAllConfirmation = false
    @State private var showSuccessBanner = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if viewModel.conflictedFiles.isEmpty {
                emptyState
            } else {
                conflictList
            }
        }
        .onAppear {
            viewModel.loadConflicts()
        }
        .overlay(alignment: .top) {
            if showSuccessBanner {
                successBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSuccessBanner)
        .alert("Resolve All Conflicts", isPresented: $showResolveAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Accept Ours for All", role: .destructive) {
                viewModel.resolveAllConflictsAcceptOurs()
                triggerSuccessBanner()
            }
        } message: {
            Text("This will keep \"Ours\" for all \(viewModel.conflictedFiles.count) conflicted files. This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 6) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .buttonStyle(.plain)

            Text("Conflicts")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))

            Spacer()

            if !viewModel.conflictedFiles.isEmpty {
                Text("\(viewModel.conflictedFiles.count) files in conflict")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.red)

                Button(action: { showResolveAllConfirmation = true }) {
                    Text("Resolve All")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)
            Text("No conflicts")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Conflict List

    private var conflictList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.conflictedFiles, id: \.self) { file in
                    conflictRow(file: file)
                    Divider().padding(.leading, 12)
                }
            }
        }
    }

    private func conflictRow(file: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)

                Text(file)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text("\(viewModel.conflictCount(for: file))")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.red, in: Capsule())
            }

            HStack(spacing: 6) {
                actionButton(title: "Accept Ours", color: .blue) {
                    viewModel.acceptOurs(file: file)
                }
                actionButton(title: "Accept Theirs", color: .purple) {
                    viewModel.acceptTheirs(file: file)
                }
                actionButton(title: "Mark Resolved", color: .green) {
                    viewModel.markResolved(file: file)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(hoveredFile == file ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .onHover { hovering in
            hoveredFile = hovering ? file : nil
        }
    }

    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Success Banner

    private var successBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
            Text("All conflicts resolved")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.green, in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    // MARK: - Helpers

    private func triggerSuccessBanner() {
        withAnimation { showSuccessBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showSuccessBanner = false }
        }
    }
}
