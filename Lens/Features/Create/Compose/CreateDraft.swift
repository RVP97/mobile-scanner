import Foundation
import Observation

/// Where an inline validation message attaches in the form.
enum DraftField: Hashable {
    case link, ssid, password, contactName, contactPhone, contactEmail, contactURL
    case text, emailTo, smsNumber, phone, eventTitle, eventDates, location, product, advanced, capacity
}

/// A problem with what was typed, plus an optional one-tap fix.
struct DraftIssue: Identifiable {
    var field: DraftField
    var message: LocalizedStringResource
    var fixTitle: LocalizedStringResource?
    var fix: (() -> Void)?

    var id: DraftField { field }
}

/// Everything typed on a compose screen. Validation is computed live from the fields, so messages
/// appear and clear as the person types; nothing is flagged until a field has content.
@Observable
final class CreateDraft {
    let intent: CreateIntent?
    /// Encoding format; for the advanced flow it's the only thing chosen up front.
    var format: Symbology

    var link = ""
    var wifi = WiFiNetwork(ssid: "", password: "")
    var contact = ContactCard()
    var contactPhone = ""
    var contactEmail = ""
    var contactURL = ""
    var text = ""
    var email = EmailMessage(to: "")
    var sms = SMSMessage(number: "")
    var phone = ""
    var event: CalendarEvent
    var location: GeoPoint?
    var locationLabel = ""
    var product = ""
    var advancedText = ""

    init(intent: CreateIntent) {
        self.intent = intent
        format = intent.formats[0]
        let start = Calendar.current.nextDate(after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? .now
        event = CalendarEvent(title: "", start: start, end: start.addingTimeInterval(3600))
    }

    /// Advanced flow: any format, free text validated by that format's rules.
    init(format: Symbology) {
        intent = nil
        self.format = format
        event = CalendarEvent(title: "")
    }

    var kind: CodeKind { intent?.kind ?? (format.isRetail ? .product : .text) }

    // MARK: Outcome

    struct Outcome {
        var document: CodeDocument?
        var issues: [DraftIssue] = []
        /// Something Lens adjusted, worth telling ("Check digit 7 added.").
        var note: LocalizedStringResource?
    }

    var outcome: Outcome {
        var outcome = contentOutcome()
        guard let document = outcome.document else { return outcome }
        // Every format has its own limits (length, character set) on top of the content rules.
        switch SymbologyValidator.check(document.raw, for: format) {
        case .valid(let value, let note):
            outcome.document?.raw = value
            outcome.note = outcome.note ?? note
        case .invalid(let message, _):
            outcome.document = nil
            outcome.issues.append(DraftIssue(field: .capacity, message: message))
        case .empty:
            outcome.document = nil
        }
        return outcome
    }

    func issue(for field: DraftField) -> DraftIssue? {
        outcome.issues.first { $0.field == field }
    }
}
