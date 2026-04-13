import Testing
import Foundation
@testable import Keyframe

private enum CodexFixtureLoader {
    private static let fixturesDirectory =
        URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures", isDirectory: true)

    static func data(named name: String) throws -> Data {
        try Data(contentsOf: fixturesDirectory.appendingPathComponent(name))
    }

    static func lines(named name: String) throws -> [String] {
        let text = String(decoding: try data(named: name), as: UTF8.self)
        return text.components(separatedBy: .newlines)
    }
}

@Suite("Codex backend fixtures", .serialized)
struct CodexBackendFixtureTests {

    @Test func styleReferenceSuccessFixtureParsesImage() async throws {
        let lines = try CodexFixtureLoader.lines(named: "codex-style-reference-success.sse")
        let data = try OpenAIService.parseSSEResponse(lines: lines)
        let service = OpenAIService()
        let imageData = try await service.extractImageFromResponsesAPI(data: data)

        let expectedImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(imageData == expectedImageData)
    }

    @Test func styleReferenceMissingInstructionsFixtureExtractsDetail() throws {
        let data = try CodexFixtureLoader.data(named: "codex-style-reference-error-missing-instructions.json")
        #expect(OpenAIService.extractErrorBody(data) == "instructions are required")
    }

    @Test func styleReferenceInputMustBeListFixtureExtractsDetail() throws {
        let data = try CodexFixtureLoader.data(named: "codex-style-reference-error-input-must-be-list.json")
        #expect(OpenAIService.extractErrorBody(data) == "Input must be a list")
    }

    @MainActor
    @Test func chatgptFirstRunStyleReferenceFlowAdvancesToCast() async throws {
        let manager = AuthManager()
        manager.logout()
        let tokens = CodexDetector.DetectedTokens(
            accessToken: "ey-style-ref",
            refreshToken: "rt-style-ref",
            accountId: "acc-style-ref"
        )
        manager.loginWithCodexTokens(tokens)
        defer { manager.logout() }

        let mode = manager.resolveAuthMode()
        guard case .oauth(let accessToken, let refreshToken, let accountId) = mode else {
            Issue.record("Expected OAuth mode after ChatGPT login"); return
        }
        #expect(accessToken == "ey-style-ref")
        #expect(refreshToken == "rt-style-ref")
        #expect(accountId == "acc-style-ref")

        let service = OpenAIService()
        await service.configure(authMode: mode)

        let state = AppState()
        state.authMode = mode
        #expect(state.isAuthenticated == true)

        state.setPhase(.style)
        state.setStyleDescription("Anime ink storyboard")

        let lines = try CodexFixtureLoader.lines(named: "codex-style-reference-success.sse")
        let responseData = try OpenAIService.parseSSEResponse(lines: lines)
        let imageData = try await service.extractImageFromResponsesAPI(data: responseData)

        state.addReferenceImage(imageData)
        state.lockStyle()

        #expect(state.project.style.referenceImages.count == 1)
        #expect(state.project.style.referenceImages[0] == imageData)
        #expect(state.project.style.locked == true)
        #expect(state.project.currentPhase == .cast)
    }
}
