@preconcurrency import AVFoundation
import Observation
import SwiftUI

/// The live camera as the UI sees it: permission, lifecycle, torch, zoom, focus, and codes mapped to
/// screen space. Session work runs on `CaptureEngine`'s queue; this type only coordinates.
@Observable
final class ScannerCamera {
    enum Access: Equatable {
        case notDetermined, authorized, denied, restricted
    }

    enum Status: Equatable {
        case idle
        case running
        case interrupted(Interruption)
        /// No usable camera (Simulator, or the hardware refused to configure).
        case unavailable
    }

    enum Interruption: Equatable {
        case inUseByAnotherApp, multitasking, systemPressure, other
    }

    /// A tap-to-focus mark, drawn briefly where the user tapped.
    struct FocusMark: Equatable, Identifiable {
        let id = UUID()
        let point: CGPoint
    }

    private(set) var access: Access = ScannerCamera.currentAccess()
    private(set) var status: Status = .idle
    private(set) var capabilities: CameraCapabilities?
    private(set) var displayZoom: CGFloat = 1
    private(set) var isTorchOn = false
    private(set) var position: AVCaptureDevice.Position = .back
    private(set) var focusMark: FocusMark?
    /// The display the scanner is on (iPhone Duo open or closed), for the camera that faces the person.
    private(set) var display: CameraDisplay = .outer

    /// Every frame's codes, in the preview view's coordinate space. Empty when codes leave the frame.
    @ObservationIgnored var onCodes: ([CodeRead]) -> Void = { _ in }

    @ObservationIgnored private let engine = CaptureEngine()
    @ObservationIgnored private var relay: MetadataRelay?
    @ObservationIgnored private weak var preview: PreviewView?
    @ObservationIgnored private var wantsRunning = false
    @ObservationIgnored private var configured: (position: AVCaptureDevice.Position, display: CameraDisplay)?
    @ObservationIgnored private var reconcileTask: Task<Void, Never>?
    @ObservationIgnored private var pinchBase: CGFloat?

    init() {
        let events = engine.events
        Task { [weak self] in
            for await event in events {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    /// The window hosting the preview, for presenting UIKit pickers above the app's sheets.
    var window: UIWindow? { preview?.window }

    var canFlip: Bool { Self.hasBothCameras }

    private static let hasBothCameras = CaptureEngine.bestDevice(for: .front, display: .outer) != nil
        && CaptureEngine.bestDevice(for: .back, display: .outer) != nil

    // MARK: Lifecycle

    /// Starts or stops the camera. Calls are serialized, so rapid toggles settle on the last request.
    func setActive(_ active: Bool) {
        wantsRunning = active
        reconcile()
    }

    /// Sets the camera up without starting it, so opening the scanner only has to start the feed. Only
    /// with access already granted: this never asks, and nothing records (no camera indicator).
    func prewarm() {
        guard Self.currentAccess() == .authorized, configured == nil, !wantsRunning else { return }
        reconcile()
    }

    /// Follows iPhone Duo opening and closing: facing the person, the camera over the display in use.
    func setDisplay(_ display: CameraDisplay) {
        guard display != self.display else { return }
        self.display = display
        if position == .front { reconcile() }
    }

    func connect(_ view: PreviewView) {
        preview = view
        attachPreview()
    }

    func refreshAccess() {
        access = Self.currentAccess()
    }

    func flip() {
        position = position == .back ? .front : .back
        isTorchOn = false
        reconcile()
    }

    private func reconcile() {
        let previous = reconcileTask
        reconcileTask = Task {
            await previous?.value
            await reconcileOnce()
        }
    }

    private func reconcileOnce() async {
        guard wantsRunning else {
            await engine.stop()
            if status != .unavailable { status = .idle }
            isTorchOn = false
            onCodes([])
            // Prewarming: configured, not running.
            if configured == nil, Self.currentAccess() == .authorized { await configureIfNeeded() }
            return
        }

        access = Self.currentAccess()
        if access == .notDetermined {
            access = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        }
        guard access == .authorized else { return }
        guard await configureIfNeeded() else { return }

        guard wantsRunning else { return }
        await engine.start()
        if case .interrupted = status { return }
        status = .running
    }

    /// Builds the session for the wanted camera, unless it already is. False when no camera is usable.
    @discardableResult
    private func configureIfNeeded() async -> Bool {
        // The back camera is the same whichever display is in use.
        let wanted = (position: position, display: position == .front ? display : .outer)
        if configured?.position != wanted.position || configured?.display != wanted.display {
            let relay = relay ?? MetadataRelay { [weak self] codes in self?.receive(codes) }
            self.relay = relay
            guard let capabilities = await engine.configure(
                position: wanted.position,
                display: wanted.display,
                types: Symbology.captureTypes,
                relay: relay
            ) else {
                status = .unavailable
                return false
            }
            configured = wanted
            self.capabilities = capabilities
            displayZoom = capabilities.initialDisplayZoom
            attachPreview()
        }
        return true
    }

    private func attachPreview() {
        guard let preview, configured != nil, let device = engine.device else { return }
        preview.attach(session: engine.session, device: device)
    }

    private func handle(_ event: CaptureEvent) {
        switch event {
        case .interrupted(let reason):
            isTorchOn = false
            status = .interrupted(Self.interruption(for: reason))
            onCodes([])
        case .interruptionEnded:
            status = wantsRunning ? .running : .idle
        case .failed(let needsRestart):
            if needsRestart, wantsRunning { reconcile() }
        }
    }

    // MARK: Codes

    private func receive(_ codes: [RawCode]) {
        guard let preview, status == .running else { return }
        let layer = preview.previewLayer
        let bounds = preview.bounds
        let reads = codes.compactMap { code -> CodeRead? in
            let type = AVMetadataObject.ObjectType(rawValue: code.type)
            guard let symbology = Symbology(metadataType: type, payload: code.payload),
                  let quad = Quad(points: code.corners.map(layer.layerPointConverted(fromCaptureDevicePoint:))),
                  bounds.contains(quad.center) else { return nil }
            return CodeRead(raw: code.payload, symbology: symbology, quad: quad)
        }
        onCodes(reads)
    }

    // MARK: Controls

    func toggleTorch() {
        let target = !isTorchOn
        Task {
            isTorchOn = await engine.setTorch(target)
        }
    }

    func setZoom(_ zoom: CGFloat, animated: Bool = true) {
        guard let profile = capabilities?.zoom else { return }
        displayZoom = profile.clampedDisplay(zoom)
        engine.setZoom(deviceFactor: profile.deviceFactor(forDisplay: displayZoom), animated: animated)
    }

    func pinch(by magnification: CGFloat) {
        let base = pinchBase ?? displayZoom
        pinchBase = base
        setZoom(base * magnification, animated: false)
    }

    func endPinch() {
        pinchBase = nil
    }

    /// Focus and expose at a point in the preview's coordinate space.
    func focus(at point: CGPoint) {
        guard let preview, capabilities?.supportsFocusPoint == true, status == .running else { return }
        engine.focus(at: preview.previewLayer.captureDevicePointConverted(fromLayerPoint: point))
        let mark = FocusMark(point: point)
        focusMark = mark
        Task {
            try? await Task.sleep(for: .seconds(1))
            if focusMark == mark { focusMark = nil }
        }
    }

    // MARK: Helpers

    private static func currentAccess() -> Access {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        default: .notDetermined
        }
    }

    private static func interruption(for reason: AVCaptureSession.InterruptionReason?) -> Interruption {
        switch reason {
        case .videoDeviceInUseByAnotherClient: .inUseByAnotherApp
        case .videoDeviceNotAvailableWithMultipleForegroundApps: .multitasking
        case .videoDeviceNotAvailableDueToSystemPressure: .systemPressure
        default: .other
        }
    }
}
