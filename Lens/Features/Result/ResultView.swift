import SwiftUI

// OWNER: Result module.
struct ResultView: View {
    var result: ScanResult

    var body: some View {
        Text(result.payload.displayTitle)
    }
}
