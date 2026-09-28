import ActivityKit
import SwiftUI
import WidgetKit

/// Holds a multi-scan session on the Lock Screen and in the Dynamic Island until it's reviewed.
struct MultiScanLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MultiScanAttributes.self) { context in
            MultiScanLockScreenView(state: context.state, startedAt: context.attributes.startedAt)
                .activityBackgroundTint(nil)
                .widgetURL(LensDeepLink.multiScan.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(context.state.count, format: .number)
                            .font(.largeTitle.weight(.semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("^[\(context.state.count) code](inflect: true)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    KindGlyphRow(kinds: context.state.kinds, size: 28)
                        .frame(maxHeight: .infinity)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.latest)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text("Latest scan")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        ReviewLink()
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                LunetMark()
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                Text(context.state.count, format: .number)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
                    .contentTransition(.numericText())
            } minimal: {
                Text(context.state.count, format: .number)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.accent)
            }
            .widgetURL(LensDeepLink.multiScan.url)
            .keylineTint(Palette.accent)
        }
    }
}

struct MultiScanLockScreenView: View {
    var state: MultiScanAttributes.ContentState
    var startedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                LunetMark()
                    .frame(width: 18, height: 18)
                Text("Multi-scan")
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text(startedAt, style: .timer)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 64, alignment: .trailing)
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("^[\(state.count) code](inflect: true)")
                        .font(.title2.weight(.semibold))
                        .contentTransition(.numericText())
                    Text(state.latest)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                KindGlyphRow(kinds: state.kinds, size: 30)
            }
            HStack {
                Spacer()
                ReviewLink()
            }
        }
        .padding(16)
    }
}

/// Deep link back into the multi-scan review.
private struct ReviewLink: View {
    var body: some View {
        Link(destination: LensDeepLink.multiScan.url) {
            Text("Review")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.onTint)
                .padding(.horizontal, 16)
                .frame(minHeight: 36)
                .background(Palette.accent, in: .capsule)
        }
    }
}

/// Kind glyphs for the most recent kinds, newest first.
private struct KindGlyphRow: View {
    var kinds: [String]
    var size: CGFloat

    var body: some View {
        HStack(spacing: -size * 0.18) {
            ForEach(kinds, id: \.self) { raw in
                let kind = CodeKind(rawValue: raw) ?? .text
                Image(systemName: kind.symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(kind.tint)
                    .frame(width: size, height: size)
                    .background {
                        // Opaque base so overlapping tiles don't show through each other.
                        let tile = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                        ZStack {
                            tile.fill(Color(.systemBackground))
                            tile.fill(kind.tint.opacity(0.2))
                        }
                    }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(kinds.compactMap { CodeKind(rawValue: $0).map { String(localized: $0.title) } }.formatted(.list(type: .and))))
    }
}

#Preview("Lock Screen", as: .content, using: MultiScanAttributes(startedAt: .now.addingTimeInterval(-42))) {
    MultiScanLiveActivity()
} contentStates: {
    MultiScanAttributes.ContentState.make(count: 3, kinds: ["wifi", "product", "link"], latest: "atlas-coffee.co/menu")
}

#Preview("Island", as: .dynamicIsland(.expanded), using: MultiScanAttributes(startedAt: .now)) {
    MultiScanLiveActivity()
} contentStates: {
    MultiScanAttributes.ContentState.make(count: 3, kinds: ["wifi", "product", "link"], latest: "atlas-coffee.co/menu")
}
