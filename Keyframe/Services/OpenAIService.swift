import Foundation

actor OpenAIService {

    enum Endpoint {
        case platform(apiKey: String)
        case codexBackend(accessToken: String, accountId: String)

        var isPlatform: Bool {
            if case .platform = self { return true }
            return false
        }
    }

    enum ServiceError: LocalizedError {
        case noContent
        case httpError(Int, String)
        case decodingError(String)
        case imageGenerationFailed(String)
        case notAuthenticated
        case missingAccountId

        var errorDescription: String? {
            switch self {
            case .noContent: return "No content in API response"
            case .httpError(let code, let msg): return "API error \(code): \(msg)"
            case .decodingError(let msg): return "Failed to decode response: \(msg)"
            case .imageGenerationFailed(let msg): return "Image generation failed: \(msg)"
            case .notAuthenticated: return "Not authenticated"
            case .missingAccountId: return "ChatGPT account ID not found. Please sign out and sign in again."
            }
        }
    }

    private var endpoint: Endpoint?

    func configure(endpoint: Endpoint) {
        self.endpoint = endpoint
    }

    private var oauthMissingAccountId = false

    func configure(authMode: AuthMode) {
        oauthMissingAccountId = false
        switch authMode {
        case .none:
            endpoint = nil
        case .apiKey(let key):
            endpoint = .platform(apiKey: key)
        case .oauth(let accessToken, _, let accountId):
            if let accountId, !accountId.isEmpty {
                endpoint = .codexBackend(accessToken: accessToken, accountId: accountId)
            } else {
                endpoint = nil
                oauthMissingAccountId = true
            }
        }
    }

    // MARK: - Scene suggestion

    func suggestScene(
        beatTitle: String,
        beatGuidance: String,
        style: StyleDefinition,
        characters: [StoryboardCharacter],
        previousFrames: [StoryboardFrame]
    ) async throws -> String {
        let characterList = characters
            .map { "- \($0.name) (\($0.role)): \($0.visualDescription)" }
            .joined(separator: "\n")

        let previousContext = previousFrames
            .compactMap { frame -> String? in
                guard let desc = frame.sceneDescription, !desc.isEmpty else { return nil }
                return "Frame \"\(frame.beatTitle)\": \(desc)"
            }
            .enumerated()
            .map { "Frame \($0.offset + 1) \($0.element)" }
            .joined(separator: "\n")

        let system = """
        You are a storyboard scene director. Your job is to suggest vivid, specific scene descriptions that will be turned into illustrations.

        Style context:
        \(style.description.isEmpty ? "No style defined yet" : style.description)

        Cast of characters:
        \(characterList.isEmpty ? "No characters defined" : characterList)

        Guidelines:
        - Be specific about character positions, expressions, and actions
        - Include environmental details that support the story beat
        - Keep descriptions concise but visually rich
        - Don't describe camera angles or technical film terminology
        - Focus on what we SEE, not what we think or feel
        """

        let user = """
        Create a scene description for this storyboard beat:

        Beat: "\(beatTitle)"
        Guidance: \(beatGuidance)

        \(previousContext.isEmpty ? "This is the first frame." : "Previous frames for context:\n\(previousContext)")

        Describe the scene in 2-3 sentences. Be specific and visual.
        """

        return try await textCompletion(system: system, user: user)
    }

    // MARK: - Scene refinement

    func refineScene(
        currentScene: String,
        userFeedback: String,
        style: StyleDefinition,
        characters: [StoryboardCharacter]
    ) async throws -> String {
        let system = "You are a storyboard scene director. Refine the scene description based on the user's feedback while maintaining consistency with the established style and characters."

        let user = """
        Current scene description:
        \(currentScene)

        User feedback:
        \(userFeedback)

        Provide an updated scene description that incorporates the feedback. Keep it to 2-3 sentences.
        """

        return try await textCompletion(system: system, user: user)
    }

    // MARK: - Frame image generation

    func generateFrameImage(
        sceneDescription: String,
        style: StyleDefinition,
        characters: [StoryboardCharacter]
    ) async throws -> Data {
        let characterList = characters
            .map { "\($0.name): \($0.visualDescription)" }
            .joined(separator: ". ")

        let prompt = """
        \(style.description)

        Scene: \(sceneDescription)

        Characters in scene: \(characterList.isEmpty ? "None" : characterList)

        Create a storyboard illustration matching the style description exactly. The image should clearly depict the described scene with consistent character appearances.
        """

        return try await imageGeneration(prompt: prompt)
    }

    // MARK: - Style reference generation

    func generateStyleReference(description: String) async throws -> Data {
        let prompt = """
        Generate a single reference sketch that demonstrates this visual style:

        \(description)

        This image will be used as a style reference for a storyboard. Create a simple scene that clearly shows: line quality, shading technique, level of detail, and overall aesthetic.
        """

        return try await imageGeneration(prompt: prompt)
    }

    // MARK: - Style analysis (vision)

    func analyzeStyle(referenceImages: [Data]) async throws -> String {
        let prompt = """
        Analyze these reference images and describe the visual style in detail. Focus on:
        - Line quality (bold, sketchy, clean, rough)
        - Shading technique (cross-hatching, gradients, flat)
        - Color palette (if any) or monochrome approach
        - Level of detail and abstraction
        - Overall mood and aesthetic

        Provide a concise but complete style description that could be used to generate consistent images in this style. Write it as a direct instruction, e.g., "Hand-drawn pencil sketch style with bold outlines..."
        """

        return try await visionCompletion(
            userText: prompt,
            images: referenceImages,
            maxTokens: 500
        )
    }

    // MARK: - Unified text completion (routes by endpoint type)

    private func textCompletion(
        system: String,
        user: String,
        model: String = "gpt-4o",
        maxTokens: Int = 300
    ) async throws -> String {
        let ep = try requireEndpoint()

        switch ep {
        case .platform(let apiKey):
            return try await platformChatCompletion(
                system: system, user: user, model: model, maxTokens: maxTokens, apiKey: apiKey
            )
        case .codexBackend(let token, let accountId):
            return try await codexTextCompletion(
                system: system, user: user, model: model, accessToken: token, accountId: accountId
            )
        }
    }

    // MARK: - Unified vision completion

    private func visionCompletion(
        userText: String,
        images: [Data],
        model: String = "gpt-4o",
        maxTokens: Int = 500
    ) async throws -> String {
        let ep = try requireEndpoint()

        switch ep {
        case .platform(let apiKey):
            return try await platformVisionCompletion(
                userText: userText, images: images, model: model, maxTokens: maxTokens, apiKey: apiKey
            )
        case .codexBackend(let token, let accountId):
            return try await codexVisionCompletion(
                userText: userText, images: images, model: model, accessToken: token, accountId: accountId
            )
        }
    }

    // MARK: - Unified image generation

    private func imageGeneration(prompt: String) async throws -> Data {
        let ep = try requireEndpoint()

        switch ep {
        case .platform(let apiKey):
            return try await platformImageGeneration(prompt: prompt, apiKey: apiKey)
        case .codexBackend(let token, let accountId):
            return try await codexImageGeneration(prompt: prompt, accessToken: token, accountId: accountId)
        }
    }

    // MARK: - Platform API (api.openai.com — used with API keys)

    private func platformChatCompletion(
        system: String, user: String, model: String, maxTokens: Int, apiKey: String
    ) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "max_tokens": maxTokens,
        ]

        let data = try await post(
            url: "https://api.openai.com/v1/chat/completions",
            body: body,
            headers: ["Authorization": "Bearer \(apiKey)"]
        )

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw ServiceError.noContent
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func platformVisionCompletion(
        userText: String, images: [Data], model: String, maxTokens: Int, apiKey: String
    ) async throws -> String {
        var contentArray: [[String: Any]] = [
            ["type": "text", "text": userText]
        ]
        for imageData in images {
            let b64 = imageData.base64EncodedString()
            contentArray.append([
                "type": "image_url",
                "image_url": ["url": "data:image/png;base64,\(b64)"]
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": contentArray]
            ],
            "max_tokens": maxTokens,
        ]

        let data = try await post(
            url: "https://api.openai.com/v1/chat/completions",
            body: body,
            headers: ["Authorization": "Bearer \(apiKey)"]
        )

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw ServiceError.noContent
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func platformImageGeneration(
        prompt: String, apiKey: String, model: String = "gpt-image-1", size: String = "1024x1024"
    ) async throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "n": 1,
            "size": size,
            "response_format": "b64_json",
        ]

        let data = try await post(
            url: "https://api.openai.com/v1/images/generations",
            body: body,
            headers: ["Authorization": "Bearer \(apiKey)"]
        )

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let b64 = first["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64)
        else {
            throw ServiceError.imageGenerationFailed("No image data in response")
        }

        return imageData
    }

    // MARK: - Codex Backend API (chatgpt.com — used with ChatGPT subscription)

    private static let codexResponsesURL = "https://chatgpt.com/backend-api/codex/responses"

    private func codexHeaders(accessToken: String, accountId: String) -> [String: String] {
        [
            "Authorization": "Bearer \(accessToken)",
            "chatgpt-account-id": accountId,
        ]
    }

    private func codexTextCompletion(
        system: String, user: String, model: String, accessToken: String, accountId: String
    ) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "instructions": system,
            "store": false,
            "stream": false,
            "input": [
                ["role": "user", "content": [["type": "input_text", "text": user]]]
            ],
        ]

        let data = try await post(
            url: Self.codexResponsesURL,
            body: body,
            headers: codexHeaders(accessToken: accessToken, accountId: accountId)
        )

        return try extractTextFromResponsesAPI(data: data)
    }

    private func codexVisionCompletion(
        userText: String, images: [Data], model: String, accessToken: String, accountId: String
    ) async throws -> String {
        var contentArray: [[String: Any]] = [
            ["type": "input_text", "text": userText]
        ]
        for imageData in images {
            let b64 = imageData.base64EncodedString()
            contentArray.append([
                "type": "input_image",
                "image_url": "data:image/png;base64,\(b64)"
            ])
        }

        let body: [String: Any] = [
            "model": model,
            "instructions": "You are a visual style analyst.",
            "store": false,
            "stream": false,
            "input": [
                ["role": "user", "content": contentArray]
            ],
        ]

        let data = try await post(
            url: Self.codexResponsesURL,
            body: body,
            headers: codexHeaders(accessToken: accessToken, accountId: accountId)
        )

        return try extractTextFromResponsesAPI(data: data)
    }

    private func codexImageGeneration(
        prompt: String, model: String = "gpt-4o", accessToken: String, accountId: String
    ) async throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "instructions": "Generate the requested image.",
            "store": false,
            "stream": false,
            "input": [
                ["role": "user", "content": [["type": "input_text", "text": prompt]]]
            ],
            "tools": [
                ["type": "image_generation", "quality": "medium", "size": "1024x1024"]
            ],
        ]

        let data = try await post(
            url: Self.codexResponsesURL,
            body: body,
            headers: codexHeaders(accessToken: accessToken, accountId: accountId)
        )

        return try extractImageFromResponsesAPI(data: data)
    }

    // MARK: - Responses API parsing

    func extractTextFromResponsesAPI(data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServiceError.noContent
        }

        if let output = json["output"] as? [[String: Any]] {
            let texts = output.compactMap { item -> String? in
                guard item["type"] as? String == "message" else { return nil }
                guard let content = item["content"] as? [[String: Any]] else { return nil }
                return content.compactMap { part -> String? in
                    guard part["type"] as? String == "output_text" else { return nil }
                    return part["text"] as? String
                }.joined()
            }
            let result = texts.joined()
            if !result.isEmpty { return result.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        if let output_text = json["output_text"] as? String, !output_text.isEmpty {
            return output_text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw ServiceError.noContent
    }

    func extractImageFromResponsesAPI(data: Data) throws -> Data {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [[String: Any]]
        else {
            throw ServiceError.imageGenerationFailed("No output in response")
        }

        for item in output {
            if item["type"] as? String == "image_generation_call",
               let b64 = item["result"] as? String,
               let imageData = Data(base64Encoded: b64) {
                return imageData
            }
        }

        throw ServiceError.imageGenerationFailed("No image data in response output")
    }

    // MARK: - HTTP

    private func post(url: String, body: [String: Any], headers: [String: String]) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            throw ServiceError.httpError(0, "Invalid URL: \(url)")
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ServiceError.httpError(httpResponse.statusCode, errorBody)
        }

        return data
    }

    private func requireEndpoint() throws -> Endpoint {
        guard let endpoint else {
            throw oauthMissingAccountId ? ServiceError.missingAccountId : ServiceError.notAuthenticated
        }
        return endpoint
    }
}
