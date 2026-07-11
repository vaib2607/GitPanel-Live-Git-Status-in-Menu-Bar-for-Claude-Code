import Foundation

enum GitPanelError: LocalizedError, Equatable {
    // Git operations
    case gitOperationFailed(String, ShellError)
    case commitFailed(String)
    case pushFailed(String)
    case pullFailed(String)
    case checkoutFailed(String)
    case mergeConflict([String])
    case rebaseConflict
    case stashFailed(String)
    case resetFailed(String)
    
    // Shell
    case shellTimeout(command: String, duration: TimeInterval)
    case shellBinaryNotFound(String)
    case shellCancelled
    
    // Network
    case networkUnavailable
    case authenticationRequired
    case rateLimited(retryAfter: Date?)
    case githubAPIError(statusCode: Int, message: String)
    
    // Repository
    case repositoryNotFound(URL)
    case permissionDenied(URL)
    case notAGitRepository(URL)
    case repositoryUnlocked(URL)
    
    // Data
    case usageDataCorrupted
    case priceTableMissing
    case cursorDBNotFound
    case jsonParsingError(String)
    
    // State
    case invalidStateTransition(from: String, to: String)
    case operationInProgress
    
    var errorDescription: String? {
        switch self {
        case .gitOperationFailed(let op, _): return "Git operation failed: \(op)"
        case .commitFailed(let msg): return "Commit failed: \(msg)"
        case .pushFailed(let msg): return "Push failed: \(msg)"
        case .pullFailed(let msg): return "Pull failed: \(msg)"
        case .checkoutFailed(let msg): return "Checkout failed: \(msg)"
        case .mergeConflict(let files): return "Merge conflict in \(files.count) file(s)"
        case .rebaseConflict: return "Rebase conflict"
        case .stashFailed(let msg): return "Stash failed: \(msg)"
        case .resetFailed(let msg): return "Reset failed: \(msg)"
        case .shellTimeout(let cmd, _): return "Command timed out: \(cmd)"
        case .shellBinaryNotFound(let bin): return "\(bin) not found"
        case .shellCancelled: return "Command cancelled"
        case .networkUnavailable: return "Network unavailable"
        case .authenticationRequired: return "GitHub authentication required"
        case .rateLimited: return "GitHub API rate limited"
        case .githubAPIError(let code, let msg): return "GitHub API error \(code): \(msg)"
        case .repositoryNotFound(let url): return "Repository not found at \(url.path)"
        case .permissionDenied(let url): return "Permission denied: \(url.path)"
        case .notAGitRepository(let url): return "Not a git repository: \(url.path)"
        case .repositoryUnlocked(let url): return "Repository lock failed: \(url.path)"
        case .usageDataCorrupted: return "Usage data corrupted"
        case .priceTableMissing: return "Price table not found"
        case .cursorDBNotFound: return "Cursor database not found"
        case .jsonParsingError(let msg): return "JSON parsing error: \(msg)"
        case .invalidStateTransition(let from, let to): return "Cannot transition from \(from) to \(to)"
        case .operationInProgress: return "Another operation is in progress"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .shellBinaryNotFound: return "Install the required tool or check your PATH"
        case .authenticationRequired: return "Run 'gh auth login' to authenticate"
        case .rateLimited: return "Wait a few minutes before trying again"
        case .permissionDenied: return "Grant file access in System Settings > Privacy"
        case .networkUnavailable: return "Check your internet connection"
        case .notAGitRepository: return "Open a valid git repository"
        default: return nil
        }
    }
    
    var actionButton: ErrorAction? {
        switch self {
        case .authenticationRequired: return ErrorAction(title: "Open Terminal", action: .openTerminal)
        case .shellBinaryNotFound(let bin): return ErrorAction(title: "Install \(bin)", action: .installBinary(bin))
        case .permissionDenied: return ErrorAction(title: "Open Settings", action: .openSettings)
        case .mergeConflict: return ErrorAction(title: "Resolve", action: .resolveConflicts)
        default: return nil
        }
    }
}

struct ErrorAction: Equatable {
    let title: String
    let action: ErrorActionType
}

enum ErrorActionType: Equatable {
    case openTerminal
    case installBinary(String)
    case openSettings
    case resolveConflicts
    case retry
    case openURL(URL)
}
