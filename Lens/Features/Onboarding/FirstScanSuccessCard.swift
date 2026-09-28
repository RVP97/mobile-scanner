import SwiftUI

/// The moment the first scan lands: a seal, what Lens understood, and what it would do.
struct FirstScanSuccessCard: View {
    var result: ScanResult
    var isSample: Bool
    var onContinue: () -> Void

    @State private var appeared = false

    private var kind: CodeKind { result.payload.kind }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Palette.safe)
                    .symbolEffect(.bounce, value: appeared)
                    .background {
                        Circle()
                            .fill(Palette.safe.opacity(0.35))
                            .blur(radius: 14)
                            .scaleEffect(appeared ? 1.3 : 0.6)
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your first scan")
                        .font(.title3.weight(.bold))
                    Text("Lunet knew what it was and what to do next.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    KindTile(kind: kind, size: 48)
                    labels
                    Spacer(minLength: 8)
                    AnswerVerbPill(kind: kind)
                }
                HStack(alignment: .top, spacing: 12) {
                    KindTile(kind: kind, size: 48)
                    VStack(alignment: .leading, spacing: 8) {
                        labels
                        AnswerVerbPill(kind: kind)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .combine)

            if !isSample {
                Text("It’s saved in History. Pull up from the camera anytime.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Continue", action: onContinue)
                .buttonStyle(.primaryAction())
        }
        .padding(20)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 32, style: .continuous))
        .onAppear {
            withAnimation(.smooth(duration: 0.6)) { appeared = true }
        }
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.payload.displayTitle)
                .font(.headline)
                .lineLimit(2)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var subtitle: String {
        var parts = [String(localized: kind.title), result.code.symbology.displayName]
        if isSample { parts.append(String(localized: "Sample")) }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    let code = ScannedCode(raw: SampleCodePlate.payload, symbology: .qr)
    FirstScanSuccessCard(
        result: ScanResult(code: code, payload: .wifi(WiFiNetwork(ssid: "Atlas Guest", password: "espresso-2019"))),
        isSample: true
    ) {}
    .padding()
    .background(.black)
    .environment(\.colorScheme, .dark)
}
