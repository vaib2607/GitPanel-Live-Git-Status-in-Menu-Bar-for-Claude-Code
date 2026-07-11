import SwiftUI

public struct RepositoryID: Hashable, Sendable {
    public let path: String
    public init(path: String) {
        self.path = path
    }
}

public struct AIProviderID: Hashable, Sendable {
    public let name: String
    public init(name: String) {
        self.name = name
    }
}

public enum GitPanelRoute: Hashable, Sendable {
    case main(RepositoryID)
    case branch(RepositoryID)
    case fileList(RepositoryID)
    case stash(RepositoryID)
    case conflicts(RepositoryID)
    case diffViewer(repo: RepositoryID, path: String)
    case repositoryInfo(RepositoryID)
    
    case usageDetail(AIProviderID)
    case costDetail(AIProviderID)
    
    case environment
    case settings
    
    public var isMain: Bool {
        if case .main = self { return true }
        return false
    }
    
    case usage
}

@Observable
@MainActor
public final class AppRouter {
    public var path: [GitPanelRoute] = []
    
    public init() {}
    
    public var currentRoute: GitPanelRoute {
        path.last ?? .environment
    }
    
    public func push(_ route: GitPanelRoute) {
        path.append(route)
    }
    
    public func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    public func popToRoot() {
        path.removeAll()
    }
}
