import Foundation
import Combine

final class FileWatcher {
    private let repoURL: URL
    private let onChange: () -> Void

    private var fileSource: DispatchSourceFileSystemObject?
    private var fallbackTimer: Timer?
    private var lastIndexSignature: String = ""
    private var debounceWork: DispatchWorkItem?
    private var debounceCount = 0

    private let debounceInterval: TimeInterval = 0.3
    private let fallbackInterval: TimeInterval = 8.0
    private let indexPath: String

    private static let allEvents: DispatchSource.FileSystemEvent = [
        .write, .rename, .delete, .attrib, .extend, .link, .revoke
    ]

    init(repoURL: URL, onChange: @escaping () -> Void) {
        self.repoURL = repoURL
        self.onChange = onChange
        self.indexPath = repoURL.appendingPathComponent(".git/index").path
    }

    func start() {
        lastIndexSignature = fileSignature()

        setupFSEvents()
        startFallbackTimer()
    }

    func stop() {
        fileSource?.cancel()
        fileSource = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        debounceWork?.cancel()
        debounceWork = nil
    }

    // MARK: - FSEvents via DispatchSource

    private func setupFSEvents() {
        let fd = open(indexPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: FileWatcher.allEvents,
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.scheduleDebouncedRefresh()
        }

        source.setCancelHandler {
            Darwin.close(fd)
        }

        fileSource = source
        source.resume()
    }

    // MARK: - Debounce

    private func scheduleDebouncedRefresh() {
        debounceWork?.cancel()
        debounceCount += 1

        let work = DispatchWorkItem { [weak self] in
            self?.performCheck()
        }
        debounceWork = work

        let delay = debounceCount < 3 ? debounceInterval : debounceInterval * 2
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func performCheck() {
        let sig = fileSignature()
        if sig != lastIndexSignature {
            lastIndexSignature = sig
            DispatchQueue.main.async { [weak self] in
                self?.onChange()
            }
        }
        debounceCount = 0
    }

    // MARK: - Fallback timer (8s)

    private func startFallbackTimer() {
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: fallbackInterval, repeats: true) { [weak self] _ in
            self?.performCheck()
        }
    }

    private func fileSignature() -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: indexPath)
        if let date = attrs?[.modificationDate] as? Date {
            return "\(date.timeIntervalSince1970)"
        }
        return "none"
    }
}
