import Foundation

final class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private var refreshDurations: [TimeInterval] = []
    private var gitDurations: [TimeInterval] = []
    private var uiDurations: [TimeInterval] = []
    private let maxSamples = 100

    // Thresholds
    let refreshThreshold: TimeInterval = 0.5  // 500ms
    let gitCommandThreshold: TimeInterval = 2.0  // 2s
    let uiUpdateThreshold: TimeInterval = 0.016  // 16ms (60fps)

    func recordRefresh(_ duration: TimeInterval) {
        append(&refreshDurations, duration)
        if duration > refreshThreshold {
            AppLogger.git.warning("Slow refresh: \(duration, format: .fixed(precision: 3))s")
        }
    }

    func recordGitCommand(_ command: String, duration: TimeInterval) {
        append(&gitDurations, duration)
        if duration > gitCommandThreshold {
            AppLogger.git.warning("Slow git command '\(command)': \(duration, format: .fixed(precision: 3))s")
        }
    }

    func recordUIUpdate(_ duration: TimeInterval) {
        append(&uiDurations, duration)
        if duration > uiUpdateThreshold {
            AppLogger.ui.warning("Slow UI update: \(duration * 1000, format: .fixed(precision: 1))ms")
        }
    }

    func averageRefreshDuration() -> TimeInterval { average(refreshDurations) }
    func p95RefreshDuration() -> TimeInterval { percentile(refreshDurations, 0.95) }
    func averageGitDuration() -> TimeInterval { average(gitDurations) }
    func p95GitDuration() -> TimeInterval { percentile(gitDurations, 0.95) }

    private func append(_ array: inout [TimeInterval], _ value: TimeInterval) {
        array.append(value)
        if array.count > maxSamples { array.removeFirst() }
    }

    private func average(_ values: [TimeInterval]) -> TimeInterval {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func percentile(_ values: [TimeInterval], _ p: Double) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = Int(Double(sorted.count - 1) * p)
        return sorted[index]
    }
}
