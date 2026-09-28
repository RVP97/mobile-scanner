@preconcurrency import AVFoundation

/// What the configured camera can do, handed back to the UI.
nonisolated struct CameraCapabilities: Hashable, Sendable {
    var position: AVCaptureDevice.Position
    var hasTorch: Bool
    var supportsFocusPoint: Bool
    var zoom: ZoomProfile
    var initialDisplayZoom: CGFloat
}

/// A code as the metadata output reported it: corners in normalized capture-device space.
nonisolated struct RawCode: Sendable {
    var type: String
    var payload: String
    var corners: [CGPoint]
}

/// Session-level events the UI reacts to.
nonisolated enum CaptureEvent: Sendable {
    case interrupted(AVCaptureSession.InterruptionReason?)
    case interruptionEnded
    case failed(needsRestart: Bool)
}

/// Delivers metadata on the main queue as plain values.
nonisolated final class MetadataRelay: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    private let handler: @MainActor ([RawCode]) -> Void

    init(handler: @escaping @MainActor ([RawCode]) -> Void) {
        self.handler = handler
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        let codes = metadataObjects.compactMap { object -> RawCode? in
            guard let code = object as? AVMetadataMachineReadableCodeObject,
                  let payload = code.stringValue, !payload.isEmpty else { return nil }
            return RawCode(type: code.type.rawValue, payload: payload, corners: code.corners)
        }
        // The delegate queue is the main queue (see `configure`).
        MainActor.assumeIsolated { handler(codes) }
    }
}

/// Owns the `AVCaptureSession`. Every session and device mutation happens on one serial queue so the
/// main thread never blocks on camera start-up, reconfiguration or zoom ramps.
nonisolated final class CaptureEngine: @unchecked Sendable {
    let session = AVCaptureSession()
    let events: AsyncStream<CaptureEvent>

    private let queue = DispatchQueue(label: "com.rvp97.scanner.capture", qos: .userInitiated)
    private let metadataOutput = AVCaptureMetadataOutput()
    private let eventContinuation: AsyncStream<CaptureEvent>.Continuation
    private let lock = NSLock()
    private var currentDevice: AVCaptureDevice?
    private var observers: [NSObjectProtocol] = []

    init() {
        (events, eventContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(8))
        observeSession()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        eventContinuation.finish()
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    /// The active camera. Safe to read from any thread.
    var device: AVCaptureDevice? { lock.withLock { currentDevice } }

    // MARK: Configuration

    /// Builds (or rebuilds, when flipping cameras) the session. Returns nil when no camera is usable.
    func configure(
        position: AVCaptureDevice.Position,
        types: [AVMetadataObject.ObjectType],
        relay: MetadataRelay
    ) async -> CameraCapabilities? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.configureOnQueue(position: position, types: types, relay: relay))
            }
        }
    }

    private func configureOnQueue(
        position: AVCaptureDevice.Position,
        types: [AVMetadataObject.ObjectType],
        relay: MetadataRelay
    ) -> CameraCapabilities? {
        guard let device = Self.bestDevice(for: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return nil }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.inputs.forEach(session.removeInput)
        for preset in [AVCaptureSession.Preset.hd1920x1080, .high] where session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
            break
        }
        guard session.canAddInput(input) else { return nil }
        session.addInput(input)

        if !session.outputs.contains(metadataOutput) {
            guard session.canAddOutput(metadataOutput) else { return nil }
            session.addOutput(metadataOutput)
        }
        metadataOutput.setMetadataObjectsDelegate(relay, queue: .main)
        let available = Set(metadataOutput.availableMetadataObjectTypes)
        metadataOutput.metadataObjectTypes = types.filter(available.contains)

        if session.isMultitaskingCameraAccessSupported {
            session.isMultitaskingCameraAccessEnabled = true
        }

        lock.withLock { currentDevice = device }
        let zoom = Self.zoomProfile(for: device)
        let initialZoom = prepare(device, zoom: zoom)

        return CameraCapabilities(
            position: position,
            hasTorch: device.hasTorch,
            supportsFocusPoint: device.isFocusPointOfInterestSupported,
            zoom: zoom,
            initialDisplayZoom: initialZoom
        )
    }

    /// Prefers a virtual device so the system switches to the ultra-wide lens for macro when a code is close.
    private static func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
            : [.builtInWideAngleCamera]
        for type in types {
            if let device = AVCaptureDevice.default(type, for: .video, position: position) { return device }
        }
        return nil
    }

    private static func zoomProfile(for device: AVCaptureDevice) -> ZoomProfile {
        let multiplier: CGFloat
        if #available(iOS 18.0, *) {
            multiplier = device.displayVideoZoomFactorMultiplier
        } else {
            let hasUltraWide = device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
            multiplier = ZoomProfile.legacyMultiplier(
                hasUltraWide: hasUltraWide,
                switchOverFactors: device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat($0.doubleValue) }
            )
        }
        return ZoomProfile(
            minimumDeviceFactor: device.minAvailableVideoZoomFactor,
            maximumDeviceFactor: device.maxAvailableVideoZoomFactor,
            displayMultiplier: multiplier
        )
    }

    /// Scanning-friendly focus, exposure and HDR. Returns the starting display zoom.
    private func prepare(_ device: AVCaptureDevice, zoom: ZoomProfile) -> CGFloat {
        guard (try? device.lockForConfiguration()) != nil else { return zoom.displayZoom(forDevice: device.videoZoomFactor) }
        defer { device.unlockForConfiguration() }

        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
        if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = false }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        if device.activeFormat.isVideoHDRSupported { device.automaticallyAdjustsVideoHDREnabled = true }
        if device.isLowLightBoostSupported { device.automaticallyEnablesLowLightBoostWhenAvailable = true }
        device.isSubjectAreaChangeMonitoringEnabled = true

        var display: CGFloat = 1
        if device.isVirtualDevice {
            device.setPrimaryConstituentDeviceSwitchingBehavior(.auto, restrictedSwitchingBehaviorConditions: [])
        } else if device.position == .back {
            // A single fixed lens can't macro: zoom in a little so small codes fill the frame at a
            // distance the lens can still focus.
            display = ZoomProfile.recommendedZoom(
                fieldOfView: device.activeFormat.videoFieldOfView,
                minimumFocusDistance: device.minimumFocusDistance
            )
        }
        device.videoZoomFactor = zoom.deviceFactor(forDisplay: display)
        return zoom.displayZoom(forDevice: device.videoZoomFactor)
    }

    // MARK: Running

    func start() async {
        await perform { session in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() async {
        await perform { session in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func perform(_ work: @escaping @Sendable (AVCaptureSession) -> Void) async {
        await withCheckedContinuation { continuation in
            queue.async {
                work(self.session)
                continuation.resume()
            }
        }
    }

    // MARK: Controls

    /// Returns whether the torch ended up on.
    func setTorch(_ on: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                guard let device = self.device, device.hasTorch, device.isTorchAvailable,
                      (try? device.lockForConfiguration()) != nil else {
                    continuation.resume(returning: false)
                    return
                }
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
                continuation.resume(returning: on)
            }
        }
    }

    func setZoom(deviceFactor: CGFloat, animated: Bool) {
        queue.async {
            guard let device = self.device, (try? device.lockForConfiguration()) != nil else { return }
            let factor = min(max(deviceFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            if animated {
                device.ramp(toVideoZoomFactor: factor, withRate: 12)
            } else {
                if device.isRampingVideoZoom { device.cancelVideoZoomRamp() }
                device.videoZoomFactor = factor
            }
            device.unlockForConfiguration()
        }
    }

    /// Focuses and exposes once at a point (normalized device coordinates); continuous focus returns
    /// when the scene changes.
    func focus(at devicePoint: CGPoint) {
        queue.async {
            guard let device = self.device, (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        }
    }

    private func resumeContinuousFocus() {
        queue.async {
            guard let device = self.device, (try? device.lockForConfiguration()) != nil else { return }
            let center = CGPoint(x: 0.5, y: 0.5)
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = center }
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = center }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.unlockForConfiguration()
        }
    }

    // MARK: Notifications

    private func observeSession() {
        let center = NotificationCenter.default
        let continuation = eventContinuation
        observers = [
            center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) { note in
                let reason = (note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int)
                    .flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
                continuation.yield(.interrupted(reason))
            },
            center.addObserver(forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil) { _ in
                continuation.yield(.interruptionEnded)
            },
            center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) { note in
                let error = note.userInfo?[AVCaptureSessionErrorKey] as? AVError
                continuation.yield(.failed(needsRestart: error?.code == .mediaServicesWereReset))
            },
            center.addObserver(forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: nil, queue: nil) { [weak self] note in
                guard let self, let device = note.object as? AVCaptureDevice, device === self.device else { return }
                self.resumeContinuousFocus()
            },
        ]
    }
}
