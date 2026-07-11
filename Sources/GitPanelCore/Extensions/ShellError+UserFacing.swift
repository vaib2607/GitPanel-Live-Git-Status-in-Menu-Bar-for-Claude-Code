import Foundation

public extension ShellError {
    var userFacingError: UserFacingError {
        switch self {
        case .commandFailed(let code, let command, _, _, let stderr):
            if code == 128 {
                // Determine recovery action based on stderr context
                let stderrLower = stderr.lowercased()
                if stderrLower.contains("not a git repository") || stderrLower.contains("not inside work tree") {
                    return UserFacingError(
                        title: "Not a Git Repository",
                        message: "The selected directory does not appear to be a Git repository.",
                        recoveryAction: RecoveryAction(title: "Choose Repository", type: .openSettings), // Assuming openSettings or a specific action triggers repo picker
                        technicalDiagnosticsID: "GIT_ERR_128_NOT_REPO",
                        severity: .error
                    )
                } else if stderrLower.contains("permission denied") {
                    return UserFacingError(
                        title: "Permission Denied",
                        message: "Git requires permission to access this repository.",
                        recoveryAction: RecoveryAction(title: "Check Permissions", type: .openSettings),
                        technicalDiagnosticsID: "GIT_ERR_128_PERMISSION",
                        severity: .error
                    )
                } else if stderrLower.contains("could not read from remote repository") || stderrLower.contains("authentication failed") {
                    return UserFacingError(
                        title: "Authentication Failed",
                        message: "Git failed to authenticate with the remote repository.",
                        recoveryAction: RecoveryAction(title: "Reauthenticate", type: .reauthenticate),
                        technicalDiagnosticsID: "GIT_ERR_128_AUTH",
                        severity: .error
                    )
                }
                
                return UserFacingError(
                    title: "Git Command Failed",
                    message: "Git command '\(command)' failed: \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))",
                    recoveryAction: RecoveryAction(title: "Retry", type: .retry),
                    technicalDiagnosticsID: "GIT_ERR_128",
                    severity: .error
                )
            }
            
            return UserFacingError(
                title: "Command Failed",
                message: "Command '\(command)' failed with code \(code): \(stderr)",
                recoveryAction: RecoveryAction(title: "Retry", type: .retry),
                technicalDiagnosticsID: "CMD_FAILED_\(code)",
                severity: .error
            )
            
        case .binaryNotFound(let name):
            return UserFacingError(
                title: "Binary Not Found",
                message: "Required command line tool '\(name)' could not be found in your PATH.",
                recoveryAction: RecoveryAction(title: "Open Settings", type: .openSettings),
                technicalDiagnosticsID: "BIN_NOT_FOUND",
                severity: .critical
            )
            
        case .timeout(let command, _, let duration):
            return UserFacingError(
                title: "Command Timed Out",
                message: "Command '\(command)' took longer than \(duration) seconds and was terminated.",
                recoveryAction: RecoveryAction(title: "Retry", type: .retry),
                technicalDiagnosticsID: "CMD_TIMEOUT",
                severity: .warning
            )
            
        case .processGroupKillFailed, .encodingError:
            return UserFacingError(
                title: "Internal Error",
                message: self.localizedDescription,
                recoveryAction: RecoveryAction(title: "Retry", type: .retry),
                technicalDiagnosticsID: "INTERNAL_ERR",
                severity: .error
            )
        }
    }
}
