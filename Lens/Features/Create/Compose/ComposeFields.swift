import SwiftUI

/// Shows the draft's issue for `field` under its row, if there is one.
private struct IssueFooter: View {
    var draft: CreateDraft
    var field: DraftField

    var body: some View {
        if let issue = draft.issue(for: field) {
            IssueRow(issue: issue)
        }
    }
}

struct LinkFields: View {
    @Bindable var draft: CreateDraft

    var body: some View {
        Section {
            TextField("atlas-coffee.co/menu", text: $draft.link)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
            IssueFooter(draft: draft, field: .link)
        } header: {
            Text("Link")
        } footer: {
            Text("Lunet adds https:// if you leave it out.")
        }
    }
}

struct WiFiFields: View {
    @Bindable var draft: CreateDraft
    @State private var revealsPassword = false

    var body: some View {
        Section {
            TextField("Network name", text: $draft.wifi.ssid)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            IssueFooter(draft: draft, field: .ssid)
            if draft.wifi.security != .open {
                HStack {
                    Group {
                        if revealsPassword {
                            TextField("Password", text: $draft.wifi.password)
                        } else {
                            SecureField("Password", text: $draft.wifi.password)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .fontDesign(revealsPassword ? .monospaced : .default)
                    Button {
                        revealsPassword.toggle()
                    } label: {
                        Image(systemName: revealsPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(revealsPassword ? Text("Hide Password") : Text("Show Password"))
                }
                IssueFooter(draft: draft, field: .password)
            }
        } header: {
            Text("Network")
        }

        Section {
            Picker("Security", selection: $draft.wifi.security) {
                Text("WPA2/WPA3").tag(WiFiNetwork.Security.wpa)
                Text("WEP").tag(WiFiNetwork.Security.wep)
                Text("None").tag(WiFiNetwork.Security.open)
            }
            .pickerStyle(.segmented)
            Toggle("Hidden network", isOn: $draft.wifi.isHidden)
        } footer: {
            Text("Anyone who scans this joins without typing the password.")
        }
    }
}

struct TextFields: View {
    @Bindable var draft: CreateDraft

    var body: some View {
        Section {
            TextField("What should it say?", text: $draft.text, axis: .vertical)
                .lineLimit(4...12)
        } header: {
            Text("Text")
        } footer: {
            if draft.text.count > 300 {
                Text("\(draft.text.count) characters. Long text makes a dense code, so print it larger.")
            }
        }
    }
}

struct EmailFields: View {
    @Bindable var draft: CreateDraft

    var body: some View {
        Section {
            TextField("To", text: $draft.email.to)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            IssueFooter(draft: draft, field: .emailTo)
            TextField("Subject", text: $draft.email.subject)
            TextField("Message", text: $draft.email.body, axis: .vertical)
                .lineLimit(3...8)
        } footer: {
            Text("Scanning opens a new email, ready to send.")
        }
    }
}

struct MessageFields: View {
    @Bindable var draft: CreateDraft

    var body: some View {
        Section {
            TextField("Phone number", text: $draft.sms.number)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
            IssueFooter(draft: draft, field: .smsNumber)
            TextField("Message", text: $draft.sms.body, axis: .vertical)
                .lineLimit(3...8)
        } footer: {
            Text("Scanning opens Messages with this text filled in.")
        }
    }
}

struct PhoneFields: View {
    @Bindable var draft: CreateDraft

    var body: some View {
        Section {
            TextField("Phone number", text: $draft.phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
            IssueFooter(draft: draft, field: .phone)
        } footer: {
            Text("Include the country code (like +1) so it works anywhere.")
        }
    }
}

struct ProductFields: View {
    @Bindable var draft: CreateDraft

    var body: some View {
        Section {
            Picker("Format", selection: $draft.format) {
                ForEach(CreateIntent.product.formats) { Text($0.displayName).tag($0) }
            }
            TextField(placeholder, text: $draft.product)
                .keyboardType(.numberPad)
                .fontDesign(.monospaced)
            IssueFooter(draft: draft, field: .product)
            if let note = draft.outcome.note {
                NoteRow(note: note)
            }
        } header: {
            Text("Product number")
        } footer: {
            Text("Use the GTIN assigned to your product. Leave off the last digit and Lunet adds the check digit.")
        }
    }

    private var placeholder: LocalizedStringKey {
        switch draft.format {
        case .ean8: "7 or 8 digits"
        case .upcA: "11 or 12 digits"
        case .upcE: "6 to 8 digits"
        default: "12 or 13 digits"
        }
    }
}

struct AdvancedFields: View {
    @Bindable var draft: CreateDraft

    var body: some View {
        Section {
            TextField(placeholder, text: $draft.advancedText, axis: draft.format.isTwoDimensional ? .vertical : .horizontal)
                .lineLimit(draft.format.isTwoDimensional ? 3...10 : 1...1)
                .keyboardType(isNumeric ? .numberPad : .asciiCapable)
                .textInputAutocapitalization(draft.format == .code39 || draft.format == .codabar ? .characters : .never)
                .autocorrectionDisabled()
                .fontDesign(draft.format.isTwoDimensional ? .default : .monospaced)
            IssueFooter(draft: draft, field: .advanced)
            if let note = draft.outcome.note {
                NoteRow(note: note)
            }
        } header: {
            Text("Content")
        } footer: {
            Text(rules)
        }
    }

    private var isNumeric: Bool {
        [.ean13, .ean8, .upcA, .upcE, .itf14, .itf, .msi, .pharmacode].contains(draft.format)
    }

    private var placeholder: LocalizedStringKey {
        isNumeric ? "Digits" : "Text"
    }

    private var rules: LocalizedStringResource {
        switch draft.format {
        case .qr, .aztec, .pdf417, .dataMatrix: "Any text."
        case .code128: "Letters, digits and standard symbols, up to 80 characters."
        case .ean13: "12 digits, or 13 with the check digit."
        case .ean8: "7 digits, or 8 with the check digit."
        case .upcA: "11 digits, or 12 with the check digit."
        case .upcE: "6 digits (number system 0), 7 with a number system of 0 or 1, 8 with the check digit, or a 12-digit UPC-A to shorten."
        case .code39: "Capital letters, digits, spaces and - . $ / + %"
        case .itf14: "13 digits, or 14 with the check digit."
        case .itf: "An even number of digits."
        case .msi: "Digits. Lunet adds the check digit."
        case .pharmacode: "A whole number from 3 to 131070."
        case .codabar: "Digits and - $ : / . + between start and stop letters A–D."
        case .microQR, .microPDF417, .code93, .gs1DataBar: ""
        }
    }
}
