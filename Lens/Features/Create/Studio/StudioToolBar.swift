import SwiftUI

/// The studio's tool switcher: glyph over name, like Photos' edit tools. The selection slides
/// between tools.
struct StudioToolBar: View {
    @Binding var selection: StudioTool
    var tools: [StudioTool]

    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tools) { tool in
                let isSelected = tool == selection
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = tool }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(height: 22)
                            .symbolEffect(.bounce, value: isSelected)
                        Text(tool.title)
                            .font(.caption.weight(isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(light: 0xFFFFFF, dark: 0x3A3A3C))
                                .matchedGeometryEffect(id: "selection", in: highlight)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(.fill.tertiary, in: .rect(cornerRadius: 18, style: .continuous))
        // Six tools share one row; like a tab bar, it stops growing at the largest non-accessibility size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

extension StudioTool {
    var symbol: String {
        switch self {
        case .looks: "sparkles"
        case .dots: "circle.grid.3x3.fill"
        case .corners: "viewfinder"
        case .color: "paintpalette.fill"
        case .logo: "photo"
        case .frame: "text.below.photo"
        }
    }
}

#Preview {
    @Previewable @State var tool = StudioTool.dots
    StudioToolBar(selection: $tool, tools: StudioTool.allCases)
        .padding()
}
