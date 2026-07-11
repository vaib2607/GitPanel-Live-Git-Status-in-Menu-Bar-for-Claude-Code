import Foundation
import os.log

private let logger = Logger(subsystem: "com.gitpanel", category: "UsageService")

// MARK: - Supporting Types

private struct TokenCounts {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheCreation = 0

    var total: Int { input + output + cacheRead + cacheCreation }
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

// MARK: - Time Range

enum UsageTimeRange: Sendable {
    case today
    case thisWeek
    case thisMonth
    case allTime

    private var dayCount: Int? {
        switch self {
        case .today: return 0
        case .thisWeek: return 7
        case .thisMonth: return 30
        case .allTime: return nil
        }
    }

    func contains(_ date: Date) -> Bool {
        guard let days = dayCount else { return true }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: startOfToday) else {
            return true
        }
        return date >= cutoff
    }
}

// MARK: - Cached Results

private struct CachedResults: Codable {
    let tokenCounts: [String: TokenCountsCodable]
    let timestamp: TimeInterval

    struct TokenCountsCodable: Codable {
        let input: Int
        let output: Int
        let cacheRead: Int
        let cacheCreation: Int
    }
}

// MARK: - UsageService

struct UsageService {
    private static var homeDirectory: String {
        if let envHome = ProcessInfo.processInfo.environment["HOME"], !envHome.isEmpty {
            return envHome
        }
        return NSHomeDirectory()
    }

    // MARK: - Incremental Parsing State

    private static var filePositions: [String: UInt64] = [:]
    private static var parsedByModel: [String: TokenCounts] = [:]
    private static var lastModDates: [String: Date] = [:]

    // MARK: - Cache State

    private static let cacheURL: URL = {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.gitpanel.usage-cache")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp.appendingPathComponent("usage-cache.json")
    }()

    // MARK: - Compute

    static func compute(timeRange: UsageTimeRange = .allTime) async throws -> UsageData {
        let base = (homeDirectory as NSString).appendingPathComponent(".claude/projects")
        let fileURLs = getJsonlFiles(in: base)

        // Try incremental parse from cache, otherwise full reparse
        let shouldRepaint = needsRepaint(fileURLs)
        if shouldRepaint {
            parseAllFiles(fileURLs)
            saveCache()
        } else {
            loadCache()
        }

        // Apply time range filter by re-parsing only if needed
        var byModel: [String: TokenCounts]
        if timeRange == .allTime {
            byModel = parsedByModel
        } else {
            byModel = [:]
            for fileURL in fileURLs {
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                for line in content.split(separator: "\n") {
                    parseLineWithTimeFilter(String(line), into: &byModel, timeRange: timeRange)
                }
            }
        }

        let table = loadTable()
        var totalCost = 0.0
        var total = TokenCounts()
        var topModel = ""
        var topCount = 0
        var modelBreakdown: [String: Double] = [:]

        for (model, t) in byModel {
            total.input += t.input
            total.output += t.output
            total.cacheRead += t.cacheRead
            total.cacheCreation += t.cacheCreation
            if let p = price(for: model, table: table) {
                let modelCost = p.cost(for: t)
                totalCost += modelCost
                modelBreakdown[model] = modelCost
            }
            if t.total > topCount {
                topCount = t.total
                topModel = model
            }
        }

        let cursorPlan = try await readCursorPlan()

        return UsageData(
            tokens: total.total,
            cost: totalCost,
            model: topModel,
            plan: cursorPlan ?? "",
            isUsingPlan: cursorPlan != nil,
            modelBreakdown: modelBreakdown,
            lastUpdated: Date()
        )
    }

    // MARK: - File Discovery

    private static func getJsonlFiles(in directory: String) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        var urls: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            if fileURL.pathExtension == "jsonl" {
                urls.append(fileURL)
            }
        }
        return urls
    }

    // MARK: - Incremental Parsing

    private static func needsRepaint(_ fileURLs: [URL]) -> Bool {
        if parsedByModel.isEmpty { return true }

        for url in fileURLs {
            let path = url.path
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let modDate = attrs[.modificationDate] as? Date else { continue }

            if let lastDate = lastModDates[path], lastDate == modDate {
                continue
            }
            return true
        }
        return false
    }

    private static func parseAllFiles(_ fileURLs: [URL]) {
        parsedByModel = [:]
        filePositions = [:]
        lastModDates = [:]

        for fileURL in fileURLs {
            let path = fileURL.path
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let modDate = attrs[.modificationDate] as? Date else { continue }

            for line in content.split(separator: "\n") {
                parseLine(String(line), into: &parsedByModel)
            }

            lastModDates[path] = modDate
            filePositions[path] = UInt64(content.utf8.count)
        }
    }

    // MARK: - Line Parsing

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
        t.input += extractTokenCount(usage: usage, key: "input_tokens")
        t.output += extractTokenCount(usage: usage, key: "output_tokens")
        t.cacheRead += extractTokenCount(usage: usage, key: "cache_read_input_tokens")
        t.cacheCreation += extractCacheCreationTokens(usage: usage)
        byModel[model] = t
    }

    private static func parseLineWithTimeFilter(_ line: String, into byModel: inout [String: TokenCounts], timeRange: UsageTimeRange) {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        if obj["error"] != nil { return }

        // Check timestamp for time range filtering
        if let timestamp = obj["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: timestamp), !timeRange.contains(date) {
                return
            }
        }

        guard let message = obj["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any],
              let model = (message["model"] as? String), !model.isEmpty
        else { return }
        if model == "<synthetic>" { return }

        var t = byModel[model] ?? TokenCounts()
        t.input += extractTokenCount(usage: usage, key: "input_tokens")
        t.output += extractTokenCount(usage: usage, key: "output_tokens")
        t.cacheRead += extractTokenCount(usage: usage, key: "cache_read_input_tokens")
        t.cacheCreation += extractCacheCreationTokens(usage: usage)
        byModel[model] = t
    }

    /// Safely extract a token count — only from keys that end in `_tokens` or `_count`.
    private static func extractTokenCount(usage: [String: Any], key: String) -> Int {
        guard let value = usage[key] as? Int else { return 0 }
        // Validate the key is actually a token count field, not a cost field
        if key.contains("cost") { return 0 }
        return value
    }

    /// Extract cache creation tokens. Only use keys ending in `_tokens`.
    /// Skip keys like `cache_creation_input_token_cost` which are monetary values.
    private static func extractCacheCreationTokens(usage: [String: Any]) -> Int {
        // Prefer the correct key
        if let tokens = usage["cache_creation_input_tokens"] as? Int {
            return tokens
        }
        // Only fall back to other _tokens keys; never use keys with "cost" in them
        for (key, value) in usage {
            if key.hasSuffix("_tokens") && key.contains("cache_creation"),
               let intValue = value as? Int {
                return intValue
            }
        }
        return 0
    }

    // MARK: - Price Table

    private static func loadTable() -> [String: ModelPrice] {
        var data: Data? = nil

        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: "model_prices", withExtension: "json"),
           let d = try? Data(contentsOf: url) {
            data = d
        }
        #endif

        if data == nil {
            if let url = Bundle.main.url(forResource: "model_prices", withExtension: "json"),
               let d = try? Data(contentsOf: url) {
                data = d
            }
        }

        if data == nil {
            let cwdUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("model_prices.json")
            if let d = try? Data(contentsOf: cwdUrl) {
                data = d
            }
        }

        if data == nil {
            let cwdUrl = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/model_prices.json")
            if let d = try? Data(contentsOf: cwdUrl) {
                data = d
            }
        }

        if let data = data,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var table: [String: ModelPrice] = [:]
            for (k, v) in obj {
                // Include ALL models, not just Claude
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
        "claude-opus-4-8":           ModelPrice(input: 5e-6,  output: 2.5e-5, cacheRead: 5e-7,  cacheCreation: 6.25e-6),
        "claude-opus-4-7":           ModelPrice(input: 5e-6,  output: 2.5e-5, cacheRead: 5e-7,  cacheCreation: 6.25e-6),
        "claude-opus-4-6":           ModelPrice(input: 5e-6,  output: 2.5e-5, cacheRead: 5e-7,  cacheCreation: 6.25e-6),
        "claude-sonnet-5":           ModelPrice(input: 2e-6,  output: 1e-5,  cacheRead: 2e-7,  cacheCreation: 2.5e-6),
        "claude-sonnet-4-6":         ModelPrice(input: 3e-6,  output: 1.5e-5, cacheRead: 3e-7,  cacheCreation: 3.75e-6),
        "claude-haiku-4-5-20251001": ModelPrice(input: 1e-6,  output: 5e-6,  cacheRead: 1e-7,  cacheCreation: 1.25e-6),
        "gpt-4o":                    ModelPrice(input: 2.5e-6, output: 1e-5,  cacheRead: 1.25e-6, cacheCreation: 2.5e-6),
        "gpt-4o-mini":               ModelPrice(input: 1.5e-7, output: 6e-7,  cacheRead: 7.5e-8, cacheCreation: 1.5e-7),
        "gpt-4-turbo":               ModelPrice(input: 1e-5,  output: 3e-5,  cacheRead: 5e-6,  cacheCreation: 1e-5),
        "gemini-1.5-pro":            ModelPrice(input: 1.25e-6, output: 5e-6, cacheRead: 3.125e-7, cacheCreation: 1.25e-6),
        "gemini-1.5-flash":          ModelPrice(input: 7.5e-8, output: 3e-7,  cacheRead: 1.875e-8, cacheCreation: 7.5e-8),
        "gemini-2.0-flash":          ModelPrice(input: 1e-7,  output: 4e-7,  cacheRead: 2.5e-8, cacheCreation: 1e-7),
        "deepseek-chat":             ModelPrice(input: 1.4e-7, output: 2.8e-7, cacheRead: 1.4e-8, cacheCreation: 1.4e-7),
        "deepseek-reasoner":         ModelPrice(input: 5.5e-7, output: 2.19e-6, cacheRead: 5.5e-8, cacheCreation: 5.5e-7)
    ]

    // MARK: - Cursor Plan

    private static func readCursorPlan() async throws -> String? {
        let db = (homeDirectory as NSString)
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
        guard FileManager.default.fileExists(atPath: db) else { return nil }
        guard let resolvedSqlite = ShellRunner.resolveBinary("sqlite3") else { return nil }

        let output = try await ShellRunner.run(
            resolvedSqlite,
            ["-readonly", db, "SELECT value FROM ItemTable WHERE key='cursorPlusSubscription'"]
        )
        var v = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.hasPrefix("\"") { v = String(v.dropFirst()) }
        if v.hasSuffix("\"") { v = String(v.dropLast()) }
        let known = ["free", "pro", "team", "business", "enterprise"]
        guard known.contains(v.lowercased()) else { return nil }
        return v.capitalized
    }

    // MARK: - Cache Persistence

    private static func saveCache() {
        var codableCounts: [String: CachedResults.TokenCountsCodable] = [:]
        for (model, tc) in parsedByModel {
            codableCounts[model] = CachedResults.TokenCountsCodable(
                input: tc.input,
                output: tc.output,
                cacheRead: tc.cacheRead,
                cacheCreation: tc.cacheCreation
            )
        }
        let cached = CachedResults(tokenCounts: codableCounts, timestamp: Date().timeIntervalSince1970)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private static func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode(CachedResults.self, from: data)
        else { return }

        // Cache valid for 5 minutes
        guard Date().timeIntervalSince1970 - cached.timestamp < 300 else { return }

        parsedByModel = [:]
        for (model, tc) in cached.tokenCounts {
            parsedByModel[model] = TokenCounts(
                input: tc.input,
                output: tc.output,
                cacheRead: tc.cacheRead,
                cacheCreation: tc.cacheCreation
            )
        }
    }
}
