import SwiftUI

/// The thumb zone: the Scan lens, and the three other ways in under it. Content scrolls away
/// beneath a soft fade.
struct HomeActionBar: View {
    var isLensAnimating: Bool
    var onScan: () -> Void
    var onPhotos: () -> Void
    var onMultiScan: () -> Void
    var onCreate: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 16) {
            ScanLensButton(isAnimating: isLensAnimating, action: onScan)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { model.lensFrame = proxy.frame(in: .global) }
                            .onChange(of: proxy.frame(in: .global)) { _, frame in model.lensFrame = frame }
                    }
                }

            LensGlassContainer(spacing: 12) {
                // Labels when they fit (small phones, long languages and large text fall back to glyphs).
                ViewThatFits(in: .horizontal) {
                    actions(showsTitles: !typeSize.isAccessibilitySize)
                    actions(showsTitles: false)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) { fade }
    }

    private func actions(showsTitles: Bool) -> some View {
        HStack(spacing: 12) {
            action("Photos", symbol: "photo.on.rectangle", hint: "Scans a code in a photo", showsTitle: showsTitles, perform: onPhotos)
            action("Multi-scan", symbol: "square.stack.3d.up", hint: "Opens the camera to collect several codes", showsTitle: showsTitles, perform: onMultiScan)
            action("Create", symbol: "plus", hint: "Makes a new code", showsTitle: showsTitles, perform: onCreate)
        }
        .fixedSize()
    }

    private func action(
        _ title: LocalizedStringKey,
        symbol: String,
        hint: LocalizedStringKey,
        showsTitle: Bool,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Group {
                if !showsTitle {
                    Image(systemName: symbol)
                        .frame(width: 48)
                } else {
                    Label(title, systemImage: symbol)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(minHeight: 44)
            .contentShape(.capsule)
            .lensGlass(.regular, in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(hint))
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    /// Fades the scrolling content out behind the controls.
    private var fade: some View {
        LinearGradient(
            stops: [
                .init(color: Color(.systemGroupedBackground).opacity(0), location: 0),
                .init(color: Color(.systemGroupedBackground).opacity(0.9), location: 0.16),
                .init(color: Color(.systemGroupedBackground), location: 0.32),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .padding(.top, -32)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}
