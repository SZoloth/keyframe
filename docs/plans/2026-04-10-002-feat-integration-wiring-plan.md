---
title: "feat: Wire OpenAI service to views + integration polish"
type: feat
status: active
date: 2026-04-10
origin: docs/plans/2026-04-10-001-feat-native-macos-app-plan.md
---

# feat: Wire OpenAI service to views + integration polish

## Overview

The Keyframe macOS app scaffolding is complete (8 units, 43 passing tests), but the core loop is not functional. Views have placeholder buttons that don't call the OpenAI API. The async auth flow has a race condition. The service layer lacks vision-based style analysis. Several UX features from the original plan (frame deletion, drag reorder, custom template creation, window title) are not yet implemented. This plan covers everything needed to go from "compiles and launches" to "works end-to-end."

## Problem Frame

A user launching Keyframe today sees the full UI, can select templates and navigate phases, but cannot generate any AI content — the buttons that should call `OpenAIService` are wired to `// Placeholder` comments. The auth flow has a bug where `authMode` is set before the async OAuth completes. Without this integration work, the app is a non-functional shell.

## Requirements Trace

- R1. Core generation loop works: suggest scene -> refine -> generate image -> accept/reject (from origin R8)
- R2. Style analysis sends reference images to GPT-4o vision and populates description (from origin R6)
- R3. Style reference generation from text description works end-to-end (from origin R6)
- R4. OAuth sign-in completes before authMode is set — no race condition (from origin R1)
- R5. Custom template creation UI (from origin R5, R12)
- R6. Frame deletion from canvas (from origin R8)
- R7. Window title reflects current file name (from origin R10)
- R8. Drag-to-reorder frames on canvas (from origin R8)

## Scope Boundaries

- No streaming responses — all API calls are request/response
- No API key validation call (kept simple; errors surface on first real API call)
- No image caching or thumbnail generation
- No Codex-specific endpoint format — both auth modes use standard `api.openai.com` endpoints (simplifies v1; can add Codex backend later if needed)
- No drag-and-drop for reference images (file picker only)

## Context & Research

### Relevant Code and Patterns

- `Keyframe/Services/OpenAIService.swift` — Actor with `suggestScene`, `refineScene`, `generateFrameImage`, `generateStyleReference`, `chatCompletion`, `imageGeneration`. Missing: `analyzeStyle` (vision endpoint with images). All methods are async throws and return `String` or `Data`.
- `Keyframe/Views/ChatView.swift` — Has `// Placeholder for scene suggestion`, `// Placeholder for image generation`, `// Re-generate` comments at lines 158, 171, 183. The local state (`messages`, `currentScene`, `pendingImageData`, `loading`) is already structured correctly.
- `Keyframe/Views/StyleView.swift` — Has `// Placeholder for style analysis` and `// Placeholder for style generation` at lines 152, 170. Mode toggle, image picker, description editor all work.
- `Keyframe/Views/SetupView.swift` — OAuth button at line 79-82 runs `Task { await authManager.loginWithOAuth() }` then immediately calls `appState.authMode = authManager.resolveAuthMode()` outside the Task, creating a race condition where authMode is resolved before OAuth completes.
- `Keyframe/State/AppState.swift` — Has `addFrame`, `removeFrame`, `reorderFrames` methods. `removeFrame` exists but no UI calls it. `reorderFrames` exists but canvas has no drag support.
- `Keyframe/Views/CanvasView.swift` — `FrameCard` has no delete button. `frameGrid` uses `LazyVGrid` with `onTapGesture` but no drag modifiers.

### Institutional Learnings

- `OpenAIService` is an `actor`, so all calls from `@MainActor` views require `await`. The service is not injected via environment — it needs to be created/accessed from views or injected similarly to `AuthManager`.
- The web app's `ChatTab.tsx` maintains a local `messages` array and `currentScene` string, resetting on frame change. Our `ChatView` already mirrors this pattern.
- The web app's style analysis uses the `content` array format with `type: "image_url"` entries for vision. Our `chatCompletion` only supports `type: "text"` content — needs a multipart variant.

## Key Technical Decisions

- **OpenAIService as environment object**: Inject it via `.environment()` from `KeyframeApp`, similar to `AuthManager`. This gives all views access without creating multiple instances or passing it through constructors.
- **Vision via multipart content array**: Add a `chatCompletionWithImages` method to `OpenAIService` that accepts `[(type, content)]` entries, supporting both text and base64 image_url items. This matches the GPT-4o vision API format.
- **Frame context menu for delete**: Use `.contextMenu` on `FrameCard` for delete action rather than a persistent button, keeping the card clean. Freeform mode only.
- **Draggable/dropDestination for reorder**: Use SwiftUI's `draggable`/`dropDestination` modifiers on frame cards. This is cleaner than `onDrag`/`onDrop` for same-container reordering.

## Open Questions

### Resolved During Planning

- **How to inject OpenAIService into views?** — As an `@State` on `KeyframeApp`, injected via `.environment()`. It's an actor so thread-safe by design.
- **How to fix the auth race condition?** — Move `authMode` update inside the `Task` block, after `await`.
- **Where to put custom template creation?** — In `SetupView`, below the template selection list, matching the web app layout.

### Deferred to Implementation

- **Image compression before sending to vision API**: Large reference images may hit API limits. May need to resize/compress before base64 encoding. Test with real images during implementation.
- **Drag reorder animation quality**: SwiftUI's `dropDestination` may have visual quirks. Acceptable for v1.

## Implementation Units

- [ ] **Unit 9: Inject OpenAIService and fix auth race condition**

**Goal:** Make `OpenAIService` available to all views via environment, auto-configure it when auth changes, and fix the async OAuth bug.

**Requirements:** R4

**Dependencies:** None (builds on existing code)

**Files:**
- Modify: `Keyframe/KeyframeApp.swift`
- Modify: `Keyframe/Views/SetupView.swift`
- Modify: `Keyframe/State/AppState.swift`

**Approach:**
- Add `@State private var openAIService = OpenAIService()` to `KeyframeApp` and inject via `.environment()`.
- Add an `onChange(of: appState.authMode)` modifier that calls `openAIService.configure(authMode:)` whenever auth changes.
- In `SetupView`, move `appState.authMode = authManager.resolveAuthMode()` inside the `Task` block after `await authManager.loginWithOAuth()`.
- Same fix for the Codex token import and API key flows — ensure `authMode` is set after the operation completes, not alongside it.

**Patterns to follow:**
- Existing `AuthManager` injection pattern in `KeyframeApp`

**Test scenarios:**
- Happy path: After OAuth completes, `appState.authMode` is non-nil and `OpenAIService` is configured
- Edge case: OAuth cancelled — `authMode` stays `.none`, service stays unconfigured
- Error path: OAuth fails — `authMode` stays `.none`, error surfaces in UI

**Verification:**
- Auth flow completes without race condition
- OpenAI service is configured and ready for API calls after sign-in

- [ ] **Unit 10: Add vision-based style analysis to OpenAIService**

**Goal:** Add `analyzeStyle` method that sends reference images to GPT-4o vision and returns a style description.

**Requirements:** R2

**Dependencies:** Unit 9

**Files:**
- Modify: `Keyframe/Services/OpenAIService.swift`
- Test: `KeyframeTests/OpenAIServiceTests.swift`

**Approach:**
- Add a `chatCompletionWithImages` private method that builds a `content` array with both `text` and `image_url` entries (base64 data URIs).
- Add public `analyzeStyle(referenceImages: [Data]) async throws -> String` that constructs the vision prompt (same as web app's `analyzeStyle` in `StyleTab.tsx`) and calls `chatCompletionWithImages`.
- The `image_url` format: `{"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}`.
- Max tokens: 500 (matching web app).

**Patterns to follow:**
- Existing `chatCompletion` method structure in `OpenAIService`
- Web app's vision prompt in `StyleTab.tsx` lines 78-100

**Test scenarios:**
- Happy path: `analyzeStyle` with endpoint configured does not throw `notAuthenticated`
- Edge case: Empty `referenceImages` array should still produce a valid request (text-only fallback)
- Error path: Unconfigured service throws `notAuthenticated`

**Verification:**
- `analyzeStyle` compiles and the request format matches GPT-4o vision API spec

- [ ] **Unit 11: Wire OpenAIService to StyleView**

**Goal:** Connect the "Analyze style" and "Generate reference" buttons to real API calls.

**Requirements:** R2, R3

**Dependencies:** Unit 10

**Files:**
- Modify: `Keyframe/Views/StyleView.swift`

**Approach:**
- Inject `OpenAIService` via `@Environment`.
- "Analyze style" button: call `openAIService.analyzeStyle(referenceImages:)`, set result via `appState.setStyleDescription()`. Show `analyzing` spinner.
- "Generate reference" button: call `openAIService.generateStyleReference(description:)`, add result via `appState.addReferenceImage()`, then auto-trigger analysis. Show `generating` spinner.
- Handle errors with `errorMessage` state, display below the button.
- After accepting a generated reference, auto-analyze to populate the description.

**Patterns to follow:**
- Web app's `StyleTab.tsx` `analyzeStyle` and `handleGenerateReference` functions

**Test scenarios:**
- Happy path: Clicking "Analyze style" with images calls the service and populates description
- Happy path: "Generate reference" creates an image and adds it to reference images
- Error path: API failure shows error text without crashing

**Verification:**
- Style analysis populates the description field from real reference images
- Style reference generation produces a visible image

- [ ] **Unit 12: Wire OpenAIService to ChatView (core generation loop)**

**Goal:** Connect "Suggest a scene", "Generate image", "Try again", and refinement to real API calls, completing the core generation loop.

**Requirements:** R1

**Dependencies:** Unit 9

**Files:**
- Modify: `Keyframe/Views/ChatView.swift`

**Approach:**
- Inject `OpenAIService` via `@Environment`.
- "Suggest a scene" button: resolve beat guidance from the template, call `openAIService.suggestScene(...)` with style, characters, previous frames. Add result to `messages` and set `currentScene`.
- "Generate image" button: call `openAIService.generateFrameImage(...)`, update `appState.updateFrame(id, status: .generating)` before call, set `pendingImageData` on success, revert to `.empty` on failure.
- "Try again" button: re-call `generateFrameImage` with same scene.
- Chat input send: if `currentScene` is set, call `openAIService.refineScene(...)` with user feedback. Otherwise treat as direct scene description.
- Error handling: catch errors, append assistant message with error text, revert loading state.
- All API calls wrapped in `Task { }` with `loading` state management.

**Patterns to follow:**
- Web app's `ChatTab.tsx` `handleSuggestScene`, `handleGenerateImage`, `handleSend` functions
- Existing `ChatView` local state management (`messages`, `currentScene`, `pendingImageData`, `loading`)

**Test scenarios:**
- Happy path: "Suggest a scene" populates chat with AI-generated scene description
- Happy path: "Generate image" shows loading, then displays generated image with Accept/Try Again
- Happy path: "Accept" commits image to frame and marks complete
- Happy path: Chat refinement updates scene description via API
- Error path: API failure adds error message to chat, reverts loading/status
- Edge case: Switching frames resets chat and scene state

**Verification:**
- Full loop works: suggest → refine → generate → accept → image appears on canvas

- [ ] **Unit 13: Custom template creation UI**

**Goal:** Add a form in SetupView for creating custom templates with named beats.

**Requirements:** R5

**Dependencies:** None

**Files:**
- Modify: `Keyframe/Views/SetupView.swift`

**Approach:**
- Add a "Create custom template" disclosure group below the template list.
- Form fields: template name, description (optional), dynamic list of beats (title + guidance).
- "Add beat" button appends a row. "Remove" button on each beat.
- "Save template" button calls `appState.addCustomTemplate(...)` and auto-selects it.
- Validation: name required, at least one beat with a title.
- Custom templates appear in the template list alongside built-in ones (already handled — `allTemplates` computed property exists).

**Patterns to follow:**
- Web app's `SetupTab.tsx` lines 284-367 for custom template form layout
- Existing `CharacterFormView` pattern for dynamic form with add/remove

**Test scenarios:**
- Happy path: Creating a custom template adds it to the selection list
- Happy path: Selecting a custom template populates frames from its beats
- Edge case: Empty name shows validation error, Save button disabled
- Edge case: Template with no beats shows validation error

**Verification:**
- Custom template creation flow works from SetupView
- Created templates persist in the project file

- [ ] **Unit 14: Frame deletion and context menu**

**Goal:** Add delete capability to frame cards via context menu.

**Requirements:** R6

**Dependencies:** None

**Files:**
- Modify: `Keyframe/Views/CanvasView.swift`

**Approach:**
- Add `.contextMenu` to `FrameCard` with "Delete frame" action (destructive role).
- Only show delete option in freeform mode (`appState.project.selectedTemplateId == "freeform"`).
- Confirmation via native `.confirmationDialog` before deletion.
- Call `appState.removeFrame(frame.id)` on confirm.

**Patterns to follow:**
- SwiftUI `.contextMenu` and `.confirmationDialog` standard patterns

**Test scenarios:**
- Happy path: Right-click frame in freeform mode shows delete option
- Happy path: Confirming delete removes frame from canvas
- Edge case: Delete last frame leaves empty state
- Edge case: Context menu does not show delete for template-based frames

**Verification:**
- Frames can be deleted in freeform mode via right-click

- [ ] **Unit 15: Window title reflecting current file**

**Goal:** Show the current `.keyframe` file name in the window title bar.

**Requirements:** R7

**Dependencies:** None

**Files:**
- Modify: `Keyframe/Views/ContentView.swift`
- Modify: `Keyframe/KeyframeApp.swift`

**Approach:**
- Use `.navigationTitle()` on the `WindowGroup` content, binding to `appState.currentFileURL?.lastPathComponent ?? "Untitled"`.
- Add document-dirty indicator: `.navigationDocument()` or manual title suffix when state has changed since last save (future enhancement, not v1).

**Patterns to follow:**
- SwiftUI `navigationTitle` on macOS window

**Test scenarios:**
- Happy path: New project shows "Untitled" in title bar
- Happy path: After File > Open, title bar shows filename
- Happy path: After File > Save As, title bar updates to new filename

**Verification:**
- Window title reflects current project file name

- [ ] **Unit 16: Drag-to-reorder frames**

**Goal:** Enable drag-and-drop reordering of frame cards on the canvas grid.

**Requirements:** R8

**Dependencies:** None

**Files:**
- Modify: `Keyframe/Views/CanvasView.swift`

**Approach:**
- Add `.draggable(frame.id)` to each `FrameCard`.
- Add `.dropDestination(for: String.self)` to the `LazyVGrid` or individual cards.
- On drop, resolve source and destination indices from frame IDs and call `appState.reorderFrames(from:to:)`.
- Only enable in freeform mode (template-based frames have fixed beat order).
- Visual feedback: insertion indicator during drag.

**Patterns to follow:**
- SwiftUI `draggable`/`dropDestination` modifiers
- Existing `appState.reorderFrames` method

**Test scenarios:**
- Happy path: Dragging a frame to a new position reorders the array
- Edge case: Dragging to same position does nothing
- Edge case: Drag-and-drop disabled for template-based projects

**Verification:**
- Frames can be reordered by drag-and-drop in freeform mode

## System-Wide Impact

- **Interaction graph:** Auth state change -> OpenAIService reconfiguration -> views can make API calls. Style analysis -> description populated -> lock gate satisfied. Scene generation -> image data -> frame status `.complete` -> export gate satisfied.
- **Error propagation:** API errors surface as inline messages (chat view) or error text below buttons (style view). Network errors do not crash the app. Auth errors trigger re-auth prompt.
- **State lifecycle risks:** In-flight API calls when user switches frames — `ChatView` resets state on frame change, orphaning any pending call (acceptable for v1; the `loading` flag prevents new calls but doesn't cancel old ones).
- **Unchanged invariants:** Data models, file format, PDF export, undo/redo, template data — all unchanged by this plan.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| GPT-4o vision API base64 size limits | Compress/resize images before encoding. Test with real photos during implementation. |
| `OpenAIService` actor isolation requires `await` everywhere | Already designed as actor. All view calls are in `Task { }` blocks. |
| Drag-and-drop visual quality on macOS with `LazyVGrid` | Acceptable for v1. Can switch to `List` or `NSCollectionView` later if needed. |
| OAuth tokens may not work with standard `api.openai.com` endpoints | API key path is unaffected. If OAuth tokens fail, surface clear error and suggest API key. |

## Sources & References

- **Origin document:** [docs/plans/2026-04-10-001-feat-native-macos-app-plan.md](docs/plans/2026-04-10-001-feat-native-macos-app-plan.md)
- Related code: `Keyframe/Services/OpenAIService.swift`, `Keyframe/Views/ChatView.swift`, `Keyframe/Views/StyleView.swift`, `Keyframe/Views/SetupView.swift`, `Keyframe/Views/CanvasView.swift`
- Web app reference: `src/components/sidebar/ChatTab.tsx`, `src/components/sidebar/StyleTab.tsx`
