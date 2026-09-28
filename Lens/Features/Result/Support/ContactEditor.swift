import Contacts
import ContactsUI
import SwiftUI

/// The system "unknown contact" card with Create New Contact / Add to Existing Contact.
/// It runs out of process, so Lens never needs access to the address book.
struct ContactEditor: UIViewControllerRepresentable {
    var card: ContactCard
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = CNContactViewController(forUnknownContact: card.cnContact)
        controller.contactStore = CNContactStore()
        controller.allowsActions = false
        controller.delegate = context.coordinator
        controller.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { _ in context.coordinator.dismiss() }
        )
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            dismiss()
        }
    }
}

extension ContactCard {
    var cnContact: CNContact {
        let contact = CNMutableContact()
        contact.givenName = givenName
        contact.familyName = familyName
        contact.organizationName = organization
        contact.jobTitle = jobTitle
        contact.phoneNumbers = phones.map {
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0))
        }
        contact.emailAddresses = emails.map { CNLabeledValue(label: CNLabelWork, value: $0 as NSString) }
        contact.urlAddresses = urls.map { CNLabeledValue(label: CNLabelURLAddressHomePage, value: $0 as NSString) }
        if !address.isEmpty {
            let postal = CNMutablePostalAddress()
            postal.street = address
            contact.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: postal)]
        }
        return contact
    }
}
