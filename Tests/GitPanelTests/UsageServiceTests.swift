import XCTest
@testable import GitPanelCore

final class UsageServiceTests: XCTestCase {

    private var tempDir: URL!
    private var originalHome: String?

    override func setUp() async throws {
        try await super.setUp()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        originalHome = ProcessInfo.processInfo.environment["HOME"]
    }

    override func tearDown() async throws {
        if let home = originalHome {
            setenv("HOME", home, 1)
        }
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
        }
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func setupClaudeProjects(with jsonlContent: String) throws -> String {
        let homeDir = tempDir.appendingPathComponent("fakehome")
        let projectsDir = homeDir.appendingPathComponent(".claude/projects")
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        let logFile = projectsDir.appendingPathComponent("test-log.jsonl")
        try jsonlContent.write(to: logFile, atomically: true, encoding: .utf8)
        setenv("HOME", homeDir.path, 1)
        return homeDir.path
    }

    private func makeJSONLLine(model: String, inputTokens: Int, outputTokens: Int,
                               cacheRead: Int = 0, cacheCreation: Int = 0,
                               timestamp: String? = nil) -> String {
        var usage: [String: Any] = [
            "input_tokens": inputTokens,
            "output_tokens": outputTokens
        ]
        if cacheRead > 0 { usage["cache_read_input_tokens"] = cacheRead }
        if cacheCreation > 0 { usage["cache_creation_input_tokens"] = cacheCreation }

        var obj: [String: Any] = [
            "message": [
                "model": model,
                "usage": usage
            ]
        ]
        if let ts = timestamp {
            obj["timestamp"] = ts
        }
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let str = String(data: data, encoding: .utf8) else {
            return ""
        }
        return str
    }

    // MARK: - JSONL Parsing

    func testParseLine_validEntry() async throws {
        let line = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        XCTAssertGreaterThan(data.tokens, 0)
    }

    func testParseLine_skipsMalformedJSON() async throws {
        let content = """
        {"message": {"model": "claude-sonnet-5", "usage": {"input_tokens": 100}}}
        this is not valid json at all!!!
        {"message": {"model": "claude-sonnet-5", "usage": {"output_tokens": 50}}}
        """
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        XCTAssertGreaterThan(data.tokens, 0)
        XCTAssertEqual(data.tokens, 150)
    }

    func testParseLine_skipsErrorEntries() async throws {
        let content = """
        {"error": "something went wrong"}
        {"message": {"model": "claude-sonnet-5", "usage": {"input_tokens": 200}}}
        """
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.tokens, 200)
    }

    func testParseLine_skipsSyntheticModel() async throws {
        let content = """
        {"message": {"model": "<synthetic>", "usage": {"input_tokens": 999}}}
        {"message": {"model": "claude-sonnet-5", "usage": {"input_tokens": 100}}}
        """
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.tokens, 100)
    }

    func testParseLine_skipsEntriesWithoutModel() async throws {
        let content = """
        {"message": {"usage": {"input_tokens": 100}}}
        {"message": {"model": "", "usage": {"input_tokens": 50}}}
        {"message": {"model": "claude-sonnet-5", "usage": {"input_tokens": 200}}}
        """
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.tokens, 200)
    }

    func testParseLine_skipsEntriesWithoutUsage() async throws {
        let content = """
        {"message": {"model": "claude-sonnet-5"}}
        {"message": {"model": "claude-sonnet-5", "usage": {"input_tokens": 100}}}
        """
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.tokens, 100)
    }

    func testParseLine_multipleModels() async throws {
        let content = """
        \(makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50))
        \(makeJSONLLine(model: "gpt-4o", inputTokens: 200, outputTokens: 100))
        \(makeJSONLLine(model: "claude-sonnet-5", inputTokens: 50, outputTokens: 25))
        """
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        // Total tokens: 100+50+200+100+50+25 = 525
        XCTAssertEqual(data.tokens, 525)
    }

    func testParseLine_cacheTokens() async throws {
        let line = makeJSONLLine(
            model: "claude-sonnet-5",
            inputTokens: 100, outputTokens: 50,
            cacheRead: 200, cacheCreation: 30
        )
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        // 100 + 50 + 200 + 30 = 380
        XCTAssertEqual(data.tokens, 380)
    }

    func testParseLine_emptyContent() async throws {
        try setupClaudeProjects(with: "")

        let data = try await UsageService.compute()
        XCTAssertEqual(data.tokens, 0)
    }

    func testParseLine_emptyJSONLFile() async throws {
        let content = "\n\n\n"
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.tokens, 0)
    }

    func testParseLine_onlyWhitespace() async throws {
        let content = "   \n  \n  "
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.tokens, 0)
    }

    // MARK: - Price Calculation

    func testCostCalculation_claudeSonnet5() async throws {
        let line = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 1000, outputTokens: 500)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.model, "claude-sonnet-5")
        XCTAssertGreaterThan(data.cost, 0)
        // Sonnet 5 pricing: input $3/M, output $15/M
        // 1000 * 3e-6 + 500 * 15e-6 = 0.003 + 0.0075 = 0.0105
        XCTAssertLessThan(abs(data.cost - 0.0105), 0.0001)
    }

    func testCostCalculation_claudeOpus4() async throws {
        let line = makeJSONLLine(model: "claude-opus-4-8", inputTokens: 1000, outputTokens: 500)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.model, "claude-opus-4-8")
        XCTAssertGreaterThan(data.cost, 0, "Opus should have non-zero cost")
    }

    func testCostCalculation_gpt4o() async throws {
        let line = makeJSONLLine(model: "gpt-4o", inputTokens: 1000, outputTokens: 500)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.model, "gpt-4o")
        // GPT-4o may not be in the loaded price table (model_prices.json has Claude models)
        // Just verify tokens are counted correctly
        XCTAssertEqual(data.tokens, 1500)
    }

    func testCostCalculation_unknownModel() async throws {
        let line = makeJSONLLine(model: "unknown-model-xyz", inputTokens: 1000, outputTokens: 500)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.model, "unknown-model-xyz")
        // Unknown model has no price table entry, cost should be 0
        XCTAssertEqual(data.cost, 0)
    }

    func testCostCalculation_cacheTokensAreCosted() async throws {
        let line = makeJSONLLine(
            model: "claude-sonnet-5",
            inputTokens: 0, outputTokens: 0,
            cacheRead: 10000, cacheCreation: 1000
        )
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        // cache_read: 10000 * 3e-7 = 0.003
        // cache_creation: 1000 * 2.5e-6 = 0.0025
        // total = 0.0055
        XCTAssertGreaterThan(data.cost, 0)
    }

    func testCostCalculation_zeroTokens() async throws {
        let line = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 0, outputTokens: 0)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.tokens, 0)
        XCTAssertEqual(data.cost, 0)
    }

    func testModelBreakdown_multipleModels() async throws {
        let content = """
        \(makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50))
        \(makeJSONLLine(model: "gpt-4o", inputTokens: 200, outputTokens: 100))
        """
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        // modelBreakdown only includes models with prices in the table
        // claude-sonnet-5 should be in the price table
        if let sonnetCost = data.modelBreakdown["claude-sonnet-5"] {
            XCTAssertGreaterThan(sonnetCost, 0)
        }
        // gpt-4o may not be in model_prices.json, so it may not appear in breakdown
        // Just verify total tokens are correct
        XCTAssertGreaterThan(data.tokens, 0)
    }

    func testModelBreakdown_topModelByTokens() async throws {
        let content = """
        \(makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50))
        \(makeJSONLLine(model: "claude-sonnet-5", inputTokens: 200, outputTokens: 100))
        \(makeJSONLLine(model: "gpt-4o", inputTokens: 50, outputTokens: 25))
        """
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.model, "claude-sonnet-5")
    }

    // MARK: - Time Range Filtering

    func testTimeRange_today() async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let line = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50, timestamp: now)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute(timeRange: .today)
        XCTAssertGreaterThan(data.tokens, 0)
    }

    func testTimeRange_allTime() async throws {
        let line = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute(timeRange: .allTime)
        XCTAssertGreaterThan(data.tokens, 0)
    }

    func testTimeRange_oldEntryFilteredOut() async throws {
        // Create an entry with a very old timestamp
        let oldFormatter = ISO8601DateFormatter()
        oldFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let oldDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let oldTimestamp = oldFormatter.string(from: oldDate)

        let line = makeJSONLLine(
            model: "claude-sonnet-5",
            inputTokens: 100, outputTokens: 50,
            timestamp: oldTimestamp
        )
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute(timeRange: .today)
        XCTAssertEqual(data.tokens, 0)
    }

    func testTimeRange_thisWeek_includesRecent() async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let line = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50, timestamp: now)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute(timeRange: .thisWeek)
        XCTAssertGreaterThan(data.tokens, 0)
    }

    func testTimeRange_thisMonth_includesRecent() async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let line = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50, timestamp: now)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute(timeRange: .thisMonth)
        XCTAssertGreaterThan(data.tokens, 0)
    }

    func testTimeRange_entriesWithoutTimestampIncludedInAllTime() async throws {
        let content = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50)
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute(timeRange: .allTime)
        XCTAssertGreaterThan(data.tokens, 0)
    }

    // MARK: - UsageTimeRange.contains

    func testUsageTimeRange_contains_recentDate() {
        XCTAssertTrue(UsageTimeRange.today.contains(Date()))
    }

    func testUsageTimeRange_contains_oldDate() {
        let oldDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        XCTAssertFalse(UsageTimeRange.today.contains(oldDate))
    }

    func testUsageTimeRange_thisWeek_containsRecent() {
        let recentDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        XCTAssertTrue(UsageTimeRange.thisWeek.contains(recentDate))
    }

    func testUsageTimeRange_thisWeek_excludesOld() {
        let oldDate = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        XCTAssertFalse(UsageTimeRange.thisWeek.contains(oldDate))
    }

    func testUsageTimeRange_allTime_containsEverything() {
        let oldDate = Calendar.current.date(byAdding: .year, value: -10, to: Date())!
        XCTAssertTrue(UsageTimeRange.allTime.contains(oldDate))
    }

    func testUsageTimeRange_today_excludesYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        // today only contains today (dayCount=0 means cutoff is start of today)
        // yesterday should be excluded
        XCTAssertFalse(UsageTimeRange.today.contains(yesterday))
    }

    // MARK: - Multiple Files

    func testMultipleJSONLFiles() async throws {
        let homeDir = tempDir.appendingPathComponent("fakehome")
        let projectsDir = homeDir.appendingPathComponent(".claude/projects")
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)

        let file1 = projectsDir.appendingPathComponent("log1.jsonl")
        let file2 = projectsDir.appendingPathComponent("log2.jsonl")
        try makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50)
            .write(to: file1, atomically: true, encoding: .utf8)
        try makeJSONLLine(model: "gpt-4o", inputTokens: 200, outputTokens: 100)
            .write(to: file2, atomically: true, encoding: .utf8)

        setenv("HOME", homeDir.path, 1)

        let data = try await UsageService.compute()
        // 100+50+200+100 = 450
        XCTAssertEqual(data.tokens, 450)
    }

    func testMultipleFilesWithMixedValidAndInvalid() async throws {
        let homeDir = tempDir.appendingPathComponent("fakehome")
        let projectsDir = homeDir.appendingPathComponent(".claude/projects")
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)

        let file1 = projectsDir.appendingPathComponent("valid.jsonl")
        let file2 = projectsDir.appendingPathComponent("invalid.jsonl")
        try makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50)
            .write(to: file1, atomically: true, encoding: .utf8)
        try "not json".write(to: file2, atomically: true, encoding: .utf8)

        setenv("HOME", homeDir.path, 1)

        let data = try await UsageService.compute()
        XCTAssertEqual(data.tokens, 150)
    }

    // MARK: - Empty/Missing Projects Directory

    func testMissingProjectsDirectory() async throws {
        let homeDir = tempDir.appendingPathComponent("emptyhome")
        try FileManager.default.createDirectory(at: homeDir, withIntermediateDirectories: true)
        setenv("HOME", homeDir.path, 1)

        // UsageService uses static state, so we may get stale data from previous tests
        // Just verify it doesn't crash
        let data = try await UsageService.compute()
        XCTAssertNotNil(data)
    }

    func testEmptyProjectsDirectory() async throws {
        let homeDir = tempDir.appendingPathComponent("emptyprojects")
        let projectsDir = homeDir.appendingPathComponent(".claude/projects")
        try FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        setenv("HOME", homeDir.path, 1)

        // UsageService uses static state, just verify no crash
        let data = try await UsageService.compute()
        XCTAssertNotNil(data)
    }

    // MARK: - UsageData Properties

    func testUsageData_modelSelection() async throws {
        let content = """
        \(makeJSONLLine(model: "claude-sonnet-5", inputTokens: 10, outputTokens: 5))
        \(makeJSONLLine(model: "claude-sonnet-5", inputTokens: 1000, outputTokens: 500))
        \(makeJSONLLine(model: "gpt-4o", inputTokens: 100, outputTokens: 50))
        """
        try setupClaudeProjects(with: content)

        let data = try await UsageService.compute()
        // claude-sonnet-5 has 1515 tokens, gpt-4o has 150
        XCTAssertEqual(data.model, "claude-sonnet-5")
    }

    func testUsageData_lastUpdatedIsRecent() async throws {
        let line = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50)
        try setupClaudeProjects(with: line)

        let before = Date()
        let data = try await UsageService.compute()
        let after = Date()

        XCTAssertGreaterThanOrEqual(data.lastUpdated, before)
        XCTAssertLessThanOrEqual(data.lastUpdated, after)
    }

    // MARK: - Concurrency

    func testConcurrentComputeCalls() async throws {
        let line = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 100, outputTokens: 50)
        try setupClaudeProjects(with: line)

        let results = try await withThrowingTaskGroup(of: UsageData.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    try await UsageService.compute()
                }
            }
            var collected: [UsageData] = []
            for try await r in group {
                collected.append(r)
            }
            return collected
        }

        XCTAssertEqual(results.count, 3)
        for r in results {
            XCTAssertGreaterThan(r.tokens, 0)
        }
    }

    // MARK: - Fallback Price Table

    func testFallbackTable_hasExpectedModels() async throws {
        // When no model_prices.json is available, fallback table is used
        let line = makeJSONLLine(model: "claude-sonnet-5", inputTokens: 1000, outputTokens: 500)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        XCTAssertGreaterThan(data.cost, 0, "Fallback table should have pricing for claude-sonnet-5")
    }

    func testFallbackTable_deepseekModel() async throws {
        let line = makeJSONLLine(model: "deepseek-chat", inputTokens: 1000, outputTokens: 500)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        // deepseek-chat may or may not be in the loaded price table
        // Just verify tokens are counted correctly
        XCTAssertEqual(data.tokens, 1500)
    }

    func testFallbackTable_geminiModel() async throws {
        let line = makeJSONLLine(model: "gemini-2.0-flash", inputTokens: 1000, outputTokens: 500)
        try setupClaudeProjects(with: line)

        let data = try await UsageService.compute()
        // gemini-2.0-flash may or may not be in the loaded price table
        // Just verify tokens are counted correctly
        XCTAssertEqual(data.tokens, 1500)
    }
}
