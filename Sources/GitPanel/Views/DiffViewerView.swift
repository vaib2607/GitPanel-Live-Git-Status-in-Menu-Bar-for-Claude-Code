import SwiftUI

// MARK: - Models

struct DiffHunk: Identifiable {
    let id = UUID()
    let header: String
    let lines: [DiffLine]
}

struct DiffLine: Identifiable {
    let id = UUID()
    let type: DiffLineType
    let content: String
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

enum DiffLineType {
    case added, removed, context, hunkHeader
}

// MARK: - Diff Parser

struct DiffParser {
    static func parse(_ rawDiff: String) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var currentHeader = ""
        var currentLines: [DiffLine] = []
        var oldLine = 0
        var newLine = 0

        let lines = rawDiff.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("@@") {
                if !currentHeader.isEmpty || !currentLines.isEmpty {
                    hunks.append(DiffHunk(header: currentHeader, lines: currentLines))
                }
                currentHeader = line
                currentLines = []

                if let range = line.range(of: #"@@ -(\d+),?\d* \+(\d+),?\d* @@"#, options: .regularExpression) {
                    let matched = String(line[range])
                    if let oldMatch = matched.range(of: #"-(\d+)"#, options: .regularExpression) {
                        let num = String(matched[oldMatch]).replacingOccurrences(of: "-", with: "")
                        oldLine = Int(num) ?? 0
                    }
                    if let newMatch = matched.range(of: #"\+(\d+)"#, options: .regularExpression) {
                        let num = String(matched[newMatch]).replacingOccurrences(of: "+", with: "")
                        newLine = Int(num) ?? 0
                    }
                }

                currentLines.append(DiffLine(type: .hunkHeader, content: line, oldLineNumber: nil, newLineNumber: nil))
            } else if line.hasPrefix("+") {
                currentLines.append(DiffLine(type: .added, content: String(line.dropFirst()), oldLineNumber: nil, newLineNumber: newLine))
                newLine += 1
            } else if line.hasPrefix("-") {
                currentLines.append(DiffLine(type: .removed, content: String(line.dropFirst()), oldLineNumber: oldLine, newLineNumber: nil))
                oldLine += 1
            } else {
                currentLines.append(DiffLine(type: .context, content: String(line.dropFirst()), oldLineNumber: oldLine, newLineNumber: newLine))
                oldLine += 1
                newLine += 1
            }
        }

        if !currentHeader.isEmpty || !currentLines.isEmpty {
            hunks.append(DiffHunk(header: currentHeader, lines: currentLines))
        }

        return hunks
    }
}

// MARK: - View

struct DiffViewerView: View {
    var viewModel: GitPanelViewModel
    var filePath: String
    var onBack: () -> Void

    @State private var rawDiff: String = ""
    @State private var hunks: [DiffHunk] = []

    private var addedCount: Int {
        hunks.flatMap { $0.lines }.filter { $0.type == .added }.count
    }

    private var removedCount: Int {
        hunks.flatMap { $0.lines }.filter { $0.type == .removed }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            if rawDiff.isEmpty {
                VStack {
                    Spacer()
                    Text("Loading diff...")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if hunks.isEmpty {
                VStack {
                    Spacer()
                    Text("No changes")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                diffContent
            }
        }
        .onAppear {
            viewModel.fetchDiff(for: filePath)
        }
        .onChange(of: viewModel.currentDiff) { _, newDiff in
            rawDiff = newDiff
            hunks = DiffParser.parse(newDiff)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text((filePath as NSString).lastPathComponent)
                    .font(.system(size: 12, weight: .semibold).monospaced())
                    .lineLimit(1)

                if !filePath.isEmpty {
                    Text((filePath as NSString).deletingLastPathComponent)
                        .font(.system(size: 10).monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !hunks.isEmpty {
                HStack(spacing: 6) {
                    if addedCount > 0 {
                        Text("+\(addedCount)")
                            .font(.system(size: 11, weight: .medium).monospaced())
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if removedCount > 0 {
                        Text("-\(removedCount)")
                            .font(.system(size: 11, weight: .medium).monospaced())
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Diff Content

    private var diffContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(hunks) { hunk in
                    ForEach(hunk.lines) { line in
                        diffLineRow(line)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Line Row

    private func diffLineRow(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            lineNumberText(line.oldLineNumber)
                .frame(width: 40, alignment: .trailing)

            lineNumberText(line.newLineNumber)
                .frame(width: 40, alignment: .trailing)

            Text(linePrefix(line.type))
                .font(.system(size: 11).monospaced())
                .foregroundStyle(prefixColor(line.type))
                .frame(width: 14, alignment: .center)

            Text(line.content)
                .font(.system(size: 11).monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(lineBackground(line.type))
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func lineNumberText(_ number: Int?) -> some View {
        Text(number.map(String.init) ?? "")
            .font(.system(size: 10).monospaced())
            .foregroundStyle(.tertiary)
    }

    private func linePrefix(_ type: DiffLineType) -> String {
        switch type {
        case .added: "+"
        case .removed: "-"
        case .context: " "
        case .hunkHeader: ""
        }
    }

    private func prefixColor(_ type: DiffLineType) -> Color {
        switch type {
        case .added: .green
        case .removed: .red
        case .context: .secondary
        case .hunkHeader: .blue
        }
    }

    private func lineBackground(_ type: DiffLineType) -> Color {
        switch type {
        case .added: Color.green.opacity(0.12)
        case .removed: Color.red.opacity(0.10)
        case .context: .clear
        case .hunkHeader: Color.blue.opacity(0.08)
        }
    }
}

// MARK: - Preview

#Preview {
    DiffViewerView(
        viewModel: GitPanelViewModel(),
        filePath: "Sources/App/ContentView.swift",
        onBack: {}
    )
    .frame(width: 600, height: 400)
}
