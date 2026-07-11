import Foundation
import AppKit

public final class CodexProvider: AIProviderProtocol, @unchecked Sendable {
    public let name = "OpenAI Codex"
    public let icon = "⚡"
    
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
        
        // Update session duration
        if _isRunning && !wasRunning {
            _sessionDuration = 0
        } else if _isRunning, let duration = _sessionDuration {
            _sessionDuration = duration + pollInterval
        } else if !_isRunning {
            _sessionDuration = nil
        }
        
        if _isRunning {
            await parseLogs()
        }
    }
    
    private func parseLogs() async {
        let logURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/logs.json")
        guard let data = try? Data(contentsOf: logURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let lastLog = json.last,
              let usage = lastLog["usage"] as? [String: Int] else { return }
        
        let inputTokens = usage["prompt_tokens"] ?? 0
        let outputTokens = usage["completion_tokens"] ?? 0
        
        // Only update if it's new
        if _tokenUsage == nil {
            _tokenUsage = TokenUsage()
        }
        
        _tokenUsage?.input = inputTokens
        _tokenUsage?.output = outputTokens
    }
    
    private func checkProcess() async -> Bool {
        // Scan running processes for `codex`
        guard let pgrep = ShellRunner.resolveBinary("pgrep") else { return false }
        do {
            let output = try await ShellRunner.run(pgrep, ["codex"])
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }
}
