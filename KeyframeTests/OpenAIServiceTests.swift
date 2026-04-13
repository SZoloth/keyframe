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

    @Test func configureFromPlatformEndpoint() async {
        let service = OpenAIService()
        await service.configure(endpoint: .platform(apiKey: "sk-live-key"))
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

    @Test func platformEndpointConfigRoutesToPlatformEndpoint() async {
        let service = OpenAIService()
        await service.configure(endpoint: .platform(apiKey: "sk-test-key"))
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

        await service.configure(endpoint: .platform(apiKey: "sk-test"))
        #expect(await service.oauthMissingAccountId == false)
        #expect(await service.endpoint?.isPlatform == true)
    }

    @MainActor @Test func providerPrepareConfiguresCodexEndpointForRequest() async {
        let provider = AIServiceProvider()
        await provider.prepare(authMode: .oauth(
            accessToken: "tok-provider",
            refreshToken: "rt-provider",
            accountId: "acc-provider"
        ))

        let ep = await provider.service.endpoint
        guard case .codexBackend(let token, let accountId) = ep else {
            Issue.record("Expected codexBackend endpoint"); return
        }
        #expect(token == "tok-provider")
        #expect(accountId == "acc-provider")
        #expect(await provider.service.oauthMissingAccountId == false)
    }

    @MainActor @Test func providerPrepareMarksMissingAccountIdForRequest() async {
        let provider = AIServiceProvider()
        await provider.prepare(authMode: .oauth(
            accessToken: "tok-provider",
            refreshToken: "rt-provider",
            accountId: nil
        ))

        #expect(await provider.service.endpoint == nil)
        #expect(await provider.service.oauthMissingAccountId == true)
    }

    // MARK: - Model constants

    @Test func codexDefaultModelIsNotGpt4o() {
        #expect(OpenAIService.codexDefaultModel != "gpt-4o")
        #expect(OpenAIService.codexDefaultModel == "gpt-5.4-mini")
    }

    @Test func platformDefaultModelIsGpt4o() {
        #expect(OpenAIService.platformDefaultModel == "gpt-4o")
    }

    @Test func codexTextBodyMatchesBackendRequirements() throws {
        let system = "You are a storyboard scene director."
        let user = "Describe a rainy alley."
        let body = OpenAIService.buildCodexTextBody(
            system: system,
            user: user,
            model: OpenAIService.codexDefaultModel
        )

        #expect(body["model"] as? String == OpenAIService.codexDefaultModel)
        #expect(body["instructions"] as? String == system)
        #expect(body["store"] as? Bool == false)
        #expect(body["stream"] as? Bool == true)

        let input = body["input"] as? [[String: Any]]
        #expect(input?.count == 1)
        #expect(input?.first?["role"] as? String == "user")

        let content = input?.first?["content"] as? [[String: Any]]
        #expect(content?.count == 1)
        #expect(content?.first?["type"] as? String == "input_text")
        #expect(content?.first?["text"] as? String == user)
    }

    @Test func codexVisionBodyMatchesBackendRequirements() throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let body = OpenAIService.buildCodexVisionBody(
            userText: "Analyze this style",
            images: [imageData],
            model: OpenAIService.codexDefaultModel
        )

        #expect(body["model"] as? String == OpenAIService.codexDefaultModel)
        #expect(body["instructions"] as? String == "You are a visual style analyst.")
        #expect(body["store"] as? Bool == false)
        #expect(body["stream"] as? Bool == true)

        let input = body["input"] as? [[String: Any]]
        #expect(input?.count == 1)
        #expect(input?.first?["role"] as? String == "user")

        let content = input?.first?["content"] as? [[String: Any]]
        #expect(content?.count == 2)
        #expect(content?.first?["type"] as? String == "input_text")
        #expect(content?.first?["text"] as? String == "Analyze this style")
        #expect(content?.last?["type"] as? String == "input_image")
        #expect(content?.last?["image_url"] as? String == "data:image/png;base64,\(imageData.base64EncodedString())")
    }

    @Test func codexImageGenerationBodyMatchesBackendRequirements() throws {
        let body = OpenAIService.buildCodexImageGenerationBody(
            prompt: "anime",
            model: OpenAIService.codexDefaultModel
        )

        #expect(body["model"] as? String == OpenAIService.codexDefaultModel)
        #expect(body["instructions"] as? String == "Generate the requested image.")
        #expect(body["store"] as? Bool == false)
        #expect(body["stream"] as? Bool == true)

        let input = body["input"] as? [[String: Any]]
        #expect(input?.count == 1)
        #expect(input?.first?["role"] as? String == "user")

        let content = input?.first?["content"] as? [[String: Any]]
        #expect(content?.count == 1)
        #expect(content?.first?["type"] as? String == "input_text")
        #expect(content?.first?["text"] as? String == "Draw anime")

        let tools = body["tools"] as? [[String: Any]]
        #expect(tools?.count == 1)
        #expect(tools?.first?["type"] as? String == "image_generation")
        #expect(body["tool_choice"] == nil)
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

@Suite("OpenAI transport simulation", .serialized)
struct OpenAITransportSimulationTests {
    private static func completedLines(responseJSON: String) -> [String] {
        [
            "event: response.completed",
            "data: {\"type\":\"response.completed\",\"response\":\(responseJSON),\"sequence_number\":1}",
            ""
        ]
    }

    @Test func codexTextCompletionSendsStreamingRequestWithAuthHeaders() async throws {
        let transport = RecordingOpenAITransport(
            streamResponses: [
                .init(
                    statusCode: 200,
                    lines: Self.completedLines(
                        responseJSON: "{\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"A simulated scene.\"}]}]}"
                    )
                )
            ]
        )
        let service = OpenAIService(transport: transport)
        await service.configure(authMode: .oauth(accessToken: "tok-sim", refreshToken: nil, accountId: "acc-sim"))

        let result = try await service.suggestScene(
            beatTitle: "Opening",
            beatGuidance: "Introduce the space",
            style: .empty,
            characters: [],
            previousFrames: []
        )

        #expect(result == "A simulated scene.")

        guard let request = await transport.requests().first else {
            Issue.record("Expected a captured request"); return
        }

        #expect(request.url == "https://chatgpt.com/backend-api/codex/responses")
        #expect(request.method == "POST")
        #expect(request.headers["Authorization"] == "Bearer tok-sim")
        #expect(request.headers["chatgpt-account-id"] == "acc-sim")
        #expect(request.headers["Accept"] == "text/event-stream")
        #expect(request.headers["Content-Type"] == "application/json")

        let body = try request.jsonBody()
        #expect(body["model"] as? String == OpenAIService.codexDefaultModel)
        #expect(body["stream"] as? Bool == true)
        #expect(body["store"] as? Bool == false)
    }

    @Test func codexStreamingHTTPErrorPropagatesFromTransport() async {
        let transport = RecordingOpenAITransport(
            streamResponses: [
                .init(statusCode: 401, lines: ["{\"detail\":\"Unauthorized\"}"])
            ]
        )
        let service = OpenAIService(transport: transport)
        await service.configure(authMode: .oauth(accessToken: "tok-sim", refreshToken: nil, accountId: "acc-sim"))

        do {
            _ = try await service.suggestScene(
                beatTitle: "Opening",
                beatGuidance: "Introduce the space",
                style: .empty,
                characters: [],
                previousFrames: []
            )
            Issue.record("Should have thrown")
        } catch let error as OpenAIService.ServiceError {
            #expect(error == .httpError(401, "Unauthorized"))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func platformTextCompletionUsesNonStreamingTransport() async throws {
        let responseJSON: [String: Any] = [
            "choices": [
                ["message": ["content": "Platform response"]]
            ]
        ]
        let transport = RecordingOpenAITransport(
            dataResponses: [
                .init(
                    statusCode: 200,
                    body: try JSONSerialization.data(withJSONObject: responseJSON)
                )
            ]
        )
        let service = OpenAIService(transport: transport)
        await service.configure(endpoint: .platform(apiKey: "sk-platform"))

        let result = try await service.suggestScene(
            beatTitle: "Opening",
            beatGuidance: "Introduce the space",
            style: .empty,
            characters: [],
            previousFrames: []
        )

        #expect(result == "Platform response")

        guard let request = await transport.requests().first else {
            Issue.record("Expected a captured request"); return
        }

        #expect(request.url == "https://api.openai.com/v1/chat/completions")
        #expect(request.headers["Authorization"] == "Bearer sk-platform")
        #expect(request.headers["Accept"] == nil)

        let body = try request.jsonBody()
        #expect(body["model"] as? String == OpenAIService.platformDefaultModel)
        #expect(body["max_tokens"] as? Int == 300)
    }

    @Test func codexImageGenerationUsesImageToolThroughTransport() async throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let transport = RecordingOpenAITransport(
            streamResponses: [
                .init(
                    statusCode: 200,
                    lines: Self.completedLines(
                        responseJSON: "{\"output\":[{\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(imageData.base64EncodedString())\"}]}"
                    )
                )
            ]
        )
        let service = OpenAIService(transport: transport)
        await service.configure(authMode: .oauth(accessToken: "tok-sim", refreshToken: nil, accountId: "acc-sim"))

        let result = try await service.generateStyleReference(description: "Ink wash storyboard")
        #expect(result == imageData)

        guard let request = await transport.requests().first else {
            Issue.record("Expected a captured request"); return
        }

        let body = try request.jsonBody()
        let tools = body["tools"] as? [[String: Any]]
        #expect(tools?.first?["type"] as? String == "image_generation")

        let input = body["input"] as? [[String: Any]]
        let content = input?.first?["content"] as? [[String: Any]]
        let promptText = content?.first?["text"] as? String
        #expect(promptText?.contains("Draw Generate a single reference sketch") == true)
    }
}

// MARK: - SSE streaming parser tests

@Suite("SSE response parsing", .serialized)
struct SSEParsingTests {

    // Helper: wrap a response object in the real API event format.
    // The live Codex Backend sends response.completed as:
    //   {"type":"response.completed","response":{...},"sequence_number":N}
    // The parser must unwrap this to return just the inner response object.
    private static func wrapCompleted(_ responseJSON: String, seq: Int = 1) -> String {
        return "{\"type\":\"response.completed\",\"response\":\(responseJSON),\"sequence_number\":\(seq)}"
    }

    // --- Text completion ---

    @Test func textCompletionSSEParsesResponseCompleted() async throws {
        let responseJSON = """
        {"id":"resp_abc","object":"response","status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"A bustling kitchen scene."}]}],"output_text":"A bustling kitchen scene."}
        """
        let lines = [
            "event: response.created",
            "data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp_abc\",\"status\":\"in_progress\"}}",
            "",
            "event: response.output_item.added",
            "data: {\"type\":\"response.output_item.added\",\"item\":{\"type\":\"message\",\"content\":[]}}",
            "",
            "event: response.output_text.delta",
            "data: {\"type\":\"response.output_text.delta\",\"delta\":\"A bustling \"}",
            "",
            "event: response.output_text.delta",
            "data: {\"type\":\"response.output_text.delta\",\"delta\":\"kitchen scene.\"}",
            "",
            "event: response.completed",
            "data: \(Self.wrapCompleted(responseJSON, seq: 5))",
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

        let responseJSON = """
        {"id":"resp_img","object":"response","status":"completed","output":[{"type":"image_generation_call","status":"completed","result":"\(b64)"}]}
        """
        let lines = [
            "event: response.created",
            "data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp_img\",\"status\":\"in_progress\"}}",
            "",
            "event: response.output_item.added",
            "data: {\"type\":\"response.output_item.added\",\"item\":{\"type\":\"image_generation_call\",\"status\":\"in_progress\"}}",
            "",
            "event: response.output_item.done",
            "data: {\"type\":\"response.output_item.done\",\"item\":{\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}}",
            "",
            "event: response.completed",
            "data: \(Self.wrapCompleted(responseJSON, seq: 3))",
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
            "data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp_img2\",\"status\":\"in_progress\"}}",
            "",
            "event: response.output_item.added",
            "data: {\"type\":\"response.output_item.added\",\"item\":{\"type\":\"image_generation_call\",\"status\":\"in_progress\"}}",
            "",
            "event: response.output_item.done",
            "data: {\"type\":\"response.output_item.done\",\"item\":{\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}}",
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
            "data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp_x\"}}",
            "",
            "event: response.output_text.delta",
            "data: {\"type\":\"response.output_text.delta\",\"delta\":\"partial\"}",
            "",
        ]
        #expect(throws: OpenAIService.ServiceError.self) {
            try OpenAIService.parseSSEResponse(lines: lines)
        }
    }

    @Test func sseOutputTextFallbackWorksEndToEnd() async throws {
        let responseJSON = """
        {"id":"resp_ot","object":"response","status":"completed","output":[],"output_text":"Style: bold ink lines with flat color."}
        """
        let lines = [
            "event: response.completed",
            "data: \(Self.wrapCompleted(responseJSON))",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let text = try await service.extractTextFromResponsesAPI(data: data)
        #expect(text == "Style: bold ink lines with flat color.")
    }

    @Test func imageGenerationViaOutputItemDoneOnlyExtractsImage() async throws {
        let testImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let b64 = testImageData.base64EncodedString()

        let lines = [
            "event: response.created",
            "data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp_ig\",\"object\":\"response\",\"status\":\"in_progress\"}}",
            "",
            "event: response.output_item.added",
            "data: {\"type\":\"response.output_item.added\",\"output_index\":0,\"item\":{\"id\":\"ig_abc\",\"type\":\"image_generation_call\",\"status\":\"in_progress\"}}",
            "",
            "event: response.output_item.done",
            "data: {\"type\":\"response.output_item.done\",\"output_index\":0,\"item\":{\"id\":\"ig_abc\",\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}}",
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
            "data: {\"type\":\"response.output_item.done\",\"output_index\":0,\"item\":{\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}}",
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

        let responseJSON = "{\"id\":\"resp_lg\",\"object\":\"response\",\"status\":\"completed\",\"output\":[{\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}]}"
        let lines = [
            "event: response.completed",
            "data: \(Self.wrapCompleted(responseJSON, seq: 99))",
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
            "data: {\"type\":\"response.output_item.done\",\"output_index\":0,\"item\":{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"first\"}]}}",
            "",
            "event: response.output_item.done",
            "data: {\"type\":\"response.output_item.done\",\"output_index\":1,\"item\":{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"second\"}]}}",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let output = json?["output"] as? [[String: Any]]
        #expect(output?.count == 1)
    }

    @Test func sseCompletedEventTakesPriorityOverOutputItemDone() async throws {
        let responseJSON = "{\"id\":\"resp_c\",\"object\":\"response\",\"status\":\"completed\",\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"final answer\"}]}]}"
        let lines = [
            "event: response.output_item.done",
            "data: {\"type\":\"response.output_item.done\",\"output_index\":0,\"item\":{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"stale\"}]}}",
            "",
            "event: response.completed",
            "data: \(Self.wrapCompleted(responseJSON, seq: 7))",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let text = try await service.extractTextFromResponsesAPI(data: data)
        #expect(text == "final answer")
    }

    // --- Realistic full SSE stream (matches captured Codex Backend response) ---

    @Test func realisticCodexBackendTextStream() async throws {
        let lines = [
            "event: response.created",
            "data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp_03a6\",\"object\":\"response\",\"created_at\":1775853744,\"status\":\"in_progress\",\"background\":false,\"output\":[]}}",
            "",
            "event: response.in_progress",
            "data: {\"type\":\"response.in_progress\",\"response\":{\"id\":\"resp_03a6\",\"object\":\"response\",\"created_at\":1775853744,\"status\":\"in_progress\"}}",
            "",
            "event: response.output_item.added",
            "data: {\"type\":\"response.output_item.added\",\"item\":{\"id\":\"msg_abc\",\"type\":\"message\",\"status\":\"in_progress\",\"content\":[],\"role\":\"assistant\"},\"output_index\":0}",
            "",
            "event: response.content_part.added",
            "data: {\"type\":\"response.content_part.added\",\"content_index\":0,\"item_id\":\"msg_abc\",\"output_index\":0,\"part\":{\"type\":\"output_text\",\"annotations\":[],\"text\":\"\"}}",
            "",
            "event: response.output_text.delta",
            "data: {\"type\":\"response.output_text.delta\",\"content_index\":0,\"delta\":\"Bold\",\"item_id\":\"msg_abc\",\"output_index\":0}",
            "",
            "event: response.output_text.delta",
            "data: {\"type\":\"response.output_text.delta\",\"content_index\":0,\"delta\":\" ink\",\"item_id\":\"msg_abc\",\"output_index\":0}",
            "",
            "event: response.output_text.delta",
            "data: {\"type\":\"response.output_text.delta\",\"content_index\":0,\"delta\":\" style.\",\"item_id\":\"msg_abc\",\"output_index\":0}",
            "",
            "event: response.output_text.done",
            "data: {\"type\":\"response.output_text.done\",\"content_index\":0,\"item_id\":\"msg_abc\",\"output_index\":0,\"text\":\"Bold ink style.\"}",
            "",
            "event: response.content_part.done",
            "data: {\"type\":\"response.content_part.done\",\"content_index\":0,\"item_id\":\"msg_abc\",\"output_index\":0,\"part\":{\"type\":\"output_text\",\"annotations\":[],\"text\":\"Bold ink style.\"}}",
            "",
            "event: response.output_item.done",
            "data: {\"type\":\"response.output_item.done\",\"item\":{\"id\":\"msg_abc\",\"type\":\"message\",\"status\":\"completed\",\"content\":[{\"type\":\"output_text\",\"annotations\":[],\"text\":\"Bold ink style.\"}],\"role\":\"assistant\"},\"output_index\":0}",
            "",
            "event: response.completed",
            "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_03a6\",\"object\":\"response\",\"created_at\":1775853744,\"status\":\"completed\",\"output\":[{\"id\":\"msg_abc\",\"type\":\"message\",\"status\":\"completed\",\"content\":[{\"type\":\"output_text\",\"annotations\":[],\"text\":\"Bold ink style.\"}],\"role\":\"assistant\"}]},\"sequence_number\":290}",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let text = try await service.extractTextFromResponsesAPI(data: data)
        #expect(text == "Bold ink style.")
    }

    @Test func realisticCodexBackendImageStream() async throws {
        let testImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])
        let b64 = testImageData.base64EncodedString()

        let lines = [
            "event: response.created",
            "data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp_img7\",\"object\":\"response\",\"created_at\":1775854000,\"status\":\"in_progress\",\"output\":[]}}",
            "",
            "event: response.in_progress",
            "data: {\"type\":\"response.in_progress\",\"response\":{\"id\":\"resp_img7\",\"status\":\"in_progress\"}}",
            "",
            "event: response.output_item.added",
            "data: {\"type\":\"response.output_item.added\",\"item\":{\"id\":\"ig_xyz\",\"type\":\"image_generation_call\",\"status\":\"in_progress\"},\"output_index\":0}",
            "",
            "event: response.output_item.done",
            "data: {\"type\":\"response.output_item.done\",\"item\":{\"id\":\"ig_xyz\",\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\",\"revised_prompt\":\"A watercolor landscape with rolling hills\"},\"output_index\":0}",
            "",
            "event: response.completed",
            "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_img7\",\"object\":\"response\",\"created_at\":1775854000,\"status\":\"completed\",\"output\":[{\"id\":\"ig_xyz\",\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\",\"revised_prompt\":\"A watercolor landscape with rolling hills\"}]},\"sequence_number\":5}",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let imageData = try await service.extractImageFromResponsesAPI(data: data)
        #expect(imageData == testImageData)
    }

    @Test func realisticModelDeclinesImageGeneration() async throws {
        let lines = [
            "event: response.created",
            "data: {\"type\":\"response.created\",\"response\":{\"id\":\"resp_decline\",\"object\":\"response\",\"status\":\"in_progress\",\"output\":[]}}",
            "",
            "event: response.output_item.added",
            "data: {\"type\":\"response.output_item.added\",\"item\":{\"id\":\"msg_d\",\"type\":\"message\",\"status\":\"in_progress\",\"content\":[]},\"output_index\":0}",
            "",
            "event: response.output_text.delta",
            "data: {\"type\":\"response.output_text.delta\",\"delta\":\"I can help but I can't generate that image.\",\"item_id\":\"msg_d\",\"output_index\":0}",
            "",
            "event: response.output_item.done",
            "data: {\"type\":\"response.output_item.done\",\"item\":{\"id\":\"msg_d\",\"type\":\"message\",\"status\":\"completed\",\"content\":[{\"type\":\"output_text\",\"text\":\"I can help but I can't generate that image.\"}]},\"output_index\":0}",
            "",
            "event: response.completed",
            "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_decline\",\"object\":\"response\",\"status\":\"completed\",\"output\":[{\"id\":\"msg_d\",\"type\":\"message\",\"status\":\"completed\",\"content\":[{\"type\":\"output_text\",\"text\":\"I can help but I can't generate that image.\"}]}]},\"sequence_number\":50}",
            "",
        ]

        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()

        do {
            _ = try await service.extractImageFromResponsesAPI(data: data)
            Issue.record("Should have thrown — model returned text, not an image")
        } catch let error as OpenAIService.ServiceError {
            #expect(error == .imageGenerationFailed("No image data in response output"))
        }
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

        // Simulate SSE response for scene suggestion (real API format)
        let sceneSuggestionSSE = [
            "event: response.completed",
            "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_scene\",\"object\":\"response\",\"status\":\"completed\",\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"A dark alley illuminated by neon signs.\"}]}]},\"sequence_number\":12}",
            "",
        ]
        let sceneData = try OpenAIService.parseSSEResponse(lines: sceneSuggestionSSE)
        let sceneText = try await service.extractTextFromResponsesAPI(data: sceneData)
        #expect(sceneText == "A dark alley illuminated by neon signs.")

        // Simulate SSE response for image generation (real API format)
        let fakeImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])
        let b64 = fakeImageData.base64EncodedString()
        let imageSSE = [
            "event: response.completed",
            "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_img_e2e\",\"object\":\"response\",\"status\":\"completed\",\"output\":[{\"type\":\"image_generation_call\",\"status\":\"completed\",\"result\":\"\(b64)\"}]},\"sequence_number\":5}",
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

private struct CapturedRequest: Sendable {
    let url: String
    let method: String
    let headers: [String: String]
    let bodyData: Data?

    init(_ request: URLRequest) {
        self.url = request.url?.absoluteString ?? ""
        self.method = request.httpMethod ?? ""
        self.headers = request.allHTTPHeaderFields ?? [:]
        self.bodyData = request.httpBody
    }

    func jsonBody() throws -> [String: Any] {
        guard let bodyData else { return [:] }
        return try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] ?? [:]
    }
}

private actor RecordingOpenAITransport: OpenAITransport {
    private var dataResponses: [OpenAIHTTPResponse]
    private var streamResponses: [OpenAIHTTPStreamResponse]
    private var capturedRequests: [CapturedRequest] = []

    init(
        dataResponses: [OpenAIHTTPResponse] = [],
        streamResponses: [OpenAIHTTPStreamResponse] = []
    ) {
        self.dataResponses = dataResponses
        self.streamResponses = streamResponses
    }

    func data(for request: URLRequest) async throws -> OpenAIHTTPResponse {
        capturedRequests.append(CapturedRequest(request))
        guard !dataResponses.isEmpty else {
            return OpenAIHTTPResponse(statusCode: 500, body: Data())
        }
        return dataResponses.removeFirst()
    }

    func stream(for request: URLRequest) async throws -> OpenAIHTTPStreamResponse {
        capturedRequests.append(CapturedRequest(request))
        guard !streamResponses.isEmpty else {
            return OpenAIHTTPStreamResponse(statusCode: 500, lines: [])
        }
        return streamResponses.removeFirst()
    }

    func requests() -> [CapturedRequest] {
        capturedRequests
    }
}
