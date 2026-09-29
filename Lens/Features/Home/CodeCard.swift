import SwiftUI

/// A Wallet-style card for one of the person's codes: the kind's color, what it is, and the code
/// itself, small, ready to be opened full screen.
struct CodeCard: View {
    let record: ScanRecord

    @State private var codeImage: UIImage?

    var body: some View {
        Group {
            if case .travel(let pass) = payload {
                TravelCardFace(pass: pass, date: record.tripDate(), codeImage: codeImage)
            } else {
                face
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.white)
        .background(CardSurface(color: record.kind.cardColor))
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .contentShape(.rect(cornerRadius: 20, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .task(id: record.styleData) { renderCode() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Shows the code full screen")
        .accessibilityAddTraits(.isButton)
    }

    private var payload: Payload { PayloadParser.parse(record.raw, symbology: record.symbology) }

    private var face: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                CardGlyph(symbol: record.kind.symbol)
                Text(record.kind.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .padding(.top, 6)
                Spacer(minLength: 8)
                if record.isPinned && record.origin == .scanned {
                    Image(systemName: "pin.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.top, 8)
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.historyTitle)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                MiniCode(image: codeImage, isSquare: record.symbology.isTwoDimensional && record.symbology != .pdf417)
            }
        }
    }

    private var subtitle: String? {
        if !record.subtitle.isEmpty { return record.subtitle }
        return nil
    }

    private var accessibilityText: Text {
        let kind = Text(record.kind.title)
        if let subtitle { return Text("\(kind), \(record.historyTitle), \(subtitle)") }
        return Text("\(kind), \(record.historyTitle)")
    }

    private func renderCode() {
        let style = CodeStyle.decoded(from: record.styleData)
        codeImage = CodeArtwork.image(raw: record.raw, symbology: record.symbology, style: style, dimension: 88, includesFrame: false)
    }
}

/// A boarding pass card: flight and day, the route large, passenger and seat.
private struct TravelCardFace: View {
    var pass: BoardingPass
    var date: Date?
    var codeImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                CardGlyph(symbol: "airplane")
                VStack(alignment: .leading, spacing: 0) {
                    Text(pass.flightDesignator)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.monospaced)
                    Text(pass.airlineName ?? String(localized: CodeKind.travel.title))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let date {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                airport(pass.from)
                Spacer(minLength: 8)
                Image(systemName: "airplane")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityHidden(true)
                Spacer(minLength: 8)
                airport(pass.to)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 12) {
                Text(detailLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                Spacer(minLength: 0)
                MiniCode(image: codeImage, isSquare: false)
            }
        }
    }

    private func airport(_ code: String) -> some View {
        Text(code)
            .font(.system(.largeTitle, design: .monospaced, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var detailLine: String {
        guard !pass.seat.isEmpty else { return pass.displayName }
        return String(localized: "\(pass.displayName) · Seat \(pass.seat)")
    }
}

/// The glyph in a frosted square, top left of every card.
private struct CardGlyph: View {
    var symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 32, height: 32)
            .background(.white.opacity(0.2), in: .rect(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The code on its white quiet zone.
private struct MiniCode: View {
    var image: UIImage?
    var isSquare: Bool

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: isSquare ? 64 : 92, height: isSquare ? 64 : 34)
        .padding(6)
        .background(.white, in: .rect(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// The card's colored surface: the kind color with a soft light from above and a faint ring, like
/// embossed card stock.
struct CardSurface: View {
    var color: Color
    /// The hairline edge; off when the surface is only part of a larger card.
    var isOutlined = true

    var body: some View {
        ZStack {
            color
            LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0)], startPoint: .top, endPoint: .center)
            GeometryReader { proxy in
                Circle()
                    .strokeBorder(.white.opacity(0.07), lineWidth: 28)
                    .frame(width: proxy.size.width * 0.9, height: proxy.size.width * 0.9)
                    .offset(x: proxy.size.width * 0.45, y: -proxy.size.width * 0.38)
            }
        }
        .overlay {
            if isOutlined {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
            }
        }
    }
}

extension CodeKind {
    /// A deep version of the kind's tint that carries white text at 4.5:1 in either appearance.
    var cardColor: Color {
        switch self {
        case .link: Color(hex: 0x0071A4)
        case .wifi: Color(hex: 0x1E7A34)
        case .product: Color(hex: 0xB25000)
        case .contact: Color(hex: 0x8A2BB9)
        case .event, .location: Color(hex: 0xC4231B)
        case .email: Color(hex: 0x0A5FCC)
        case .sms, .phone: Color(hex: 0x1E7A34)
        case .travel: Color(hex: 0xC2185B)
        case .crypto: Color(hex: 0xA15C00)
        case .shipment: Color(hex: 0x7A5C3A)
        case .text: Color(hex: 0x48484A)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

#if DEBUG
#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 12) {
            ForEach(HistorySamples.records().filter { $0.isPinned || $0.origin == .created }) { record in
                CodeCard(record: record).frame(width: 320, height: 204)
            }
        }
        .padding()
    }
    .modelContainer(HistorySamples.container)
}
#endif
