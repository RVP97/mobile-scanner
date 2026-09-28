import Contacts
import ContactsUI
import SwiftUI

struct ContactFields: View {
    @Bindable var draft: CreateDraft
    @State private var picking = false

    var body: some View {
        Section {
            Button {
                picking = true
            } label: {
                Label("Use My Card", systemImage: "person.crop.circle")
            }
            .background(ContactPickerPresenter(isPresented: $picking, onPick: fill))
        } footer: {
            Text("Pick your card (or anyone's) to fill this in. Lunet only sees the one you choose.")
        }

        Section {
            TextField("First name", text: $draft.contact.givenName)
                .textContentType(.givenName)
            TextField("Last name", text: $draft.contact.familyName)
                .textContentType(.familyName)
            TextField("Company", text: $draft.contact.organization)
                .textContentType(.organizationName)
            TextField("Job title", text: $draft.contact.jobTitle)
                .textContentType(.jobTitle)
        } header: {
            Text("Name")
        }

        Section {
            TextField("Phone", text: $draft.contactPhone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
            if let issue = draft.issue(for: .contactPhone) { IssueRow(issue: issue) }
            TextField("Email", text: $draft.contactEmail)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if let issue = draft.issue(for: .contactEmail) { IssueRow(issue: issue) }
            TextField("Website", text: $draft.contactURL)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if let issue = draft.issue(for: .contactURL) { IssueRow(issue: issue) }
            TextField("Address", text: $draft.contact.address, axis: .vertical)
                .textContentType(.fullStreetAddress)
                .lineLimit(1...4)
        } header: {
            Text("Details")
        }

        Section {
            TextField("Note", text: $draft.contact.note, axis: .vertical)
                .lineLimit(1...4)
        } footer: {
            Text("Saved as a vCard. Scanning offers to add it to Contacts.")
        }
    }

    private func fill(from contact: CNContact) {
        func value(_ key: String, _ read: () -> String) -> String {
            contact.isKeyAvailable(key) ? read() : ""
        }
        draft.contact.givenName = value(CNContactGivenNameKey) { contact.givenName }
        draft.contact.familyName = value(CNContactFamilyNameKey) { contact.familyName }
        draft.contact.organization = value(CNContactOrganizationNameKey) { contact.organizationName }
        draft.contact.jobTitle = value(CNContactJobTitleKey) { contact.jobTitle }
        draft.contactPhone = value(CNContactPhoneNumbersKey) { contact.phoneNumbers.first?.value.stringValue ?? "" }
        draft.contactEmail = value(CNContactEmailAddressesKey) { contact.emailAddresses.first.map { String($0.value) } ?? "" }
        draft.contactURL = value(CNContactUrlAddressesKey) { contact.urlAddresses.first.map { String($0.value) } ?? "" }
        draft.contact.address = value(CNContactPostalAddressesKey) {
            contact.postalAddresses.first.map { CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress) } ?? ""
        }
    }
}

/// Presents the system contact picker. It runs out of process, so no Contacts permission is needed.
private struct ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPick: (CNContact) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, controller.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        controller.present(picker, animated: true)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPickerPresenter

        init(_ parent: ContactPickerPresenter) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onPick(contact)
            parent.isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}
