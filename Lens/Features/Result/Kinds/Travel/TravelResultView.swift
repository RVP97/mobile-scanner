import SwiftUI

/// Boarding pass: the pass card, "Add to Calendar", a bright full-screen pass for the gate, flight tracking.
/// Apple Wallet needs a pass signed for the airline, so it's only offered when `WalletPassService` can sign one.
struct TravelResultView: View {
    var pass: BoardingPass
    var result: ScanResult

    @Environment(\.openURL) private var openURL
    @State private var calendarDraft: CalendarDraft?

    var body: some View {
        let date = pass.date()

        VStack(alignment: .leading, spacing: 16) {
            BoardingPassCard(pass: pass, date: date)

            WalletPassButton(pass: pass, raw: result.code.raw, symbology: result.code.symbology)

            ResultPrimaryButton(title: "Add to Calendar", symbol: "calendar.badge.plus", tint: CodeKind.travel.tint) {
                calendarDraft = draft(on: date ?? .now)
            }

            ResultActionRow(result: result, copyText: nil, showCodeTitle: "Show Pass") {
                Button {
                    if let url = WebSearch.url(for: String(localized: "\(pass.flightDesignator) flight status", comment: "Web search query")) { openURL(url) }
                } label: {
                    Label("Track Flight", systemImage: "airplane.departure")
                }
            }
        }
        .sheet(item: $calendarDraft) { EventEditor(draft: $0).ignoresSafeArea() }
    }

    private func draft(on date: Date) -> CalendarDraft {
        var notes = [String(localized: "Passenger: \(pass.displayName)")]
        if !pass.seat.isEmpty { notes.append(String(localized: "Seat \(pass.seat)")) }
        if !pass.bookingReference.isEmpty { notes.append(String(localized: "Booking \(pass.bookingReference)")) }
        let route = "\(pass.from) → \(pass.to)"
        return CalendarDraft(
            title: String(localized: "Flight \(pass.flightDesignator) · \(route)"),
            start: date,
            end: date,
            isAllDay: true,
            location: TravelDirectory.city(for: pass.from).map { "\($0) (\(pass.from))" } ?? pass.from,
            notes: notes.joined(separator: "\n")
        )
    }
}

#if DEBUG
#Preview { ResultPreview(.sampleTravel) }
#endif
