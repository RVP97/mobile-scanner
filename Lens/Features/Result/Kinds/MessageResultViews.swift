import SwiftUI

/// `mailto:` / `MATMSG:` — the draft, then "Compose Email" in the default mail app.
struct EmailResultView: View {
    var message: EmailMessage
    var result: ScanResult
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultCard {
                DetailRow(label: "To", value: message.to.isEmpty ? String(localized: "No recipient") : message.to)
                if !message.subject.isEmpty {
                    CardDivider()
                    DetailRow(label: "Subject", value: message.subject)
                }
                if !message.body.isEmpty {
                    CardDivider()
                    DetailRow(label: "Message", value: message.body)
                }
            }
            if let url = ContactLinks.mail(message.to, subject: message.subject, body: message.body) {
                ResultPrimaryButton(title: "Compose Email", symbol: "square.and.pencil", tint: CodeKind.email.tint) {
                    openURL(url)
                }
            }
            ResultActionRow(result: result, copyText: message.to.isEmpty ? result.code.raw : message.to)
        }
    }
}

/// `sms:` / `SMSTO:` — number and message, then "Send Message" in Messages.
struct SMSResultView: View {
    var message: SMSMessage
    var result: ScanResult
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultCard {
                DetailRow(label: "To", value: message.number.isEmpty ? String(localized: "No recipient") : message.number)
                if !message.body.isEmpty {
                    CardDivider()
                    DetailRow(label: "Message", value: message.body)
                }
            }
            if let url = ContactLinks.sms(message.number, body: message.body) {
                ResultPrimaryButton(title: "Send Message", symbol: "message.fill", tint: CodeKind.sms.tint) {
                    openURL(url)
                }
            }
            ResultActionRow(result: result, copyText: message.body.isEmpty ? message.number : message.body)
        }
    }
}

/// `tel:` — the number, large, and "Call".
struct PhoneResultView: View {
    var number: String
    var result: ScanResult
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultCard {
                Text(number)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let url = ContactLinks.tel(number) {
                ResultPrimaryButton(title: "Call", symbol: "phone.fill", tint: CodeKind.phone.tint) {
                    openURL(url)
                }
            }
            ResultActionRow(result: result, copyText: number) {
                if let url = ContactLinks.sms(number) {
                    Button { openURL(url) } label: { Label("Message", systemImage: "message") }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Email") { ResultPreview(.sample("mailto:hola@atlas-coffee.co?subject=Catering&body=Hi!")) }
#Preview("SMS") { ResultPreview(.sample("SMSTO:+525512345678:Table 4 is ready")) }
#Preview("Phone") { ResultPreview(.sample("tel:+525512345678")) }
#endif
