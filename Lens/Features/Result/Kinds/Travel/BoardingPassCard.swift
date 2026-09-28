import SwiftUI

/// A boarding pass drawn like the paper one: airline and flight, a big route, then the details grid.
struct BoardingPassCard: View {
    var pass: BoardingPass
    var date: Date?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(16)
            route
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            perforation
            details
                .padding(16)
        }
        .background(.fill.tertiary, in: .rect(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        // "Norte Air … NR 412", or just "NR 412" when the airline isn't one Lens knows by name.
        HStack {
            Label {
                Text(pass.airlineName ?? pass.flightDesignator)
                    .fontDesign(pass.airlineName == nil ? .monospaced : .default)
            } icon: {
                Image(systemName: "airplane")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(CodeKind.travel.tint)
            Spacer()
            if pass.airlineName != nil {
                Text(pass.flightDesignator)
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.monospaced)
            }
        }
    }

    private var route: some View {
        HStack(alignment: .top) {
            airport(pass.from, alignment: .leading)
            Spacer(minLength: 8)
            Image(systemName: "airplane")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .accessibilityLabel("to")
            Spacer(minLength: 8)
            airport(pass.to, alignment: .trailing)
        }
    }

    private func airport(_ code: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(code)
                .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let city = TravelDirectory.city(for: code) {
                Text(city)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Dashed tear line between the stub and the details.
    private var perforation: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(.separator)
            .frame(height: 1)
            .padding(.horizontal, 16)
            .accessibilityHidden(true)
    }

    private var details: some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 3
        let items = detailItems
        return Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(Array(items[start..<min(start + columns, items.count)].enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 4) {
                            MicroLabel(item.label)
                            Text(item.value)
                                .font(.headline)
                                .fontDesign(item.monospaced ? .monospaced : .default)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private struct Item {
        var label: LocalizedStringKey
        var value: String
        var monospaced = false
    }

    private var detailItems: [Item] {
        var items = [Item(label: "Passenger", value: pass.displayName)]
        if let date {
            items.append(Item(label: "Date", value: date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))))
        }
        if !pass.seat.isEmpty { items.append(Item(label: "Seat", value: pass.seat, monospaced: true)) }
        if !pass.cabinName.isEmpty { items.append(Item(label: "Cabin", value: pass.cabinName)) }
        if !pass.sequence.isEmpty { items.append(Item(label: "Sequence", value: pass.sequence, monospaced: true)) }
        if !pass.bookingReference.isEmpty { items.append(Item(label: "Booking", value: pass.bookingReference, monospaced: true)) }
        return items
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}
