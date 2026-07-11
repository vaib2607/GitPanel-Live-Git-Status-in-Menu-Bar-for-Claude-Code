import SwiftUI

public enum GitPanelRoute: Hashable {
    case main
    case branch
    case environment
    case usage
    case usageDetail
    case costDetail
    case repositoryInfo
    case fileList
    case diffViewer(String)
    case stash
    case conflicts
    case multiAgent
    case spending
    case build
    case mcp
    case timeline
}

@MainActor
@Observable public final class AppRouter {
    public var path: [GitPanelRoute] = []
    
    public init() {}
    
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
    
    public var currentRoute: GitPanelRoute {
        path.last ?? .main
    }
}
