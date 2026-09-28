import SwiftUI

/// Contact card: monogram, Call · Message · Email, every number and address, and "Add to Contacts".
struct ContactResultView: View {
    var card: ContactCard
    var result: ScanResult

    @Environment(\.openURL) private var openURL
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !rows.isEmpty {
                ResultCard {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { CardDivider() }
                        DetailRow(label: row.label, value: row.value) {
                            if let action = row.action {
                                RowIconButton(symbol: action.symbol, label: action.label, tint: CodeKind.contact.tint) {
                                    openURL(action.url)
                                }
                            }
                        }
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

    private struct RowAction {
        var symbol: String
        var label: LocalizedStringKey
        var url: URL
    }

    private struct Row {
        var label: LocalizedStringKey
        var value: String
        var action: RowAction?
    }

    /// Every way to reach them, each with its one-tap action (call, email, open) beside it.
    private var rows: [Row] {
        let phones = card.phones.map { phone in
            Row(label: "Phone", value: phone,
                action: ContactLinks.tel(phone).map { RowAction(symbol: "phone.fill", label: "Call \(phone)", url: $0) })
        }
        let emails = card.emails.map { email in
            Row(label: "Email", value: email,
                action: ContactLinks.mail(email).map { RowAction(symbol: "envelope.fill", label: "Email \(email)", url: $0) })
        }
        let websites = card.urls.map { site in
            Row(label: "Website", value: site,
                action: URL(string: site.contains("://") ? site : "https://\(site)").map { RowAction(symbol: "safari.fill", label: "Open \(site)", url: $0) })
        }
        return phones + emails + websites
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
