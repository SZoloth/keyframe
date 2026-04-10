---
title: Using ChatGPT subscriptions in third-party apps via the Codex Backend API
date: 2026-04-10
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
---

# Using ChatGPT subscriptions in third-party apps via the Codex Backend API

## Context

OpenAI operates two separate API surfaces with different billing models:

1. **Platform API** (`api.openai.com/v1`) — requires an API key, bills per-token against the developer's or user's Platform account
2. **Codex Backend API** (`chatgpt.com/backend-api/codex/responses`) — accepts ChatGPT OAuth tokens, bills against the user's ChatGPT subscription (Plus/Pro/Team)

The "Sign in with ChatGPT" OAuth flow (via `auth.openai.com`) grants identity-scoped tokens. These tokens are *not* accepted by the Platform API for model access — they only provide user identity. Sending them to `api.openai.com/v1` results in 401 errors.

Apps like [Open Interpreter](https://github.com/openinterpreter/open-interpreter) and the Codex CLI use the Codex Backend API to let users run AI features against their ChatGPT subscription without needing a separate API key.

## Guidance

### Dual routing architecture

Route API calls to different endpoints based on how the user authenticated:

```swift
enum Endpoint {
    case platform(apiKey: String)
    case codexBackend(accessToken: String, accountId: String)
}
```

- **API key users** → route to `api.openai.com/v1` (Chat Completions API format)
- **OAuth users** → route to `chatgpt.com/backend-api/codex/responses` (Responses API format)

### Codex Backend API requirements

The Codex Backend endpoint uses the **Responses API** format, not Chat Completions:

```swift
// Headers
"Authorization": "Bearer <oauth_access_token>"
"chatgpt-account-id": "<account_id>"

// Body (text completion)
{
    "model": "gpt-4o",
    "instructions": "<system prompt>",
    "store": false,
    "stream": false,
    "input": [
        {"role": "user", "content": [{"type": "input_text", "text": "<user message>"}]}
    ]
}

// Body (image generation — uses tools array)
{
    "model": "gpt-4o",
    "instructions": "Generate the requested image.",
    "store": false,
    "stream": false,
    "input": [
        {"role": "user", "content": [{"type": "input_text", "text": "<prompt>"}]}
    ],
    "tools": [
        {"type": "image_generation", "quality": "medium", "size": "1024x1024"}
    ]
}
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

### Response parsing

The Codex Backend returns Responses API format. Text lives under `output[].content[].text` with type `output_text`, or in a top-level `output_text` field. Image data comes from `output[]` items with type `image_generation_call` and a `result` field containing base64-encoded image data.

### stream parameter

`stream` is **optional** in the Responses API and defaults to `false`. Setting `stream: false` is valid and returns the complete response in a single JSON payload. Only use `stream: true` if you need incremental output.

## Why This Matters

Without dual routing, OAuth users hit 401 errors on every API call because `auth.openai.com` tokens lack Platform API scopes. The user experience is: "I signed in with my ChatGPT account, but nothing works."

The Codex Backend API is the same endpoint that OpenAI's own Codex CLI and IDE extensions use. It's undocumented publicly but stable — used by the official Codex product and third-party apps like Open Interpreter.

Using this pattern means ChatGPT subscribers can use your app immediately without creating a separate Platform account or adding a credit card for API billing.

## When to Apply

- Your app offers "Sign in with ChatGPT" as an authentication option
- You want feature parity between API-key and OAuth users (text, vision, image generation)
- You need to support image generation via ChatGPT subscription (the `image_generation` tool type)
- The user has a ChatGPT Plus, Pro, or Team subscription

## Examples

### Before: single endpoint, OAuth users get 401

```swift
func configure(authMode: AuthMode) {
    switch authMode {
    case .apiKey(let key):
        apiKey = key
    case .oauth(let accessToken, _, _):
        apiKey = accessToken  // Fails: OAuth tokens are not API keys
    }
}
// All calls go to api.openai.com/v1 → 401 for OAuth users
```

### After: dual routing by auth type

```swift
func configure(authMode: AuthMode) {
    switch authMode {
    case .apiKey(let key):
        endpoint = .platform(apiKey: key)
    case .oauth(let accessToken, _, let accountId):
        if let accountId, !accountId.isEmpty {
            endpoint = .codexBackend(accessToken: accessToken, accountId: accountId)
        } else {
            // Surface a specific error, not generic "not authenticated"
            oauthMissingAccountId = true
        }
    }
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

- `docs/solutions/integration-issues/openai-image-url-expiration-2026-04-10.md` — related OpenAI API integration pattern (b64_json for persistence)
- [Open Interpreter](https://github.com/openinterpreter/open-interpreter) — reference implementation using this pattern
- [OpenAI Responses API docs](https://platform.openai.com/docs/api-reference/responses/create) — official API reference for the payload format
