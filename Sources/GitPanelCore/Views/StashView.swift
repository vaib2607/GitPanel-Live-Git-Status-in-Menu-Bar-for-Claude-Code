import SwiftUI

struct StashView: View {
    var viewModel: GitPanelViewModel
    var onBack: () -> Void

    @State private var isLoading = false
    @State private var showStashDialog = false
    @State private var stashMessage = ""
    @State private var expandedStashId: String?
    @State private var stashDiff: String?
    @State private var isLoadingDiff = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if isLoading {
                Spacer()
                ProgressView("Loading stashes...")
                Spacer()
            } else if viewModel.stashEntries.isEmpty {
                emptyState
            } else {
                stashList
            }
        }
        .task {
            await loadStashes()
        }
        .sheet(isPresented: $showStashDialog) {
            stashDialog
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)

            Text("Stash")
                .font(.headline)

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showStashDialog = true }) {
                    Label("Stash Changes", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: popTopStash) {
                    Label("Pop", systemImage: "arrow.up.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.stashEntries.isEmpty)

                Button(action: dropTopStash) {
                    Label("Drop", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.stashEntries.isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No stashes")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Stash your changes to save them for later.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - Stash List

    private var stashList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.stashEntries.enumerated()), id: \.element.id) { index, stash in
                    stashRow(stash, index: index)
                    if stash.id != viewModel.stashEntries.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }

    // MARK: - Stash Row

    private func stashRow(_ stash: StashEntry, index: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(stash.ref)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Text(stash.message)
                        .font(.body)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: expandedStashId == stash.id ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isHovered {
                        expandedStashId = stash.id
                    }
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedStashId == stash.id {
                        expandedStashId = nil
                        stashDiff = nil
                    } else {
                        expandedStashId = stash.id
                        loadDiff(for: index)
                    }
                }
            }
            .contextMenu {
                Button(action: { popStash(index: index) }) {
                    Label("Pop", systemImage: "arrow.up.doc")
                }
                Button(action: { dropStash(index: index) }) {
                    Label("Drop", systemImage: "trash")
                }
                Divider()
                Button(action: { showDiff(index: index, ref: stash.ref) }) {
                    Label("Show Diff", systemImage: "doc.text.magnifyingglass")
                }
                Divider()
                Button(action: { copyRef(ref: stash.ref) }) {
                    Label("Copy Ref", systemImage: "doc.on.doc")
                }
            }

            if expandedStashId == stash.id {
                stashDiffView
            }
        }
    }

    // MARK: - Diff Preview

    private var stashDiffView: some View {
        Group {
            if isLoadingDiff {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if let diff = stashDiff {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(diff)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            } else {
                HStack {
                    Spacer()
                    Text("No diff available")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Stash Dialog

    private var stashDialog: some View {
        VStack(spacing: 16) {
            Text("Stash Changes")
                .font(.headline)

            TextField("Message (optional)", text: $stashMessage)
                .textFieldStyle(.roundedBorder)
                .font(.body)

            HStack {
                Button("Cancel") {
                    showStashDialog = false
                    stashMessage = ""
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Stash") {
                    createStash(message: stashMessage)
                    showStashDialog = false
                    stashMessage = ""
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    // MARK: - Actions

    private func loadStashes() async {
        isLoading = true
        await viewModel.loadStashes()
        isLoading = false
    }

    private func loadDiff(for index: Int) {
        isLoadingDiff = true
        Task {
            stashDiff = await viewModel.stashDiff(index: index)
            isLoadingDiff = false
        }
    }

    private func createStash(message: String) {
        Task {
            await viewModel.stashChanges(message: message.isEmpty ? nil : message)
            await loadStashes()
        }
    }

    private func popTopStash() {
        popStash(index: 0)
    }

    private func dropTopStash() {
        dropStash(index: 0)
    }

    private func popStash(index: Int) {
        Task {
            await viewModel.popStash(index: index)
            await loadStashes()
        }
    }

    private func dropStash(index: Int) {
        Task {
            await viewModel.dropStash(index: index)
            await loadStashes()
        }
    }

    private func showDiff(index: Int, ref: String) {
        expandedStashId = ref
        loadDiff(for: index)
    }

    private func copyRef(ref: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ref, forType: .string)
    }
}

#Preview {
    StashView(
        viewModel: GitPanelViewModel(),
        onBack: {}
    )
    .frame(width: 500, height: 400)
}
