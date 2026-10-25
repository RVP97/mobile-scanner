#if DEBUG
import Foundation
import os

/// Debug: `-qaWatchdog YES` logs every main-thread stall over 100 ms, and `PerfMark` timestamps.
nonisolated enum PerfWatchdog {
    static let log = Logger(subsystem: "com.rvp97.scanner", category: "perf")

    static func startIfRequested() {
        guard UserDefaults.standard.bool(forKey: "qaWatchdog") else { return }
        Thread.detachNewThread {
            while true {
                let sent = Date()
                let done = DispatchSemaphore(value: 0)
                DispatchQueue.main.async { done.signal() }
                done.wait()
                let ms = Date().timeIntervalSince(sent) * 1000
                if ms > 100 { log.notice("HANG \(Int(ms)) ms") }
                Thread.sleep(forTimeInterval: 0.02)
            }
        }
    }

    static func mark(_ label: String) {
        log.notice("MARK \(label, privacy: .public)")
    }
}
#endif
