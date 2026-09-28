import Foundation

/// Decides when to ask for an App Store review: once each time successful scans cross a milestone,
/// and only when the user has just come back to the camera from a result.
enum ReviewPrompter {
    static let milestones = [5, 30, 150]

    /// Set when Home gives way to a result; cleared when Home comes back.
    static var leftHomeForResult = false

    /// The milestone to prompt for now, if any: the highest one reached that hasn't been prompted yet.
    static func milestone(scans: Int, lastPrompted: Int) -> Int? {
        milestones.last { $0 <= scans && $0 > lastPrompted }
    }
}
