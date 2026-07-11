import Foundation
import SwiftUI

@MainActor
@Observable
public final class GitState {
    public var repoName: String = ""
    public var branchName: String = ""
    public var commitCount: Int = 0
    public var linesAdded: Int = 0
    public var linesDeleted: Int = 0
    public var hasChanges: Bool = false
    public var isAheadOfRemote: Bool = false
    public var isBehindRemote: Bool = false
    public var lastCommitHash: String = ""
    public var lastCommitMessage: String = ""
    public var lastCommitDate: Date = .distantPast
    public var remoteName: String = ""
    public var isRebaseInProgress: Bool = false
    public var isMergeInProgress: Bool = false
    public var isCherryPickInProgress: Bool = false
    public var isRevertInProgress: Bool = false
    public var repoState: RepoState = .clean
    public var remotes: [Remote] = []
    public var submodules: [Submodule] = []
    public var branches: [GitBranch] = []
    public var prStatus: PRStatus = .noPRs
    public var usageData: UsageData?
    public var environmentMode: EnvironmentMode = .production
    public var bannerMessage: BannerMessage?
    public var isGitRepo: Bool = false
    public var lastUpdated: Date = .distantPast

    public var syncStatus: String {
        var parts: [String] = []
        if isAheadOfRemote { parts.append("ahead") }
        if isBehindRemote { parts.append("behind") }
        return parts.isEmpty ? "Synced" : parts.joined(separator: " · ")
    }

    public var stagedCount: Int = 0
    public var unstagedCount: Int = 0
    public var untrackedCount: Int = 0
    public var conflictCount: Int = 0

    public func apply(_ snapshot: GitStateSnapshot) {
        self.isGitRepo = snapshot.isGitRepo
        self.repoName = snapshot.repoName
        self.branchName = snapshot.branchName
        self.isAheadOfRemote = snapshot.isAheadOfRemote
        self.isBehindRemote = snapshot.isBehindRemote
        self.hasChanges = snapshot.hasChanges
        self.stagedCount = snapshot.stagedCount
        self.unstagedCount = snapshot.unstagedCount
        self.untrackedCount = snapshot.untrackedCount
        self.conflictCount = snapshot.conflictCount
        self.linesAdded = snapshot.linesAdded
        self.linesDeleted = snapshot.linesDeleted
        self.lastCommitHash = snapshot.lastCommitHash
        self.lastCommitMessage = snapshot.lastCommitMessage
        self.lastCommitDate = snapshot.lastCommitDate
        self.remotes = snapshot.remotes
        self.remoteName = snapshot.remoteName
        self.submodules = snapshot.submodules
        self.branches = snapshot.branches
        self.repoState = snapshot.repoState
        self.lastUpdated = Date()
    }

    public init() {}
}

public struct Remote: Identifiable, Sendable, Hashable {
    public let name: String
    public let url: String
    public var isDefault: Bool = false
    public var id: String { name + url }

    public init(name: String, url: String, isDefault: Bool = false) {
        self.name = name
        self.url = url
        self.isDefault = isDefault
    }
}

public struct Submodule: Identifiable, Sendable, Hashable {
    public let name: String
    public let path: String
    public let url: String
    public var branch: String?
    public var id: String { path }

    public init(name: String, path: String, url: String, branch: String? = nil) {
        self.name = name
        self.path = path
        self.url = url
        self.branch = branch
    }
}

public struct GitBranch: Identifiable, Sendable, Hashable {
    public let name: String
    public let isCurrent: Bool
    public var isRemote: Bool = false
    public var remoteName: String?
    public var upstreamName: String?
    public var ahead: Int = 0
    public var behind: Int = 0
    public var id: String { name }

    public init(name: String, isCurrent: Bool, isRemote: Bool = false, remoteName: String? = nil, upstreamName: String? = nil, ahead: Int = 0, behind: Int = 0) {
        self.name = name
        self.isCurrent = isCurrent
        self.isRemote = isRemote
        self.remoteName = remoteName
        self.upstreamName = upstreamName
        self.ahead = ahead
        self.behind = behind
    }
}

public enum PRStatus: Sendable, Hashable {
    case noPRs
    case notInstalled
    case pullRequests([PRInfo])
}

public struct PRInfo: Identifiable, Sendable, Hashable {
    public let number: Int
    public let title: String
    public let url: String
    public let state: String
    public let author: String
    public let branch: String
    public let reviewDecision: String?
    public let mergeable: Bool?
    public var id: Int { number }

    public init(number: Int, title: String, url: String, state: String, author: String, branch: String, reviewDecision: String?, mergeable: Bool?) {
        self.number = number
        self.title = title
        self.url = url
        self.state = state
        self.author = author
        self.branch = branch
        self.reviewDecision = reviewDecision
        self.mergeable = mergeable
    }
}

public struct UsageData: Sendable, Hashable {
    public let tokens: Int
    public let cost: Double
    public let model: String
    public let plan: String
    public let isUsingPlan: Bool
    public let modelBreakdown: [String: Double]
    public let lastUpdated: Date

    public init(
        tokens: Int,
        cost: Double,
        model: String,
        plan: String,
        isUsingPlan: Bool,
        modelBreakdown: [String: Double] = [:],
        lastUpdated: Date = Date()
    ) {
        self.tokens = tokens
        self.cost = cost
        self.model = model
        self.plan = plan
        self.isUsingPlan = isUsingPlan
        self.modelBreakdown = modelBreakdown
        self.lastUpdated = lastUpdated
    }
}

public struct GitCommit: Identifiable, Equatable, Sendable, Hashable {
    public let id: String
    public let message: String
    public let author: String
    public let date: Date
    
    public init(id: String, message: String, author: String, date: Date) {
        self.id = id
        self.message = message
        self.author = author
        self.date = date
    }
}

public enum EnvironmentMode: String, CaseIterable, Sendable, Identifiable {
    case local = "Work locally"
    case codex = "Connect Codex web"
    case cloud = "Send to cloud"
    case production
    case development

    public var id: String { rawValue }
}

public struct BannerMessage: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let detail: String?
    public let kind: Kind

    public enum Kind: Sendable {
        case success
        case error
        case warning
    }

    public init(title: String, detail: String? = nil, kind: Kind) {
        self.title = title
        self.detail = detail
        self.kind = kind
    }
}

public enum RepoState: String, CaseIterable, Sendable {
    case clean
    case dirty
    case mergeConflict
    case rebasing
    case cherryPicking
    case detachedHEAD
    case reverting
    case bisecting
    case staging
    case pushing
    case pulling
    case merging
    case resolving

    public var label: String {
        switch self {
        case .clean: return "Clean"
        case .dirty: return "Dirty"
        case .mergeConflict: return "Merge Conflict"
        case .rebasing: return "Rebasing"
        case .cherryPicking: return "Cherry Picking"
        case .detachedHEAD: return "Detached HEAD"
        case .reverting: return "Reverting"
        case .bisecting: return "Bisecting"
        case .staging: return "Staging"
        case .pushing: return "Pushing"
        case .pulling: return "Pulling"
        case .merging: return "Merging"
        case .resolving: return "Resolving"
        }
    }

    public var icon: String {
        switch self {
        case .clean: return "checkmark.circle.fill"
        case .dirty: return "arrow.up.circle.fill"
        case .staging: return "plus.circle.fill"
        case .pushing: return "arrow.up.circle.fill"
        case .pulling: return "arrow.down.circle.fill"
        case .merging, .rebasing, .resolving: return "arrow.triangle.branch.circlepath"
        case .mergeConflict: return "exclamationmark.triangle.fill"
        case .cherryPicking, .reverting, .bisecting: return "arrow.triangle.branch.circlepath"
        case .detachedHEAD: return "arrow.triangle.merge"
        }
    }

    public var color: Color {
        switch self {
        case .clean: return .green
        case .dirty: return .orange
        case .staging: return .blue
        case .pushing, .pulling: return .cyan
        case .merging: return .yellow
        case .rebasing: return .purple
        case .resolving: return .red
        case .mergeConflict: return .red
        case .cherryPicking, .reverting, .bisecting: return .yellow
        case .detachedHEAD: return .purple
        }
    }
}

public struct GitWorktree: Identifiable, Hashable {
    public let id = UUID()
    public let path: String
    public let branch: String
    public let isCurrent: Bool

    public init(path: String, branch: String, isCurrent: Bool) {
        self.path = path
        self.branch = branch
        self.isCurrent = isCurrent
    }
}

public struct GitStatus: Identifiable, Hashable {
    public let id = UUID()
    public let path: String
    public let statusCode: String
    public let staged: Bool

    public init(path: String, statusCode: String, staged: Bool) {
        self.path = path
        self.statusCode = statusCode
        self.staged = staged
    }
}

public struct GitStateSnapshot: Equatable, Sendable {
    public let isGitRepo: Bool
    public let repoName: String
    public let branchName: String
    public let isAheadOfRemote: Bool
    public let isBehindRemote: Bool
    public let hasChanges: Bool
    public let stagedCount: Int
    public let unstagedCount: Int
    public let untrackedCount: Int
    public let conflictCount: Int
    public let linesAdded: Int
    public let linesDeleted: Int
    public let lastCommitHash: String
    public let lastCommitMessage: String
    public let lastCommitDate: Date
    public let remotes: [Remote]
    public let remoteName: String
    public let submodules: [Submodule]
    public let branches: [GitBranch]
    public let repoState: RepoState

    public init(
        isGitRepo: Bool,
        repoName: String,
        branchName: String,
        isAheadOfRemote: Bool,
        isBehindRemote: Bool,
        hasChanges: Bool,
        stagedCount: Int,
        unstagedCount: Int,
        untrackedCount: Int,
        conflictCount: Int,
        linesAdded: Int,
        linesDeleted: Int,
        lastCommitHash: String,
        lastCommitMessage: String,
        lastCommitDate: Date,
        remotes: [Remote],
        remoteName: String,
        submodules: [Submodule],
        branches: [GitBranch],
        repoState: RepoState
    ) {
        self.isGitRepo = isGitRepo
        self.repoName = repoName
        self.branchName = branchName
        self.isAheadOfRemote = isAheadOfRemote
        self.isBehindRemote = isBehindRemote
        self.hasChanges = hasChanges
        self.stagedCount = stagedCount
        self.unstagedCount = unstagedCount
        self.untrackedCount = untrackedCount
        self.conflictCount = conflictCount
        self.linesAdded = linesAdded
        self.linesDeleted = linesDeleted
        self.lastCommitHash = lastCommitHash
        self.lastCommitMessage = lastCommitMessage
        self.lastCommitDate = lastCommitDate
        self.remotes = remotes
        self.remoteName = remoteName
        self.submodules = submodules
        self.branches = branches
        self.repoState = repoState
    }
}
