import SwiftUI

/// The thumb zone: the Scan lens, over the toolbar. Content scrolls away beneath a soft fade.
struct HomeActionBar: View {
    var isLensAnimating: Bool
    var onScan: () -> Void

    @Environment(AppModel.self) private var model

    var body: some View {
        ScanLensButton(
            isAnimating: isLensAnimating,
            catchTrigger: model.scannerCloseCount,
            onPressChange: { $0 ? model.beginPeek() : model.endPeek() },
            action: onScan
        )
        // The camera zooms open out of the lens, and back into it.
        .codeZoomSource(id: ScannerZoom.lens, cornerRadius: ScanLensButton.defaultDiameter / 2)
        .padding(.top, 20)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) { fade }
    }

    /// Fades the scrolling content out behind the controls.
    private var fade: some View {
        LinearGradient(
            stops: [
                .init(color: Color(.systemGroupedBackground).opacity(0), location: 0),
                .init(color: Color(.systemGroupedBackground).opacity(0.9), location: 0.16),
                .init(color: Color(.systemGroupedBackground), location: 0.32),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .padding(.top, -32)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}
