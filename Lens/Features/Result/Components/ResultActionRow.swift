import SwiftUI
import UIKit

/// The secondary row under every result: optional kind-specific actions, then Copy · Share · Show Code.
/// Wraps to a column at accessibility text sizes.
struct ResultActionRow<Leading: View>: View {
    var result: ScanResult
    /// What "Copy" puts on the pasteboard. Nil hides Copy (when a leading action already copies).
    var copyText: String?
    var showCodeTitle: LocalizedStringKey = "Show Code"
    /// Off when the body already draws the code (a product's barcode).
    var showsCode = true
    @ViewBuilder var leading: Leading

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingCode = ResultActionRow.opensCodeOnLaunch

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        layout {
            leading
            if let copyText { CopyButton(text: copyText) }
            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            if showsCode {
                Button { showingCode = true } label: {
                    Label(showCodeTitle, systemImage: "qrcode")
                }
            }
        }
        .buttonStyle(.secondaryAction)
        .fullScreenCover(isPresented: $showingCode) {
            CodeCover(raw: result.code.raw, symbology: result.code.symbology, title: result.payload.displayTitle)
        }
    }

    /// `-qaCodeCover YES` opens the full-screen code straight away, for review.
    private static var opensCodeOnLaunch: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "qaCodeCover")
        #else
        false
        #endif
    }

    private var shareText: String {
        if case .link(let url) = result.payload { return url.absoluteString }
        return result.code.raw
    }
}

extension ResultActionRow where Leading == EmptyView {
    init(result: ScanResult, copyText: String?, showCodeTitle: LocalizedStringKey = "Show Code", showsCode: Bool = true) {
        self.init(result: result, copyText: copyText, showCodeTitle: showCodeTitle, showsCode: showsCode) { EmptyView() }
    }
}

/// Copies text and confirms in place ("Copied") with a success haptic.
struct CopyButton: View {
    var text: String
    var title: LocalizedStringKey = "Copy"

    @State private var copies = 0
    @State private var showingConfirmation = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            copies += 1
            showingConfirmation = true
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                showingConfirmation = false
            }
        } label: {
            Label(showingConfirmation ? "Copied" : title, systemImage: showingConfirmation ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
        }
        .sensoryFeedback(.success, trigger: copies)
        .animation(.snappy, value: showingConfirmation)
    }
}

/// Full-width filled action in the result's tint, with an optional spinner while busy.
struct ResultPrimaryButton: View {
    var title: LocalizedStringKey
    var symbol: String
    var tint: Color
    var isBusy = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView().tint(Palette.onTint)
                } else {
                    Image(systemName: symbol)
                }
                Text(title).lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(.primaryAction(tint))
        .disabled(isBusy)
    }
}
