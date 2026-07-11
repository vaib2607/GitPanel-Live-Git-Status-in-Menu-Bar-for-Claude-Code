import SwiftUI

struct StashView: View {
    var viewModel: GitPanelViewModel
    var onBack: () -> Void

    @State private var stashes: [GitStash] = []
    @State private var isLoading = false
    @State private var showStashDialog = false
    @State private var stashMessage = ""
    @State private var selectedStash: GitStash?
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
            } else if stashes.isEmpty {
                emptyState
            } else {
                stashList
            }
        }
        .font(.system(.body, design: .monospaced))
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
                    .font(.system(.body, design: .monospaced).weight(.semibold))
            }
            .buttonStyle(.plain)

            Text("Stash")
                .font(.system(.headline, design: .monospaced))

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showStashDialog = true }) {
                    Label("Stash Changes", systemImage: "plus")
                        .font(.system(.caption, design: .monospaced))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: popTopStash) {
                    Label("Pop", systemImage: "arrow.up.doc")
                        .font(.system(.caption, design: .monospaced))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(stashes.isEmpty)

                Button(action: dropTopStash) {
                    Label("Drop", systemImage: "trash")
                        .font(.system(.caption, design: .monospaced))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(stashes.isEmpty)
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
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("Stash your changes to save them for later.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - Stash List

    private var stashList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(stashes) { stash in
                    stashRow(stash)
                    if stash.id != stashes.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }

    // MARK: - Stash Row

    private func stashRow(_ stash: GitStash) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(stash.ref)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)

                        if let timestamp = stash.timestamp {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(timestamp)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Text(stash.message)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: expandedStashId == stash.id ? "chevron.up" : "chevron.down")
                    .font(.system(.caption, design: .monospaced))
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
                        loadDiff(for: stash)
                    }
                }
            }
            .contextMenu {
                Button(action: { popStash(stash) }) {
                    Label("Pop", systemImage: "arrow.up.doc")
                }
                Button(action: { dropStash(stash) }) {
                    Label("Drop", systemImage: "trash")
                }
                Divider()
                Button(action: { showDiff(stash) }) {
                    Label("Show Diff", systemImage: "doc.text.magnifyingglass")
                }
                Divider()
                Button(action: { copyRef(stash) }) {
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
                        .font(.system(.caption, design: .monospaced))
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
                .font(.system(.headline, design: .monospaced))

            TextField("Message (optional)", text: $stashMessage)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))

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
        stashes = await viewModel.loadStashes()
        isLoading = false
    }

    private func loadDiff(for stash: GitStash) {
        isLoadingDiff = true
        Task {
            stashDiff = await viewModel.stashDiff(stash)
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
        guard let top = stashes.first else { return }
        popStash(top)
    }

    private func dropTopStash() {
        guard let top = stashes.first else { return }
        dropStash(top)
    }

    private func popStash(_ stash: GitStash) {
        Task {
            await viewModel.popStash(stash)
            await loadStashes()
        }
    }

    private func dropStash(_ stash: GitStash) {
        Task {
            await viewModel.dropStash(stash)
            await loadStashes()
        }
    }

    private func showDiff(_ stash: GitStash) {
        expandedStashId = stash.id
        loadDiff(for: stash)
    }

    private func copyRef(_ stash: GitStash) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(stash.ref, forType: .string)
    }
}

// MARK: - Model

struct GitStash: Identifiable, Hashable {
    let id: String
    let ref: String
    let message: String
    let timestamp: String?

    init(ref: String, message: String, timestamp: String? = nil) {
        self.id = ref
        self.ref = ref
        self.message = message
        self.timestamp = timestamp
    }
}

// MARK: - ViewModel Extension

extension GitPanelViewModel {
    func loadStashes() async -> [GitStash] {
        let output = await runGit("stash list")
        return output
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> GitStash? in
                guard let range = line.range(of: ": ") else {
                    return GitStash(ref: line, message: line)
                }
                let ref = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let rest = String(line[range.upperBound...])
                let parts = rest.split(separator: " ", maxSplits: 1)
                let message = parts.count > 1 ? String(parts[1]) : String(parts.first ?? "")
                return GitStash(ref: ref, message: message)
            }
    }

    func stashDiff(_ stash: GitStash) async -> String? {
        await runGit("stash show -p \(stash.ref)")
    }

    func stashChanges(message: String?) async {
        if let message {
            _ = await runGit("stash push -m \"\(message)\"")
        } else {
            _ = await runGit("stash push")
        }
    }

    func popStash(_ stash: GitStash) async {
        _ = await runGit("stash pop \(stash.ref)")
    }

    func dropStash(_ stash: GitStash) async {
        _ = await runGit("stash drop \(stash.ref)")
    }
}

#Preview {
    StashView(
        viewModel: GitPanelViewModel(),
        onBack: {}
    )
    .frame(width: 500, height: 400)
}
