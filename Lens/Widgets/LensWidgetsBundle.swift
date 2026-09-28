import SwiftUI
import WidgetKit

@main
struct LensWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ScanWidget()
        MyCodeWidget()
        MultiScanLiveActivity()
        if #available(iOS 18.0, *) {
            ScanCodeControl()
            MultiScanControl()
        }
    }
}
