import Testing
import Foundation
@testable import Keyframe

@Suite("OpenAI service configuration")
struct OpenAIServiceTests {

    @Test func standardEndpointUsesAPIKey() {
        let ep = OpenAIService.Endpoint.standard(apiKey: "sk-test123")
        #expect(ep.baseURL == "https://api.openai.com/v1")
        #expect(ep.authHeader == "Bearer sk-test123")
    }

    @Test func oauthEndpointUsesAccessToken() {
        let ep = OpenAIService.Endpoint.oauth(accessToken: "eyJhbGci...")
        #expect(ep.baseURL == "https://api.openai.com/v1")
        #expect(ep.authHeader == "Bearer eyJhbGci...")
    }

    @Test func configureFromAuthModeNone() async {
        let service = OpenAIService()
        await service.configure(authMode: .none)
        // Should not crash; endpoint is nil internally
    }

    @Test func configureFromAuthModeAPIKey() async {
        let service = OpenAIService()
        await service.configure(authMode: .apiKey("sk-live-key"))
        // Configured without error
    }

    @Test func configureFromAuthModeOAuth() async {
        let service = OpenAIService()
        await service.configure(authMode: .oauth(accessToken: "token123", refreshToken: "rt_456"))
        // Configured without error
    }

    @Test func unconfiguredServiceThrowsNotAuthenticated() async {
        let service = OpenAIService()
        do {
            _ = try await service.suggestScene(
                beatTitle: "Test",
                beatGuidance: "Test",
                style: .empty,
                characters: [],
                previousFrames: []
            )
            Issue.record("Should have thrown")
        } catch let error as OpenAIService.ServiceError {
            #expect(error == .notAuthenticated)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func serviceErrorDescriptions() {
        let errors: [OpenAIService.ServiceError] = [
            .noContent,
            .httpError(401, "Unauthorized"),
            .decodingError("bad json"),
            .imageGenerationFailed("no data"),
            .notAuthenticated,
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}

extension OpenAIService.ServiceError: Equatable {
    public static func == (lhs: OpenAIService.ServiceError, rhs: OpenAIService.ServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.noContent, .noContent): return true
        case (.notAuthenticated, .notAuthenticated): return true
        case (.httpError(let a, let b), .httpError(let c, let d)): return a == c && b == d
        case (.decodingError(let a), .decodingError(let b)): return a == b
        case (.imageGenerationFailed(let a), .imageGenerationFailed(let b)): return a == b
        default: return false
        }
    }
}
