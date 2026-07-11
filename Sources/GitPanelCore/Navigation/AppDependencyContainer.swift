import Foundation
import SwiftUI

public protocol GitServiceProtocol: Sendable {
    func branches(repo: URL) async throws -> [GitBranch]
    // Other git functions will be added by Agent 3
}

public protocol UsageServiceProtocol: Sendable {
    func compute() async throws -> UsageData
}

public protocol DiagnosticsLoggerProtocol: Sendable {
    func log(_ message: String, level: ErrorSeverity)
}

public protocol ClockProtocol: Sendable {
    var now: Date { get }
}

public struct RealClock: ClockProtocol {
    public init() {}
    public var now: Date { Date() }
}

@Observable
public final class AppDependencyContainer: Sendable {
    public let gitService: GitServiceProtocol
    public let usageService: UsageServiceProtocol
    public let logger: DiagnosticsLoggerProtocol
    public let clock: ClockProtocol
    
    public init(
        gitService: GitServiceProtocol,
        usageService: UsageServiceProtocol,
        logger: DiagnosticsLoggerProtocol,
        clock: ClockProtocol = RealClock()
    ) {
        self.gitService = gitService
        self.usageService = usageService
        self.logger = logger
        self.clock = clock
    }
}
