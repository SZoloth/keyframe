---
title: Test ChatGPT/Codex flows without driving the Keyframe app UI
date: 2026-04-13
category: developer-experience
module: OpenAIService/AuthManager
problem_type: developer_experience
component: testing_framework
severity: high
applies_when:
  - You need confidence in ChatGPT/Codex request behavior without manual app driving
  - OAuth or Codex auth state affects routing, refresh, or request validity
  - The integration depends on SSE streams, strict headers, or request-body contracts
  - UI automation is blocked by login, passkeys, or brittle desktop accessibility
symptoms:
  - API confidence depends on launching the app and clicking through setup
  - Request headers and outbound JSON are hard to verify directly
  - Auth refresh and missing-account-id flows are only indirectly exercised
root_cause: missing_tooling
resolution_type: tooling_addition
tags:
  - openai
  - codex-backend-api
  - oauth
  - testing
  - simulation
  - sse
  - auth-refresh
  - developer-experience
---

# Test ChatGPT/Codex flows without driving the Keyframe app UI

## Context

Keyframe's riskiest integration behavior lives below the SwiftUI layer: auth restoration, refresh-token handling, endpoint routing, Codex request shape, SSE parsing, and HTTP error handling. Manual app testing is still useful for final acceptance, but it is a poor primary mechanism for proving that these contracts work because it is slow, brittle, and blocked by browser login and desktop accessibility.

The fix was to make the service layer directly testable rather than pushing more responsibility onto UI automation.

## Guidance

Inject the network and auth seams that actually control the integration:

```swift
protocol OpenAITransport: Sendable {
    func data(for request: URLRequest) async throws -> OpenAIHTTPResponse
    func stream(for request: URLRequest) async throws -> OpenAIHTTPStreamResponse
}

protocol OAuthTransport: Sendable {
    func data(for request: URLRequest) async throws -> OAuthHTTPResponse
}

protocol KeyframeOAuthClient: Actor {
    func startAuthorization() async throws -> OAuthService.Tokens
    func cancel() async
    func refreshAccessToken(refreshToken: String) async throws -> OAuthService.Tokens
}
```

Use production implementations that wrap `URLSession.shared`, but let tests inject recording fakes:

```swift
actor OpenAIService {
    private let transport: any OpenAITransport

    init(transport: any OpenAITransport = URLSessionOpenAITransport()) {
        self.transport = transport
    }
}

@MainActor
final class AuthManager {
    private let oauthService: any KeyframeOAuthClient

    init(oauthService: any KeyframeOAuthClient = OAuthService()) {
        self.oauthService = oauthService
    }
}
```

Once those seams exist, write service-level simulations that assert the things the UI cannot prove efficiently:

- exact request URL, headers, and JSON body
- streaming versus non-streaming transport behavior
- HTTP error propagation from the transport layer
- SSE success payload parsing through the real service methods
- auth refresh preserving the stored ChatGPT account ID when the refresh response omits it
- login, cancel, and refresh behavior in `AuthManager` without opening a browser

Keep the UI layer thin. It should configure the service and display results, not own the contract proof.

## Why This Matters

Without these seams, the test strategy drifts toward "click the app and hope," which is the weakest way to validate an API contract. That makes regressions expensive to catch:

- request-shape regressions only surface after a live app run
- auth bugs hide behind browser state and local keychain state
- SSE and HTTP edge cases are painful to reproduce manually
- QA time goes into setup friction instead of meaningful contract coverage

With injected transports and auth clients, the contract becomes fast, deterministic, and reviewable in tests. Manual app use becomes the final confidence layer, not the main debugging tool.

## When to Apply

- A desktop or native app depends on external auth and API contracts
- The risky logic sits in service objects, not view rendering
- Login or browser state makes UI automation expensive
- You need to verify transport details such as headers, body shape, streaming, or retries

## Examples

### Before

```swift
let (data, response) = try await URLSession.shared.data(for: request)
let (bytes, response) = try await URLSession.shared.bytes(for: request)

private let oauthService = OAuthService()
```

This forces tests to stop at static helpers or to rely on the app itself to exercise live behavior.

### After

```swift
let transport = RecordingOpenAITransport(
    streamResponses: [
        .init(
            statusCode: 200,
            lines: [
                "event: response.completed",
                "data: {\"type\":\"response.completed\",\"response\":{\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"A simulated scene.\"}]}]},\"sequence_number\":1}",
                ""
            ]
        )
    ]
)

let service = OpenAIService(transport: transport)
await service.configure(authMode: .oauth(accessToken: "tok", refreshToken: nil, accountId: "acc"))

let result = try await service.suggestScene(
    beatTitle: "Opening",
    beatGuidance: "Introduce the space",
    style: .empty,
    characters: [],
    previousFrames: []
)
```

Now the test can prove the outbound request and the parsed result without launching the app UI.

## Related

- `docs/solutions/best-practices/keyframe-chatgpt-codex-contract-2026-04-10.md`
- `docs/solutions/best-practices/chatgpt-subscription-via-codex-backend-api-2026-04-10.md`
- `docs/solutions/integration-issues/codex-backend-streaming-and-model-errors-2026-04-10.md`
