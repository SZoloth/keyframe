import Foundation

actor OpenAIService {

    enum Endpoint {
        case standard(apiKey: String)
        case oauth(accessToken: String)

        var baseURL: String {
            switch self {
            case .standard: return "https://api.openai.com/v1"
            case .oauth: return "https://api.openai.com/v1"
            }
        }

        var authHeader: String {
            switch self {
            case .standard(let key): return "Bearer \(key)"
            case .oauth(let token): return "Bearer \(token)"
            }
        }
    }

    enum ServiceError: LocalizedError {
        case noContent
        case httpError(Int, String)
        case decodingError(String)
        case imageGenerationFailed(String)
        case notAuthenticated

        var errorDescription: String? {
            switch self {
            case .noContent: return "No content in API response"
            case .httpError(let code, let msg): return "API error \(code): \(msg)"
            case .decodingError(let msg): return "Failed to decode response: \(msg)"
            case .imageGenerationFailed(let msg): return "Image generation failed: \(msg)"
            case .notAuthenticated: return "Not authenticated"
            }
        }
    }

    private var endpoint: Endpoint?

    func configure(endpoint: Endpoint) {
        self.endpoint = endpoint
    }

    func configure(authMode: AuthMode) {
        switch authMode {
        case .none:
            endpoint = nil
        case .apiKey(let key):
            endpoint = .standard(apiKey: key)
        case .oauth(let accessToken, _):
            endpoint = .oauth(accessToken: accessToken)
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

        return try await chatCompletion(system: system, user: user)
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

        return try await chatCompletion(system: system, user: user)
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

        return try await chatCompletionWithImages(
            userText: prompt,
            images: referenceImages,
            maxTokens: 500
        )
    }

    // MARK: - Chat completions

    private func chatCompletionWithImages(
        userText: String,
        images: [Data],
        model: String = "gpt-4o",
        maxTokens: Int = 500
    ) async throws -> String {
        let ep = try requireEndpoint()

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
            url: "\(ep.baseURL)/chat/completions",
            body: body,
            auth: ep.authHeader
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

    private func chatCompletion(
        system: String,
        user: String,
        model: String = "gpt-4o",
        maxTokens: Int = 300
    ) async throws -> String {
        let ep = try requireEndpoint()

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "max_tokens": maxTokens,
        ]

        let data = try await post(
            url: "\(ep.baseURL)/chat/completions",
            body: body,
            auth: ep.authHeader
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

    // MARK: - Image generation

    private func imageGeneration(
        prompt: String,
        model: String = "gpt-image-1",
        size: String = "1024x1024"
    ) async throws -> Data {
        let ep = try requireEndpoint()

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "n": 1,
            "size": size,
            "response_format": "b64_json",
        ]

        let data = try await post(
            url: "\(ep.baseURL)/images/generations",
            body: body,
            auth: ep.authHeader
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

    // MARK: - HTTP

    private func post(url: String, body: [String: Any], auth: String) async throws -> Data {
        guard let requestURL = URL(string: url) else {
            throw ServiceError.httpError(0, "Invalid URL: \(url)")
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(auth, forHTTPHeaderField: "Authorization")
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
        guard let endpoint else { throw ServiceError.notAuthenticated }
        return endpoint
    }
}
