---
title: "feat: TDD screen-by-screen verification of Keyframe app"
type: feat
status: active
date: 2026-04-10
---

# TDD screen-by-screen verification of Keyframe app

## Overview

Add comprehensive test coverage that walks through every screen and interaction in the Keyframe app, phase by phase. Tests verify behavior through public interfaces (AppState, AuthManager, models) following TDD's red-green-refactor loop: one test at a time, one behavior at a time. Each unit maps to a screen or interaction the user encounters when walking through the app from launch to export.

## Problem frame

The app has solid model and service tests but no systematic coverage of the user-facing interaction flows. Phase gating, screen transitions, data flow between screens, and edge cases at screen boundaries are untested. Without this, regressions slip through when fixing layout or adding features.

## Requirements trace

- R1. Every phase transition (setup -> style -> cast -> frames -> export) is tested through AppState's public API
- R2. Auth flows (API key, Codex import, OAuth status, logout, resolve) are covered end-to-end
- R3. Style definition workflow (add/remove images, set description, lock, cap at 3) is tested
- R4. Cast management (add, edit, remove characters; proceed gating) is tested
- R5. Frame generation workflow (template selection, freeform add/remove, scene description, image accept, status transitions) is tested
- R6. Export gating (requires at least one complete frame) is tested
- R7. Undo/redo works correctly across all phase mutations
- R8. Edge cases at screen boundaries are covered (empty states, max limits, invalid inputs)

## Scope boundaries

- Tests cover AppState, AuthManager, CodexDetector, model logic, and phase flow through public APIs
- Tests do NOT test SwiftUI view rendering, layout, or visual appearance (no ViewInspector, no snapshot tests)
- Tests do NOT make real network calls (OpenAI API tests remain as-is)
- Tests do NOT test OAuth browser flow (requires real browser interaction)
- Tests DO test the logical decisions views would make (gating, state transitions, data mutations)

## Context and research

### Relevant code and patterns

- Existing tests use Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect`)
- Tests are `@MainActor` and `.serialized` when testing `AppState` (which is `@MainActor @Observable`)
- Test files live in `KeyframeTests/` and are included in the `KeyframeTests` target via `project.yml`
- All AppState mutations go through public methods that call `pushHistory()` for undo support
- Phase gating logic is centralized in `AppState.canAdvanceToPhase(_:)`

### Existing coverage gaps

Existing tests cover:
- Template selection, character CRUD, frame updates, undo/redo basics, phase gating rules, reorder
- Keychain CRUD, CodexDetector parsing, AuthManager API key flow and Codex import
- Project JSON round-trips, template lookup
- OpenAI service endpoint configuration and error types

Missing coverage:
- Full phase-flow walkthrough (setup -> style -> cast -> frames -> export)
- Style workflow (add images, analyze, lock, cap, remove)
- Character update with partial fields
- Frame status lifecycle (empty -> generating -> complete)
- Custom template creation flow
- Reset project behavior
- Auth mode resolution priority (OAuth > API key > none)
- Sign-in button behavior (setPhase to setup)
- Multiple undo/redo across different mutation types
- Sidebar tab sync logic
- Edge cases: adding 4th reference image, removing nonexistent character, updating nonexistent frame

## Key technical decisions

- **Test through AppState, not views**: SwiftUI views are thin wrappers over AppState mutations. Testing AppState proves the behavior without needing UI test infrastructure.
- **One test file per screen/flow**: Maps mental model of "screen by screen" to file organization, keeping tests navigable.
- **Vertical TDD slices**: Each implementation unit is one test-then-implementation cycle. Write one test, make it pass, move to the next.
- **No mocking of AppState internals**: Tests use real AppState instances. The only stubbing is for external dependencies (file I/O for CodexDetector, Keychain for AuthManager).

## Implementation units

- [ ] **Unit 1: Setup screen - auth mode resolution and phase entry**

**Goal:** Test the auth resolution logic that runs when SetupView appears, and the sign-in button's navigation to setup phase.

**Requirements:** R1, R2

**Dependencies:** None

**Files:**
- Create: `KeyframeTests/SetupFlowTests.swift`

**Approach:**
- Test `resolveAuthMode()` priority: OAuth tokens take precedence over API key, both take precedence over none
- Test that `setPhase(.setup)` correctly transitions phase (simulates sign-in button in HeaderView)
- Test that a fresh AppState starts in `.setup` phase

**Patterns to follow:**
- `KeyframeTests/AuthTests.swift` for AuthManager patterns
- `KeyframeTests/AppStateTests.swift` for AppState mutation patterns

**Test scenarios:**
- Happy path: resolveAuthMode returns .oauth when both OAuth and API key exist
- Happy path: resolveAuthMode returns .apiKey when only API key exists
- Happy path: resolveAuthMode returns .none when nothing stored
- Happy path: setPhase(.setup) changes currentPhase to .setup
- Happy path: fresh AppState starts in .setup phase
- Edge case: setPhase(.setup) is always allowed (canAdvanceToPhase(.setup) is always true)

**Verification:**
- All tests pass. Auth resolution priority is proven.

---

- [ ] **Unit 2: Setup screen - template selection and custom template creation**

**Goal:** Test that selecting built-in templates and freeform populates frames correctly, and that custom template creation works end-to-end.

**Requirements:** R5

**Dependencies:** Unit 1

**Files:**
- Modify: `KeyframeTests/SetupFlowTests.swift`

**Approach:**
- Test each built-in template produces correct frame count and titles
- Test custom template creation with valid and edge-case inputs
- Test that custom templates appear in lookup after being added

**Patterns to follow:**
- `KeyframeTests/AppStateTests.swift` (selectTemplate tests already exist; extend with custom template flow)

**Test scenarios:**
- Happy path: selecting hero-journey produces 8 frames with correct first title
- Happy path: selecting problem-solution produces 3 frames
- Happy path: addCustomTemplate followed by selectTemplate populates frames from custom beats
- Happy path: custom template appears in BuiltInTemplates.find with customTemplates parameter
- Edge case: selecting nonexistent template ID does not crash or change state
- Edge case: custom template with isCustom flag returns true

**Verification:**
- All template selection paths produce correct frames. Custom templates integrate with lookup.

---

- [ ] **Unit 3: Setup screen - proceed gating (setup -> style)**

**Goal:** Test the proceed button logic: can only advance to style when authenticated.

**Requirements:** R1, R2

**Dependencies:** Unit 1

**Files:**
- Modify: `KeyframeTests/SetupFlowTests.swift`

**Approach:**
- Test canAdvanceToPhase(.style) returns false when authMode is .none
- Test canAdvanceToPhase(.style) returns true when authMode is .apiKey or .oauth
- Test setPhase(.style) changes phase when authenticated
- Test the full flow: authenticate then proceed

**Test scenarios:**
- Happy path: authenticated user can advance to style
- Happy path: setPhase(.style) after auth changes currentPhase
- Error path: unauthenticated user cannot advance to style (canAdvanceToPhase returns false)
- Integration: authenticate via API key -> canAdvanceToPhase(.style) becomes true -> setPhase(.style) succeeds

**Verification:**
- Phase gating from setup to style is proven correct.

---

- [ ] **Unit 4: Style screen - reference image management**

**Goal:** Test adding, removing, and capping reference images at 3.

**Requirements:** R3

**Dependencies:** None

**Files:**
- Create: `KeyframeTests/StyleFlowTests.swift`

**Approach:**
- Test addReferenceImage adds data to style.referenceImages
- Test removeReferenceImage at valid index removes correctly
- Test cap at 3 images (4th add is silently ignored)
- Test remove at invalid index does nothing

**Test scenarios:**
- Happy path: addReferenceImage appends data, count increases
- Happy path: add 3 images, all are retained
- Happy path: removeReferenceImage(at: 1) with 3 images leaves 2, correct items remain
- Edge case: addReferenceImage when already at 3 does not increase count
- Edge case: removeReferenceImage at out-of-bounds index does nothing
- Edge case: removeReferenceImage on empty array does nothing

**Verification:**
- Reference image CRUD respects the 3-image cap and handles edge cases.

---

- [ ] **Unit 5: Style screen - description and lock flow**

**Goal:** Test setting the style description, locking style, and the auto-advance to cast phase.

**Requirements:** R3, R1

**Dependencies:** Unit 4

**Files:**
- Modify: `KeyframeTests/StyleFlowTests.swift`

**Approach:**
- Test setStyleDescription stores the value
- Test lockStyle sets locked=true and advances to .cast
- Test canAdvanceToPhase(.cast) requires style.locked

**Test scenarios:**
- Happy path: setStyleDescription("Pencil sketch") stores description
- Happy path: lockStyle sets locked=true and currentPhase=.cast
- Happy path: canAdvanceToPhase(.cast) is true when style.locked is true
- Error path: canAdvanceToPhase(.cast) is false when style.locked is false
- Integration: add image -> set description -> lock -> phase is .cast

**Verification:**
- Style lock flow works and auto-advances to cast.

---

- [ ] **Unit 6: Cast screen - character CRUD and proceed gating**

**Goal:** Test add, update (partial), and remove characters, plus the cast -> frames gating.

**Requirements:** R4, R1

**Dependencies:** None

**Files:**
- Create: `KeyframeTests/CastFlowTests.swift`

**Approach:**
- Test addCharacter, updateCharacter with partial updates, removeCharacter
- Test canAdvanceToPhase(.frames) requires at least one character
- Test proceed from cast to frames

**Test scenarios:**
- Happy path: addCharacter increases count, character has correct fields
- Happy path: updateCharacter with only name changes name, preserves role and description
- Happy path: updateCharacter with only role changes role, preserves rest
- Happy path: removeCharacter removes by ID, count decreases
- Happy path: canAdvanceToPhase(.frames) is true when characters is non-empty
- Error path: canAdvanceToPhase(.frames) is false when characters is empty
- Edge case: updateCharacter with nonexistent ID does nothing
- Edge case: removeCharacter with nonexistent ID does nothing
- Integration: add character -> setPhase(.frames) succeeds

**Verification:**
- Character management works with partial updates and gating is correct.

---

- [ ] **Unit 7: Frames screen - frame status lifecycle and scene workflow**

**Goal:** Test frame status transitions (empty -> generating -> complete), scene description updates, and image acceptance.

**Requirements:** R5

**Dependencies:** None

**Files:**
- Create: `KeyframeTests/FramesFlowTests.swift`

**Approach:**
- Test updateFrame with status transitions
- Test updateFrame with sceneDescription and imageData
- Test that accepting an image sets status to .complete
- Test selectFrame behavior

**Test scenarios:**
- Happy path: new frame starts with status .empty
- Happy path: updateFrame with status .generating changes status
- Happy path: updateFrame with sceneDescription, imageData, and status .complete simulates full accept flow
- Happy path: selectFrame sets selectedFrameId, selectedFrame computed property returns matching frame
- Happy path: selectFrame(nil) clears selection
- Edge case: updateFrame on nonexistent frame ID does nothing
- Edge case: selectedFrame returns nil when selectedFrameId does not match any frame

**Verification:**
- Frame lifecycle from empty to complete is proven. Selection works.

---

- [ ] **Unit 8: Export screen - export gating**

**Goal:** Test that export phase requires at least one complete frame.

**Requirements:** R6, R1

**Dependencies:** Unit 7

**Files:**
- Create: `KeyframeTests/ExportFlowTests.swift`

**Approach:**
- Test canAdvanceToPhase(.export) with no complete frames
- Test canAdvanceToPhase(.export) with one complete frame
- Test full flow from setup to export

**Test scenarios:**
- Happy path: canAdvanceToPhase(.export) is true when at least one frame has status .complete
- Error path: canAdvanceToPhase(.export) is false when no frames have status .complete
- Error path: canAdvanceToPhase(.export) is false when frames exist but all are .empty or .generating
- Integration: full phase walkthrough: auth -> select template -> lock style -> add character -> complete a frame -> canAdvanceToPhase(.export) is true

**Verification:**
- Export gating is correct. Full app walkthrough passes.

---

- [ ] **Unit 9: Cross-cutting - undo/redo across phase mutations**

**Goal:** Test that undo/redo works correctly across different types of mutations and phase changes.

**Requirements:** R7

**Dependencies:** Units 1-8

**Files:**
- Create: `KeyframeTests/UndoRedoFlowTests.swift`

**Approach:**
- Test undo after phase change restores previous phase
- Test undo after lockStyle restores unlocked state and previous phase
- Test undo after addCharacter removes the character
- Test redo after undo restores the mutation
- Test that undo history is bounded (max 50 snapshots)
- Test interleaving different mutation types with undo

**Test scenarios:**
- Happy path: undo after setPhase restores previous phase
- Happy path: undo after lockStyle restores style.locked=false and previous phase
- Happy path: undo after addCharacter restores empty characters
- Happy path: redo after undo restores the change
- Happy path: multiple undos walk back through history
- Edge case: 51 mutations followed by 51 undos - only 50 succeed, then canUndo is false
- Integration: setPhase(.style) -> lockStyle() -> addCharacter -> undo -> undo -> undo restores setup phase

**Verification:**
- Undo/redo is reliable across mutation types. History cap works.

---

- [ ] **Unit 10: Cross-cutting - reset project and edge cases**

**Goal:** Test resetProject clears everything, and various boundary conditions across the app.

**Requirements:** R8

**Dependencies:** Units 1-9

**Files:**
- Create: `KeyframeTests/EdgeCaseTests.swift`

**Approach:**
- Test resetProject returns to empty state
- Test resetProject clears selectedFrameId
- Test resetProject is undoable
- Test various boundary scenarios

**Test scenarios:**
- Happy path: resetProject after full setup returns project to .empty and clears selectedFrameId
- Happy path: undo after resetProject restores previous state
- Edge case: addFrame on empty project (no template selected) still works
- Edge case: moveFrame with only 1 frame does nothing (source = before)
- Edge case: multiple rapid setPhase calls produce correct undo history
- Edge case: setStyleDescription with empty string stores empty string
- Edge case: addCustomTemplate followed by resetProject clears custom templates

**Verification:**
- Reset and edge cases are handled gracefully. No crashes.

---

- [ ] **Unit 11: Build verification**

**Goal:** Run full test suite and verify all tests pass.

**Requirements:** R1-R8

**Dependencies:** Units 1-10

**Files:**
- No new files

**Approach:**
- Run `xcodebuild test` against the KeyframeTests target
- Fix any compilation or test failures

**Test expectation: none -- this is a build/run verification step**

**Verification:**
- `xcodebuild test` exits with code 0. All tests green.

## System-wide impact

- **Interaction graph:** Tests exercise AppState methods that views call. No views are modified.
- **Error propagation:** Test failures surface through Swift Testing's `#expect` and `Issue.record`.
- **State lifecycle risks:** None. Tests create fresh AppState instances per test.
- **API surface parity:** No API changes. Tests only consume existing public interfaces.
- **Integration coverage:** Unit 8 includes a full-app walkthrough test that exercises all phases sequentially.
- **Unchanged invariants:** All existing tests, views, models, and services remain unmodified.

## Risks and dependencies

| Risk | Mitigation |
|------|------------|
| Keychain tests may leak state between runs | Existing pattern: each test cleans up with `KeychainService.delete()` / `deleteAll()` |
| `@MainActor` requirement on AppState tests | Follow existing `.serialized` trait pattern in test suites |
| Tests may duplicate existing coverage | Review existing tests before writing each unit; extend rather than duplicate |

## Sources and references

- Existing tests: `KeyframeTests/AppStateTests.swift`, `KeyframeTests/AuthTests.swift`, `KeyframeTests/ProjectModelTests.swift`
- TDD skill: vertical slices, behavior-focused, public interface only
- Swift Testing framework: `@Suite`, `@Test`, `#expect`, `Issue.record`
