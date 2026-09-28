import SwiftUI

/// The intercepted link: where it really goes, why it's flagged, and a calm way out.
struct DangerLinkView: View {
    var verdict: SafetyVerdict

    @AppStorage(Pref.blockDangerous) private var blockDangerous = Pref.Default.blockDangerous
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var confirmingOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headline

            VStack(alignment: .leading, spacing: 8) {
                MicroLabel("Where it really goes")
                ResultCard { RedirectPathView(verdict: verdict) }
            }

            if !reasons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    MicroLabel("Why it's flagged")
                    ResultCard {
                        ForEach(reasons) { FindingRow(finding: $0) }
                    }
                }
            }

            VStack(spacing: 8) {
                Button(action: model.dismissResult) {
                    Label("Don't Open", systemImage: "hand.raised.fill")
                }
                .buttonStyle(.primaryAction(.primary))

                HStack(spacing: 8) {
                    if canOpen {
                        Button {
                            if blockDangerous { confirmingOpen = true } else { openURL(verdict.original) }
                        } label: {
                            Label("Open Anyway", systemImage: "arrow.up.forward.square")
                        }
                    }
                    if let reportURL {
                        Button { openURL(reportURL) } label: {
                            Label("Report", systemImage: "exclamationmark.bubble")
                        }
                    }
                }
                .buttonStyle(.secondaryAction)
            }
        }
        .confirmationDialog("Open this link anyway?", isPresented: $confirmingOpen, titleVisibility: .visible) {
            Button("Open Anyway", role: .destructive) { openURL(verdict.original) }
            Button("Don't Open", role: .cancel) {}
        } message: {
            Text("Lens thinks this link is a scam. Only continue if you trust whoever gave you the code.")
        }
    }

    private var headline: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.title2)
                .foregroundStyle(Palette.danger)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("This code isn't what it says")
                    .font(.title3.bold())
                Text("Lens stopped it before anything opened.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.danger.opacity(0.12), in: .rect(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var reasons: [SafetyVerdict.Finding] {
        verdict.findings.filter { $0.level >= .caution }
    }

    /// Only web links can be opened; `javascript:` and `data:` never.
    private var canOpen: Bool {
        ["http", "https"].contains(verdict.original.scheme?.lowercased() ?? "")
    }

    /// A pre-filled email to the Anti-Phishing Working Group.
    private var reportURL: URL? {
        let chain = ([verdict.original] + verdict.redirectChain).map(\.absoluteString).joined(separator: "\n")
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "reportphishing@apwg.org"
        components.queryItems = [
            URLQueryItem(name: "subject", value: String(localized: "Phishing QR code")),
            URLQueryItem(name: "body", value: String(localized: "I scanned a QR code that leads to a phishing page:\n\n\(chain)\n\nReported with Lens.")),
        ]
        return components.url
    }
}

#if DEBUG
#Preview { ResultPreview(.sampleDanger) }
#endif
