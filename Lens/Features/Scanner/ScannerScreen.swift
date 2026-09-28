import SwiftData
import SwiftUI

/// Home: the full-bleed camera under the app's persistent sheet, with minimal floating controls.
struct ScannerScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(Pref.onboardingDone) private var onboardingDone = false
    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics

    @State private var camera = ScannerCamera()
    @State private var coordinator = ScanCoordinator()

    /// Height of the sheet's peek detent; floating controls sit above it.
    private let sheetPeek: CGFloat = 132
    /// Fraction of the screen the result sheet covers (`AppModel.resultDetent`).
    private let resultFraction: CGFloat = 0.62

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                cameraLayer(size: proxy.size)
            }
            .ignoresSafeArea()

            chrome
        }
        .background(.black)
        .environment(\.colorScheme, .dark)
        .dropDestination(for: DroppedImage.self) { items, _ in
            guard let image = items.first else { return false }
            Task { await coordinator.importImage(image.data, context: context) }
            return true
        }
        .onAppear(perform: setUp)
        .onChange(of: cameraShouldRun, initial: true) { _, run in
            camera.setActive(run)
        }
        .onChange(of: detectionEnabled, initial: true) { _, enabled in
            coordinator.tracker.setPaused(!enabled)
        }
        .onChange(of: reduceMotion, initial: true) { _, value in
            coordinator.reduceMotion = value
        }
        .onChange(of: model.isMultiScanActive) { _, active in
            if active {
                MultiScanActivity.start()
            } else {
                MultiScanActivity.end()
                if model.sheetContent != .multiReview { model.multiScanCodes.removeAll() }
            }
        }
        .sensoryFeedback(trigger: coordinator.lockFeedback) { _, _ in
            haptics ? .impact(weight: .medium) : nil
        }
        .sensoryFeedback(trigger: coordinator.captureFeedback) { _, _ in
            haptics ? .impact(weight: .light) : nil
        }
    }

    // MARK: State

    private var isShowingResult: Bool {
        if case .result = model.sheetContent { true } else { false }
    }

    /// The camera runs only when someone can see it: not during onboarding, in the background, behind a
    /// modal, or while the sheet covers the screen.
    private var cameraShouldRun: Bool {
        onboardingDone
            && scenePhase != .background
            && !model.cameraPaused
            && model.modal == nil
            && model.detent != .large
    }

    private var detectionEnabled: Bool {
        cameraShouldRun && model.sheetContent == .home
    }

    private var context: ScanCoordinator.Context {
        ScanCoordinator.Context(model: model, modelContext: modelContext, openURL: openURL)
    }

    private func setUp() {
        let context = context
        let coordinator = coordinator
        camera.onCodes = { reads in coordinator.process(reads, context: context) }
        if Pref.bool(Pref.multiScan, default: Pref.Default.multiScan), !model.isMultiScanActive {
            model.isMultiScanActive = true
        }
    }

    // MARK: Camera layer (full screen, preview-layer coordinates)

    private func cameraLayer(size: CGSize) -> some View {
        let lock = coordinator.lock
        return ZStack(alignment: .topLeading) {
            CameraPreview(camera: camera)
                .onTapGesture(coordinateSpace: .local) { camera.focus(at: $0) }
                .gesture(
                    MagnifyGesture()
                        .onChanged { camera.pinch(by: $0.magnification) }
                        .onEnded { _ in camera.endPinch() }
                )
                .accessibilityLabel("Camera")
                .accessibilityHint("Point at a QR code or barcode to scan it.")
                .accessibilityAddTraits(.allowsDirectInteraction)

            ScannerScrims()

            if camera.status == .running {
                ReticleView(
                    quad: lock?.quad ?? coordinator.tracker.trackedQuad,
                    idle: .idle(in: size, bottomInset: sheetPeek),
                    tint: lock.map { $0.result.payload.kind.tint } ?? .white
                )
                .opacity(coordinator.stage == .lifting || !detectionEnabled && lock == nil ? 0 : 1)
                .animation(.smooth(duration: 0.2), value: coordinator.stage)
            }

            if let mark = camera.focusMark {
                FocusMarkView()
                    .id(mark.id)
                    .position(mark.point)
            }

            if let lock, coordinator.stage == .locked {
                LockChip(payload: lock.result.payload)
                    .position(LockChip.position(for: lock.quad, in: size, bottomInset: sheetPeek))
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            if let lock, coordinator.stage == .lifting {
                LiftingCode(
                    kind: lock.result.payload.kind,
                    codeImage: lock.codeImage,
                    source: lock.quad,
                    destination: liftDestination(in: size)
                )
            }

            Color.black
                .opacity(isShowingResult ? 0.35 : 0)
                .allowsHitTesting(false)
                .animation(.smooth(duration: 0.3), value: isShowingResult)
        }
        .frame(width: size.width, height: size.height)
    }

    /// Where the result sheet's header tile lands.
    private func liftDestination(in size: CGSize) -> CGRect {
        let sheetTop = size.height * (1 - resultFraction)
        return CGRect(x: 28, y: sheetTop + 24, width: 56, height: 56)
    }

    // MARK: Chrome (safe-area aware)

    private var chrome: some View {
        VStack(spacing: 12) {
            ScannerTopBar(
                camera: camera,
                isMultiScanActive: Bindable(model).isMultiScanActive,
                onCreate: { model.modal = .create },
                onScanPhotos: scanFromPhotos,
                onScanPasteboard: scanPasteboard,
                onSettings: { model.modal = .settings }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if let toast = coordinator.toast {
                ScannerToast(toast: toast)
                    .id(toast.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer(minLength: 0)

            if let status = statusKind {
                CameraStatusView(kind: status, onOpenSettings: openSettings, onScanPhotos: scanFromPhotos)
                Spacer(minLength: 0)
            }

            bottomControls
                .padding(.horizontal, 16)
                .padding(.bottom, sheetPeek + 12)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var bottomControls: some View {
        let showsControls = model.sheetContent == .home && coordinator.stage != .lifting
        VStack(spacing: 16) {
            if model.isMultiScanActive {
                MultiScanTray(codes: model.multiScanCodes, onDone: openMultiReview)
            }
            if let profile = camera.capabilities?.zoom, !profile.presets.isEmpty, camera.status == .running {
                ZoomCapsule(profile: profile, zoom: camera.displayZoom) { camera.setZoom($0) }
            }
        }
        .opacity(showsControls ? 1 : 0)
        .allowsHitTesting(showsControls)
        .animation(.smooth(duration: 0.25), value: showsControls)
    }

    private var statusKind: CameraStatusView.Kind? {
        guard onboardingDone else { return nil }
        switch camera.access {
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return nil
        case .authorized: break
        }
        switch camera.status {
        case .unavailable: return .unavailable
        case .interrupted(let reason): return .interrupted(reason)
        case .idle, .running: return nil
        }
    }

    // MARK: Actions

    private func openMultiReview() {
        withAnimation(.smooth(duration: 0.35)) {
            model.sheetContent = .multiReview
            model.detent = .large
        }
    }

    private func scanFromPhotos() {
        Task {
            guard let data = await PhotoImport.pickImage(from: camera.window) else { return }
            await coordinator.importImage(data, context: context)
        }
    }

    private func scanPasteboard() {
        guard let data = UIPasteboard.general.image?.pngData() else { return }
        Task { await coordinator.importImage(data, context: context) }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

/// Keeps glass controls legible over bright scenes without tinting the view.
private struct ScannerScrims: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 180)
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .frame(height: 280)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Scanner") {
    ScannerScreen()
        .environment(AppModel())
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
#endif
