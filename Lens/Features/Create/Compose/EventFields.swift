import SwiftUI

struct EventFields: View {
    @Bindable var draft: CreateDraft

    var body: some View {
        Section {
            TextField("Title", text: $draft.event.title)
            TextField("Location", text: $draft.event.location)
        }

        Section {
            Toggle("All-day", isOn: $draft.event.isAllDay)
            DatePicker("Starts", selection: date(\.start), displayedComponents: components)
            DatePicker("Ends", selection: date(\.end), displayedComponents: components)
            if let issue = draft.issue(for: .eventDates) { IssueRow(issue: issue) }
        } footer: {
            Text("Times are saved in universal time, so they show correctly in any time zone.")
        }

        Section {
            TextField("Notes", text: $draft.event.notes, axis: .vertical)
                .lineLimit(2...6)
        }
    }

    private var components: DatePickerComponents {
        draft.event.isAllDay ? [.date] : [.date, .hourAndMinute]
    }

    private func date(_ keyPath: WritableKeyPath<CalendarEvent, Date?>) -> Binding<Date> {
        Binding {
            draft.event[keyPath: keyPath] ?? .now
        } set: {
            draft.event[keyPath: keyPath] = $0
        }
    }
}
