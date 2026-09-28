import SwiftUI

/// Rate, share, privacy and version.
struct SettingsAboutSection: View {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6758315540")!
    static let reviewURL = URL(string: "https://apps.apple.com/app/id6758315540?action=write-review")!

    var body: some View {
        Section("About") {
            Link(destination: Self.reviewURL) {
                Label("Rate Lens", systemImage: "star")
            }
            ShareLink(item: Self.appStoreURL, message: Text("Lens reads any code and checks links before you open them.")) {
                Label("Share Lens", systemImage: "square.and.arrow.up")
            }
            NavigationLink {
                PrivacyView()
            } label: {
                Label("Privacy", systemImage: "hand.raised")
            }
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
