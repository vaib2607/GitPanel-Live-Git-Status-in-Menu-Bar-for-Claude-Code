import Foundation

public struct GitFile: Identifiable, Sendable, Hashable {
    public let id = UUID()
    public let filename: String
    public var oldFilename: String?
    public let status: GitFileStatus
    public let additions: Int
    public let deletions: Int

    public init(filename: String, oldFilename: String? = nil, status: GitFileStatus, additions: Int, deletions: Int) {
        self.filename = filename
        self.oldFilename = oldFilename
        self.status = status
        self.additions = additions
        self.deletions = deletions
    }
}

public enum GitFileStatus: String, Codable, Sendable {
    case modified
    case added
    case deleted
    case untracked
    case renamed
    case copied
}
