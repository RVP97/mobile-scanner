import ActivityKit
import Foundation

/// Live Activity for a multi-scan session. The Scanner calls these as codes come in.
enum MultiScanActivity {
    /// Each change waits for the one before, off the main thread: requesting an activity is a
    /// synchronous call to the system, made as the camera opens, and an end must not overtake it.
    private static var last: Task<Void, Never>?

    private static func enqueue(_ work: @escaping @Sendable () async -> Void) {
        let previous = last
        last = Task.detached(priority: .utility) {
            await previous?.value
            await work()
        }
    }

    /// Starts a fresh session, replacing any activity left over from a previous one.
    static func start() {
        let initial = MultiScanAttributes.ContentState.make(count: 0, kinds: [], latest: String(localized: "Point at a code"))
        enqueue {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let current = try? Activity.request(
                attributes: MultiScanAttributes(startedAt: .now),
                content: ActivityContent(state: initial, staleDate: nil)
            )
            for activity in Activity<MultiScanAttributes>.activities where activity.id != current?.id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// - Parameters:
    ///   - kinds: kinds of the codes collected so far, in scan order (oldest first).
    ///   - latest: title of the newest code.
    static func update(count: Int, kinds: [CodeKind], latest: String) {
        let state = MultiScanAttributes.ContentState.make(count: count, kinds: kinds.map(\.rawValue), latest: latest)
        enqueue {
            for activity in Activity<MultiScanAttributes>.activities {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    static func end() {
        enqueue {
            for activity in Activity<MultiScanAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
