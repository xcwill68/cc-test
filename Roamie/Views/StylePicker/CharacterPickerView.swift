import SwiftUI

struct CharacterPickerView: View {
    @Binding var selected: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("旅行角色")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CharacterAsset.allCases) { character in
                        CharacterCard(character: character,
                                      isSelected: selected == character.assetName)
                            .onTapGesture { selected = character.assetName }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

private struct CharacterCard: View {
    let character: CharacterAsset
    let isSelected: Bool
    @State private var animFrame: Int = 0
    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                        ? Color.orange.opacity(0.15)
                        : Color.secondary.opacity(0.08))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                    )
                // Show emoji as stand-in for real sprite
                Text(character.emoji)
                    .font(.largeTitle)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            Text(character.displayName)
                .font(.caption.bold())
                .foregroundStyle(isSelected ? .orange : .primary)
        }
        .onReceive(timer) { _ in
            animFrame = (animFrame + 1) % character.frameCount
        }
    }
}
