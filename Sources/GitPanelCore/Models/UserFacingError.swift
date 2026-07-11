import Foundation

public enum ErrorSeverity: String, Equatable, Sendable {
    case warning
    case error
    case critical
}

public enum RecoveryActionType: String, Equatable, Sendable {
    case retry
    case openSettings
    case clearCache
    case reauthenticate
    case openStatusPage
    case resolveConflicts
}

public struct RecoveryAction: Equatable, Sendable {
    public let title: String
    public let type: RecoveryActionType
    
    public init(title: String, type: RecoveryActionType) {
        self.title = title
        self.type = type
    }
}

public struct UserFacingError: LocalizedError, Equatable, Sendable {
    public let title: String
    public let message: String
    public let recoveryAction: RecoveryAction?
    public let technicalDiagnosticsID: String
    public let severity: ErrorSeverity
    
    public init(title: String, message: String, recoveryAction: RecoveryAction? = nil, technicalDiagnosticsID: String, severity: ErrorSeverity = .error) {
        self.title = title
        self.message = message
        self.recoveryAction = recoveryAction
        self.technicalDiagnosticsID = technicalDiagnosticsID
        self.severity = severity
    }
    
    public var errorDescription: String? { title }
    public var failureReason: String? { message }
}
