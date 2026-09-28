import AVFoundation
import SwiftData
import SwiftUI

/// A real first scan over the live camera, with a sample code for when nothing is nearby.
struct FirstScanStep: View {
    /// Called with the real scan (nil for the sample) when the user continues.
    var onFinish: (ScanResult?) -> Void
    var onSkip: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics

    @State private var cameraAllowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @State private var phase: Phase = .looking

    enum Phase: Equatable {
        case looking
        /// The sample is on screen and being "scanned".
        case sample
        case success(ScanResult, isSample: Bool)
    }

    var body: some View {
        ZStack {
            camera
            viewfinder
        }
        .overlay(alignment: .top) {
            if phase == .looking {
                coachMark.transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottom
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .sensoryFeedback(.success, trigger: phase) { _, new in
            if case .success = new { haptics } else { false }
        }
    }

    // MARK: Camera

    @ViewBuilder
    private var camera: some View {
        if cameraAllowed {
            CodeScannerView(isPaused: phase != .looking, onScan: handle)
                .ignoresSafeArea()
        } else {
            Color.black
                .ignoresSafeArea()
                .overlay {
                    if phase == .looking {
                        CameraOffNotice().padding(.horizontal, 32)
                    }
                }
        }
    }

    private var viewfinder: some View {
        let locked = phase != .looking
        return ZStack {
            if showsSample {
                SampleCodePlate()
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            ViewfinderBrackets()
                .fill(locked ? Palette.accent : .white)
                .frame(width: locked ? 212 : 248, height: locked ? 212 : 248)
                .shadow(color: .black.opacity(0.3), radius: 6)
                .opacity(cameraAllowed || locked ? 1 : 0)
        }
        .offset(y: -40)
        .animation(reduceMotion ? nil : .snappy(duration: 0.4), value: locked)
        .accessibilityHidden(true)
    }

    private var showsSample: Bool {
        switch phase {
        case .looking: false
        case .sample: true
        case .success(_, let isSample): isSample
        }
    }

    private var coachMark: some View {
        Label("Point at any code around you", systemImage: "qrcode.viewfinder")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .lensGlass(.clear, in: .capsule)
            .padding(.top, 16)
            .opacity(cameraAllowed ? 1 : 0)
    }

    // MARK: Bottom

    @ViewBuilder
    private var bottom: some View {
        switch phase {
        case .looking:
            SampleOffer(onTry: trySample, onSkip: onSkip)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        case .sample:
            EmptyView()
        case .success(let result, let isSample):
            FirstScanSuccessCard(result: result, isSample: isSample) {
                onFinish(isSample ? nil : result)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Actions

    private func handle(_ code: ScannedCode) {
        guard phase == .looking else { return }
        let result = ScanResult(code: code, payload: PayloadParser.parse(code.raw, symbology: code.symbology))
        RecordWriter.save(result, in: modelContext)
        withAnimation(.smooth(duration: 0.45)) {
            phase = .success(result, isSample: false)
        }
    }

    private func trySample() {
        withAnimation(.smooth(duration: 0.35)) { phase = .sample }
        Task {
            // Long enough to see the code land in the viewfinder, short enough to feel instant.
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 900))
            let code = ScannedCode(raw: SampleCodePlate.payload, symbology: .qr)
            let result = ScanResult(code: code, payload: PayloadParser.parse(code.raw, symbology: .qr))
            withAnimation(.smooth(duration: 0.45)) {
                phase = .success(result, isSample: true)
            }
        }
    }
}

/// "No code nearby? Try a sample".
private struct SampleOffer: View {
    var onTry: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "wifi")
                    .font(.headline)
                    .foregroundStyle(CodeKind.wifi.tint)
                    .frame(width: 40, height: 40)
                    .background(Palette.tileFill(.wifi), in: .rect(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("No code nearby?")
                        .font(.headline)
                    Text("Scan a sample Wi-Fi code instead.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button("Try a Sample", action: onTry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.onTint)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Palette.accent, in: .capsule)
                    .buttonStyle(.plain)
                    .fixedSize()
            }
            .padding(16)
            .lensGlass(.regular, in: .rect(cornerRadius: 24, style: .continuous))

            Button("Scan Later", action: onSkip)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
        }
    }
}

/// Shown when the camera is off, so the step still works.
private struct CameraOffNotice: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Camera access is off")
                .font(.headline)
            Text("You can still try the sample, or turn on the camera for Lunet in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
        .offset(y: -40)
    }
}

/// The sample code, as it would be printed on a café table tent.
struct SampleCodePlate: View {
    static let payload = "WIFI:T:WPA;S:Atlas Guest;P:espresso-2019;;"

    var body: some View {
        VStack(spacing: 8) {
            if let image = CodeRenderer.image(raw: Self.payload, symbology: .qr, dimension: 132) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 132, height: 132)
            }
            Text(verbatim: "ATLAS GUEST WI-FI")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(.black.opacity(0.7))
        }
        .padding(12)
        .background(.white, in: .rect(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(Text("Sample Wi-Fi code"))
    }
}

#Preview {
    FirstScanStep { _ in } onSkip: {}
        .environment(\.colorScheme, .dark)
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
