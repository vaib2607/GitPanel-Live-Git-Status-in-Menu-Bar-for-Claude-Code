import Foundation

public struct TimelineEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let type: String // "commit", "build", "mcp_start"
    public let message: String
}

@MainActor
@Observable public final class TimelineEngine {
    public static let shared = TimelineEngine()
    
    public var events: [TimelineEvent] = []
    
    private init() {
        load()
    }
    
    public func addEvent(type: String, message: String) {
        let event = TimelineEvent(id: UUID(), timestamp: Date(), type: type, message: message)
        events.insert(event, at: 0)
        save()
    }
    
    private func save() {
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".gitpanel/timeline.json")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(events) {
            try? data.write(to: url)
        }
    }
    
    private func load() {
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".gitpanel/timeline.json")
        if let data = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode([TimelineEvent].self, from: data) {
            events = loaded
        }
    }
}
