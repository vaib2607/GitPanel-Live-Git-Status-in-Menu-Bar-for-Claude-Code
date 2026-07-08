import Foundation
import SwiftUI

struct DiffStats {
    let linesAdded: Int
    let linesDeleted: Int
    let stagedLinesAdded: Int
    let stagedLinesDeleted: Int
    let filesChanged: Int
    let stagedFiles: Int
    let unstagedFiles: Int
    let untrackedFiles: Int
    let conflicts: Int

    var totalAdded: Int { linesAdded + stagedLinesAdded }
    var totalDeleted: Int { linesDeleted + stagedLinesDeleted }
    var isClean: Bool { totalAdded + totalDeleted == 0 }

    static let empty = DiffStats(
        linesAdded: 0, linesDeleted: 0,
        stagedLinesAdded: 0, stagedLinesDeleted: 0,
        filesChanged: 0, stagedFiles: 0, unstagedFiles: 0,
        untrackedFiles: 0, conflicts: 0
    )
}

enum RepoState: String, CaseIterable {
    case clean, dirty, mergeConflict, rebasing, cherryPicking
    case detachedHEAD, reverting, bisecting

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
        }
    }

    var accentColor: Color {
        switch self {
        case .clean: return .green
        case .dirty: return .orange
        case .mergeConflict: return .red
        case .rebasing, .cherryPicking, .reverting, .bisecting: return .yellow
        case .detachedHEAD: return .purple
        }
    }
}

struct RepositorySnapshot {
    let name: String
    let branch: String
    let isGitRepo: Bool
    let state: RepoState
    let diff: DiffStats
    let ahead: Int
    let behind: Int
    let lastUpdated: Date
    let remotes: [Remote]
    let submodules: [Submodule]
    let dependencies: [String]

    static let empty = RepositorySnapshot(
        name: "", branch: "", isGitRepo: false, state: .clean,
        diff: .empty, ahead: 0, behind: 0, lastUpdated: Date.distantPast,
        remotes: [], submodules: [], dependencies: []
    )
}

struct GitStatus {
    let added: Int
    let modified: Int
    let deleted: Int
    let untracked: Int

    var hasChanges: Bool { total > 0 }
    var total: Int { added + modified + deleted + untracked }

    static let empty = GitStatus(added: 0, modified: 0, deleted: 0, untracked: 0)
}

struct GitBranch: Identifiable, Hashable {
    let name: String
    let isCurrent: Bool
    var id: String { name }
}

struct GitWorktree: Identifiable {
    let path: String
    let branch: String
    let isCurrent: Bool
    var id: String { path }
}

struct PRStatus {
    let exists: Bool
    let title: String?
    let number: Int?
    let state: String?
    let url: String?
    let available: Bool

    static let unavailable = PRStatus(exists: false, title: nil, number: nil, state: nil, url: nil, available: false)
    static let noPRs = PRStatus(exists: false, title: nil, number: nil, state: nil, url: nil, available: true)
}

struct Submodule: Identifiable {
    let name: String
    let path: String
    let url: String
    var id: String { path }
}

struct Remote: Identifiable {
    let name: String
    let url: String
    var id: String { name + url }
}

enum EnvironmentMode: String, CaseIterable, Identifiable {
    case local = "Work locally"
    case codex = "Connect Codex web"
    case cloud = "Send to cloud"

    var id: String { rawValue }
}
