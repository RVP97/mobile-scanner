import SwiftUI
import WidgetKit

/// Shows the code the user pinned from Create (a Wi-Fi network, a contact card) so anyone
/// can scan it straight off the Home Screen.
struct MyCodeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedCodeStore.widgetKind, provider: PinnedCodeProvider()) { entry in
            MyCodeWidgetView(entry: entry)
        }
        .configurationDisplayName("My Code")
        .description("Keep a code you made one glance away, ready to be scanned.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct PinnedCodeProvider: TimelineProvider {
    struct Entry: TimelineEntry {
        var date: Date
        var image: UIImage?
        var title: String
    }

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, image: nil, title: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // The app reloads this timeline whenever the pinned code changes.
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> Entry {
        let pinned = SharedCodeStore.pinnedCode()
        return Entry(date: .now, image: pinned?.image, title: pinned?.title ?? "")
    }
}

struct MyCodeWidgetView: View {
    var entry: PinnedCodeProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let image = entry.image {
                pinned(image)
                    .widgetURL(LensDeepLink.history.url)
            } else {
                empty
                    .widgetURL(LensDeepLink.create.url)
            }
        }
        .containerBackground(for: .widget) { Color(.secondarySystemBackground) }
    }

    @ViewBuilder
    private func pinned(_ image: UIImage) -> some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 16) {
                CodePlate(image: image)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.headline)
                        .lineLimit(3)
                    Text("Scan with any camera")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        default:
            VStack(spacing: 6) {
                CodePlate(image: image)
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "qrcode")
                .font(.title2)
                .foregroundStyle(Palette.accent)
                .widgetAccentable()
            Spacer(minLength: 4)
            Text("My Code")
                .font(.headline)
            Text("Make a code in Ojito and pin it here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }
}

/// The code on a white plate, so it stays scannable in dark mode and tinted Home Screens.
private struct CodePlate: View {
    var image: UIImage

    var body: some View {
        codeImage
            .aspectRatio(contentMode: .fit)
            .padding(8)
            .background(.white, in: .rect(cornerRadius: 14, style: .continuous))
            .accessibilityLabel(Text("Pinned code"))
    }

    @ViewBuilder
    private var codeImage: some View {
        let base = Image(uiImage: image).resizable().interpolation(.none)
        if #available(iOS 18.0, *) {
            base.widgetAccentedRenderingMode(.fullColor)
        } else {
            base
        }
    }
}

#Preview("Empty", as: .systemSmall) {
    MyCodeWidget()
} timeline: {
    PinnedCodeProvider.Entry(date: .now, image: nil, title: "")
}

#Preview("Pinned", as: .systemMedium) {
    MyCodeWidget()
} timeline: {
    PinnedCodeProvider.Entry(date: .now, image: UIImage(systemName: "qrcode"), title: "Casa Chen Wi-Fi")
}
