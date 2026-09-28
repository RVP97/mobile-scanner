import Foundation

// OWNER: Onboarding & Everywhere module. Live Activity for a multi-scan session.
// Scanner calls these; keep signatures stable.
enum MultiScanActivity {
    static func start() {}
    static func update(count: Int, kinds: [CodeKind], latest: String) {}
    static func end() {}
}
