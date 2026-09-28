import SwiftUI

/// Contact card: monogram, Call · Message · Email, every number and address, and "Add to Contacts".
struct ContactResultView: View {
    var card: ContactCard
    var result: ScanResult

    @Environment(\.openURL) private var openURL
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultCard {
                identity
                quickActions
            }

            if !rows.isEmpty {
                ResultCard {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { CardDivider() }
                        DetailRow(label: row.label, value: row.value)
                    }
                }
            }

            ResultPrimaryButton(title: "Add to Contacts", symbol: "person.crop.circle.badge.plus", tint: CodeKind.contact.tint) {
                showingEditor = true
            }

            ResultActionRow(result: result, copyText: result.code.raw)
        }
        .sheet(isPresented: $showingEditor) {
            ContactEditor(card: card).ignoresSafeArea()
        }
    }

    private var identity: some View {
        HStack(spacing: 16) {
            Text(card.initials)
                .font(.title2.weight(.semibold))
                .foregroundStyle(CodeKind.contact.tint)
                .frame(width: 64, height: 64)
                .background(Palette.tileFill(.contact), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.displayName).font(.headline)
                if !card.jobTitle.isEmpty { Text(card.jobTitle).foregroundStyle(.secondary) }
                if !card.organization.isEmpty, card.organization != card.displayName {
                    Text(card.organization).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            quickAction("Call", symbol: "phone.fill", url: card.phones.first.flatMap { ContactLinks.tel($0) })
            quickAction("Message", symbol: "message.fill", url: card.phones.first.flatMap { ContactLinks.sms($0) })
            quickAction("Email", symbol: "envelope.fill", url: card.emails.first.flatMap { ContactLinks.mail($0) })
        }
        .buttonStyle(.secondaryAction)
    }

    private func quickAction(_ title: LocalizedStringKey, symbol: String, url: URL?) -> some View {
        Button { if let url { openURL(url) } } label: {
            Label(title, systemImage: symbol)
        }
        .disabled(url == nil)
    }

    private struct Row {
        var label: LocalizedStringKey
        var value: String
    }

    private var rows: [Row] {
        card.phones.map { Row(label: "Phone", value: $0) }
            + card.emails.map { Row(label: "Email", value: $0) }
            + card.urls.map { Row(label: "Website", value: $0) }
            + (card.address.isEmpty ? [] : [Row(label: "Address", value: card.address)])
            + (card.note.isEmpty ? [] : [Row(label: "Note", value: card.note)])
    }
}

/// `tel:`, `sms:` and `mailto:` URLs from what people actually type in a card.
enum ContactLinks {
    static func dialable(_ number: String) -> String {
        number.filter { $0.isASCIIDigit || $0 == "+" || $0 == "*" || $0 == "#" || $0 == "," }
    }

    static func tel(_ number: String) -> URL? {
        let digits = dialable(number)
        return digits.isEmpty ? nil : URL(string: "tel:\(digits)")
    }

    static func sms(_ number: String, body: String = "") -> URL? {
        let digits = dialable(number)
        guard !digits.isEmpty || !body.isEmpty else { return nil }
        guard !body.isEmpty else { return URL(string: "sms:\(digits)") }
        let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(["&", "=", "+", "?"])) ?? ""
        return URL(string: "sms:\(digits)&body=\(encoded)")
    }

    static func mail(_ address: String, subject: String = "", body: String = "") -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        var items: [URLQueryItem] = []
        if !subject.isEmpty { items.append(URLQueryItem(name: "subject", value: subject)) }
        if !body.isEmpty { items.append(URLQueryItem(name: "body", value: body)) }
        components.queryItems = items.isEmpty ? nil : items
        return components.url
    }
}

#if DEBUG
#Preview { ResultPreview(.sampleContact) }
#endif
