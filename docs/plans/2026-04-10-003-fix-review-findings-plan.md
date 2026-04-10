---
title: "fix: Address code review findings from integration wiring"
type: fix
status: active
date: 2026-04-10
origin: docs/plans/2026-04-10-002-feat-integration-wiring-plan.md
---

# fix: Address code review findings from integration wiring

## Overview

Code review of the completed integration wiring surfaced 1 P1, 2 P2, and 3 P3 findings plus testing gaps for recently added state management methods. This plan addresses the P1 and P2 items and fills the most important testing gaps. P3 items (advisory) are noted but deferred.

## Problem Frame

The app builds and tests pass, but three issues would cause runtime failures or data loss: a placeholder OAuth client ID that will reject every login attempt, a potential continuation leak in the OAuth flow, and image URLs that expire before the user saves their project. The testing gaps leave frame reorder and deletion logic without coverage.

## Requirements Trace

- R1. OAuth client ID is a real, working value (review finding #1)
- R2. Concurrent OAuth authorization attempts cannot leak continuations (review finding #2)
- R3. Image generation returns inline base64 data, not expiring URLs (review finding #3)
- R4. Test coverage for `moveFrame`, `removeFrame`, and `reorderFrames` (testing gap)

## Scope Boundaries

- P3 advisory items (AIServiceProvider fire-and-forget, SetupView extraction, Endpoint enum dedup) are deferred — they don't cause runtime failures
- No UI changes in this plan
- No new features

## Key Technical Decisions

- **b64_json over URL**: OpenAI image URLs expire after ~60 minutes. Since Keyframe saves projects to disk and users may not save immediately, requesting `response_format: "b64_json"` eliminates the race between generation and persistence. This also removes the URL-download fallback code path.
- **Continuation guard pattern**: Cancel any existing continuation before storing a new one. This prevents silent leaks without changing the external API.

## Implementation Units

- [ ] **Unit 17: Replace placeholder OAuth client ID**

**Goal:** Insert the real OpenAI OAuth client ID so login actually works.

**Requirements:** R1

**Dependencies:** None

**Files:**
- Modify: `Keyframe/Services/OAuthService.swift`

**Approach:**
- Replace the placeholder `"DRivsnm2Mu42T3KOpqdtwB3NYkHRMBsjrealClientId"` with the actual OpenAI OAuth client ID
- The real client ID should come from the OpenAI developer dashboard (platform.openai.com)

**Test expectation:** none — config-only change, no behavioral logic

**Verification:**
- OAuth login flow reaches the OpenAI consent screen instead of returning an invalid_client error

- [ ] **Unit 18: Guard against continuation leak in OAuthService**

**Goal:** Prevent a leaked `CheckedContinuation` if `startAuthorization()` is called while a previous flow is still pending.

**Requirements:** R2

**Dependencies:** None

**Files:**
- Modify: `Keyframe/Services/OAuthService.swift`
- Test: `KeyframeTests/AuthTests.swift`

**Approach:**
- At the top of `startAuthorization()`, check if `authContinuation` is non-nil. If so, cancel the existing listener and resume the stale continuation with `OAuthError.cancelled` before proceeding with the new flow.
- This mirrors the `cancel()` method's logic but is self-contained within `startAuthorization`.

**Patterns to follow:**
- Existing `cancel()` method in `OAuthService.swift` (same resume + nil + stopListener pattern)

**Test scenarios:**
- Happy path: single authorization flow completes normally (existing test, verify still passes)
- Edge case: verify that `OAuthService.cancel()` resumes with cancellation error (existing test coverage)

**Verification:**
- Calling `startAuthorization()` twice does not trigger a Swift runtime warning about resumed continuations
- The first flow's caller receives a `CancellationError` or `OAuthError.cancelled`

- [ ] **Unit 19: Request b64_json format for image generation**

**Goal:** Eliminate dependency on expiring OpenAI image URLs by requesting inline base64 data.

**Requirements:** R3

**Dependencies:** None

**Files:**
- Modify: `Keyframe/Services/OpenAIService.swift`

**Approach:**
- Add `"response_format": "b64_json"` to the `imageGeneration` request body
- Remove the URL-download fallback code path (lines that check for `url` in response and download via URLSession) since b64_json is now guaranteed
- Keep the `b64_json` decode path as the sole handler

**Test scenarios:**
- Happy path: `imageGeneration` body includes `response_format` key set to `b64_json`

**Verification:**
- The `imageGeneration` method no longer contains a URL-download fallback
- Generated images are returned as `Data` from base64 decoding without network round-trips

- [ ] **Unit 20: Add tests for frame reorder and deletion**

**Goal:** Cover `moveFrame`, `removeFrame`, and `reorderFrames` with unit tests.

**Requirements:** R4

**Dependencies:** None

**Files:**
- Modify: `KeyframeTests/AppStateTests.swift`

**Approach:**
- Add test cases to the existing `AppStateTests` suite

**Patterns to follow:**
- Existing tests in `AppStateTests.swift` (e.g., `testAddFrame`, `testSelectFrame`)

**Test scenarios:**
- Happy path: `removeFrame` removes the frame and clears selection if the removed frame was selected
- Happy path: `removeFrame` preserves selection when a different frame is selected
- Happy path: `reorderFrames` swaps two adjacent frames correctly
- Happy path: `moveFrame` moves a frame from position 0 to position 2
- Edge case: `removeFrame` with non-existent ID does nothing (no crash, no state change)
- Edge case: `reorderFrames` with out-of-bounds indices does nothing
- Edge case: `moveFrame` with identical sourceId and beforeId does nothing

**Verification:**
- All new tests pass
- Existing tests remain green

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Real OAuth client ID not yet obtained | Unit 17 is blocked until the ID is retrieved from platform.openai.com. Other units are independent. |

## Deferred (P3 advisory, no plan needed)

- `AIServiceProvider.configure` fire-and-forget timing — extremely unlikely in practice given UI gating
- `SetupView` at 360+ lines — extract `CustomTemplateFormView` in a future cleanup pass
- `Endpoint` enum cases share identical `baseURL` — intentional for v1, collapse when/if endpoints diverge
