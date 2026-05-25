import SwiftUI

extension View {
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.simultaneousGesture(TapGesture().onEnded {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        })
    }
}
