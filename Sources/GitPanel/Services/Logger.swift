import Foundation
import os

// MARK: - Logger Category

enum LoggerCategory: String {
    case git = "GitService"
    case shell = "ShellRunner"
    case github = "GitHubService"
    case usage = "UsageService"
    case ui = "UI"
    case watcher = "FileWatcher"
}

// MARK: - AppLogger

final class AppLogger {

    static let shared = AppLogger()

    private var loggers: [LoggerCategory: os.Logger] = [:]

    private init() {
        for category in LoggerCategory.allCases {
            loggers[category] = os.Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "com.gitpanel",
                category: category.rawValue
            )
        }
    }

    // MARK: - Category Accessors

    static var git: os.Logger { shared.logger(for: .git) }
    static var shell: os.Logger { shared.logger(for: .shell) }
    static var github: os.Logger { shared.logger(for: .github) }
    static var usage: os.Logger { shared.logger(for: .usage) }
    static var ui: os.Logger { shared.logger(for: .ui) }
    static var watcher: os.Logger { shared.logger(for: .watcher) }

    private func logger(for category: LoggerCategory) -> os.Logger {
        loggers[category, default: os.Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.gitpanel",
            category: category.rawValue
        )]
    }
}

// MARK: - LoggerCategory: CaseIterable

extension LoggerCategory: CaseIterable {}

// MARK: - Performance Timing

extension AppLogger {

    static func time<T>(
        _ operation: String,
        category: LoggerCategory,
        _ body: () throws -> T
    ) rethrows -> T {
        let start = Date()
        let result = try body()
        let elapsed = Date().timeIntervalSince(start)
        shared.logger(for: category)
            .debug("\(operation, privacy: .public) completed in \(elapsed, format: .fixed(precision: 3))s")
        return result
    }

    static func timeAsync<T>(
        _ operation: String,
        category: LoggerCategory,
        _ body: () async throws -> T
    ) async rethrows -> T {
        let start = Date()
        let result = try await body()
        let elapsed = Date().timeIntervalSince(start)
        shared.logger(for: category)
            .debug("\(operation, privacy: .public) completed in \(elapsed, format: .fixed(precision: 3))s")
        return result
    }
}

// MARK: - Convenience Logging Helpers

extension AppLogger {

    // MARK: Git

    static func gitCommand(_ command: String, args: [String]) {
        git.debug("Running: \(command, privacy: .public) \(args.joined(separator: " "), privacy: .public)")
    }

    static func gitSuccess(_ message: String) {
        git.info("Git success: \(message, privacy: .public)")
    }

    static func gitError(_ message: String, error: Error? = nil) {
        if let error {
            git.error("Git error: \(message, privacy: .public) — \(error.localizedDescription, privacy: .public)")
        } else {
            git.error("Git error: \(message, privacy: .public)")
        }
    }

    // MARK: Shell

    static func shellCommand(_ command: String) {
        shell.debug("Shell command: \(command, privacy: .public)")
    }

    static func shellOutput(_ output: String) {
        shell.debug("Shell output: \(output, privacy: .sensitive)")
    }

    static func shellError(_ message: String, exitCode: Int32? = nil) {
        if let exitCode {
            shell.error("Shell error (exit \(exitCode)): \(message, privacy: .public)")
        } else {
            shell.error("Shell error: \(message, privacy: .public)")
        }
    }

    // MARK: GitHub

    static func githubRequest(_ endpoint: String) {
        github.debug("API request: \(endpoint, privacy: .public)")
    }

    static func githubSuccess(_ message: String) {
        github.info("GitHub success: \(message, privacy: .public)")
    }

    static func githubError(_ message: String, error: Error? = nil) {
        if let error {
            github.error("GitHub error: \(message, privacy: .public) — \(error.localizedDescription, privacy: .public)")
        } else {
            github.error("GitHub error: \(message, privacy: .public)")
        }
    }

    // MARK: Usage

    static func usageEvent(_ event: String, properties: [String: String] = [:]) {
        let props = properties.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        usage.info("Event: \(event, privacy: .public) \(props, privacy: .public)")
    }

    static func usageError(_ message: String) {
        usage.error("Usage error: \(message, privacy: .public)")
    }

    // MARK: UI

    static func uiAction(_ action: String) {
        ui.debug("UI action: \(action, privacy: .public)")
    }

    static func uiNavigation(_ destination: String) {
        ui.info("Navigation: \(destination, privacy: .public)")
    }

    static func uiError(_ message: String) {
        ui.error("UI error: \(message, privacy: .public)")
    }

    // MARK: Watcher

    static func watcherEvent(_ event: String, path: String) {
        watcher.debug("File event: \(event, privacy: .public) at \(path, privacy: .public)")
    }

    static func watcherStarted(watching path: String) {
        watcher.info("Watcher started: \(path, privacy: .public)")
    }

    static func watcherError(_ message: String, path: String? = nil) {
        if let path {
            watcher.error("Watcher error: \(message, privacy: .public) — path: \(path, privacy: .public)")
        } else {
            watcher.error("Watcher error: \(message, privacy: .public)")
        }
    }
}
