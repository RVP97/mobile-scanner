import SwiftUI

/// Calendar event: a date block, time and place, notes, and "Add to Calendar".
struct EventResultView: View {
    var event: CalendarEvent
    var result: ScanResult

    @State private var draft: CalendarDraft?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultCard {
                HStack(alignment: .top, spacing: 16) {
                    if let start = event.start { dateBlock(start) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title.isEmpty ? String(localized: "Untitled event") : event.title)
                            .font(.headline)
                        if let time = timeText {
                            Label(time, systemImage: "clock").foregroundStyle(.secondary)
                        }
                        if !event.location.isEmpty {
                            Label(event.location, systemImage: "mappin.and.ellipse").foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)

                if !event.notes.isEmpty {
                    CardDivider()
                    DetailRow(label: "Notes", value: event.notes)
                }
            }

            if let calendarDraft = CalendarDraft(event) {
                ResultPrimaryButton(title: "Add to Calendar", symbol: "calendar.badge.plus", tint: CodeKind.event.tint) {
                    draft = calendarDraft
                }
            }

            ResultActionRow(result: result, copyText: copyText)
        }
        .sheet(item: $draft) { EventEditor(draft: $0).ignoresSafeArea() }
    }

    private func dateBlock(_ date: Date) -> some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(CodeKind.event.tint)
            Text(date.formatted(.dateTime.day()))
                .font(.title.weight(.semibold))
                .monospacedDigit()
        }
        .frame(width: 60, height: 64)
        .background(Palette.tileFill(.event), in: .rect(cornerRadius: 14, style: .continuous))
    }

    private var timeText: String? {
        guard let start = event.start else { return nil }
        let day = start.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if event.isAllDay {
            guard let end = event.inclusiveEnd, !Calendar.current.isDate(end, inSameDayAs: start) else {
                return String(localized: "\(day) · All day")
            }
            return "\(day) – \(end.formatted(.dateTime.weekday(.wide).day().month(.wide)))"
        }
        guard let end = event.end else { return "\(day) · \(start.formatted(date: .omitted, time: .shortened))" }
        let range = (start..<max(end, start.addingTimeInterval(1))).formatted(.interval.hour().minute())
        return Calendar.current.isDate(end, inSameDayAs: start)
            ? "\(day) · \(range)"
            : (start..<end).formatted(.interval.day().month().hour().minute())
    }

    private var copyText: String {
        [event.title, event.dateSummary, event.location].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

#if DEBUG
#Preview { ResultPreview(.sampleEvent) }
#endif
