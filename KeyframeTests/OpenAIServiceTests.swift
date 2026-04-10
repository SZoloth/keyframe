import Testing
import Foundation
@testable import Keyframe

@Suite("OpenAI service configuration")
struct OpenAIServiceTests {

    @Test func platformEndpointIsPlatform() {
        let ep = OpenAIService.Endpoint.platform(apiKey: "sk-test123")
        #expect(ep.isPlatform == true)
    }

    @Test func codexBackendEndpointIsNotPlatform() {
        let ep = OpenAIService.Endpoint.codexBackend(accessToken: "tok", accountId: "acc-1")
        #expect(ep.isPlatform == false)
    }

    @Test func configureFromAuthModeNone() async {
        let service = OpenAIService()
        await service.configure(authMode: .none)
    }

    @Test func configureFromAuthModeAPIKey() async {
        let service = OpenAIService()
        await service.configure(authMode: .apiKey("sk-live-key"))
    }

    @Test func configureFromAuthModeOAuth() async {
        let service = OpenAIService()
        await service.configure(authMode: .oauth(accessToken: "token123", refreshToken: "rt_456", accountId: "acc-789"))
    }

    @Test func oauthWithoutAccountIdThrowsMissingAccountId() async {
        let service = OpenAIService()
        await service.configure(authMode: .oauth(accessToken: "token", refreshToken: nil, accountId: nil))
        do {
            _ = try await service.suggestScene(
                beatTitle: "Test", beatGuidance: "Test",
                style: .empty, characters: [], previousFrames: []
            )
            Issue.record("Should have thrown")
        } catch let error as OpenAIService.ServiceError {
            #expect(error == .missingAccountId)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func oauthWithEmptyAccountIdThrowsMissingAccountId() async {
        let service = OpenAIService()
        await service.configure(authMode: .oauth(accessToken: "token", refreshToken: nil, accountId: ""))
        do {
            _ = try await service.suggestScene(
                beatTitle: "Test", beatGuidance: "Test",
                style: .empty, characters: [], previousFrames: []
            )
            Issue.record("Should have thrown")
        } catch let error as OpenAIService.ServiceError {
            #expect(error == .missingAccountId)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
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

    // MARK: - Responses API parsing

    @Test func extractTextFromOutputArray() async throws {
        let service = OpenAIService()
        let json: [String: Any] = [
            "output": [
                [
                    "type": "message",
                    "content": [
                        ["type": "output_text", "text": "Hello, world!"]
                    ]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = try await service.extractTextFromResponsesAPI(data: data)
        #expect(result == "Hello, world!")
    }

    @Test func extractTextFromOutputTextFallback() async throws {
        let service = OpenAIService()
        let json: [String: Any] = [
            "output_text": "Fallback text"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = try await service.extractTextFromResponsesAPI(data: data)
        #expect(result == "Fallback text")
    }

    @Test func extractTextThrowsOnEmpty() async {
        let service = OpenAIService()
        let json: [String: Any] = ["output": []]
        let data = try! JSONSerialization.data(withJSONObject: json)
        do {
            _ = try await service.extractTextFromResponsesAPI(data: data)
            Issue.record("Should have thrown")
        } catch let error as OpenAIService.ServiceError {
            #expect(error == .noContent)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func extractImageFromResponseOutput() async throws {
        let service = OpenAIService()
        let testImageData = Data([0x89, 0x50, 0x4E, 0x47])
        let b64 = testImageData.base64EncodedString()
        let json: [String: Any] = [
            "output": [
                [
                    "type": "image_generation_call",
                    "result": b64
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let result = try await service.extractImageFromResponsesAPI(data: data)
        #expect(result == testImageData)
    }

    @Test func extractImageThrowsOnMissingImageData() async {
        let service = OpenAIService()
        let json: [String: Any] = [
            "output": [
                ["type": "message", "content": [["type": "output_text", "text": "no image"]]]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        do {
            _ = try await service.extractImageFromResponsesAPI(data: data)
            Issue.record("Should have thrown")
        } catch let error as OpenAIService.ServiceError {
            #expect(error == .imageGenerationFailed("No image data in response output"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Error descriptions

    @Test func serviceErrorDescriptions() {
        let errors: [OpenAIService.ServiceError] = [
            .noContent,
            .httpError(401, "Unauthorized"),
            .decodingError("bad json"),
            .imageGenerationFailed("no data"),
            .notAuthenticated,
            .missingAccountId,
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
        case (.missingAccountId, .missingAccountId): return true
        case (.httpError(let a, let b), .httpError(let c, let d)): return a == c && b == d
        case (.decodingError(let a), .decodingError(let b)): return a == b
        case (.imageGenerationFailed(let a), .imageGenerationFailed(let b)): return a == b
        default: return false
        }
    }
}
