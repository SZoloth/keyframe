---
title: "fix: Enforce ChatGPT-only auth contract"
type: fix
status: active
date: 2026-04-10
---

# fix: Enforce ChatGPT-only auth contract

## Overview

The Codex contract hardening work tightened the ChatGPT/Codex request shape, but the app still exposes and restores API-key auth at the product layer. This follow-up closes that gap: Keyframe should behave as a ChatGPT/Codex-only app for this stabilization phase, and the new fixture-backed Codex artifacts must be tracked so the hardened contract is reviewable and durable.

## Problem Frame

Recent review surfaced two concrete issues:

1. The app still presents and restores API-key auth even though the current product contract is ChatGPT/Codex-only for this phase.
2. The strongest contract-hardening artifacts exist locally but are not fully incorporated into tracked, reviewable project scope.

As long as the API-key path stays user-facing and app-state-visible, the product still carries the parity burden that the previous hardening plan was trying to remove. As long as the new fixture suite and evidence doc remain easy to exclude from review scope, the contract can drift again.

## Requirements Trace

- R1. Keyframe no longer offers API-key authentication in the current product experience.
- R2. Persisted auth resolution restores ChatGPT/Codex auth only; stale API-key state cannot silently authenticate the app.
- R3. The first-run style-reference flow remains green under the narrowed ChatGPT/Codex-only contract.
- R4. Codex hardening artifacts are tracked, included in the generated Xcode project state, and visible in review scope.

## Scope Boundaries

- No redesign of the setup or style screens beyond removing API-key-specific affordances and copy.
- No changes to the already-hardened Codex request contract unless a test or compile issue forces a narrow follow-up.
- No attempt to fully delete every dormant platform helper in `OpenAIService.swift` if the app contract can be narrowed cleanly at the auth and test layers.
- Local-only files such as `Keyframe.xcodeproj/xcuserdata/`, `Keyframe.xcodeproj/project.xcworkspace/xcuserdata/`, and `default.profraw` remain out of scope.

## Context & Research

### Relevant Code and Patterns

- `Keyframe/Views/SetupView.swift` still renders `Use API key instead` and the inline API-key form.
- `Keyframe/Services/AuthManager.swift` still saves, resolves, and returns `.apiKey(...)`.
- `Keyframe/State/AppState.swift` still models `AuthMode.apiKey(String)`.
- `Keyframe/Views/HeaderView.swift` still renders `API Key` and `Using API key`.
- `KeyframeTests/CodexBackendFixtureTests.swift` already demonstrates the target first-run contract: ChatGPT tokens, style reference fixture, then `lockStyle()`.
- `project.yml` already includes `KeyframeTests` as a source root, which means new test files belong in the project once `Keyframe.xcodeproj/project.pbxproj` is regenerated.

### Institutional Learnings

- `docs/solutions/best-practices/keyframe-chatgpt-codex-contract-2026-04-10.md` defines the current evidence hierarchy and explicitly states that the stabilization-phase contract is ChatGPT/Codex-first.
- `docs/solutions/best-practices/chatgpt-subscription-via-codex-backend-api-2026-04-10.md` records the backend differences that motivated the contract hardening.

## Key Technical Decisions

- **Narrow the product contract at the app boundary**: Remove API-key behavior from auth state, auth resolution, setup UI, and product-facing tests. This is the smallest change that actually enforces the phase contract.
- **Keep contract validation centered on Codex fixtures**: The durable regression layer should be Codex request-builder tests plus fixture-backed backend tests, not broader platform parity coverage.
- **Treat generated project state as part of the deliverable**: Because this repo tracks `Keyframe.xcodeproj/project.pbxproj`, the plan must include regenerating and reviewing that file whenever new test sources are added.
- **Do not expand scope into a full platform-helper purge unless necessary**: Removing dormant private helpers in `OpenAIService.swift` is lower leverage than removing the app-level affordances and test assumptions that keep parity alive.

## Open Questions

### Resolved During Planning

- **Should this fix remove API-key support only from the UI, or from the app contract more broadly?** Remove it from the broader app contract for this phase. UI-only removal would still leave `AuthMode`, auth restoration, and tests carrying parity complexity.
- **Do we need `project.yml` changes to include the new fixture suite?** No. `project.yml` already includes `KeyframeTests`; the generated `Keyframe.xcodeproj/project.pbxproj` just needs to be refreshed and committed.

### Deferred to Implementation

- **Should dormant platform-only helpers in `OpenAIService.swift` be deleted now or left as non-product code?** Defer until implementation. If they become dead-weight noise or complicate compilation/tests, remove them. Otherwise, keep the fix focused on the product boundary.

## Implementation Units

- [ ] **Unit 1: Collapse the app auth contract to ChatGPT/Codex-only**

**Goal:** Remove API-key auth from the current product experience and persisted app auth resolution.

**Requirements:** R1, R2

**Dependencies:** None

**Files:**
- Modify: `Keyframe/State/AppState.swift`
- Modify: `Keyframe/Services/AuthManager.swift`
- Modify: `Keyframe/Services/KeychainService.swift`
- Modify: `Keyframe/Views/SetupView.swift`
- Modify: `Keyframe/Views/HeaderView.swift`
- Test: `KeyframeTests/AuthTests.swift`
- Test: `KeyframeTests/SetupFlowTests.swift`

**Approach:**
- Remove `AuthMode.apiKey(String)` from app-facing state.
- Remove API-key save/load/resolve behavior from `AuthManager` so persisted auth restoration returns only `.oauth(...)` or `.none`.
- Remove API-key-specific setup affordances, help copy, and header labels.
- Ensure stale API-key values do not mark the app authenticated after launch.
- Keep the Codex CLI session import and ChatGPT OAuth flows intact.

**Execution note:** Start with failing auth and setup tests that express the narrowed contract before removing the API-key path from the app boundary.

**Patterns to follow:**
- Existing Codex-first setup flow in `Keyframe/Views/SetupView.swift`
- Existing ChatGPT token import path in `Keyframe/Services/AuthManager.swift`

**Test scenarios:**
- Happy path: resolving stored OAuth tokens returns `.oauth(...)` and allows advancing from setup to style.
- Happy path: unauthenticated setup view offers `Sign in with ChatGPT` and, when available, `Use Codex CLI session`, but no API-key affordance.
- Edge case: a stale stored API-key value does not authenticate the app and does not appear in the header/auth badge.
- Error path: cancelled OAuth returns auth state to idle without exposing an API-key fallback.
- Integration: after Codex token import, the header/auth status reflects ChatGPT/Codex-only messaging.

**Verification:**
- No product-facing code path emits or depends on `.apiKey(...)`.
- Setup and header UI contain no API-key-specific strings or controls.

- [ ] **Unit 2: Migrate feature tests to the narrowed Codex contract**

**Goal:** Remove product-test dependence on API-key auth and make Codex the supported behavioral path in setup/style/export flows.

**Requirements:** R2, R3

**Dependencies:** Unit 1

**Files:**
- Modify: `KeyframeTests/AuthTests.swift`
- Modify: `KeyframeTests/AppStateTests.swift`
- Modify: `KeyframeTests/SetupFlowTests.swift`
- Modify: `KeyframeTests/StyleFlowTests.swift`
- Modify: `KeyframeTests/EdgeCaseTests.swift`
- Modify: `KeyframeTests/ExportFlowTests.swift`
- Modify: `KeyframeTests/OpenAIServiceTests.swift`
- Test: `KeyframeTests/CodexBackendFixtureTests.swift`

**Approach:**
- Replace API-key-backed auth setup in feature-bearing tests with ChatGPT/Codex token setup where the test only needs authenticated gating.
- Remove or rewrite product-facing API-key tests that no longer represent supported behavior.
- Keep Codex request-builder tests and Codex fixture tests as the primary contract layer.
- Preserve narrow low-level assertions only if they still exercise supported code or unavoidable compatibility seams.

**Execution note:** Characterize the current Codex-first happy path first, then port the surrounding auth-gated flow tests one suite at a time.

**Patterns to follow:**
- `KeyframeTests/CodexBackendFixtureTests.swift`
- Existing Codex request-builder assertions in `KeyframeTests/OpenAIServiceTests.swift`

**Test scenarios:**
- Happy path: setup/style/export flow tests remain green when authenticated with `.oauth(...)`.
- Happy path: the first-run style-reference fixture path still advances to cast.
- Edge case: test suites that previously used `.apiKey(...)` for simple gating still behave correctly when switched to `.oauth(...)`.
- Error path: missing OAuth account ID still produces the specific Codex auth failure instead of a generic authenticated state.
- Integration: no feature-bearing test relies on API-key auth to prove setup, style, frames, or export behavior.

**Verification:**
- Product-facing suites no longer reference `.apiKey(...)` unless a test is intentionally documenting deferred legacy behavior.
- The contract-hardening suite remains the canonical proof for the first-run Codex flow.

- [ ] **Unit 3: Bring Codex hardening artifacts fully into tracked project scope**

**Goal:** Ensure the new fixture-backed contract work is tracked, included in generated project state, and reviewable as part of the branch.

**Requirements:** R4

**Dependencies:** Unit 2

**Files:**
- Modify: `Keyframe.xcodeproj/project.pbxproj`
- Modify: `docs/solutions/best-practices/chatgpt-subscription-via-codex-backend-api-2026-04-10.md`
- Create: `KeyframeTests/CodexBackendFixtureTests.swift`
- Create: `KeyframeTests/Fixtures/codex-style-reference-success.sse`
- Create: `KeyframeTests/Fixtures/codex-style-reference-error-missing-instructions.json`
- Create: `KeyframeTests/Fixtures/codex-style-reference-error-input-must-be-list.json`
- Create: `docs/solutions/best-practices/keyframe-chatgpt-codex-contract-2026-04-10.md`

**Approach:**
- Treat the existing fixture suite, fixture files, and evidence doc as part of the intended deliverable rather than incidental local state.
- Regenerate and review `Keyframe.xcodeproj/project.pbxproj` so the added test file is included in the tracked project artifact.
- Keep unrelated local-only files untracked and out of the plan.

**Patterns to follow:**
- Existing tracked docs under `docs/solutions/`
- Existing generated-project workflow implied by `project.yml`

**Test expectation:** none -- this unit is about tracked scope and generated project state, not new runtime behavior

**Verification:**
- The fixture suite is included in the tracked Xcode project state.
- The artifact files no longer appear as excluded untracked scope in review.
- Local-only files remain intentionally untracked.

- [ ] **Unit 4: Align repo documentation with the narrowed product contract**

**Goal:** Update repo-facing guidance so future work does not reintroduce API-key parity as a default assumption during this phase.

**Requirements:** R1, R4

**Dependencies:** Unit 1

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/solutions/best-practices/chatgpt-subscription-via-codex-backend-api-2026-04-10.md`
- Modify: `docs/solutions/best-practices/keyframe-chatgpt-codex-contract-2026-04-10.md`

**Approach:**
- Update project overview and auth descriptions to reflect the current ChatGPT/Codex-only stabilization posture.
- Make the evidence hierarchy and current product boundary explicit so future agents do not treat API-key parity as required behavior for this phase.

**Patterns to follow:**
- Existing solution-doc frontmatter and format in `docs/solutions/`

**Test expectation:** none -- documentation and guidance alignment only

**Verification:**
- Repo guidance no longer describes API-key auth as part of the current supported product contract for this phase.

## System-Wide Impact

- **Interaction graph:** auth state changes affect setup gating, header badge copy, persisted credential resolution, and any test that assumes `isAuthenticated` via `.apiKey(...)`.
- **Error propagation:** removing API-key restoration should reduce false-positive authenticated states and make Codex-specific auth failures more explicit.
- **State lifecycle risks:** stale API-key data in Keychain/UserDefaults must be ignored or purged so older local state does not leak into the narrowed contract.
- **Integration coverage:** the fixture-backed first-run style-reference flow is the key cross-layer scenario because it spans auth restoration, request contract, response parsing, and phase advancement.
- **Unchanged invariants:** the ChatGPT OAuth flow, Codex CLI token import flow, and Codex request-builder contract remain the supported path and should not regress.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Removing `.apiKey(...)` creates wider compile fallout than expected | Start at the auth boundary and port tests suite-by-suite so fallout is discovered early, not after broad cleanup |
| Stale persisted API-key data still authenticates legacy local environments | Explicitly test stale-key restore behavior and clear or ignore API-key storage during auth resolution |
| New fixture suite is implemented but still omitted from tracked project state | Regenerate and review `Keyframe.xcodeproj/project.pbxproj` as part of the deliverable, not as a local afterthought |

## Documentation / Operational Notes

- Keep `docs/smoke-test-script.md` out of scope unless it becomes necessary to prove the narrowed contract.
- Ignore `xcuserdata` and `default.profraw` during implementation; they are local artifacts, not part of the fix.

## Sources & References

- Related plan context: `docs/plans/2026-04-10-003-fix-review-findings-plan.md`
- Related code: `Keyframe/Views/SetupView.swift`
- Related code: `Keyframe/Services/AuthManager.swift`
- Related code: `KeyframeTests/CodexBackendFixtureTests.swift`
- Related docs: `docs/solutions/best-practices/keyframe-chatgpt-codex-contract-2026-04-10.md`
- Related docs: `docs/solutions/best-practices/chatgpt-subscription-via-codex-backend-api-2026-04-10.md`
