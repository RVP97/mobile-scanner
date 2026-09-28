import EventKit
import EventKitUI
import SwiftUI

/// What to prefill in the system "New Event" sheet.
struct CalendarDraft: Identifiable {
    let id = UUID()
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var location = ""
    var notes = ""
}

extension CalendarDraft {
    init?(_ event: CalendarEvent) {
        guard let start = event.start else { return nil }
        let end = event.isAllDay ? (event.inclusiveEnd ?? start) : (event.end ?? start.addingTimeInterval(3600))
        self.init(title: event.title, start: start, end: max(end, start), isAllDay: event.isAllDay,
                  location: event.location, notes: event.notes)
    }
}

/// The system event editor. It runs out of process, so adding an event needs no calendar permission.
struct EventEditor: UIViewControllerRepresentable {
    var draft: CalendarDraft
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.startDate = draft.start
        event.endDate = draft.end
        event.isAllDay = draft.isAllDay
        event.location = draft.location.isEmpty ? nil : draft.location
        event.notes = draft.notes.isEmpty ? nil : draft.notes

        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}
