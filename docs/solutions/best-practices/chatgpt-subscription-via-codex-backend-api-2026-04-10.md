---
title: Using ChatGPT subscriptions in third-party apps via the Codex Backend API
date: 2026-04-10
last_updated: 2026-04-10
category: best-practices
module: OpenAIService
problem_type: best_practice
component: authentication
severity: high
applies_when:
  - Building a desktop/native app that uses OpenAI models
  - Users have ChatGPT Plus/Pro/Team subscriptions and expect to use them
  - You want to avoid requiring users to pay separately for Platform API credits
tags:
  - openai
  - chatgpt-subscription
  - codex-backend-api
  - oauth
  - responses-api
  - dual-routing
  - authentication
  - sse
  - streaming
---

# Using ChatGPT subscriptions in third-party apps via the Codex Backend API

## Context

OpenAI operates two separate API surfaces with different billing models:

1. **Platform API** (`api.openai.com/v1`) — requires an API key, bills per-token against the developer's or user's Platform account
2. **Codex Backend API** (`chatgpt.com/backend-api/codex/responses`) — accepts ChatGPT OAuth tokens, bills against the user's ChatGPT subscription (Plus/Pro/Team)

The "Sign in with ChatGPT" OAuth flow (via `auth.openai.com`) grants identity-scoped tokens. These tokens are *not* accepted by the Platform API for model access — they only provide user identity. Sending them to `api.openai.com/v1` results in 401 errors.

Apps like [Open Interpreter](https://github.com/openinterpreter/open-interpreter) and the Codex CLI use the Codex Backend API to let users run AI features against their ChatGPT subscription without needing a separate API key.

For Keyframe's current stabilization phase, the product boundary is narrower than the underlying service layer: the supported app experience is ChatGPT/Codex-only. Platform API routing may still exist as an internal compatibility seam, but it is not a supported setup path in the app UI.

## Guidance

### Routing architecture

At the service layer, route API calls to different endpoints based on the credential type you actually have:

```swift
enum Endpoint {
    case platform(apiKey: String)
    case codexBackend(accessToken: String, accountId: String)
}
```

- **Platform API credentials** → route to `api.openai.com/v1` (Chat Completions / Images API formats)
- **ChatGPT OAuth credentials** → route to `chatgpt.com/backend-api/codex/responses` (Responses API format)

For Keyframe, only the second branch is part of the current supported product contract.

### Codex Backend API requirements

The Codex Backend endpoint uses the **Responses API** format, not Chat Completions. Three critical constraints discovered through production failures:

1. **`stream` must be `true`** — the Codex Backend rejects `stream: false` with a 400 error: *"Stream must be set to true"*. This means you must implement Server-Sent Events (SSE) parsing for every call.
2. **Model selection differs from Platform API** — the Codex Backend does not support `gpt-4o`. Use `gpt-5.4-mini` (or `gpt-5.4`, `gpt-5.3-codex`, `gpt-5.2`). Sending `gpt-4o` returns a 400 error: *"The 'gpt-4o' model is not supported when using Codex with a ChatGPT account."*
3. **Image generation requests are stricter than the public Responses examples** — for Keyframe's style reference flow, the backend rejected missing `instructions` and rejected string `input` with *`{"detail":"Input must be a list"}`*. Use a list-form `input` with a user message item.

```swift
// Headers
"Authorization": "Bearer <oauth_access_token>"
"chatgpt-account-id": "<account_id>"

// Body (text completion)
{
    "model": "gpt-5.4-mini",
    "instructions": "<system prompt>",
    "store": false,
    "stream": true,
    "input": [
        {"role": "user", "content": [{"type": "input_text", "text": "<user message>"}]}
    ]
}

// Body (image generation — uses tools array)
{
    "model": "gpt-5.4-mini",
    "instructions": "Generate the requested image.",
    "store": false,
    "stream": true,
    "input": [
        {"role": "user", "content": [{"type": "input_text", "text": "<prompt>"}]}
    ],
    "tools": [
        {"type": "image_generation", "quality": "medium", "size": "1024x1024"}
    ]
}
```

### Model defaults by endpoint

Keep separate defaults so the right model is always selected:

```swift
static let platformDefaultModel = "gpt-4o"       // Platform API (api.openai.com)
static let codexDefaultModel = "gpt-5.4-mini"    // Codex Backend (chatgpt.com)
```

### Extracting the account ID from JWT

The `chatgpt-account-id` header is required. Extract it from the `id_token` (preferred) or `access_token` returned by the OAuth token exchange. The claim path varies:

```swift
private static func extractAccountId(from jwt: String) -> String? {
    guard let payload = decodeJWTPayload(jwt) else { return nil }

    // Try multiple claim paths
    if let id = payload["chatgpt_account_id"] as? String { return id }
    if let ext = payload["ext"] as? [String: Any],
       let id = ext["chatgpt_account_id"] as? String { return id }
    if let id = payload["account_id"] as? String { return id }
    if let id = payload["sub"] as? String { return id }

    return nil
}
```

### Vision input format

The Responses API uses a flat `image_url` string for vision input (different from the Chat Completions API's nested object):

```swift
// Responses API (Codex Backend) — flat string
["type": "input_image", "image_url": "data:image/png;base64,<b64>"]

// Chat Completions API (Platform) — nested object
["type": "image_url", "image_url": ["url": "data:image/png;base64,<b64>"]]
```

### Source of truth when docs disagree

When there is a mismatch between public Responses docs and the ChatGPT Codex backend, use this order:

1. Observed Keyframe runtime behavior against `chatgpt.com/backend-api/codex/responses`
2. Official Codex auth docs
3. Official public Responses and image-generation docs
4. Third-party apps and repos

### SSE response parsing (required)

Since `stream: true` is mandatory, every Codex Backend response arrives as a Server-Sent Events stream. The stream contains multiple event types; the two that carry final results:

- **`response.completed`** — contains the full response JSON with all outputs. Prefer this when present.
- **`response.output_item.done`** — contains individual completed output items. Use as a fallback when `response.completed` is absent.

```swift
static func parseSSEResponse(lines: [String]) throws -> Data {
    var currentEvent = ""
    var completedData: Data?
    var lastOutputItemDoneData: Data?

    for line in lines {
        if line.hasPrefix("event: ") {
            currentEvent = String(line.dropFirst(7))
        } else if line.hasPrefix("data: ") {
            let payload = String(line.dropFirst(6))
            guard let data = payload.data(using: .utf8) else { continue }

            switch currentEvent {
            case "response.completed":
                completedData = data
            case "response.output_item.done":
                lastOutputItemDoneData = data
            default:
                break
            }
        }
    }

    if let finalData = completedData { return finalData }

    // Fallback: unwrap output_item.done for image generation
    if let itemData = lastOutputItemDoneData,
       let eventJson = try? JSONSerialization.jsonObject(with: itemData) as? [String: Any] {
        let item = (eventJson["item"] as? [String: Any]) ?? eventJson
        let wrapped: [String: Any] = ["output": [item]]
        return try JSONSerialization.data(withJSONObject: wrapped)
    }

    throw ServiceError.noContent
}
```

**Text extraction**: Text lives under `output[].content[].text` with type `output_text`, or in a top-level `output_text` field.

**Image extraction**: Image data comes from `output[]` items with type `image_generation_call` and a `result` field containing base64-encoded image data. Note that `response.output_item.done` may nest the actual item under an `"item"` key — the parser above handles both flat and nested structures.

## Why This Matters

Without correct routing, OAuth users hit 401 errors on every API call because `auth.openai.com` tokens lack Platform API scopes. The user experience is: "I signed in with my ChatGPT account, but nothing works."

The Codex Backend API is the same endpoint that OpenAI's own Codex CLI and IDE extensions use. It's undocumented publicly but stable — used by the official Codex product and third-party apps like Open Interpreter.

Using this pattern means ChatGPT subscribers can use your app immediately without creating a separate Platform account or adding a credit card for API billing.

## When to Apply

- Your app offers "Sign in with ChatGPT" as an authentication option
- You need to support text, vision, or image generation via ChatGPT subscription
- The user has a ChatGPT Plus, Pro, or Team subscription
- You need a documented fallback when the service layer still retains non-ChatGPT credential paths internally

## Examples

### Before: single endpoint, OAuth users get 401

```swift
func configure(authMode: AuthMode) {
    switch authMode {
    case .none:
        endpoint = nil
    case .oauth(let accessToken, _, _):
        apiKey = accessToken  // Fails: OAuth tokens are not API keys
    }
}
// All calls go to api.openai.com/v1 → 401 for OAuth users
```

### After: app boundary stays ChatGPT-only, service layer still routes correctly

```swift
func configure(authMode: AuthMode) {
    switch authMode {
    case .none:
        endpoint = nil
    case .oauth(let accessToken, _, let accountId):
        if let accountId, !accountId.isEmpty {
            endpoint = .codexBackend(accessToken: accessToken, accountId: accountId)
        } else {
            // Surface a specific error, not generic "not authenticated"
            oauthMissingAccountId = true
        }
    }
}

func configure(endpoint: Endpoint) {
    self.endpoint = endpoint
}

private func textCompletion(system: String, user: String, model: String) async throws -> String {
    let ep = try requireEndpoint()
    switch ep {
    case .platform(let apiKey):
        return try await platformChatCompletion(...)   // Chat Completions API
    case .codexBackend(let token, let accountId):
        return try await codexTextCompletion(...)       // Responses API
    }
}
```

## Related

- `docs/solutions/integration-issues/codex-backend-streaming-and-model-errors-2026-04-10.md` — bug track doc covering the specific failures that led to these corrections
- `docs/solutions/best-practices/keyframe-chatgpt-codex-contract-2026-04-10.md` — source-of-truth hierarchy and backend-vs-public-doc differences for Keyframe
- `docs/solutions/integration-issues/openai-image-url-expiration-2026-04-10.md` — related OpenAI API integration pattern (b64_json for persistence)
- [Open Interpreter](https://github.com/openinterpreter/open-interpreter) — reference implementation using this pattern
- [OpenAI Responses API docs](https://platform.openai.com/docs/api-reference/responses/create) — official API reference for the payload format
