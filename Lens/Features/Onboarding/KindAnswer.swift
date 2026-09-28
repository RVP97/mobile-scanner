import SwiftUI

extension CodeKind {
    /// The one thing Lens offers to do with this kind of code, as introduced in onboarding.
    var answerVerb: LocalizedStringKey {
        switch self {
        case .link: "Open Safely"
        case .wifi: "Join Network"
        case .product: "Search the Web"
        case .contact: "Save Contact"
        case .event: "Add to Calendar"
        case .email: "Write Email"
        case .sms: "Send Message"
        case .phone: "Call"
        case .location: "Open in Maps"
        case .travel: "Add to Wallet"
        case .crypto: "Copy Address"
        case .shipment: "Track Package"
        case .text: "Copy"
        }
    }
}

/// The kind's verb in a soft capsule of its tint.
struct AnswerVerbPill: View {
    var kind: CodeKind

    var body: some View {
        Text(kind.answerVerb)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(kind.tint)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(kind.tint.opacity(0.14), in: .capsule)
    }
}
