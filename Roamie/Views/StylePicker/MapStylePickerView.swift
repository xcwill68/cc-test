import SwiftUI

struct MapStylePickerView: View {
    @Binding var selected: PixelMapStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("地图风格")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(PixelMapStyle.allCases) { style in
                    StyleCard(style: style, isSelected: selected == style)
                        .onTapGesture {
                            selected = style
                        }
                }
            }
        }
    }
}

private struct StyleCard: View {
    let style: PixelMapStyle
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Preview block (placeholder pixel art preview)
            RoundedRectangle(cornerRadius: 8)
                .fill(style == .terrain
                    ? LinearGradient(colors: [Color(uiColor: .systemGreen).opacity(0.7),
                                              Color(uiColor: .systemBlue).opacity(0.5)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color(uiColor: .systemIndigo).opacity(0.6),
                                              Color(uiColor: .systemBlue).opacity(0.4)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 72, height: 56)
                .overlay(
                    Image(systemName: style.iconSystemName)
                        .font(.title3)
                        .foregroundStyle(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2.5)
                )

            Text(style.displayName)
                .font(.caption.bold())
                .foregroundStyle(isSelected ? .orange : .primary)
        }
    }
}
