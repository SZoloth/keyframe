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

    // MARK: - Endpoint routing by auth mode

    @Test func apiKeyRoutesToPlatformEndpoint() async {
        let service = OpenAIService()
        await service.configure(authMode: .apiKey("sk-test-key"))
        let ep = await service.endpoint
        guard case .platform(let key) = ep else {
            Issue.record("Expected platform endpoint"); return
        }
        #expect(key == "sk-test-key")
    }

    @Test func oauthRoutesToCodexBackendEndpoint() async {
        let service = OpenAIService()
        await service.configure(authMode: .oauth(accessToken: "tok", refreshToken: "rt", accountId: "acc-42"))
        let ep = await service.endpoint
        guard case .codexBackend(let token, let accountId) = ep else {
            Issue.record("Expected codexBackend endpoint"); return
        }
        #expect(token == "tok")
        #expect(accountId == "acc-42")
    }

    @Test func oauthWithNilAccountIdSetsFlag() async {
        let service = OpenAIService()
        await service.configure(authMode: .oauth(accessToken: "tok", refreshToken: nil, accountId: nil))
        let ep = await service.endpoint
        let flag = await service.oauthMissingAccountId
        #expect(ep == nil)
        #expect(flag == true)
    }

    @Test func oauthWithEmptyAccountIdSetsFlag() async {
        let service = OpenAIService()
        await service.configure(authMode: .oauth(accessToken: "tok", refreshToken: nil, accountId: ""))
        let ep = await service.endpoint
        let flag = await service.oauthMissingAccountId
        #expect(ep == nil)
        #expect(flag == true)
    }

    @Test func reconfigureResetsFlag() async {
        let service = OpenAIService()
        await service.configure(authMode: .oauth(accessToken: "tok", refreshToken: nil, accountId: nil))
        #expect(await service.oauthMissingAccountId == true)

        await service.configure(authMode: .apiKey("sk-test"))
        #expect(await service.oauthMissingAccountId == false)
        #expect(await service.endpoint?.isPlatform == true)
    }

    // MARK: - Model constants

    @Test func codexDefaultModelIsNotGpt4o() {
        #expect(OpenAIService.codexDefaultModel != "gpt-4o")
        #expect(OpenAIService.codexDefaultModel == "gpt-5.4-mini")
    }

    @Test func platformDefaultModelIsGpt4o() {
        #expect(OpenAIService.platformDefaultModel == "gpt-4o")
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

// MARK: - SSE streaming parser tests

@Suite("SSE response parsing", .serialized)
struct SSEParsingTests {

    // --- Text completion ---

    @Test func textCompletionSSEParsesResponseCompleted() async throws {
        let completedJSON = """
        {"id":"resp_abc","object":"response","status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"A bustling kitchen scene."}]}],"output_text":"A bustling kitchen scene."}
        """
        let lines = [
            "event: response.created",
            "data: {\"id\":\"resp_abc\",\"status\":\"in_progress\"}",
            "",
            "event: response.output_item.added",
            "data: {\"type\":\"message\",\"content\":[]}",
            "",
            "event: response.output_text.delta",
            "data: {\"delta\":\"A bustling \"}",
            "",
            "event: response.output_text.delta",
            "data: {\"delta\":\"kitchen scene.\"}",
            "",
            "event: response.completed",
            "data: \(completedJSON)",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let text = try await service.extractTextFromResponsesAPI(data: data)
        #expect(text == "A bustling kitchen scene.")
    }

    // --- Image generation ---

    @Test func imageGenerationSSEParsesFromResponseCompleted() async throws {
        let testImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])
        let b64 = testImageData.base64EncodedString()

        let completedJSON = """
        {"id":"resp_img","object":"response","status":"completed","output":[{"type":"image_generation_call","status":"completed","result":"\(b64)"}]}
        """
        let lines = [
            "event: response.created",
            "data: {\"id\":\"resp_img\",\"status\":\"in_progress\"}",
            "",
            "event: response.output_item.added",
            "data: {\"type\":\"image_generation_call\",\"status\":\"in_progress\"}",
            "",
            "event: response.output_item.done",
            "data: {\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}",
            "",
            "event: response.completed",
            "data: \(completedJSON)",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let imageData = try await service.extractImageFromResponsesAPI(data: data)
        #expect(imageData == testImageData)
    }

    @Test func imageGenerationSSEFallsBackToOutputItemDone() async throws {
        let testImageData = Data([0x89, 0x50, 0x4E, 0x47])
        let b64 = testImageData.base64EncodedString()

        let lines = [
            "event: response.created",
            "data: {\"id\":\"resp_img2\",\"status\":\"in_progress\"}",
            "",
            "event: response.output_item.added",
            "data: {\"type\":\"image_generation_call\",\"status\":\"in_progress\"}",
            "",
            "event: response.output_item.done",
            "data: {\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let imageData = try await service.extractImageFromResponsesAPI(data: data)
        #expect(imageData == testImageData)
    }

    // --- Edge cases ---

    @Test func emptySSEStreamThrowsNoContent() {
        let lines: [String] = []
        #expect(throws: OpenAIService.ServiceError.self) {
            try OpenAIService.parseSSEResponse(lines: lines)
        }
    }

    @Test func sseWithOnlyDeltasAndNoCompletedThrows() {
        let lines = [
            "event: response.created",
            "data: {\"id\":\"resp_x\"}",
            "",
            "event: response.output_text.delta",
            "data: {\"delta\":\"partial\"}",
            "",
        ]
        #expect(throws: OpenAIService.ServiceError.self) {
            try OpenAIService.parseSSEResponse(lines: lines)
        }
    }

    @Test func sseOutputTextFallbackWorksEndToEnd() async throws {
        let completedJSON = """
        {"id":"resp_ot","object":"response","status":"completed","output":[],"output_text":"Style: bold ink lines with flat color."}
        """
        let lines = [
            "event: response.completed",
            "data: \(completedJSON)",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let text = try await service.extractTextFromResponsesAPI(data: data)
        #expect(text == "Style: bold ink lines with flat color.")
    }

    @Test func imageGenerationViaOutputItemDoneOnlyExtractsImage() async throws {
        // Realistic scenario: Codex backend sends output_item.done with flat structure, no response.completed
        let testImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let b64 = testImageData.base64EncodedString()

        let lines = [
            "event: response.created",
            "data: {\"id\":\"resp_ig\",\"object\":\"response\",\"status\":\"in_progress\"}",
            "",
            "event: response.output_item.added",
            "data: {\"output_index\":0,\"item\":{\"id\":\"ig_abc\",\"type\":\"image_generation_call\",\"status\":\"in_progress\"}}",
            "",
            "event: response.output_item.done",
            "data: {\"output_index\":0,\"item\":{\"id\":\"ig_abc\",\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}}",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let imageData = try await service.extractImageFromResponsesAPI(data: data)
        #expect(imageData == testImageData)
    }

    @Test func sseWithNestedItemFallbackExtractsImage() async throws {
        let testImageData = Data([0xFF, 0xD8, 0xFF])
        let b64 = testImageData.base64EncodedString()

        let lines = [
            "event: response.output_item.done",
            "data: {\"output_index\":0,\"item\":{\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}}",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let imageData = try await service.extractImageFromResponsesAPI(data: data)
        #expect(imageData == testImageData)
    }

    @Test func sseWithLargeBase64ImagePayload() async throws {
        let largeImageData = Data(repeating: 0xAB, count: 200_000)
        let b64 = largeImageData.base64EncodedString()

        let lines = [
            "event: response.completed",
            "data: {\"id\":\"resp_lg\",\"output\":[{\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}]}",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let imageData = try await service.extractImageFromResponsesAPI(data: data)
        #expect(imageData == largeImageData)
    }

    @Test func sseWithMultipleOutputItemDoneKeepsLast() throws {
        let lines = [
            "event: response.output_item.done",
            "data: {\"output_index\":0,\"item\":{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"first\"}]}}",
            "",
            "event: response.output_item.done",
            "data: {\"output_index\":1,\"item\":{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"second\"}]}}",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let output = json?["output"] as? [[String: Any]]
        #expect(output?.count == 1)
    }

    @Test func sseCompletedEventTakesPriorityOverOutputItemDone() async throws {
        let lines = [
            "event: response.output_item.done",
            "data: {\"output_index\":0,\"item\":{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"stale\"}]}}",
            "",
            "event: response.completed",
            "data: {\"id\":\"resp_c\",\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"final answer\"}]}]}",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let text = try await service.extractTextFromResponsesAPI(data: data)
        #expect(text == "final answer")
    }
}

// MARK: - End-to-end Codex flow (model + routing + SSE)

@Suite("End-to-end Codex flow", .serialized)
struct CodexEndToEndTests {

    @Test func fullPhaseWalkthroughWithCodexBackendAndSSE() async throws {
        let state = await AppState()

        // Setup: OAuth auth
        await MainActor.run {
            state.authMode = .oauth(accessToken: "ey_test", refreshToken: "rt", accountId: "acc-99")
        }
        let isAuth = await state.isAuthenticated
        #expect(isAuth == true)

        // Verify routing goes to Codex backend
        let service = OpenAIService()
        await service.configure(authMode: await state.authMode)
        let ep = await service.endpoint
        guard case .codexBackend(let token, let accountId) = ep else {
            Issue.record("Expected codexBackend endpoint"); return
        }
        #expect(token == "ey_test")
        #expect(accountId == "acc-99")

        // Verify model selection
        #expect(OpenAIService.codexDefaultModel == "gpt-5.4-mini")

        // Style: lock with description only
        await MainActor.run {
            state.setPhase(.style)
            state.setStyleDescription("Bold ink lines, cinematic")
            state.lockStyle()
        }
        let phase1 = await state.project.currentPhase
        #expect(phase1 == .cast)

        // Cast: add character without visual description
        await MainActor.run {
            state.addCharacter(StoryboardCharacter(name: "Zara", role: "Lead", visualDescription: ""))
        }
        let canFrames = await state.canAdvanceToPhase(.frames)
        #expect(canFrames == true)

        // Select template and advance to frames
        await MainActor.run {
            state.selectTemplate("problem-solution")
            state.setPhase(.frames)
        }

        // Simulate SSE response for scene suggestion
        let sceneSuggestionSSE = [
            "event: response.completed",
            "data: {\"id\":\"resp_scene\",\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"A dark alley illuminated by neon signs.\"}]}]}",
            "",
        ]
        let sceneData = try OpenAIService.parseSSEResponse(lines: sceneSuggestionSSE)
        let sceneText = try await service.extractTextFromResponsesAPI(data: sceneData)
        #expect(sceneText == "A dark alley illuminated by neon signs.")

        // Simulate SSE response for image generation
        let fakeImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])
        let b64 = fakeImageData.base64EncodedString()
        let imageSSE = [
            "event: response.output_item.done",
            "data: {\"output_index\":0,\"item\":{\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}}",
            "",
        ]
        let imgSSEData = try OpenAIService.parseSSEResponse(lines: imageSSE)
        let generatedImage = try await service.extractImageFromResponsesAPI(data: imgSSEData)
        #expect(generatedImage == fakeImageData)

        // Mark frame complete
        let frameId = await state.project.frames[0].id
        await MainActor.run {
            state.updateFrame(frameId, sceneDescription: sceneText, imageData: generatedImage, status: .complete)
        }
        let canExport = await state.canAdvanceToPhase(.export)
        #expect(canExport == true)

        // Advance to export
        await MainActor.run { state.setPhase(.export) }
        let finalPhase = await state.project.currentPhase
        #expect(finalPhase == .export)
    }

    @Test func fullPhaseWalkthroughWithPlatformAPI() async throws {
        let state = await AppState()

        // Setup: API key auth
        await MainActor.run {
            state.authMode = .apiKey("sk-test-platform")
        }
        let isAuth = await state.isAuthenticated
        #expect(isAuth == true)

        // Verify routing goes to platform
        let service = OpenAIService()
        await service.configure(authMode: await state.authMode)
        let ep = await service.endpoint
        guard case .platform(let key) = ep else {
            Issue.record("Expected platform endpoint"); return
        }
        #expect(key == "sk-test-platform")
        #expect(OpenAIService.platformDefaultModel == "gpt-4o")

        // Style: lock with image + description
        await MainActor.run {
            state.setPhase(.style)
            state.addReferenceImage(Data([1, 2, 3]))
            state.setStyleDescription("Pencil sketch with watercolor wash")
            state.lockStyle()
        }
        let phase1 = await state.project.currentPhase
        #expect(phase1 == .cast)

        // Cast: add character with full details
        await MainActor.run {
            state.addCharacter(StoryboardCharacter(name: "Max", role: "Protagonist", visualDescription: "Tall with glasses", referenceImageData: Data([4, 5])))
        }
        let canFrames = await state.canAdvanceToPhase(.frames)
        #expect(canFrames == true)

        // Select template and advance to frames
        await MainActor.run {
            state.selectTemplate("raskin-pitch")
            state.setPhase(.frames)
        }
        let frameCount = await state.project.frames.count
        #expect(frameCount == 5)

        // Mark a frame complete
        let frameId = await state.project.frames[0].id
        await MainActor.run {
            state.updateFrame(frameId, sceneDescription: "Boardroom scene", imageData: Data([6, 7, 8]), status: .complete)
        }
        let canExport = await state.canAdvanceToPhase(.export)
        #expect(canExport == true)

        await MainActor.run { state.setPhase(.export) }
        let finalPhase = await state.project.currentPhase
        #expect(finalPhase == .export)
    }
}

extension OpenAIService.ServiceError: @retroactive Equatable {
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
