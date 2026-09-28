import SwiftUI

/// The glass chip that names what a locked code is: "Link · atlas-coffee.co".
struct LockChip: View {
    var payload: Payload

    var body: some View {
        HStack(spacing: 8) {
            KindTile(kind: payload.kind, size: 28)
            Text("\(Text(payload.kind.title)) · \(payload.displayTitle)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .frame(minHeight: 40)
        .lensGlass(.regular, in: Capsule())
        .frame(maxWidth: 320)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .combine)
    }

    /// Below the code, or above it when the sheet would cover it; always fully on screen.
    static func position(for quad: Quad, in size: CGSize, bottomInset: CGFloat) -> CGPoint {
        let box = quad.expanded(by: 10).boundingBox
        let halfWidth = min(160, size.width / 2)
        let x = min(max(box.midX, halfWidth + 8), size.width - halfWidth - 8)
        let below = box.maxY + 32
        let y = below < size.height - bottomInset - 32 ? below : max(box.minY - 32, 80)
        return CGPoint(x: x, y: y)
    }
}

/// The signature moment: a crisp copy of the code, laid exactly over the printed one, lifts off the
/// surface, flattens and rounds into the kind tile where the result sheet's header lands.
struct LiftingCode: View {
    var kind: CodeKind
    var codeImage: UIImage?
    var source: Quad
    var destination: CGRect

    @State private var progress: CGFloat = 0

    /// Layout size of the face before projection; only its proportions matter.
    private let side: CGFloat = 120

    var body: some View {
        ZStack {
            codeFace
                .opacity(1 - progress)
            KindTile(kind: kind, size: side)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: side * 0.28, style: .continuous))
                .opacity(progress)
        }
        .frame(width: side, height: side)
        .modifier(LiftEffect(source: source, destination: Quad(rect: destination), progress: progress))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.smooth(duration: 0.34)) { progress = 1 }
        }
    }

    @ViewBuilder
    private var codeFace: some View {
        let shape = RoundedRectangle(cornerRadius: 4 + 30 * progress, style: .continuous)
        if let codeImage {
            Image(uiImage: codeImage)
                .interpolation(.none)
                .resizable()
                .background(.white)
                .clipShape(shape)
        } else {
            shape.fill(kind.tint.opacity(0.35))
        }
    }
}

/// Projects its view (laid out at the origin) onto a quad that travels from `source` to `destination`.
nonisolated struct LiftEffect: GeometryEffect {
    var source: Quad
    var destination: Quad
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let quad = source.interpolated(to: destination, fraction: progress)
        return Homography(mapping: size, onto: quad).projectionTransform
    }
}

#Preview("Lock chip") {
    ZStack {
        Color.gray
        LockChip(payload: .link(URL(string: "https://atlas-coffee.co/menu")!))
    }
    .environment(\.colorScheme, .dark)
}
