import ActivityKit
import Foundation

/// Live Activity for a multi-scan session. The Scanner calls these as codes come in.
enum MultiScanActivity {
    /// Starts a fresh session, replacing any activity left over from a previous one.
    static func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let initial = MultiScanAttributes.ContentState.make(count: 0, kinds: [], latest: String(localized: "Point at a code"))
        let current = try? Activity.request(
            attributes: MultiScanAttributes(startedAt: .now),
            content: ActivityContent(state: initial, staleDate: nil)
        )
        let currentID = current?.id
        Task {
            for activity in Activity<MultiScanAttributes>.activities where activity.id != currentID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// - Parameters:
    ///   - kinds: kinds of the codes collected so far, in scan order (oldest first).
    ///   - latest: title of the newest code.
    static func update(count: Int, kinds: [CodeKind], latest: String) {
        let state = MultiScanAttributes.ContentState.make(count: count, kinds: kinds.map(\.rawValue), latest: latest)
        Task {
            for activity in Activity<MultiScanAttributes>.activities {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    static func end() {
        Task {
            for activity in Activity<MultiScanAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
