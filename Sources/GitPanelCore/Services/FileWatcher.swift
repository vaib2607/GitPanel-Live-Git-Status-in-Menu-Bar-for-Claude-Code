import Foundation
import CoreServices

private let fseventLib: UnsafeMutableRawPointer? = {
    dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_LAZY)
}()

@discardableResult
func FSEventStreamSetExcludedPaths(_ streamRef: FSEventStreamRef, _ pathsToExclude: CFArray) -> Bool {
    typealias FuncType = @convention(c) (FSEventStreamRef, CFArray) -> UInt8
    guard let lib = fseventLib,
          let sym = dlsym(lib, "FSEventStreamSetExcludedPaths") else {
        return false
    }
    let function = unsafeBitCast(sym, to: FuncType.self)
    return function(streamRef, pathsToExclude) != 0
}

final class FileWatcher {
    var onIndexChange: (() -> Void)?

    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue.global(qos: .utility)

    // A Sendable box to retain the callback / stream continuation safely.
    final class CallbackBox: @unchecked Sendable {
        var onEvent: ((URL) -> Void)?
        var continuation: AsyncStream<URL>.Continuation?
        var watchedRepoPath: String?
    }
    private let box = CallbackBox()

    func startWatching(repo: URL) {
        stop()

        box.watchedRepoPath = repo.path
        box.onEvent = { [weak self] _ in
            self?.onIndexChange?()
        }

        let pathsToWatch = [repo.path as CFString]
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(box).toOpaque(),
            retain: { info in
                guard let info = info else { return nil }
                _ = Unmanaged<FileWatcher.CallbackBox>.fromOpaque(info).retain()
                return info
            },
            release: { info in
                guard let info = info else { return }
                Unmanaged<FileWatcher.CallbackBox>.fromOpaque(info).release()
            },
            copyDescription: nil
        )

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

        let pathsToExclude = [
            repo.appendingPathComponent(".git").path as CFString,
            repo.appendingPathComponent("node_modules").path as CFString,
            repo.appendingPathComponent(".build").path as CFString
        ]
        _ = FSEventStreamSetExcludedPaths(eventStream, pathsToExclude as CFArray)

        stream = eventStream
        FSEventStreamSetDispatchQueue(eventStream, queue)
        FSEventStreamStart(eventStream)
    }

    func startWatchingStream(repo: URL) -> AsyncStream<URL> {
        stop()

        box.watchedRepoPath = repo.path
        let (stream, continuation) = AsyncStream<URL>.makeStream()
        box.continuation = continuation

        let pathsToWatch = [repo.path as CFString]
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passRetained(box).toOpaque(),
            retain: { info in
                guard let info = info else { return nil }
                _ = Unmanaged<FileWatcher.CallbackBox>.fromOpaque(info).retain()
                return info
            },
            release: { info in
                guard let info = info else { return }
                Unmanaged<FileWatcher.CallbackBox>.fromOpaque(info).release()
            },
            copyDescription: nil
        )

        guard let eventStream = FSEventStreamCreate(
            nil,
            fileWatcherCallback,
            &context,
            pathsToWatch as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else {
            continuation.finish()
            return stream
        }

        let pathsToExclude = [
            repo.appendingPathComponent(".git").path as CFString,
            repo.appendingPathComponent("node_modules").path as CFString,
            repo.appendingPathComponent(".build").path as CFString
        ]
        _ = FSEventStreamSetExcludedPaths(eventStream, pathsToExclude as CFArray)

        self.stream = eventStream
        FSEventStreamSetDispatchQueue(eventStream, queue)
        FSEventStreamStart(eventStream)

        return stream
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        box.continuation?.finish()
        box.continuation = nil
        box.onEvent = nil
        box.watchedRepoPath = nil
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
    let box = Unmanaged<FileWatcher.CallbackBox>.fromOpaque(pointer).takeUnretainedValue()

    let pathsArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
    let count = CFArrayGetCount(pathsArray)

    for i in 0..<count {
        guard let pathPtr = CFArrayGetValueAtIndex(pathsArray, i) else { continue }
        let pathCF = Unmanaged<CFString>.fromOpaque(pathPtr).takeUnretainedValue()
        let path = pathCF as String
        // Exclude root folder event and ignored directories
        if let repoPath = box.watchedRepoPath {
            let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            let resolvedRepo = URL(fileURLWithPath: repoPath).resolvingSymlinksInPath().path
            if resolvedPath == resolvedRepo {
                continue
            }
        }

        // Exclude node_modules, .build, and .git folders
        if path.contains("node_modules") || path.contains(".build") || path.contains("/.git/") || path.hasSuffix("/.git") {
            continue
        }

        let url = URL(fileURLWithPath: path)
        box.onEvent?(url)
        box.continuation?.yield(url)
    }
}
