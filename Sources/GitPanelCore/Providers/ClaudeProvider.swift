import Foundation
import AppKit

public final class ClaudeProvider: AIProviderProtocol, @unchecked Sendable {
    public let name = "Claude Code"
    public let icon = "◆"
    
    private var _isRunning: Bool = false
    private var _sessionDuration: TimeInterval? = nil
    private var _tokenUsage: TokenUsage? = nil
    private var _workspacePath: URL? = nil
    
    private var checkTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 5.0
    
    public init() {}
    
    public var isRunning: Bool { _isRunning }
    public var sessionDuration: TimeInterval? { _sessionDuration }
    public var tokenUsage: TokenUsage? { _tokenUsage }
    public var workspacePath: URL? { _workspacePath }
    
    public func startMonitoring() async {
        guard checkTask == nil else { return }
        checkTask = Task {
            while !Task.isCancelled {
                await checkStatus()
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            }
        }
    }
    
    public func stopMonitoring() async {
        checkTask?.cancel()
        checkTask = nil
        _isRunning = false
    }
    
    private func checkStatus() async {
        let wasRunning = _isRunning
        
        // Check if process is running
        _isRunning = await checkProcess()
        
        // Update session duration roughly (v1.1 simple approach)
        if _isRunning && !wasRunning {
            _sessionDuration = 0
        } else if _isRunning, let duration = _sessionDuration {
            _sessionDuration = duration + pollInterval
        } else if !_isRunning {
            _sessionDuration = nil
        }
        
        // Fetch token usage if running (or fetch latest snapshot)
        if let usageData = try? await UsageService.compute(timeRange: .today) {
            _tokenUsage = TokenUsage(
                input: usageData.tokens, // UsageService currently sums them, we can just put it all in input for now as a proxy, or refactor UsageService to return TokenUsage later
                output: 0,
                cacheRead: 0,
                cacheCreation: 0
            )
            // Fix: Actually UsageService returns `UsageData(tokens: ..., cost: ...)` which aggregates everything.
            // For now we map total tokens to input tokens just to show something, since UsageService obscures the breakdown.
            _tokenUsage?.input = usageData.tokens
        }
    }
    
    private func checkProcess() async -> Bool {
        // Use `pgrep claude` to see if it's running
        guard let pgrep = ShellRunner.resolveBinary("pgrep") else { return false }
        do {
            let output = try await ShellRunner.run(pgrep, ["claude"])
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }
}
