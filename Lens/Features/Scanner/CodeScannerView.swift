import SwiftUI

// OWNER: Scanner module. A reusable live camera that reports decoded codes.
// Onboarding embeds this for the first-scan step. Keep this signature stable.
struct CodeScannerView: View {
    var isPaused: Bool = false
    var onScan: (ScannedCode) -> Void

    var body: some View {
        Color.black
    }
}
