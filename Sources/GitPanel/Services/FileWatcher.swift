import Foundation

final class FileWatcher {
    var onIndexChange: (() -> Void)?

    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue.global(qos: .utility)

    func startWatching(repo: URL) {
        stop()

        let gitDir = repo.appendingPathComponent(".git").path

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let pathsToWatch = [gitDir as CFString]

        guard let eventStream = FSEventStreamCreate(
            nil,
            fileWatcherCallback,
            &context,
            pathsToWatch as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else {
            return
        }

        stream = eventStream
        FSEventStreamSetDispatchQueue(eventStream, queue)
        FSEventStreamStart(eventStream)
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}

private func fileWatcherCallback(
    _ allocator: OpaquePointer,
    _ info: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let pointer = info else { return }
    let watcher = Unmanaged<FileWatcher>.fromOpaque(pointer).takeUnretainedValue()

    let paths = eventPaths.bindMemory(to: UnsafePointer<CChar>.self, capacity: numEvents)
    let count = Int(numEvents)

    for i in 0..<count {
        let flags = eventFlags[i]
        let path = String(cString: paths[i])

        let isDir = flags & UInt32(kFSEventStreamEventFlagItemIsDir) != 0
        let isFile = flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0
        let isModified = flags & UInt32(kFSEventStreamEventFlagItemModified) != 0
        let isCreated = flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0
        let isRenamed = flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0

        let isGitChange = path.contains("/.git/")

        if isGitChange && (isFile || (isDir && (isCreated || isRenamed || isModified))) {
            Task { @MainActor in
                watcher.onIndexChange?()
            }
            return
        }
    }
}
