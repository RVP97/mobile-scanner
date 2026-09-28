import Foundation

// Compiled into the app and the widget extension.
enum LensShared {
    static let appGroup = "group.com.rvp97.scanner"
    static let scanURL = URL(string: "lens://scan")!
    static let multiScanURL = URL(string: "lens://scan?mode=multi")!
    static let createURL = URL(string: "lens://create")!
    static let historyURL = URL(string: "lens://history")!
}
