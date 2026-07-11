import Foundation

public enum DataSource: String, Equatable, Sendable {
    case localGit
    case localLogs
    case providerAPI
    case githubAPI
    case cache
    case calculated
    case unknown
}

public struct DataMetadata: Equatable, Sendable {
    public let source: DataSource
    public let lastUpdated: Date?
    public let isStale: Bool
    
    public init(source: DataSource, lastUpdated: Date? = nil, isStale: Bool = false) {
        self.source = source
        self.lastUpdated = lastUpdated
        self.isStale = isStale
    }
}

public enum DataState<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case loaded(Value, DataMetadata?)
    case empty(reason: String)
    case unavailable(reason: String)
    case failed(UserFacingError)
    
    public var value: Value? {
        if case .loaded(let v, _) = self { return v }
        return nil
    }
    
    public var error: UserFacingError? {
        if case .failed(let e) = self { return e }
        return nil
    }
    
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
