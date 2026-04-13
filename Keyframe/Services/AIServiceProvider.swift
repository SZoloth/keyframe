import Foundation
import Observation

@MainActor
@Observable
final class AIServiceProvider {
    let service = OpenAIService()

    func prepare(authMode: AuthMode) async {
        await service.configure(authMode: authMode)
    }

    func configure(authMode: AuthMode) {
        Task { await prepare(authMode: authMode) }
    }
}
