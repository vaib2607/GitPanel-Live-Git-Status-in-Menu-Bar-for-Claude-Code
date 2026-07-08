import Foundation

struct GitHubService {
    func isAvailable() -> Bool {
        FileManager.default.isExecutableFile(atPath: GitService.ghPath)
    }

    func prStatus(repo: URL) async throws -> PRStatus {
        do {
            let output = try await ShellRunner.run(
                "gh pr list --json number,title,url,state,author,headRefName,reviewDecision,isDraft,mergeable",
                at: repo.path
            )

            guard let data = output.data(using: .utf8),
                  let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { return .noPRs }

            let prs: [PRInfo] = arr.compactMap { dict in
                guard let number = dict["number"] as? Int,
                      let title = dict["title"] as? String,
                      let url = dict["url"] as? String,
                      let state = dict["state"] as? String,
                      let author = dict["author"] as? String,
                      let branch = dict["headRefName"] as? String
                else { return nil }

                return PRInfo(
                    number: number,
                    title: title,
                    url: url,
                    state: state,
                    author: author,
                    branch: branch,
                    reviewDecision: dict["reviewDecision"] as? String,
                    mergeable: dict["mergeable"] as? Bool
                )
            }

            return prs.isEmpty ? .noPRs : .pullRequests(prs)
        } catch ShellError.commandFailed(let code, _, _) where code == 127 {
            return .notInstalled
        }
    }
}
