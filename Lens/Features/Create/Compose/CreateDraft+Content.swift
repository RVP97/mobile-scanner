import Foundation

/// Per-intent rules: build the payload text and explain anything that's off, in plain words.
extension CreateDraft {
    func contentOutcome() -> Outcome {
        guard let intent else { return advancedOutcome() }
        switch intent {
        case .link: return linkOutcome()
        case .wifi: return wifiOutcome()
        case .contact: return contactOutcome()
        case .text: return textOutcome()
        case .email: return emailOutcome()
        case .sms: return smsOutcome()
        case .phone: return phoneOutcome()
        case .event: return eventOutcome()
        case .location: return locationOutcome()
        case .product: return productOutcome()
        }
    }

    private func document(_ raw: String, _ payload: Payload, title: String, caption: String) -> CodeDocument {
        CodeDocument(raw: raw, symbology: format, payload: payload, title: title, caption: caption)
    }

    // MARK: Intents

    private func linkOutcome() -> Outcome {
        let typed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return Outcome() }
        if typed.contains(" ") { return Outcome(issues: [DraftIssue(field: .link, message: "Links can't contain spaces.")]) }
        guard let url = PayloadComposer.link(typed) else {
            return Outcome(issues: [DraftIssue(field: .link, message: "That doesn't look like a web address yet.")])
        }
        let host = url.host() ?? url.absoluteString
        return Outcome(document: document(url.absoluteString, .link(url), title: host, caption: String(localized: "Scan to open \(host)")))
    }

    private func wifiOutcome() -> Outcome {
        let ssid = wifi.ssid
        var issues: [DraftIssue] = []
        if ssid.utf8.count > 32 { issues.append(DraftIssue(field: .ssid, message: "Network names are 32 characters at most.")) }
        let password = wifi.password
        switch wifi.security {
        case .wpa:
            if !password.isEmpty, password.count < 8 {
                issues.append(DraftIssue(field: .password, message: "WPA passwords have at least 8 characters."))
            } else if password.count > 63 {
                issues.append(DraftIssue(field: .password, message: "WPA passwords have 63 characters at most."))
            }
        case .wep:
            let isHex = password.allSatisfy(\.isHexDigit)
            let valid = [5, 13].contains(password.count) || (isHex && [10, 26].contains(password.count))
            if !password.isEmpty, !valid {
                issues.append(DraftIssue(field: .password, message: "WEP keys are 5 or 13 characters, or 10 or 26 hex digits."))
            }
        case .open:
            break
        }
        let complete = !ssid.isEmpty && (wifi.security == .open || !password.isEmpty)
        guard complete, issues.isEmpty else { return Outcome(issues: issues) }
        return Outcome(document: document(
            PayloadComposer.wifi(wifi), .wifi(wifi), title: ssid, caption: String(localized: "Scan to join \(ssid)")
        ))
    }

    private func contactOutcome() -> Outcome {
        var card = contact
        card.phones = [contactPhone].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        card.emails = [contactEmail.trimmingCharacters(in: .whitespaces)].filter { !$0.isEmpty }
        card.urls = [contactURL.trimmingCharacters(in: .whitespaces)].filter { !$0.isEmpty }
        var issues: [DraftIssue] = []
        if let email = card.emails.first, !Self.looksLikeEmail(email) {
            issues.append(DraftIssue(field: .contactEmail, message: "Check the email address."))
        }
        if let phone = card.phones.first, !Self.looksLikePhone(phone) {
            issues.append(DraftIssue(field: .contactPhone, message: "Phone numbers use digits, spaces and + ( ) -."))
        }
        if let url = card.urls.first, PayloadComposer.link(url) == nil {
            issues.append(DraftIssue(field: .contactURL, message: "That doesn't look like a web address yet."))
        }
        let name = card.fullName.isEmpty ? card.organization : card.fullName
        guard !name.isEmpty, issues.isEmpty else { return Outcome(issues: issues) }
        return Outcome(document: document(
            PayloadComposer.vCard(card), .contact(card), title: name, caption: String(localized: "Scan to save \(name)")
        ))
    }

    private func textOutcome() -> Outcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Outcome() }
        let title = String(trimmed.split(separator: "\n").first?.prefix(40) ?? "")
        return Outcome(document: document(text, .text(text), title: title, caption: String(localized: "Scan to read")))
    }

    private func emailOutcome() -> Outcome {
        let to = email.to.trimmingCharacters(in: .whitespaces)
        guard !to.isEmpty else { return Outcome() }
        guard Self.looksLikeEmail(to) else { return Outcome(issues: [DraftIssue(field: .emailTo, message: "Check the email address.")]) }
        return Outcome(document: document(
            PayloadComposer.email(email), .email(email), title: to, caption: String(localized: "Scan to email \(to)")
        ))
    }

    private func smsOutcome() -> Outcome {
        let number = sms.number.trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty else { return Outcome() }
        guard Self.looksLikePhone(number) else {
            return Outcome(issues: [DraftIssue(field: .smsNumber, message: "Phone numbers use digits, spaces and + ( ) -.")])
        }
        return Outcome(document: document(
            PayloadComposer.sms(sms), .sms(sms), title: number, caption: String(localized: "Scan to text \(number)")
        ))
    }

    private func phoneOutcome() -> Outcome {
        let number = phone.trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty else { return Outcome() }
        guard Self.looksLikePhone(number) else {
            return Outcome(issues: [DraftIssue(field: .phone, message: "Phone numbers use digits, spaces and + ( ) -.")])
        }
        return Outcome(document: document(
            PayloadComposer.phone(number), .phone(PayloadComposer.dialable(number)), title: number,
            caption: String(localized: "Scan to call \(number)")
        ))
    }

    private func eventOutcome() -> Outcome {
        var issues: [DraftIssue] = []
        if let start = event.start, let end = event.end, end < start, !event.isAllDay {
            issues.append(DraftIssue(field: .eventDates, message: "The event ends before it starts.", fixTitle: "End an Hour Later") { [self] in
                self.event.end = start.addingTimeInterval(3600)
            })
        }
        let title = event.title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, issues.isEmpty else { return Outcome(issues: issues) }
        return Outcome(document: document(
            PayloadComposer.event(event), .event(event), title: title, caption: String(localized: "Scan to add \(title)")
        ))
    }

    private func locationOutcome() -> Outcome {
        guard var point = location else { return Outcome() }
        point.label = locationLabel.trimmingCharacters(in: .whitespaces)
        let title = point.label.isEmpty
            ? String(format: "%.4f, %.4f", point.latitude, point.longitude)
            : point.label
        return Outcome(document: document(
            PayloadComposer.location(point), .location(point), title: title, caption: String(localized: "Scan for directions")
        ))
    }

    private func productOutcome() -> Outcome {
        switch SymbologyValidator.check(product, for: format) {
        case .empty:
            return Outcome()
        case .invalid(let message, let fix):
            return Outcome(issues: [DraftIssue(field: .product, message: message, fixTitle: fix?.title) { [self] in
                if let fix { self.product = fix.replacement }
            }])
        case .valid(let value, let note):
            return Outcome(
                document: document(value, .product(gtin: value), title: value, caption: String(localized: "Scan for product details")),
                note: note
            )
        }
    }

    private func advancedOutcome() -> Outcome {
        switch SymbologyValidator.check(advancedText, for: format) {
        case .empty:
            return Outcome()
        case .invalid(let message, let fix):
            return Outcome(issues: [DraftIssue(field: .advanced, message: message, fixTitle: fix?.title) { [self] in
                if let fix { self.advancedText = fix.replacement }
            }])
        case .valid(let value, let note):
            let payload = format.isRetail ? .product(gtin: value) : PayloadParser.parse(value, symbology: format)
            return Outcome(
                document: document(value, payload, title: value, caption: format.isTwoDimensional ? String(localized: "Scan to read") : ""),
                note: note
            )
        }
    }

    // MARK: Heuristics

    static func looksLikeEmail(_ text: String) -> Bool {
        text.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) != nil
    }

    static func looksLikePhone(_ text: String) -> Bool {
        let allowed = Set("0123456789+()-. ")
        return text.allSatisfy(allowed.contains) && text.filter(\.isNumber).count >= 3
            && !text.dropFirst().contains("+")
    }
}
