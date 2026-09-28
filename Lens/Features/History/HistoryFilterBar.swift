import SwiftUI

/// Horizontally scrolling filter chips: All, Pinned, Created, then kinds.
struct HistoryFilterBar: View {
    @Binding var selection: HistoryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HistoryFilter.chips) { chip in
                    chipButton(chip)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chipButton(_ chip: HistoryFilter) -> some View {
        let isSelected = chip == selection
        return Button {
            withAnimation(.snappy) { selection = chip }
        } label: {
            Text(chip.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Palette.onTint : Color.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(isSelected ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(.fill.tertiary), in: .capsule)
                .padding(.vertical, 5)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview {
    @Previewable @State var filter = HistoryFilter.all
    HistoryFilterBar(selection: $filter)
}
#endif
