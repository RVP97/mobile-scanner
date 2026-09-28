import SwiftUI

/// Rate, share, privacy and version.
struct SettingsAboutSection: View {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6758315540")!
    static let reviewURL = URL(string: "https://apps.apple.com/app/id6758315540?action=write-review")!

    var body: some View {
        Section("About") {
            NavigationLink(value: SettingsRoute.privacy) {
                SettingsLabel("Privacy", symbol: "lock.fill", color: .blue)
            }
            Link(destination: Self.reviewURL) {
                SettingsLabel("Rate Lens", symbol: "star.fill", color: .yellow)
            }
            .foregroundStyle(.primary)
            ShareLink(item: Self.appStoreURL, message: Text("Lens reads any code and checks links before you open them.")) {
                SettingsLabel("Share Lens", symbol: "square.and.arrow.up", color: .green)
            }
            .foregroundStyle(.primary)
            LabeledContent("Version", value: Self.version)
        }
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
