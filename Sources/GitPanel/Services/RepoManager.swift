import Foundation
import SwiftUI

@Observable final class RepoManager {
    static let shared = RepoManager()
    var repoURL: URL

    private let storageKey = "selectedRepoPath"

    init() {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let stored = UserDefaults.standard.string(forKey: storageKey),
           !stored.isEmpty,
           FileManager.default.fileExists(atPath: stored) {
            self.repoURL = URL(fileURLWithPath: stored)
        } else {
            self.repoURL = cwd
        }
    }

    func setRepo(_ url: URL) {
        repoURL = url
        UserDefaults.standard.set(url.path, forKey: storageKey)
    }
}
