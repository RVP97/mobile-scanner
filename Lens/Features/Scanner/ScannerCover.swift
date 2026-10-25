import SwiftData
import SwiftUI

/// The camera, full screen, zoomed open out of Home's Scan lens (and back into it when it closes, or
/// follows the finger down when swiped away). A finger on the lens already starts the camera, so the
/// picture is live as it opens; the controls settle in after it, and the brackets land with a ripple.
/// On iPhone Duo, where the status bar is a column down one side, the controls stand in that column
/// and the camera has the rest of the display. The camera runs only while this is up, and it closes
/// itself after a while with nothing to read.
struct ScannerCover: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    @AppStorage(Pref.haptics) private var haptics = Pref.Default.haptics

    private var camera: ScannerCamera { model.camera }
    @State private var coordinator = ScanCoordinator()
    /// Settled in after the zoom: the controls are up and the scanner reads codes.
    @State private var isOpen = false
    /// Bumped when the brackets land in place after opening (the ripple).
    @State private var landings = 0
    @State private var isPickingPhoto = false
    /// Reset on every touch, so it's held by reference: as view state each reset redrew the scanner.
    @State private var idle = IdleClockBox()
    /// The countdown ring's fill during the last seconds, nil otherwise.
    @State private var countdown: Double?
    /// The cover lays out edge to edge, so it reads the safe area from the window: every side on its
    /// own, since on iPhone Duo the status bar is a column down one side.
    @State private var insets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
    /// iPhone Duo's status column, where the controls stand; nil for the usual top and bottom bars.
    @State private var railEdge: HorizontalEdge?
    /// Read when the scanner opens and when the pasteboard changes, never per frame (it's a call to
    /// another process).
    @State private var canScanPasteboard = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layout = Layout(size: size, insets: insets, railEdge: railEdge)
            ZStack {
                // Its own view: the tracked code moves every frame, and only this has to follow it.
                ScannerFeed(
                    camera: camera,
                    coordinator: coordinator,
                    layout: layout,
                    isOpen: isOpen,
                    detectionEnabled: detectionEnabled,
                    showsReticle: statusKind == nil,
                    landings: landings,
                    context: context,
                    onActivity: registerActivity
                )
                chrome(layout)
            }
        }
        .ignoresSafeArea()
        // Turning, or iPhone Duo opening and closing, moves the safe area.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in readInsets() }
        .onStatusColumnChange { edge in withAnimation(.smooth(duration: 0.3)) { railEdge = edge } }
        .environment(\.colorScheme, .dark)
        .background(.black)
        .sheet(item: sheet) { SheetContent(sheet: $0, overCamera: true) }
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in registerActivity() })
        .dropDestination(for: DroppedImage.self) { items, _ in
            guard let image = items.first else { return false }
            Task { await coordinator.importImage(image.data, context: context) }
            return true
        }
        .onAppear(perform: open)
        .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
            canScanPasteboard = UIPasteboard.general.hasImages
        }
        .onDisappear {
            camera.setActive(false)
            MultiScanActivity.end()
        }
        // iPhone Duo open (regular width) faces the person with the camera over the inner display.
        .onChange(of: sizeClass, initial: true) { _, size in camera.setDisplay(size == .regular ? .inner : .outer) }
        .onChange(of: cameraShouldRun, initial: true) { _, run in camera.setActive(run) }
        .onChange(of: detectionEnabled, initial: true) { _, enabled in coordinator.tracker.setPaused(!enabled) }
        .onChange(of: reduceMotion, initial: true) { _, value in coordinator.reduceMotion = value }
        .onChange(of: model.isMultiScanActive, initial: true) { _, active in
            if active { coordinator.tracker.clearChoices() }
            active ? MultiScanActivity.start() : MultiScanActivity.end()
        }
        .onChange(of: coordinator.tracker.choices.isEmpty) { registerActivity() }
        .onChange(of: coordinator.stage) { registerActivity() }
        .onChange(of: isIdlePaused, initial: true) { _, paused in
            paused ? idle.clock.pause(at: Self.now) : idle.clock.resume(at: Self.now)
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
        #if DEBUG
        .onChange(of: camera.status == .running, initial: true) { _, running in PerfWatchdog.mark("camera running \(running)") }
        #endif
        .sensoryFeedback(trigger: coordinator.lockFeedback) { _, _ in haptics ? .impact(weight: .medium) : nil }
        .sensoryFeedback(trigger: coordinator.captureFeedback) { _, _ in haptics ? .impact(weight: .light) : nil }
    }

    // MARK: Layout

    /// Where everything goes: the controls in a bar at the top and a row at the bottom, or (iPhone Duo)
    /// a rail down the status column; the reticle in the middle of what's left of the camera.
    struct Layout {
        var size: CGSize
        var insets: EdgeInsets
        var railEdge: HorizontalEdge?

        /// The rail stands inside the status column when it fits, otherwise beside it.
        var railInColumn: Bool { railColumn >= ScannerRail.width + 4 }

        private var railColumn: CGFloat { railEdge == .trailing ? insets.trailing : railEdge == .leading ? insets.leading : 0 }

        /// The rail's frame (the whole column, so its contents can line up with the clock).
        var railFrame: CGRect? {
            guard let railEdge else { return nil }
            let width = railInColumn ? railColumn : railColumn + ScannerRail.width + 16
            let top = railInColumn ? StatusColumn.clearance : max(insets.top, 12) + 12
            let bottom = max(insets.bottom, 16) + 8
            let x = railEdge == .trailing ? size.width - width : 0
            return CGRect(x: x, y: top, width: width, height: max(0, size.height - top - bottom))
        }

        /// The camera's open area, clear of the rail or the bars, where the reticle centers.
        var content: EdgeInsets {
            var room = insets
            if let rail = railFrame {
                if railEdge == .trailing { room.trailing = rail.width } else { room.leading = rail.width }
                room.bottom = max(insets.bottom, 16)
                room.top = max(insets.top, 16)
            } else {
                room.bottom = bottomRowCenter.y > 0 ? size.height - bottomRowCenter.y + 56 : insets.bottom
            }
            return room
        }

        /// Close, in the middle of the content's width, low over the camera (no rail).
        var bottomRowCenter: CGPoint {
            let midX = insets.leading + (size.width - insets.leading - insets.trailing) / 2
            return CGPoint(x: midX, y: size.height - max(insets.bottom, 16) - 62)
        }

        var idleQuad: Quad {
            let room = content
            let midX = room.leading + (size.width - room.leading - room.trailing) / 2
            return .idle(in: size, bottomInset: room.bottom, centerX: midX, insets: room)
        }
    }

    // MARK: State

    private var sheet: Binding<AppModel.Sheet?> {
        Binding(get: { model.sheet }, set: { model.sheet = $0 })
    }

    /// Live for as long as the cover is up, through the zoom back into the lens.
    private var cameraShouldRun: Bool {
        scenePhase != .background && !isPickingPhoto && model.sheet != .multiReview
    }

    private var detectionEnabled: Bool {
        isOpen && model.isScannerPresented && cameraShouldRun && model.sheet == nil
    }

    /// Time doesn't count toward closing while something else has the person's attention.
    private var isIdlePaused: Bool {
        model.sheet != nil || isPickingPhoto || !model.multiScanCodes.isEmpty || scenePhase != .active
    }

    private var context: ScanCoordinator.Context {
        ScanCoordinator.Context(model: model, modelContext: modelContext, openURL: openURL)
    }

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    // MARK: Opening

    private func open() {
        #if DEBUG
        PerfWatchdog.mark("cover appeared")
        #endif
        readInsets()
        let context = context
        let coordinator = coordinator
        camera.onCodes = { reads in coordinator.process(reads, context: context) }
        idle.clock = ScannerIdleClock(now: Self.now)
        countdown = nil
        canScanPasteboard = UIPasteboard.general.hasImages
        // The controls settle in as the zoom finishes, and the brackets land just after.
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.35).delay(0.18)) { isOpen = true }
        guard !reduceMotion else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(380))
            landings += 1
        }
    }

    private func readInsets() {
        guard let window = camera.window ?? UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
        let safe = window.safeAreaInsets
        let rtl = window.effectiveUserInterfaceLayoutDirection == .rightToLeft
        insets = EdgeInsets(top: safe.top, leading: rtl ? safe.right : safe.left, bottom: safe.bottom, trailing: rtl ? safe.left : safe.right)
    }

    // MARK: Idle

    private func registerActivity() {
        idle.clock.reset(at: Self.now)
        if countdown != nil { withAnimation(.snappy) { countdown = nil } }
    }

    private func watchIdleTime() async {
        guard isOpen else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(200))
            let now = Self.now
            if idle.clock.isExpired(at: now) {
                model.closeScanner()
                return
            }
            let next = idle.clock.isWarning(at: now) ? idle.clock.warningProgress(at: now) : nil
            if next != countdown {
                withAnimation(next == nil ? .snappy : .linear(duration: 0.2)) { countdown = next }
            }
        }
    }

    // MARK: Chrome

    private var controls: ScannerControls {
        ScannerControls(
            countdown: countdown,
            isMultiScanActive: Bindable(model).isMultiScanActive,
            canScanPasteboard: canScanPasteboard,
            canFlip: camera.canFlip,
            onClose: { model.closeScanner() },
            onPhotos: scanFromPhotos,
            onPasteboard: scanPasteboard,
            onFlip: camera.flip
        )
    }

    private func chrome(_ layout: Layout) -> some View {
        let showsControls = model.sheet == nil && coordinator.stage != .lifting
        let content = layout.content
        let rail = layout.railFrame
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 12) {
                if rail == nil {
                    ScannerTopBar(camera: camera)
                        // Under the status bar, or (iPhone Duo, status bar down the side) clear of the corner.
                        .padding(.top, max(insets.top, 12) + 8)
                }
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
                        .opacity(showsControls ? 1 : 0)
                        .allowsHitTesting(showsControls)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.top, rail == nil ? 0 : content.top)
            .padding(.leading, content.leading + 16)
            .padding(.trailing, content.trailing + 16)
            .padding(.bottom, rail == nil ? layout.size.height - layout.bottomRowCenter.y + ScannerBottomRow.closeDiameter / 2 + 20 : content.bottom + 8)
            .frame(width: layout.size.width, height: layout.size.height)
            .animation(.smooth(duration: 0.3), value: model.isMultiScanActive)
            .animation(.smooth(duration: 0.25), value: coordinator.tracker.choices.isEmpty)

            Group {
                if let rail {
                    ScannerRail(camera: camera, controls: controls)
                        .frame(width: layout.railInColumn ? rail.width : nil, height: rail.height)
                        .frame(width: rail.width)
                        .alignsWithStatusColumn()
                        .offset(x: rail.minX, y: rail.minY)
                        .transition(.move(edge: layout.railEdge == .trailing ? .trailing : .leading).combined(with: .opacity))
                } else {
                    ScannerBottomRow(controls: controls)
                        .position(layout.bottomRowCenter)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .opacity(showsControls ? 1 : 0)
            .allowsHitTesting(showsControls)
        }
        .animation(.smooth(duration: 0.25), value: showsControls)
        .opacity(isOpen ? 1 : 0)
        // Into the lens, the controls go first so only the picture shrinks back.
        .opacity(model.isScannerPresented ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: model.isScannerPresented)
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

private final class IdleClockBox {
    var clock = ScannerIdleClock(now: ProcessInfo.processInfo.systemUptime)
}

/// The camera and what's drawn over the code it sees: the reticle, choices, the lock and its lift into
/// the result. The tracked code moves every frame; kept apart from the cover, only this redraws then.
private struct ScannerFeed: View {
    var camera: ScannerCamera
    var coordinator: ScanCoordinator
    var layout: ScannerCover.Layout
    var isOpen: Bool
    var detectionEnabled: Bool
    var showsReticle: Bool
    var landings: Int
    var context: ScanCoordinator.Context
    var onActivity: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fraction of the screen the result sheet covers (`AppModel.resultDetent`).
    private let resultFraction: CGFloat = 0.62

    private var isShowingResult: Bool {
        if case .result = model.sheet { true } else { false }
    }

    var body: some View {
        let size = layout.size
        let lock = coordinator.lock
        let bottomInset = layout.content.bottom
        let idle = layout.idleQuad
        let tracked = coordinator.tracker.trackedQuad
        let choices = coordinator.stage == .searching && model.sheet == nil ? coordinator.tracker.choices : []
        ZStack(alignment: .topLeading) {
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
                .opacity(camera.status == .running ? 0 : 1)
                .animation(.easeOut(duration: 0.45), value: camera.status == .running)
                .allowsHitTesting(false)

            ScannerScrims(railEdge: layout.railEdge)

            if showsReticle {
                ReticleView(
                    quad: lock?.quad ?? tracked,
                    idle: idle,
                    tint: lock.map { $0.result.payload.kind.tint } ?? .white,
                    lineWidth: 4
                )
                .opacity(reticleOpacity(hasChoices: !choices.isEmpty))
                .animation(.smooth(duration: 0.2), value: coordinator.stage)
                .animation(.smooth(duration: 0.2), value: choices.isEmpty)
                .animation(.smooth(duration: 0.3), value: idle)
            }

            if showsReticle && !reduceMotion {
                LandingRipple(quad: idle, trigger: landings)
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
        .onChange(of: tracked != nil) { _, seen in if seen { onActivity() } }
    }

    private func reticleOpacity(hasChoices: Bool) -> Double {
        if hasChoices || coordinator.stage == .lifting { return 0 }
        // While opening and closing the brackets are part of the zoom (the lens draws them too).
        if !isOpen || !model.isScannerPresented { return 1 }
        return !detectionEnabled && coordinator.lock == nil ? 0 : 1
    }

    /// Where the result sheet's header tile lands.
    private func liftDestination(in size: CGSize) -> CGRect {
        let sheetTop = size.height * (1 - resultFraction)
        return CGRect(x: 28, y: sheetTop + 20, width: 52, height: 52)
    }
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

/// Keeps glass controls legible over bright scenes without tinting the view: across the top and
/// bottom, or down the rail's side on iPhone Duo.
private struct ScannerScrims: View {
    var railEdge: HorizontalEdge?

    var body: some View {
        Group {
            if let railEdge {
                let trailing = railEdge == .trailing
                LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: trailing ? .trailing : .leading, endPoint: trailing ? .leading : .trailing)
                    .frame(width: 200)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: trailing ? .trailing : .leading)
            } else {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 180)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 320)
                }
            }
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
