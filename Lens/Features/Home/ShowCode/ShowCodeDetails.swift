import SwiftUI

/// What the person showing the code may need to say out loud: the network and password, the link.
struct ShowCodeDetails: View {
    let item: ShowCodeItem

    var body: some View {
        let rows = self.rows
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().padding(.leading, 16) }
                    DetailLine(row: row)
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
        }
    }

    private var rows: [DetailLine.Row] {
        switch item.payload {
        case .wifi(let network):
            var rows = [DetailLine.Row(label: "Network", value: network.ssid, note: securityName(network.security))]
            if network.security != .open, !network.password.isEmpty {
                rows.append(.init(label: "Password", value: network.password, monospaced: true, copyTitle: "Copy Password"))
            }
            return rows
        case .link(let url):
            return [.init(label: "Link", value: url.absoluteString, monospaced: true, copyTitle: "Copy Link")]
        case .contact(let card):
            var rows: [DetailLine.Row] = []
            if let phone = card.phones.first { rows.append(.init(label: "Phone", value: phone, copyTitle: "Copy Phone Number")) }
            if let email = card.emails.first { rows.append(.init(label: "Email", value: email, copyTitle: "Copy Email Address")) }
            return rows
        case .product(let gtin):
            return [.init(label: "Number", value: gtin, monospaced: true, copyTitle: "Copy Number")]
        case .text(let text):
            return [.init(label: "Text", value: text, copyTitle: "Copy Text")]
        default:
            return []
        }
    }

    private func securityName(_ security: WiFiNetwork.Security) -> String {
        switch security {
        case .wpa: "WPA"
        case .wep: "WEP"
        case .open: String(localized: "Open")
        }
    }
}

/// One labelled value with an optional copy button.
private struct DetailLine: View {
    struct Row {
        var label: LocalizedStringKey
        var value: String
        var monospaced = false
        var note: String?
        var copyTitle: LocalizedStringKey?
    }

    let row: Row
    @State private var copies = 0
    @State private var showsCopied = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(row.value)
                    .font(row.monospaced ? .body.monospaced() : .body.weight(.semibold))
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if let note = row.note {
                Text(note)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let copyTitle = row.copyTitle {
                Button(action: copy) {
                    Image(systemName: showsCopied ? "checkmark" : "doc.on.doc")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(copyTitle))
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, row.copyTitle == nil ? 16 : 6)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .sensoryFeedback(.success, trigger: copies)
    }

    private func copy() {
        UIPasteboard.general.string = row.value
        copies += 1
        withAnimation(.snappy) { showsCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) { showsCopied = false }
        }
    }
}

/// A boarding pass as the gate sees it: the colored stub with the route, then the code on white.
struct PassFace: View {
    var pass: BoardingPass
    var image: UIImage?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            stub
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.white)
                .background(CardSurface(color: CodeKind.travel.cardColor, isOutlined: false))
            code
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(.white)
        }
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .shadow(color: CodeKind.travel.cardColor.opacity(0.25), radius: 16, y: 8)
    }

    private var stub: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "airplane")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.2), in: .rect(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(pass.flightDesignator)
                        .font(.headline)
                        .fontDesign(.monospaced)
                    Text(pass.airlineName ?? String(localized: CodeKind.travel.title))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.88))
                }
                Spacer(minLength: 8)
                if let date = pass.date() {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.headline)
                }
            }
            HStack(alignment: .top) {
                airport(pass.from, alignment: .leading)
                Spacer(minLength: 8)
                Image(systemName: "airplane")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 12)
                    .accessibilityLabel("to")
                Spacer(minLength: 8)
                airport(pass.to, alignment: .trailing)
            }
            details
        }
        .accessibilityElement(children: .combine)
    }

    private func airport(_ code: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(code)
                .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let city = TravelDirectory.city(for: code) {
                Text(city)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
            }
        }
    }

    private var details: some View {
        let items: [(LocalizedStringKey, String)] = [
            ("Passenger", pass.displayName),
            ("Seat", pass.seat),
            ("Booking", pass.bookingReference),
        ].filter { !$0.1.isEmpty }
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
        return layout {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .foregroundStyle(.white.opacity(0.88))
                    Text(item.1)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var code: some View {
        if let image {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 340)
                .accessibilityLabel(Text("Boarding pass code"))
        } else {
            Color.white.frame(height: 120)
        }
    }
}
