import SwiftUI
import WidgetKit

/// Home Screen "Scan" button and the circular Lock Screen shortcut.
struct ScanWidget: Widget {
    static let kind = "com.rvp97.scanner.scan"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: StaticProvider()) { _ in
            ScanWidgetView()
                .widgetURL(LensDeepLink.scan.url)
        }
        .configurationDisplayName("Scan")
        .description("Open the camera, ready to read any code.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

/// A widget that never changes: one entry, no refreshes.
struct StaticProvider: TimelineProvider {
    struct Entry: TimelineEntry {
        var date: Date
    }

    func placeholder(in context: Context) -> Entry { Entry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

struct ScanWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    /// The color mark on a full-color Home Screen; the one-color glyph when tinted or clear.
    @ViewBuilder private var mark: some View {
        if renderingMode == .fullColor {
            OjitoMark()
        } else {
            OjitoGlyph()
                .widgetAccentable()
        }
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                OjitoGlyph()
                    .padding(10)
                    .widgetAccentable()
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Scan Code"))
            .containerBackground(for: .widget) { Color.clear }
        default:
            VStack(alignment: .leading, spacing: 0) {
                mark
                    .frame(width: 64, height: 40, alignment: .leading)
                Spacer(minLength: 8)
                Text("Scan")
                    .font(.title2.weight(.semibold))
                Text("Any code, checked first.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .containerBackground(for: .widget) { Color(.systemBackground) }
        }
    }
}

#Preview("Small", as: .systemSmall) {
    ScanWidget()
} timeline: {
    StaticProvider.Entry(date: .now)
}

#Preview("Circular", as: .accessoryCircular) {
    ScanWidget()
} timeline: {
    StaticProvider.Entry(date: .now)
}
