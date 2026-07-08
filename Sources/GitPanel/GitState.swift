import Foundation
import SwiftUI

@Observable
final class GitState {
    var repoName: String = ""
    var branchName: String = ""
    var commitCount: Int = 0
    var linesAdded: Int = 0
    var linesDeleted: Int = 0
    var hasChanges: Bool = false
    var isAheadOfRemote: Bool = false
    var isBehindRemote: Bool = false
    var lastCommitHash: String = ""
    var lastCommitMessage: String = ""
    var lastCommitDate: Date = .distantPast
    var remoteName: String = ""
    var isRebaseInProgress: Bool = false
    var isMergeInProgress: Bool = false
    var isCherryPickInProgress: Bool = false
    var isRevertInProgress: Bool = false
    var repoState: RepoState = .clean
    var remotes: [Remote] = []
    var submodules: [Submodule] = []
    var branches: [GitBranch] = []
    var prStatus: PRStatus = .noPRs
    var usageData: UsageData?
    var environmentMode: EnvironmentMode = .production
    var bannerMessage: BannerMessage?
    var isGitRepo: Bool = false
    var lastUpdated: Date = .distantPast

    var syncStatus: String {
        var parts: [String] = []
        if isAheadOfRemote { parts.append("ahead") }
        if isBehindRemote { parts.append("behind") }
        return parts.isEmpty ? "Synced" : parts.joined(separator: " · ")
    }

    var stagedCount: Int { 0 }
    var unstagedCount: Int { 0 }
    var untrackedCount: Int { 0 }
    var conflictCount: Int { 0 }
}

struct Remote: Identifiable, Sendable, Hashable {
    let name: String
    let url: String
    var isDefault: Bool = false
    var id: String { name + url }
}

struct Submodule: Identifiable, Sendable, Hashable {
    let name: String
    let path: String
    let url: String
    var branch: String?
    var id: String { path }
}

struct GitBranch: Identifiable, Sendable, Hashable {
    let name: String
    let isCurrent: Bool
    var isRemote: Bool = false
    var remoteName: String?
    var upstreamName: String?
    var ahead: Int = 0
    var behind: Int = 0
    var id: String { name }
}

enum PRStatus: Sendable, Hashable {
    case noPRs
    case notInstalled
    case pullRequests([PRInfo])
}

struct PRInfo: Identifiable, Sendable, Hashable {
    let number: Int
    let title: String
    let url: String
    let state: String
    let author: String
    let branch: String
    let reviewDecision: String?
    let mergeable: Bool?
    var id: Int { number }
}

struct UsageData: Sendable, Hashable {
    let tokens: Int
    let cost: Double
    let model: String
    let plan: String
    let isUsingPlan: Bool
}

enum EnvironmentMode: String, CaseIterable, Sendable, Identifiable {
    case local = "Work locally"
    case codex = "Connect Codex web"
    case cloud = "Send to cloud"
    case production
    case development

    var id: String { rawValue }
}

struct BannerMessage: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let detail: String?
    let kind: Kind

    enum Kind: Sendable {
        case success
        case error
        case warning
    }
}

enum RepoState: String, CaseIterable, Sendable {
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

    var label: String {
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

    var icon: String {
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

    var color: Color {
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

struct GitWorktree: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let branch: String
    let isCurrent: Bool
}

struct GitStatus: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let statusCode: String
    let staged: Bool
}
