import SwiftUI

/// Rate, share, privacy and version.
struct SettingsAboutSection: View {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6758315540")!
    static let reviewURL = URL(string: "https://apps.apple.com/app/id6758315540?action=write-review")!

    var body: some View {
        Section("About") {
            identity
            NavigationLink(value: SettingsRoute.privacy) {
                SettingsLabel("Privacy", symbol: "lock.fill", color: .blue)
            }
            Link(destination: Self.reviewURL) {
                SettingsLabel("Rate Ojito", symbol: "star.fill", color: .yellow)
            }
            .foregroundStyle(.primary)
            ShareLink(item: Self.appStoreURL, message: Text("Ojito reads any code and checks links before you open them.")) {
                SettingsLabel("Share Ojito", symbol: "square.and.arrow.up", color: .green)
            }
            .foregroundStyle(.primary)
        }
    }

    /// The icon, the name and the version: who you're talking to.
    private var identity: some View {
        HStack(spacing: 16) {
            OjitoAppIcon(size: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Ojito")
                    .font(.headline)
                Text("Version \(Self.version)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// "2.0.0 (100)".
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        Form { SettingsAboutSection() }
    }
}
#endif
