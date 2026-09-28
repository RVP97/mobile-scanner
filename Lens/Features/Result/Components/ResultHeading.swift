import Foundation

/// What the result header says for a payload. Each kind's body is built around it, so the two never
/// repeat each other. A nil title means the body is the hero and the header stays compact.
struct ResultHeading: Equatable {
    var title: String?
    var subtitle: String?
    var monospacedTitle = false
    /// A person's initials, drawn in place of the kind glyph.
    var monogram: String?

    static let compact = ResultHeading(title: nil)

    /// - Parameter productName: a product's name once the lookup finds it.
    init(_ payload: Payload, productName: String? = nil) {
        switch payload {
        case .link(let url):
            self.init(title: url.displayHost ?? String(url.absoluteString.prefix(80)))
        case .wifi(let network):
            let security = network.isHidden
                ? "\(network.securityDescription) · \(String(localized: "Hidden"))"
                : network.securityDescription
            self.init(title: network.ssid, subtitle: security)
        case .product(let gtin):
            self.init(title: productName ?? GTIN.grouped(gtin), monospacedTitle: productName == nil)
        case .contact(let card):
            let role = [card.jobTitle, card.organization].filter { !$0.isEmpty && $0 != card.displayName }
            self.init(title: card.displayName, subtitle: role.joined(separator: " · "))
            monogram = card.initials.isEmpty ? nil : card.initials
        case .event(let event):
            self.init(title: event.title.isEmpty ? String(localized: "Event") : event.title)
        case .email(let message):
            self.init(title: message.to.isEmpty ? String(localized: "New email") : message.to)
        case .sms(let message):
            self.init(title: message.number.isEmpty ? String(localized: "New message") : message.number)
        case .phone(let number):
            self.init(title: number)
        case .location(let point):
            self.init(title: point.label.isEmpty ? point.coordinateText : point.label)
        case .crypto(let request):
            let amount = request.amount.isEmpty ? nil : "\(request.amount) \(request.currencyCode)"
            let payee = request.label.isEmpty ? nil : String(localized: "To \(request.label)")
            self.init(
                title: amount ?? String(localized: "\(request.networkName) address"),
                subtitle: amount == nil ? payee : [request.networkName, payee].compactMap(\.self).joined(separator: " · ")
            )
        case .shipment(let number):
            let carrier = ShipmentCarrier.carrier(forTrackingNumber: number)
            self.init(
                title: number,
                subtitle: carrier.map { String(localized: "\($0.name) package") } ?? String(localized: "Tracking number"),
                monospacedTitle: true
            )
        case .travel, .text:
            self = .compact
        }
    }

    init(title: String?, subtitle: String? = nil, monospacedTitle: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.monospacedTitle = monospacedTitle
    }
}
