import Foundation
import SwiftUI

@MainActor
@Observable final class RepoManager {
    static let shared = RepoManager()
    var repoURL: URL
    var history: [String] = []

    private let storageKey = "selectedRepoPath"
    private let historyKey = "repositoryHistory"

    init() {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        let stored = UserDefaults.standard.string(forKey: storageKey)
        if let stored = stored, !stored.isEmpty, FileManager.default.fileExists(atPath: stored) {
            self.repoURL = URL(fileURLWithPath: stored)
        } else {
            self.repoURL = cwd
        }

        let rawHistory = UserDefaults.standard.stringArray(forKey: historyKey) ?? []
        self.history = rawHistory.filter { path in
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        }
        UserDefaults.standard.set(self.history, forKey: historyKey)

        // Ensure current repo is in history
        if !self.history.contains(repoURL.path) {
            addToHistory(repoURL)
        }
    }

    func setRepo(_ url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw NSError(domain: "RepoManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Path is not a directory"])
        }

        repoURL = url
        UserDefaults.standard.set(url.path, forKey: storageKey)
        addToHistory(url)
    }

    func removeRepoFromHistory(_ path: String) {
        history.removeAll { $0 == path }
        UserDefaults.standard.set(history, forKey: historyKey)
    }

    private func addToHistory(_ url: URL) {
        history.removeAll { $0 == url.path }
        history.insert(url.path, at: 0)
        if history.count > 20 { // Cap history length to 20
            history = Array(history.prefix(20))
        }
        UserDefaults.standard.set(history, forKey: historyKey)
    }
}
