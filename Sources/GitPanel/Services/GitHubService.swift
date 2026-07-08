import Foundation

struct GitHubService {
    func isAvailable() -> Bool {
        FileManager.default.isExecutableFile(atPath: GitService.ghPath)
    }

    /// `available` distinguishes "gh not installed" from "installed but no open PR".
    func prStatus(repo: URL) -> PRStatus {
        guard isAvailable() else { return .unavailable }
        let r = ShellRunner.run(
            executable: GitService.ghPath,
            arguments: ["pr", "status", "--json", "number,title,state,url"],
            workingDirectory: repo
        )
        guard r.success,
              let data = r.output.data(using: .utf8),
              let arr = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? nil
        else { return .noPRs }

        guard let first = arr.first else { return .noPRs }
        let number = first["number"] as? Int
        let title = first["title"] as? String
        let state = first["state"] as? String
        let url = first["url"] as? String
        return PRStatus(exists: true, title: title, number: number, state: state, url: url, available: true)
    }
}
