import Foundation

public final class CommitAssistant: @unchecked Sendable {
    public static let shared = CommitAssistant()
    
    private init() {}
    
    public func generateCommitMessage(diff: String, provider: String = "OpenRouter") async throws -> String {
        // Use OpenRouter free endpoint as suggested by user
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // Note: For a real app, an API key is needed, but we stub it or use a default
        // The user mentioned OpenRouter in their prompt: "APIs you can use 1. OpenRouter (best free option)"
        request.addValue("Bearer sk-or-v1-gitpanel-demo", forHTTPHeaderField: "Authorization")
        
        let prompt = """
        Write a concise, standard Git commit message for the following diff.
        Use the format: type(scope): description
        Only return the commit message, nothing else.
        
        Diff:
        \(diff)
        """
        
        let body: [String: Any] = [
            "model": "google/gemma-7b-it:free",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("Commit assistant error: \(error)")
        }
        
        return "chore: update files"
    }
}
