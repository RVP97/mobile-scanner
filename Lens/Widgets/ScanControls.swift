import SwiftUI
import WidgetKit

/// "Scan Code" for Control Center, the Lock Screen and the Action button.
@available(iOS 18.0, *)
struct ScanCodeControl: ControlWidget {
    static let kind = "com.rvp97.scanner.control.scan"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenScannerControlIntent()) {
                Label("Scan Code", systemImage: "qrcode.viewfinder")
            }
        }
        .displayName("Scan Code")
        .description("Open the Lunet camera from anywhere.")
    }
}

/// Starts a multi-scan session straight away.
@available(iOS 18.0, *)
struct MultiScanControl: ControlWidget {
    static let kind = "com.rvp97.scanner.control.multi-scan"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenMultiScanControlIntent()) {
                Label("Multi-scan", systemImage: "square.stack.3d.up")
            }
        }
        .displayName("Multi-scan")
        .description("Collect several codes in a row, then review them together.")
    }
}
