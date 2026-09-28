import SwiftUI

/// A reusable live camera with no chrome that reports each code once it's read reliably.
/// Onboarding embeds this for the first-scan step; it shares the scanner's engine and stabilizer.
struct CodeScannerView: View {
    var isPaused: Bool = false
    var onScan: (ScannedCode) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = ScannerCamera()
    @State private var tracker = ScanTracker()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CameraPreview(camera: camera)
                    .onTapGesture(coordinateSpace: .local) { camera.focus(at: $0) }
                    .accessibilityLabel("Camera")
                    .accessibilityHint("Point at a QR code or barcode to scan it.")

                if camera.status == .running {
                    ReticleView(
                        quad: tracker.trackedQuad,
                        idle: .idle(in: proxy.size, bottomInset: 0)
                    )
                    .opacity(isPaused ? 0 : 1)
                }

                if camera.access == .denied || camera.access == .restricted || camera.status == .unavailable {
                    Image(systemName: "video.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Camera unavailable")
                }
            }
        }
        .background(.black)
        .environment(\.colorScheme, .dark)
        .onAppear {
            let tracker = tracker
            let report = onScan
            camera.onCodes = { reads in
                tracker.ingest(reads).first.map { report($0.scannedCode) }
            }
        }
        .onChange(of: shouldRun, initial: true) { _, run in
            camera.setActive(run)
        }
        .onChange(of: isPaused, initial: true) { _, paused in
            tracker.setPaused(paused)
        }
        .onDisappear {
            camera.setActive(false)
        }
    }

    private var shouldRun: Bool {
        !isPaused && scenePhase != .background
    }
}

#Preview("Embedded scanner") {
    CodeScannerView { _ in }
        .frame(height: 360)
        .clipShape(.rect(cornerRadius: 24))
        .padding()
}
