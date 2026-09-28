import PassKit
import SwiftUI

/// Boarding pass: the pass card, "Add to Calendar", a bright full-screen pass for the gate, flight tracking.
/// Apple Wallet needs a pass signed for the airline, so it's only offered when `WalletPassService` can sign one.
struct TravelResultView: View {
    var pass: BoardingPass
    var result: ScanResult

    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @State private var calendarDraft: CalendarDraft?
    @State private var walletPass: PKPass?
    @State private var walletError: String?
    @State private var isPreparingPass = false

    var body: some View {
        let date = pass.date()

        VStack(alignment: .leading, spacing: 16) {
            BoardingPassCard(pass: pass, date: date)

            if WalletPassService.isAvailable, PKAddPassesViewController.canAddPasses() {
                // Apple's own badge, as Wallet's branding guidelines require.
                AddPassButton(style: colorScheme == .dark ? .blackOutline : .black) {
                    guard !isPreparingPass else { return }
                    Task { await prepareWalletPass() }
                }
                .frame(height: 54)
                .opacity(isPreparingPass ? 0.5 : 1)
                .overlay { if isPreparingPass { ProgressView().tint(.white) } }
                .accessibilityLabel("Add to Apple Wallet")
                Text("Pass details are sent to Lunet's signing service to create your pass. Nothing is stored.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let walletError {
                    Label(walletError, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.caution)
                }
            }

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
        .sheet(isPresented: Binding(get: { walletPass != nil }, set: { if !$0 { walletPass = nil } })) {
            if let walletPass { AddPassSheet(pass: walletPass).ignoresSafeArea() }
        }
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

    private func prepareWalletPass() async {
        isPreparingPass = true
        defer { isPreparingPass = false }
        do {
            let data = try await WalletPassService.makePass(for: pass, raw: result.code.raw, symbology: result.code.symbology)
            walletPass = try PKPass(data: data)
            walletError = nil
        } catch {
            walletError = String(localized: "Couldn't create a Wallet pass for this flight.")
        }
    }
}

#if DEBUG
#Preview { ResultPreview(.sampleTravel) }
#endif
