import Foundation

public struct ChangedFiles: Equatable, Sendable {
    public let staged: [GitFile]
    public let unstaged: [GitFile]
    public let untracked: [GitFile]
    
    public init(staged: [GitFile] = [], unstaged: [GitFile] = [], untracked: [GitFile] = []) {
        self.staged = staged
        self.unstaged = unstaged
        self.untracked = untracked
    }
}

public struct RepositorySnapshot: Equatable, Sendable {
    public let status: GitStateSnapshot
    public let changes: ChangedFiles
    
    public init(status: GitStateSnapshot, changes: ChangedFiles) {
        self.status = status
        self.changes = changes
    }
}
