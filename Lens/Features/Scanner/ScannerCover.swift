import SwiftData
import SwiftUI

/// The camera, full screen, opened from Home's Scan lens: the lens circle widens into the viewfinder
/// and closes back into it. The camera runs only while this is up, and it closes itself after a
/// while with nothing to read.
struct ScannerCover: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics

    @State private var camera = ScannerCamera()
    @State private var coordinator = ScanCoordinator()
    @State private var isOpen = false
    @State private var isPickingPhoto = false
    @State private var idleClock = ScannerIdleClock(now: ScannerCover.now)
    /// The countdown ring's fill during the last seconds, nil otherwise.
    @State private var countdown: Double?
    /// The cover lays out edge to edge, so it reads the status bar's height from the window.
    @State private var topInset: CGFloat = 59

    /// Fraction of the screen the result sheet covers (`AppModel.resultDetent`).
    private let resultFraction: CGFloat = 0.62
    private static let closeDiameter = ScannerBottomRow.closeDiameter

    var body: some View {
        GeometryReader { proxy in
            let screen = proxy.frame(in: .global)
            let anchor = closeCenter(in: screen)
            ZStack {
                cameraLayer(size: screen.size, controlsTop: anchor.y - 64)
                chrome(anchor: anchor)
            }
            .mask { reveal(anchor: anchor, in: screen.size) }
            .opacity(reduceMotion && !isOpen ? 0 : 1)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .presentationBackground(.clear)
        .sheet(item: sheet) { SheetContent(sheet: $0, overCamera: true) }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in registerActivity() })
        .dropDestination(for: DroppedImage.self) { items, _ in
            guard let image = items.first else { return false }
            Task { await coordinator.importImage(image.data, context: context) }
            return true
        }
        .onAppear(perform: open)
        .onDisappear {
            camera.setActive(false)
            MultiScanActivity.end()
        }
        .onChange(of: model.isScannerClosing) { _, closing in
            closing ? close() : open()
        }
        .onChange(of: cameraShouldRun, initial: true) { _, run in camera.setActive(run) }
        .onChange(of: detectionEnabled, initial: true) { _, enabled in coordinator.tracker.setPaused(!enabled) }
        .onChange(of: reduceMotion, initial: true) { _, value in coordinator.reduceMotion = value }
        .onChange(of: model.isMultiScanActive, initial: true) { _, active in
            active ? MultiScanActivity.start() : MultiScanActivity.end()
        }
        .onChange(of: coordinator.tracker.trackedQuad != nil) { _, seen in if seen { registerActivity() } }
        .onChange(of: coordinator.stage) { registerActivity() }
        .onChange(of: isIdlePaused, initial: true) { _, paused in
            paused ? idleClock.pause(at: Self.now) : idleClock.resume(at: Self.now)
        }
        .task(id: isOpen) { await watchIdleTime() }
        .sensoryFeedback(trigger: coordinator.lockFeedback) { _, _ in haptics ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: coordinator.captureFeedback) { _, _ in haptics ? .impact(weight: .light) : nil }
    }

    // MARK: State

    private var sheet: Binding<AppModel.Sheet?> {
        Binding(get: { model.sheet }, set: { model.sheet = $0 })
    }

    private var isShowingResult: Bool {
        if case .result = model.sheet { true } else { false }
    }

    private var cameraShouldRun: Bool {
        isOpen && scenePhase != .background && !isPickingPhoto && model.sheet != .multiReview
    }

    private var detectionEnabled: Bool {
        cameraShouldRun && model.sheet == nil
    }

    /// Time doesn't count toward closing while something else has the person's attention.
    private var isIdlePaused: Bool {
        model.sheet != nil || isPickingPhoto || !model.multiScanCodes.isEmpty || scenePhase != .active
    }

    private var context: ScanCoordinator.Context {
        ScanCoordinator.Context(model: model, modelContext: modelContext, openURL: openURL)
    }

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Close sits exactly where Home's Scan lens was.
    private func closeCenter(in screen: CGRect) -> CGPoint {
        if let lens = model.lensFrame, screen.contains(CGPoint(x: lens.midX, y: lens.midY)) {
            return CGPoint(x: lens.midX - screen.minX, y: lens.midY - screen.minY)
        }
        return CGPoint(x: screen.width / 2, y: screen.height - 150)
    }

    // MARK: Opening and closing

    private func open() {
        if let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first {
            topInset = window.safeAreaInsets.top
        }
        let context = context
        let coordinator = coordinator
        camera.onCodes = { reads in coordinator.process(reads, context: context) }
        idleClock = ScannerIdleClock(now: Self.now)
        countdown = nil
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.42)) { isOpen = true }
    }

    private func close() {
        withAnimation(reduceMotion ? .easeIn(duration: 0.18) : .smooth(duration: 0.34)) {
            isOpen = false
        } completion: {
            model.scannerDidClose()
        }
    }

    /// A circle that grows out of the lens until it covers the screen.
    private func reveal(anchor: CGPoint, in size: CGSize) -> some View {
        let farthest = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            .map { hypot($0.x - anchor.x, $0.y - anchor.y) }
            .max() ?? 0
        let diameter = reduceMotion || isOpen ? farthest * 2 : Self.closeDiameter
        return Circle()
            .frame(width: diameter, height: diameter)
            .position(anchor)
    }

    // MARK: Idle

    private func registerActivity() {
        idleClock.reset(at: Self.now)
        if countdown != nil { withAnimation(.snappy) { countdown = nil } }
    }

    private func watchIdleTime() async {
        guard isOpen else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(200))
            let now = Self.now
            if idleClock.isExpired(at: now) {
                model.closeScanner()
                return
            }
            let next = idleClock.isWarning(at: now) ? idleClock.warningProgress(at: now) : nil
            if next != countdown {
                withAnimation(next == nil ? .snappy : .linear(duration: 0.2)) { countdown = next }
            }
        }
    }

    // MARK: Camera layer (full screen, preview-layer coordinates)

    private func cameraLayer(size: CGSize, controlsTop: CGFloat) -> some View {
        let lock = coordinator.lock
        let bottomInset = max(0, size.height - controlsTop)
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
                    idle: .idle(in: size, bottomInset: bottomInset),
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
                    .position(LockChip.position(for: lock.quad, in: size, bottomInset: bottomInset))
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
        .background { ScannerBackdrop(size: size) }
    }

    /// Where the result sheet's header tile lands.
    private func liftDestination(in size: CGSize) -> CGRect {
        let sheetTop = size.height * (1 - resultFraction)
        return CGRect(x: 28, y: sheetTop + 20, width: 52, height: 52)
    }

    // MARK: Chrome

    private func chrome(anchor: CGPoint) -> some View {
        let showsControls = model.sheet == nil && coordinator.stage != .lifting
        return ZStack {
            GeometryReader { proxy in
                VStack(spacing: 12) {
                    ScannerTopBar(camera: camera)
                        .padding(.horizontal, 16)
                        .padding(.top, topInset + 8)
                    if let toast = coordinator.toast {
                        ScannerToast(toast: toast)
                            .id(toast.id)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                    if let status = statusKind {
                        CameraStatusView(kind: status, onOpenSettings: openSystemSettings, onScanPhotos: scanFromPhotos)
                            .opacity(model.sheet == nil ? 1 : 0)
                        Spacer(minLength: 0)
                    }
                    if model.isMultiScanActive {
                        MultiScanTray(codes: model.multiScanCodes) { model.sheet = .multiReview }
                            .padding(.horizontal, 16)
                            .opacity(showsControls ? 1 : 0)
                            .allowsHitTesting(showsControls)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.smooth(duration: 0.3), value: model.isMultiScanActive)
                .padding(.bottom, max(0, proxy.size.height - anchor.y + Self.closeDiameter / 2 + 20))
            }

            ScannerBottomRow(
                countdown: countdown,
                isMultiScanActive: Bindable(model).isMultiScanActive,
                canScanPasteboard: UIPasteboard.general.hasImages,
                canFlip: camera.canFlip,
                onClose: { model.closeScanner() },
                onPhotos: scanFromPhotos,
                onPasteboard: scanPasteboard,
                onFlip: camera.flip
            )
            .position(anchor)
            .opacity(showsControls ? 1 : 0)
            .allowsHitTesting(showsControls)
        }
        .animation(.smooth(duration: 0.25), value: showsControls)
        .opacity(isOpen ? 1 : 0)
        .animation(isOpen ? .smooth(duration: 0.3).delay(0.15) : .easeOut(duration: 0.12), value: isOpen)
    }

    private var statusKind: CameraStatusView.Kind? {
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

    private func scanFromPhotos() {
        isPickingPhoto = true
        Task {
            let data = await PhotoImport.pickImage(from: camera.window)
            isPickingPhoto = false
            guard let data else { return }
            await coordinator.importImage(data, context: context)
        }
    }

    private func scanPasteboard() {
        guard let data = UIPasteboard.general.image?.pngData() else { return }
        Task { await coordinator.importImage(data, context: context) }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

/// What shows before the first frame, or when there's no camera: a deep lens-blue glow, not a void.
private struct ScannerBackdrop: View {
    var size: CGSize

    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Color(hex: 0x0E2A3A), Color(hex: 0x05121A).opacity(0.6), .clear],
                center: UnitPoint(x: 0.5, y: 0.4),
                startRadius: 0,
                endRadius: max(size.width, size.height) * 0.6
            )
        }
        .ignoresSafeArea()
    }
}

/// Keeps glass controls legible over bright scenes without tinting the view.
private struct ScannerScrims: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 180)
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A result or the multi-scan review, in the sheet over Home or over the camera.
struct SheetContent: View {
    let sheet: AppModel.Sheet
    var overCamera = false

    var body: some View {
        Group {
            switch sheet {
            case .result(let result):
                ResultView(result: result, offersScanAnother: overCamera)
                    .id(result.id)
                    .presentationDetents([AppModel.resultDetent, .large])
            case .multiReview:
                MultiScanReview()
                    .presentationDetents([.medium, .large])
            }
        }
        .presentationDragIndicator(.visible)
        .modifier(CameraSheetSurface(isOverCamera: overCamera))
    }
}

/// Light glass over a dark camera reads as muddy grey, so there the sheet gets a solid surface.
private struct CameraSheetSurface: ViewModifier {
    var isOverCamera: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if isOverCamera && colorScheme == .light {
            content.presentationBackground(Color(.systemBackground))
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("Scanner") {
    ScannerCover()
        .environment(AppModel())
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
#endif
