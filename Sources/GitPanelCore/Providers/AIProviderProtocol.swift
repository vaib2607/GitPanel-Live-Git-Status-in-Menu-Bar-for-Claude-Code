import Foundation

public struct TokenUsage: Sendable, Equatable {
    public var input: Int
    public var output: Int
    public var cacheRead: Int
    public var cacheCreation: Int
    
    public var total: Int { input + output + cacheRead + cacheCreation }
    
    public init(input: Int = 0, output: Int = 0, cacheRead: Int = 0, cacheCreation: Int = 0) {
        self.input = input
        self.output = output
        self.cacheRead = cacheRead
        self.cacheCreation = cacheCreation
    }
}

public protocol AIProviderProtocol: Sendable {
    var name: String { get }
    var icon: String { get } // Menu bar icon (e.g., "◆" for Claude, "⚡" for Codex)
    
    var isRunning: Bool { get }
    var sessionDuration: TimeInterval? { get }
    var tokenUsage: TokenUsage? { get }
    var workspacePath: URL? { get }
    
    func startMonitoring() async
    func stopMonitoring() async
}
