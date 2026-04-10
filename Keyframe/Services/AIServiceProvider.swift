import Foundation
import Observation

@MainActor
@Observable
final class AIServiceProvider {
    let service = OpenAIService()

    func configure(authMode: AuthMode) {
        Task { await service.configure(authMode: authMode) }
    }
}
