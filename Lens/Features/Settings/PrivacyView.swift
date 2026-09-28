import SwiftUI

/// Plain-language privacy page: what Lens keeps, and the only times it touches the network.
struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your scans stay on your iPhone.")
                        .font(.title3.weight(.semibold))
                    Text("Ojito has no account and no tracking. We never see what you scan, create or where you are.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("What Ojito doesn't do") {
                PrivacyPoint(symbol: "person.crop.circle.badge.xmark", title: "No account",
                             detail: "There's nothing to sign up for and nothing to sign in to.")
                PrivacyPoint(symbol: "chart.bar.xaxis", title: "No tracking or analytics",
                             detail: "Ojito doesn't collect usage data, and there are no ads.")
                PrivacyPoint(symbol: "icloud.slash", title: "Nothing stored on our side",
                             detail: "History, created codes and settings are stored only on this iPhone.")
            }

            Section {
                PrivacyPoint(symbol: "link", title: "Deep link check",
                             detail: "To show where a link really goes, Ojito contacts that link's own server to follow redirects and look up the domain's age. You can turn this off in Settings.")
                PrivacyPoint(symbol: "barcode", title: "Product lookup",
                             detail: "When you open a product barcode, Ojito asks Open Food Facts or Open Products Facts about that one number.")
                PrivacyPoint(symbol: "wallet.pass", title: "Add to Apple Wallet",
                             detail: "Wallet only accepts signed passes, so Ojito sends that one pass's details to its signing service. It signs the pass and returns it immediately; nothing is stored or logged.")
                PrivacyPoint(symbol: "location", title: "Place names",
                             detail: "If Remember where I scanned is on, Apple Maps turns your location into a place name. The name and coordinates stay in your History.")
            } header: {
                Text("When Ojito uses the network")
            } footer: {
                Text("Opening a link, joining a network or adding a contact happens in the app you choose, under its own privacy policy.")
            }

            Section("Your controls") {
                PrivacyPoint(symbol: "faceid", title: "Lock History",
                             detail: "Require Face ID or your passcode before anyone can see your scans.")
                PrivacyPoint(symbol: "trash", title: "Delete anytime",
                             detail: "Swipe to delete a single scan, or clear everything in Settings.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyPoint: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Palette.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    NavigationStack { PrivacyView() }
}
#endif
