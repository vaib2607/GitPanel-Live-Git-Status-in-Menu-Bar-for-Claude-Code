import Foundation

struct UsageData {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheCreationTokens: Int
    let estimatedCost: Double
    let cursorPlan: String?
    let source: Source

    enum Source { case claude, cursor, manual, none }

    var hasData: Bool { source != .none }
}

private struct TokenCounts {
    var input = 0, output = 0, cacheRead = 0, cacheCreation = 0
}

private struct ModelPrice {
    let input: Double
    let output: Double
    let cacheRead: Double
    let cacheCreation: Double

    func cost(for t: TokenCounts) -> Double {
        Double(t.input) * input
      + Double(t.output) * output
      + Double(t.cacheRead) * cacheRead
      + Double(t.cacheCreation) * cacheCreation
    }
}

/// Reads real Claude Code usage offline from ~/.claude/projects/**/*.jsonl
/// and prices it with the LiteLLM model_prices_and_context_window.json
/// (bundled; embedded fallback if the resource is missing).
struct UsageService {
    static func compute(manual: String) -> UsageData {
        var byModel: [String: TokenCounts] = [:]
        let base = (NSHomeDirectory() as NSString).appendingPathComponent(".claude/projects")

        if let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: base),
            includingPropertiesForKeys: nil
        ) {
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "jsonl" else { continue }
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                for line in content.split(separator: "\n") {
                    parseLine(String(line), into: &byModel)
                }
            }
        }

        let table = loadTable()
        var cost = 0.0
        var total = TokenCounts()
        for (model, t) in byModel {
            total.input += t.input
            total.output += t.output
            total.cacheRead += t.cacheRead
            total.cacheCreation += t.cacheCreation
            if let p = price(for: model, table: table) {
                cost += p.cost(for: t)
            }
        }

        let cursorPlan = readCursorPlan()
        let source: UsageData.Source
        if total.input + total.output > 0 {
            source = .claude
        } else if !manual.isEmpty {
            source = .manual
        } else if cursorPlan != nil {
            source = .cursor
        } else {
            source = .none
        }

        return UsageData(
            inputTokens: total.input,
            outputTokens: total.output,
            cacheReadTokens: total.cacheRead,
            cacheCreationTokens: total.cacheCreation,
            estimatedCost: cost,
            cursorPlan: cursorPlan,
            source: source
        )
    }

    private static func parseLine(_ line: String, into byModel: inout [String: TokenCounts]) {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        if obj["error"] != nil { return }
        guard let message = obj["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any],
              let model = (message["model"] as? String), !model.isEmpty
        else { return }
        if model == "<synthetic>" { return }

        var t = byModel[model] ?? TokenCounts()
        t.input += usage["input_tokens"] as? Int ?? 0
        t.output += usage["output_tokens"] as? Int ?? 0
        t.cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
        t.cacheCreation += usage["cache_creation_input_tokens"] as? Int ?? 0
        byModel[model] = t
    }

    private static func loadTable() -> [String: ModelPrice] {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("model_prices.json"),
           let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var table: [String: ModelPrice] = [:]
            for (k, v) in obj {
                guard let d = v as? [String: Any] else { continue }
                table[k] = ModelPrice(
                    input: d["input_cost_per_token"] as? Double ?? 0,
                    output: d["output_cost_per_token"] as? Double ?? 0,
                    cacheRead: d["cache_read_input_token_cost"] as? Double ?? 0,
                    cacheCreation: d["cache_creation_input_token_cost"] as? Double ?? 0
                )
            }
            if !table.isEmpty { return table }
        }
        return fallbackTable
    }

    private static func price(for model: String, table: [String: ModelPrice]) -> ModelPrice? {
        if let p = table[model] { return p }
        let matches = table.keys.filter { !$0.contains(".") && model.hasPrefix($0) }
        if let best = matches.max(by: { $0.count < $1.count }), let p = table[best] {
            return p
        }
        return nil
    }

    private static let fallbackTable: [String: ModelPrice] = [
        "claude-opus-4-8":       ModelPrice(input: 5e-6,  output: 2.5e-5, cacheRead: 5e-7,  cacheCreation: 6.25e-6),
        "claude-opus-4-7":       ModelPrice(input: 5e-6,  output: 2.5e-5, cacheRead: 5e-7,  cacheCreation: 6.25e-6),
        "claude-opus-4-6":       ModelPrice(input: 5e-6,  output: 2.5e-5, cacheRead: 5e-7,  cacheCreation: 6.25e-6),
        "claude-sonnet-5":       ModelPrice(input: 2e-6,  output: 1e-5,  cacheRead: 2e-7,  cacheCreation: 2.5e-6),
        "claude-sonnet-4-6":     ModelPrice(input: 3e-6,  output: 1.5e-5,cacheRead: 3e-7,  cacheCreation: 3.75e-6),
        "claude-haiku-4-5-20251001": ModelPrice(input: 1e-6, output: 5e-6, cacheRead: 1e-7, cacheCreation: 1.25e-6)
    ]

    private static func readCursorPlan() -> String? {
        let db = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
        guard FileManager.default.fileExists(atPath: db) else { return nil }
        let r = ShellRunner.run(
            executable: "/usr/bin/sqlite3",
            arguments: [db, "SELECT value FROM ItemTable WHERE key='cursorAuth/stripeMembershipType';"]
        )
        var v = r.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.hasPrefix("\"") { v = String(v.dropFirst()) }
        if v.hasSuffix("\"") { v = String(v.dropLast()) }
        let known = ["free", "pro", "team", "business", "enterprise"]
        guard known.contains(v.lowercased()) else { return nil }
        return v.capitalized
    }
}
