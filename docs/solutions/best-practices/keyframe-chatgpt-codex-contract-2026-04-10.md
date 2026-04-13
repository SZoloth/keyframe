---
title: Keyframe ChatGPT Codex contract and evidence hierarchy
date: 2026-04-10
last_updated: 2026-04-13
category: best-practices
module: OpenAIService
problem_type: best_practice
component: documentation
severity: high
tags:
  - openai
  - chatgpt-subscription
  - codex-backend-api
  - contract
  - testing
  - image-generation
---

# Keyframe ChatGPT Codex contract and evidence hierarchy

## Purpose

Keyframe currently succeeds or fails on the first-run style reference flow. That flow uses ChatGPT login, the Codex backend, and the hosted `image_generation` tool. The contract for this path must be anchored to one evidence ladder so the app does not drift every time public API docs and observed backend behavior disagree.

## Current product contract

For the current stabilization phase, treat the ChatGPT/Codex path as the contract that matters most:

1. User signs in with ChatGPT.
2. Keyframe stores the OAuth access token, refresh token, and ChatGPT account ID.
3. Style reference generation sends a request to `https://chatgpt.com/backend-api/codex/responses`.
4. A successful response returns an SSE stream whose final payload contains an `image_generation_call`.
5. Keyframe stores the generated image as a style reference and allows the user to lock style and continue to cast setup.

At the product boundary, `AuthMode` is ChatGPT/Codex-only for this phase: the app models `none` or `oauth`, setup exposes ChatGPT sign-in and Codex CLI import, and stale legacy API-key state is ignored and purged during auth resolution.

## Evidence hierarchy

When sources disagree, use this order:

1. **Observed Keyframe runtime behavior against the ChatGPT Codex backend**
2. **Official Codex docs** for ChatGPT login, token caching, and session semantics
3. **Official public Responses and image-generation docs** for request-shape ideas only when they are not contradicted by the live backend
4. **Third-party apps and repos** for UX patterns or rough direction, never as the contract source

## Observed backend differences

The ChatGPT Codex backend behaves like a stricter variant of the public Responses API. The following differences are now part of Keyframe's contract:

| Topic | Public docs allow | Observed backend requires |
|---|---|---|
| `stream` | Optional in public Responses API | `true` |
| Image generation `input` | String or list | List |
| Image generation `instructions` | Optional in public examples | Required |
| OAuth model choice | Public Responses examples often show generic mainline models | `gpt-5.4-mini` works, `gpt-4o` does not |

Concrete failures seen in Keyframe:

- `{"detail":"instructions are required"}`
- `{"detail":"Input must be a list"}`
- `API error 400: "Stream must be set to true"`
- `API error 400: "The 'gpt-4o' model is not supported when using Codex with a ChatGPT account"`

## Testing implications

Tests for this path must lock down four things:

1. Outbound request shape for Codex text, vision, and image generation bodies
2. Backend error detail parsing from real captured error JSON
3. SSE parsing from real style-reference success payloads
4. The first-run ChatGPT login -> style reference -> lock style -> cast flow

Inline hand-written JSON is not enough on its own. Use fixture-backed tests for captured backend errors and success streams when the backend has already proven stricter than the public docs.

For the service layer, prefer injected transports and auth clients over UI-driven testing so request headers, body shape, refresh behavior, and HTTP/SSE edge cases can be proved without launching the app.

## What not to use as authority

OpenInterpreter is useful as a general example of AI product UX, but it is not the contract authority for this problem. Its public docs are centered on API-key based OpenAI usage, not the ChatGPT subscription backed Codex endpoint that Keyframe depends on for this flow.

## Related

- `docs/solutions/best-practices/chatgpt-subscription-via-codex-backend-api-2026-04-10.md`
- `docs/solutions/developer-experience/test-chatgpt-codex-flows-without-ui-2026-04-13.md`
- `docs/solutions/integration-issues/codex-backend-streaming-and-model-errors-2026-04-10.md`
