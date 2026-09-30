import SwiftData
import SwiftUI

/// The camera, full screen, opened from Home's Scan lens. A finger on the lens already starts the
/// camera and turns the lens's glass into a window onto it; letting go opens that window out to the
/// whole screen while Home sinks back, and the brackets in the lens fly out and snap into the reticle
/// with a ripple and a click. The picture itself never moves, only the window around it. Closing
/// folds the window back into the lens, which catches it. The camera runs only while this is up, and it closes itself after a
/// while with nothing to read.
struct ScannerCover: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Home's appearance, kept while the scanner is still just the lens (so the status bar doesn't flip).
    @Environment(\.colorScheme) private var outerColorScheme

    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics

    private var camera: ScannerCamera { model.camera }
    @State private var coordinator = ScanCoordinator()
    @State private var isOpen = false
    /// The first camera frame is up, so the feed can fade in rather than pop.
    @State private var isFeedLive = false
    /// Bumped when the brackets land in place after opening (the ripple).
    @State private var landings = 0
    /// Closing, until this cover is gone (outlasts `isScannerClosing`, which resets a frame early).
    @State private var isFoldingAway = false
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
                cameraLayer(size: screen.size, controlsTop: anchor.y - 64, anchor: anchor)
                chrome(anchor: anchor)
            }
            .mask { reveal(anchor: anchor, in: screen.size) }
            .overlay {
                if !reduceMotion {
                    LensEdge(
                        diameter: revealDiameter(anchor: anchor, in: screen.size),
                        closedDiameter: Self.glassDiameter,
                        openDiameter: farthestReach(from: anchor, in: screen.size) * 2
                    )
                    .position(anchor)
                }
            }
            // Closing, the window melts into the real lens over its last stretch instead of cutting.
            .modifier(MeltIntoLens(
                diameter: revealDiameter(anchor: anchor, in: screen.size),
                closedDiameter: Self.glassDiameter,
                openDiameter: farthestReach(from: anchor, in: screen.size) * 2,
                isActive: isFoldingAway && !reduceMotion
            ))
            .opacity(reduceMotion && !isOpen ? 0 : 1)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, isOpen ? .dark : outerColorScheme)
        .presentationBackground(.clear)
        .sheet(item: sheet) { SheetContent(sheet: $0, overCamera: true) }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in registerActivity() })
        .dropDestination(for: DroppedImage.self) { items, _ in
            guard let image = items.first else { return false }
            Task { await coordinator.importImage(image.data, context: context) }
            return true
        }
        .onAppear {
            prepare()
            if !model.isPeeking { expand() }
        }
        .onDisappear {
            camera.setActive(false)
            MultiScanActivity.end()
        }
        .onChange(of: model.isScannerClosing) { _, closing in
            // Reopened mid-close. (Not when the cover is going away: that used to replay the opening.)
            if closing { close() } else if model.isScannerPresented { expand() }
        }
        .onChange(of: model.isPeeking) { _, peeking in
            if !peeking && model.isScannerPresented && !model.isScannerClosing { expand() }
        }
        .onChange(of: cameraShouldRun, initial: true) { _, run in camera.setActive(run) }
        .onChange(of: detectionEnabled, initial: true) { _, enabled in coordinator.tracker.setPaused(!enabled) }
        .onChange(of: reduceMotion, initial: true) { _, value in coordinator.reduceMotion = value }
        .onChange(of: model.isMultiScanActive, initial: true) { _, active in
            if active { coordinator.tracker.clearChoices() }
            active ? MultiScanActivity.start() : MultiScanActivity.end()
        }
        .onChange(of: coordinator.tracker.trackedQuad != nil) { _, seen in if seen { registerActivity() } }
        .onChange(of: coordinator.tracker.choices.isEmpty) { registerActivity() }
        .onChange(of: coordinator.stage) { registerActivity() }
        .onChange(of: isIdlePaused, initial: true) { _, paused in
            paused ? idleClock.pause(at: Self.now) : idleClock.resume(at: Self.now)
        }
        .task(id: isOpen) { await watchIdleTime() }
        #if DEBUG
        .task(id: isOpen) {
            guard isOpen, QAHarness.feedsTwoCodes else { return }
            while !Task.isCancelled {
                coordinator.process(QAHarness.twoCodeFrame, context: context)
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        #endif
        .onChange(of: camera.status == .running, initial: true) { _, running in
            withAnimation(.easeOut(duration: 0.45)) { isFeedLive = running }
        }
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

    /// Live from the finger landing on the lens until the window has folded all the way back into it.
    private var cameraShouldRun: Bool {
        (isOpen || model.isPeeking || model.isScannerClosing) && scenePhase != .background && !isPickingPhoto && model.sheet != .multiReview
    }

    private var detectionEnabled: Bool {
        isOpen && cameraShouldRun && model.sheet == nil
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

    private func prepare() {
        if let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first {
            topInset = window.safeAreaInsets.top
        }
        let context = context
        let coordinator = coordinator
        camera.onCodes = { reads in coordinator.process(reads, context: context) }
        idleClock = ScannerIdleClock(now: Self.now)
        countdown = nil
    }

    private func expand() {
        isFoldingAway = false
        guard !isOpen else { return }
        idleClock = ScannerIdleClock(now: Self.now)
        if !reduceMotion { LensHaptics.shared.open() }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Self.openAnimation) {
            isOpen = true
            model.isScannerRevealed = true
        }
        guard !reduceMotion else { return }
        // The brackets land a beat after the lens fills the screen.
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            if isOpen { landings += 1 }
        }
    }

    private func close() {
        isFoldingAway = true
        if !reduceMotion { LensHaptics.shared.close() }
        withAnimation(reduceMotion ? .easeIn(duration: 0.18) : Self.closeAnimation) {
            isOpen = false
            model.isScannerRevealed = false
        } completion: {
            model.scannerDidClose()
            if !reduceMotion { LensHaptics.shared.settle() }
        }
    }

    /// Quick off the lens, then a long settle as the edge sweeps past the corners.
    private static let openAnimation = Animation.spring(response: 0.55, dampingFraction: 0.86)
    private static let closeAnimation = Animation.spring(response: 0.42, dampingFraction: 0.92)
    /// The lens's glass, inside its colored rim, so the real rim frames the hand-off both ways.
    private static let glassDiameter = ScanLensButton.defaultDiameter - 2 * ScanLensButton.rimWidth

    /// The window onto the camera: the lens's glass, opening out past the screen's far corner.
    private func reveal(anchor: CGPoint, in size: CGSize) -> some View {
        let diameter = revealDiameter(anchor: anchor, in: size)
        return Circle()
            .frame(width: diameter, height: diameter)
            .position(anchor)
    }

    private func revealDiameter(anchor: CGPoint, in size: CGSize) -> CGFloat {
        if reduceMotion || isOpen { return farthestReach(from: anchor, in: size) * 2 }
        // Under a finger the lens is pressed in, and the window with it.
        return Self.glassDiameter * (model.isPeeking ? LensFace.pressedScale : 1)
    }

    private func farthestReach(from anchor: CGPoint, in size: CGSize) -> CGFloat {
        [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            .map { hypot($0.x - anchor.x, $0.y - anchor.y) }
            .max() ?? 0
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

    private func cameraLayer(size: CGSize, controlsTop: CGFloat, anchor: CGPoint) -> some View {
        let lock = coordinator.lock
        let bottomInset = max(0, size.height - controlsTop)
        let choices = coordinator.stage == .searching && model.sheet == nil ? coordinator.tracker.choices : []
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

            // Until the first frame: the backdrop, then the feed fades up through it.
            ScannerBackdrop(size: size)
                .opacity(isFeedLive ? 0 : 1)
                .allowsHitTesting(false)

            ScannerScrims()

            if statusKind == nil {
                ReticleView(
                    quad: lock?.quad ?? coordinator.tracker.trackedQuad,
                    // Closed, the brackets sit where the Scan lens draws them.
                    idle: isOpen ? .idle(in: size, bottomInset: bottomInset) : ScanLensButton.glyphQuad(around: anchor, pressed: model.isPeeking),
                    tint: lock.map { $0.result.payload.kind.tint } ?? .white,
                    // In the lens, the brackets have the lens glyph's weight.
                    lineWidth: isOpen || reduceMotion ? 4 : 3.4
                )
                .opacity(reticleOpacity(hasChoices: !choices.isEmpty))
                .animation(.smooth(duration: 0.2), value: coordinator.stage)
                .animation(.smooth(duration: 0.2), value: choices.isEmpty)
            }

            if statusKind == nil && !reduceMotion {
                LandingRipple(quad: .idle(in: size, bottomInset: bottomInset), trigger: landings)
            }

            if !choices.isEmpty {
                CodeChoicePins(choices: choices) { coordinator.choose($0, context: context) }
                    .transition(.opacity)
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

    private func reticleOpacity(hasChoices: Bool) -> Double {
        if hasChoices || coordinator.stage == .lifting { return 0 }
        // While opening and closing the brackets are part of the transition.
        if !isOpen || model.isScannerClosing { return 1 }
        return !detectionEnabled && coordinator.lock == nil ? 0 : 1
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
                    if !coordinator.tracker.choices.isEmpty && coordinator.stage == .searching && model.sheet == nil {
                        ChoiceHint()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
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
                .animation(.smooth(duration: 0.25), value: coordinator.tracker.choices.isEmpty)
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
        #if DEBUG
        if QAHarness.fakesCamera { return nil }
        #endif
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

/// The rim of the opening window: a glass hairline and a soft shadow that lifts the camera above
/// Home. Strong at the lens, gone by the time the edge nears the corners. It follows the window's own
/// animated diameter, so it never drifts from the edge.
private struct LensEdge: View, Animatable {
    var diameter: CGFloat
    var closedDiameter: CGFloat
    var openDiameter: CGFloat

    var animatableData: CGFloat {
        get { diameter }
        set { diameter = newValue }
    }

    /// How far the shadow reaches out over Home.
    private let shadowReach: CGFloat = 26

    var body: some View {
        let t = lensProgress(diameter, closed: closedDiameter, open: openDiameter)
        let fade = 1 - smoothstep(t, from: 0.1, to: 0.6)
        let radius = diameter / 2
        let outer = radius + shadowReach
        ZStack {
            // A soft shadow just outside the edge, as a gradient (no blur pass on a screen-sized layer).
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: max(0, (radius - 1) / outer)),
                        .init(color: .black.opacity(0.28), location: radius / outer),
                        .init(color: .clear, location: 1),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: outer
                ))
                .frame(width: outer * 2, height: outer * 2)
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.12), .white.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.5
                )
                .frame(width: diameter, height: diameter)
        }
        .opacity(t > 0.001 ? fade : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Fades the whole scanner out as its window closes the last stretch into the Scan lens, so the real
/// lens (rim, glyph, "Scan") shows through and takes over without a cut.
private struct MeltIntoLens: ViewModifier, Animatable {
    var diameter: CGFloat
    var closedDiameter: CGFloat
    var openDiameter: CGFloat
    var isActive: Bool

    var animatableData: CGFloat {
        get { diameter }
        set { diameter = newValue }
    }

    func body(content: Content) -> some View {
        let t = lensProgress(diameter, closed: closedDiameter, open: openDiameter)
        content.opacity(isActive ? smoothstep(t, from: 0.005, to: 0.1) : 1)
    }
}

/// 0 with the window in the lens, 1 with it past the screen's far corner.
private func lensProgress(_ diameter: CGFloat, closed: CGFloat, open: CGFloat) -> CGFloat {
    min(max((diameter - closed) / max(open - closed, 1), 0), 1)
}

private func smoothstep(_ x: CGFloat, from a: CGFloat, to b: CGFloat) -> CGFloat {
    let u = min(max((x - a) / (b - a), 0), 1)
    return u * u * (3 - 2 * u)
}

/// The brackets landing: a soft light ring that leaves the reticle and fades, like a drop in water.
private struct LandingRipple: View {
    var quad: Quad
    var trigger: Int

    var body: some View {
        let box = quad.expanded(by: 10).boundingBox
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(.white, lineWidth: 2)
            .frame(width: box.width, height: box.height)
            .keyframeAnimator(initialValue: Ripple(), trigger: trigger) { content, ripple in
                content
                    .scaleEffect(ripple.scale)
                    .opacity(ripple.opacity)
                    .blur(radius: ripple.blur)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1, duration: 0)
                    CubicKeyframe(1.55, duration: 0.7)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.9, duration: 0)
                    CubicKeyframe(0, duration: 0.7)
                }
                KeyframeTrack(\.blur) {
                    LinearKeyframe(0, duration: 0)
                    CubicKeyframe(6, duration: 0.7)
                }
            }
            .position(x: box.midX, y: box.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private struct Ripple {
        var scale: CGFloat = 1
        var opacity: Double = 0
        var blur: CGFloat = 0
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
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            switch sheet {
            case .result(let result):
                ResultView(result: result, offersScanAnother: overCamera)
                    .id(result.id)
                    .presentationDetents(resultDetents)
            case .multiReview:
                MultiScanReview()
                    .presentationDetents([.medium, .large])
            }
        }
        .presentationDragIndicator(.visible)
        // On iPad, room for a whole result; the default form sheet would cut a flagged link short.
        .pageSizedSheet()
        .modifier(CameraSheetSurface(isOverCamera: overCamera))
    }

    private var resultDetents: Set<PresentationDetent> {
        #if DEBUG
        if QAHarness.opensSheetsLarge { return [.large] }
        #endif
        // On iPad the sheet is already sized to the page; a fraction of it would cut the result short.
        return sizeClass == .regular ? [.large] : [AppModel.resultDetent, .large]
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
