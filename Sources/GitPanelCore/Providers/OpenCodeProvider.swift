import Foundation
import AppKit

public final class OpenCodeProvider: AIProviderProtocol, @unchecked Sendable {
    public let name = "OpenCode"
    public let icon = "💻"
    
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
        _isRunning = await checkProcess()
        
        if _isRunning && !wasRunning {
            _sessionDuration = 0
        } else if _isRunning, let duration = _sessionDuration {
            _sessionDuration = duration + pollInterval
        } else if !_isRunning {
            _sessionDuration = nil
        }
    }
    
    private func checkProcess() async -> Bool {
        guard let pgrep = ShellRunner.resolveBinary("pgrep") else { return false }
        do {
            let output = try await ShellRunner.run(pgrep, ["opencode"])
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }
}
