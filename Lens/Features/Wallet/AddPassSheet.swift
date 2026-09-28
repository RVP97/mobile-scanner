import PassKit
import SwiftUI

/// Presents Apple's "Add to Wallet" sheet for a signed pass.
///
///     .sheet(item: $pendingPass) { item in
///         AddPassSheet(pass: item.pass) { added in … }
///             .ignoresSafeArea()
///     }
struct AddPassSheet: UIViewControllerRepresentable {
    let pass: PKPass
    /// Called once the sheet is dismissed; `true` if the pass is now in the user's Wallet.
    var onFinish: ((Bool) -> Void)?

    init(pass: PKPass, onFinish: ((Bool) -> Void)? = nil) {
        self.pass = pass
        self.onFinish = onFinish
    }

    /// Whether this device can add passes at all (false on some iPads / restricted devices).
    static var canAddPasses: Bool { PKAddPassesViewController.canAddPasses() }

    /// Whether "Add to Wallet" should be offered: Wallet present and App Attest supported (false in the Simulator).
    static var isAvailable: Bool { canAddPasses && WalletClient.isSupported }

    func makeCoordinator() -> Coordinator { Coordinator(pass: pass, onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard let controller = PKAddPassesViewController(pass: pass) else {
            // Invalid pass data or passes unavailable: report failure right away.
            Task { @MainActor in context.coordinator.finish() }
            return UIViewController()
        }
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        let pass: PKPass
        var onFinish: ((Bool) -> Void)?
        private var finished = false

        init(pass: PKPass, onFinish: ((Bool) -> Void)?) {
            self.pass = pass
            self.onFinish = onFinish
        }

        func finish() {
            guard !finished else { return }
            finished = true
            onFinish?(PKPassLibrary().containsPass(pass))
        }

        nonisolated func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            MainActor.assumeIsolated {
                controller.dismiss(animated: true)
                finish()
            }
        }
    }
}

/// Identifiable wrapper so a freshly downloaded pass can drive `.sheet(item:)`.
struct PendingWalletPass: Identifiable {
    let id = UUID()
    let pass: PKPass

    /// Builds the pass from the `.pkpass` bytes `WalletClient.passData(for:)` returns.
    init(data: Data) throws {
        pass = try PKPass(data: data)
    }
}

/// SwiftUI wrapper around Apple's official `PKAddPassButton` (required by Wallet branding guidelines).
struct AddPassButton: UIViewRepresentable {
    var style: PKAddPassButtonStyle = .black
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        button.setContentHuggingPriority(.required, for: .vertical)
        return button
    }

    func updateUIView(_ button: PKAddPassButton, context: Context) {
        context.coordinator.action = action
        button.addPassButtonStyle = style
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PKAddPassButton, context: Context) -> CGSize? {
        let intrinsic = uiView.intrinsicContentSize
        return CGSize(width: proposal.width ?? intrinsic.width, height: max(intrinsic.height, 48))
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}
