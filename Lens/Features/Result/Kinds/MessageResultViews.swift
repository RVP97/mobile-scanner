import SwiftUI

/// `mailto:` / `MATMSG:` — the draft, then "Compose Email" in the default mail app.
struct EmailResultView: View {
    var message: EmailMessage
    var result: ScanResult
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // The recipient is the header; the card is the draft itself.
            if !message.subject.isEmpty || !message.body.isEmpty {
                ResultCard {
                    if !message.subject.isEmpty {
                        DetailRow(label: "Subject", value: message.subject)
                    }
                    if !message.subject.isEmpty, !message.body.isEmpty {
                        CardDivider()
                    }
                    if !message.body.isEmpty {
                        DetailRow(label: "Message", value: message.body)
                    }
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
            if !message.body.isEmpty {
                ResultCard {
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

/// `tel:` — the number is the header; the body is "Call" and a way to message it.
struct PhoneResultView: View {
    var number: String
    var result: ScanResult
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
