import SwiftUI

@Observable
final class AppEnvironment {
    var errorMessage: String?
    var isShowingError: Bool = false

    func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}
