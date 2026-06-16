import CoreServices
import Foundation

final class DirectoryFSEventsWatcher {
    private var stream: FSEventStreamRef?
    private let onEventPaths: ([String]) -> Void
    
    init(onEventPaths: @escaping ([String]) -> Void) {
        self.onEventPaths = onEventPaths
    }
    
    deinit {
        stop()
    }
    
    func start(path: String) {
        stop()
        
        let pathsToWatch = [path as CFString] as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let flags = FSEventStreamCreateFlags(
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot)
        )
        
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.eventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            flags
        ) else {
            return
        }
        
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }
    
    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
    
    fileprivate func deliver(eventPaths: [String]) {
        guard !eventPaths.isEmpty else { return }
        onEventPaths(eventPaths)
    }
    
    private static let eventCallback: FSEventStreamCallback = {
        _, clientCallBackInfo, numEvents, eventPaths, _, _ in
        guard let clientCallBackInfo else { return }
        let watcher = Unmanaged<DirectoryFSEventsWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
        
        let cPaths = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>?.self)
        var paths: [String] = []
        paths.reserveCapacity(numEvents)
        for index in 0..<numEvents {
            guard let cPath = cPaths[index] else { continue }
            paths.append(String(cString: cPath))
        }
        watcher.deliver(eventPaths: paths)
    }
}
