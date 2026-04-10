---
title: Codex Backend API rejects stream:false and gpt-4o model
date: 2026-04-10
category: integration-issues
module: OpenAIService
problem_type: integration_issue
component: service_object
symptoms:
  - 'API error 400: "Stream must be set to true"'
  - 'API error 400: "The ''gpt-4o'' model is not supported when using Codex with a ChatGPT account"'
  - Image generation returns "No output in response" after enabling streaming
root_cause: wrong_api
resolution_type: code_fix
severity: critical
tags:
  - openai
  - codex-backend-api
  - streaming
  - sse
  - model-selection
  - image-generation
  - responses-api
---

# Codex Backend API rejects stream:false and gpt-4o model

## Problem

The Codex Backend API (`chatgpt.com/backend-api/codex/responses`) has two undocumented hard requirements that differ from the public Responses API documentation: `stream` must be `true`, and `gpt-4o` is not a supported model. Sending either incorrect value returns a 400 error with no further guidance.

## Symptoms

- `API error 400: "Stream must be set to true"` when any Codex Backend request includes `"stream": false`
- `API error 400: "The 'gpt-4o' model is not supported when using Codex with a ChatGPT account"` on text, vision, and image generation calls
- After fixing `stream: true`, image generation returns `"No output in response"` because the SSE stream was not being parsed — the code expected a single JSON response body

## What Didn't Work

- **Setting `stream: false`**: The public Responses API docs state that `stream` defaults to `false` and is optional. The Codex Backend diverges from this — it mandates `true`.
- **Using `gpt-4o`**: The Platform API uses `gpt-4o` as the default model. The Codex Backend requires Codex-specific models (`gpt-5.4-mini`, `gpt-5.4`, `gpt-5.3-codex`, `gpt-5.2`).
- **Reading the response body as a single JSON payload**: After setting `stream: true`, the response body is an SSE stream, not a JSON object. The initial implementation tried to decode the raw body as JSON, which failed silently and produced a `noContent` error.

## Solution

Three changes, applied in sequence:

**1. Model selection per endpoint**

```swift
static let platformDefaultModel = "gpt-4o"
static let codexDefaultModel = "gpt-5.4-mini"
```

Every API method checks `endpoint.isPlatform` and selects the matching default.

**2. Mandatory streaming for Codex Backend**

Changed all Codex Backend request bodies from `"stream": false` to `"stream": true`.

**3. SSE response parser**

Extracted SSE parsing into a testable static method that handles two event types:

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

    if let itemData = lastOutputItemDoneData,
       let eventJson = try? JSONSerialization.jsonObject(with: itemData) as? [String: Any] {
        let item = (eventJson["item"] as? [String: Any]) ?? eventJson
        let wrapped: [String: Any] = ["output": [item]]
        return try JSONSerialization.data(withJSONObject: wrapped)
    }

    throw ServiceError.noContent
}
```

The `postStreaming` method collects all SSE lines from `URLSession.shared.bytes(for:)` and passes them to `parseSSEResponse`, whose output is compatible with the existing `extractTextFromResponsesAPI` and `extractImageFromResponsesAPI` methods.

## Why This Works

The Codex Backend API is a separate surface from the public Platform API. It shares the Responses API payload format but enforces different constraints:

| Constraint | Platform API | Codex Backend |
|---|---|---|
| `stream` | Optional, defaults to `false` | **Required `true`** |
| `gpt-4o` | Supported | **Not supported** |
| Response format | Single JSON (when `stream: false`) | **SSE stream only** |

The `response.completed` SSE event contains the full response JSON, so the downstream parsing logic (text extraction, image extraction) works identically to the non-streaming case. The `response.output_item.done` fallback handles cases where image generation results arrive in item-level events without a final `response.completed` event.

## Prevention

- Unit tests assert model constants: `codexDefaultModel != "gpt-4o"` and `platformDefaultModel == "gpt-4o"`
- 8 SSE parsing tests cover text extraction, image extraction, large payloads, nested `item` structures, empty streams, and event priority (`response.completed` over `output_item.done`)
- End-to-end tests walk through the full OAuth → codexBackend routing → SSE parsing → frame completion flow
- The `parseSSEResponse` method is a static function, testable without network calls

## Related Issues

- `docs/solutions/best-practices/chatgpt-subscription-via-codex-backend-api-2026-04-10.md` — updated with corrected streaming and model guidance
- `docs/solutions/integration-issues/openai-image-url-expiration-2026-04-10.md` — related b64_json pattern for image persistence
