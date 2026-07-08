import Foundation

struct GitService {
    static let gitPath: String = resolve("git") ?? "/usr/bin/git"
    static let ghPath: String = resolve("gh") ?? "/usr/local/bin/gh"

    private static func resolve(_ name: String) -> String? {
        let r = ShellRunner.run(executable: "/usr/bin/env", arguments: ["which", name])
        let p = r.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return p.isEmpty ? nil : p
    }

    func isGitRepo(repo: URL) -> Bool {
        let r = ShellRunner.run(executable: Self.gitPath, arguments: ["rev-parse", "--is-inside-work-tree"], workingDirectory: repo)
        return r.success && r.output == "true"
    }

    func status(repo: URL) -> GitStatus {
        guard isGitRepo(repo: repo) else { return .empty }
        let r = ShellRunner.run(executable: Self.gitPath, arguments: ["status", "--porcelain"], workingDirectory: repo)
        var added = 0, modified = 0, deleted = 0, untracked = 0
        for line in r.output.split(separator: "\n") {
            let s = String(line)
            guard s.count >= 2 else { continue }
            let x = s[s.startIndex]
            let y = s[s.index(s.startIndex, offsetBy: 1)]
            if x == "A" || y == "A" { added += 1 }
            else if x == "D" || y == "D" { deleted += 1 }
            else if x == "?" || y == "?" { untracked += 1 }
            else { modified += 1 }
        }
        return GitStatus(added: added, modified: modified, deleted: deleted, untracked: untracked)
    }

    func currentBranch(repo: URL) -> String {
        let r = ShellRunner.run(executable: Self.gitPath, arguments: ["branch", "--show-current"], workingDirectory: repo)
        let b = r.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return b.isEmpty ? "(detached HEAD)" : b
    }

    func branches(repo: URL) -> [GitBranch] {
        let r = ShellRunner.run(executable: Self.gitPath, arguments: ["branch", "--list", "--sort=-committerdate"], workingDirectory: repo)
        var result: [GitBranch] = []
        for line in r.output.split(separator: "\n") {
            var s = String(line).trimmingCharacters(in: .whitespaces)
            let isCurrent = s.hasPrefix("*")
            s = s.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty else { continue }
            result.append(GitBranch(name: s, isCurrent: isCurrent))
        }
        return result
    }

    func checkout(repo: URL, branch: String) {
        _ = ShellRunner.run(executable: Self.gitPath, arguments: ["checkout", branch], workingDirectory: repo)
    }

    func createBranch(repo: URL, name: String) {
        _ = ShellRunner.run(executable: Self.gitPath, arguments: ["checkout", "-b", name], workingDirectory: repo)
    }

    func commit(repo: URL, message: String) -> ShellResult {
        ShellRunner.run(executable: Self.gitPath, arguments: ["commit", "-m", message], workingDirectory: repo)
    }

    func aheadBehind(repo: URL) -> (ahead: Int, behind: Int) {
        guard isGitRepo(repo: repo) else { return (0, 0) }
        let r = ShellRunner.run(
            executable: Self.gitPath,
            arguments: ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"],
            workingDirectory: repo
        )
        guard r.success else { return (0, 0) }
        let parts = r.output.split(separator: "\t").map { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
        if parts.count == 2 { return (ahead: parts[1], behind: parts[0]) }
        return (0, 0)
    }

    func push(repo: URL) -> ShellResult {
        ShellRunner.run(executable: Self.gitPath, arguments: ["push"], workingDirectory: repo)
    }

    func worktrees(repo: URL) -> [GitWorktree] {
        let r = ShellRunner.run(executable: Self.gitPath, arguments: ["worktree", "list", "--porcelain"], workingDirectory: repo)
        var result: [GitWorktree] = []
        var currentPath: String?
        var currentBranch: String?
        var isCurrent = false
        func flush() {
            if let p = currentPath {
                result.append(GitWorktree(path: p, branch: currentBranch ?? "", isCurrent: isCurrent))
            }
            currentPath = nil; currentBranch = nil; isCurrent = false
        }
        for line in r.output.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("worktree ") {
                flush()
                currentPath = String(s.dropFirst("worktree ".count))
            } else if s.hasPrefix("branch ") {
                currentBranch = String(s.dropFirst("branch ".count))
            } else if s == "HEAD" {
                isCurrent = true
            }
        }
        flush()
        return result
    }

    func submodules(repo: URL) -> [Submodule] {
        let r = ShellRunner.run(executable: Self.gitPath, arguments: ["submodule", "status"], workingDirectory: repo)
        var result: [Submodule] = []
        for line in r.output.split(separator: "\n") {
            var s = String(line).trimmingCharacters(in: .whitespaces)
            s = s.replacingOccurrences(of: "+", with: "")
                     .replacingOccurrences(of: "-", with: "")
                     .replacingOccurrences(of: " ", with: "")
            let parts = s.components(separatedBy: " ")
            guard parts.count >= 2 else { continue }
            let path = parts[1]
            let url = parts.count >= 3 ? parts[2].trimmingCharacters(in: CharacterSet(charactersIn: "()")) : ""
            result.append(Submodule(name: (path as NSString).lastPathComponent, path: path, url: url))
        }
        return result
    }

    func remotes(repo: URL) -> [Remote] {
        let r = ShellRunner.run(executable: Self.gitPath, arguments: ["remote", "-v"], workingDirectory: repo)
        var seen = Set<String>()
        var result: [Remote] = []
        for line in r.output.split(separator: "\n") {
            let s = String(line)
            let parts = s.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let name = String(parts[0])
            let url = String(parts[1])
                .replacingOccurrences(of: " (fetch)", with: "")
                .replacingOccurrences(of: " (push)", with: "")
            if seen.contains(name) { continue }
            seen.insert(name)
            result.append(Remote(name: name, url: url))
        }
        return result
    }

    func dependencies(repo: URL) -> [String] {
        let fm = FileManager.default
        let candidates = [
            "package.json", "Podfile", "Package.swift", "Gemfile",
            "requirements.txt", "Cargo.toml", "pubspec.yaml",
            "go.mod", "build.gradle", "pom.xml"
        ]
        return candidates.filter { fm.fileExists(atPath: repo.appendingPathComponent($0).path) }
    }

    // MARK: - CodexBar-style git commands

    struct PorcelainV2Result {
        let ahead: Int
        let behind: Int
        let staged: Int
        let unstaged: Int
        let untracked: Int
        let conflicts: Int
    }

    func porcelainV2(repo: URL) -> PorcelainV2Result {
        let r = ShellRunner.run(
            executable: Self.gitPath,
            arguments: ["status", "--porcelain=v2", "--branch"],
            workingDirectory: repo
        )
        guard r.success else {
            return PorcelainV2Result(ahead: 0, behind: 0, staged: 0, unstaged: 0, untracked: 0, conflicts: 0)
        }

        var ahead = 0, behind = 0
        var staged = 0, unstaged = 0, untracked = 0, conflicts = 0

        for line in r.output.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("# branch.ab") {
                let parts = s.components(separatedBy: " ")
                for part in parts {
                    if part.hasPrefix("+"), let v = Int(part.dropFirst()) { ahead = v }
                    if part.hasPrefix("-"), let v = Int(part.dropFirst()) { behind = v }
                }
            } else if s.hasPrefix("?") {
                untracked += 1
            } else if s.hasPrefix("u") {
                conflicts += 1
            } else if s.first == "1" || s.first == "2" {
                // Format: 1 <xy> ... or 2 <xy> ...
                let cols = s.split(separator: " ")
                if cols.count >= 2 {
                    let xy = String(cols[1])
                    let x = xy.first!
                    let y = xy.last!
                    if x != "." && x != "?" { staged += 1 }
                    if y != "." && y != "?" { unstaged += 1 }
                }
            }
        }

        return PorcelainV2Result(ahead: ahead, behind: behind, staged: staged, unstaged: unstaged, untracked: untracked, conflicts: conflicts)
    }

    struct NumstatResult {
        let added: Int
        let deleted: Int
    }

    func diffNumstat(repo: URL) -> NumstatResult {
        let r = ShellRunner.run(executable: Self.gitPath, arguments: ["diff", "--numstat"], workingDirectory: repo)
        return parseNumstat(r.output)
    }

    func diffCachedNumstat(repo: URL) -> NumstatResult {
        let r = ShellRunner.run(executable: Self.gitPath, arguments: ["diff", "--cached", "--numstat"], workingDirectory: repo)
        return parseNumstat(r.output)
    }

    private func parseNumstat(_ output: String) -> NumstatResult {
        var added = 0, deleted = 0
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count >= 2 else { continue }
            let a = Int(parts[0]) ?? 0
            let d = Int(parts[1]) ?? 0
            added += a
            deleted += d
        }
        return NumstatResult(added: added, deleted: deleted)
    }

    func detectRepoState(repo: URL) -> RepoState {
        let gitDir = repo.appendingPathComponent(".git")
        let fm = FileManager.default

        if fm.fileExists(atPath: gitDir.appendingPathComponent("rebase-merge").path) ||
           fm.fileExists(atPath: gitDir.appendingPathComponent("rebase-apply").path) {
            return .rebasing
        }
        if fm.fileExists(atPath: gitDir.appendingPathComponent("CHERRY_PICK_HEAD").path) {
            return .cherryPicking
        }
        if fm.fileExists(atPath: gitDir.appendingPathComponent("REVERT_HEAD").path) {
            return .reverting
        }
        if fm.fileExists(atPath: gitDir.appendingPathComponent("BISECT_LOG").path) {
            return .bisecting
        }

        let headPath = gitDir.appendingPathComponent("HEAD")
        if let head = try? String(contentsOf: headPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !head.hasPrefix("ref: ") {
            return .detachedHEAD
        }

        let porcelain = porcelainV2(repo: repo)
        if porcelain.conflicts > 0 { return .mergeConflict }

        let numstat = diffNumstat(repo: repo)
        let cached = diffCachedNumstat(repo: repo)
        if numstat.added + numstat.deleted + cached.added + cached.deleted > 0 { return .dirty }

        return .clean
    }
}
