---
title: "feat: Rewrite Keyframe as native SwiftUI macOS app with ChatGPT OAuth"
type: feat
status: active
date: 2026-04-10
---

# feat: Rewrite Keyframe as native SwiftUI macOS app with ChatGPT OAuth

## Overview

Replace the existing Next.js web app with a native SwiftUI macOS application. The primary driver is enabling frictionless "Sign in with ChatGPT" authentication — a desktop app can handle the OAuth PKCE flow natively by listening on `localhost:1455` for the redirect callback, matching the Codex CLI's whitelisted redirect URI. The native app also provides better canvas performance, macOS Keychain token storage, native file save/open, and proper undo/redo via `UndoManager`.

## Problem Frame

Keyframe currently requires users to paste an OpenAI API key — high friction, poor security (stored in localStorage, sent client-side with `dangerouslyAllowBrowser: true`). Users with ChatGPT Plus/Pro/Teams subscriptions are already paying for access but can't use their subscription in Keyframe. The OAuth redirect flow that would fix this requires a `localhost:1455` callback URI (the only URI OpenAI whitelists), which deployed web apps can't intercept. A macOS app can.

## Requirements Trace

- R1. Users can sign in with their ChatGPT account via OAuth PKCE (browser redirect flow)
- R2. Users can alternatively provide an API key for usage-based access
- R3. OAuth tokens stored securely in macOS Keychain, auto-refreshed
- R4. App detects existing `~/.codex/auth.json` and offers to reuse those credentials
- R5. Template selection (Raskin Pitch, Hero's Journey, Problem→Solution, Freeform) with custom template creation
- R6. Style definition via image upload or text description, with AI style analysis and locking
- R7. Cast of characters with name, role, visual description, and optional reference image
- R8. Per-frame scene generation loop: suggest scene → refine via chat → generate image → accept/reject
- R9. PDF export with title page + frames (2 per page) with captions
- R10. Native macOS file save/open for project persistence (.keyframe JSON files)
- R11. Undo/redo for all project mutations via `UndoManager`
- R12. Custom template creation and persistence

## Scope Boundaries

- No web version — the macOS app replaces it
- No real-time collaboration (dropped from web version)
- No Supabase / cloud persistence — projects save as local files
- No App Store submission in this phase — distribute directly or via TestFlight
- No iOS/iPadOS version
- No tldraw — native SwiftUI grid replaces it

## Context & Research

### Relevant Code and Patterns (from web codebase)

- `src/lib/types.ts` — Core type definitions (Phase, Character, StoryboardFrame, StyleDefinition, Template). Port directly to Swift `Codable` structs.
- `src/lib/templates.ts` — Three built-in templates with beats and guidance. Port data verbatim.
- `src/lib/openai.ts` — Prompt engineering for scene suggestions, image generation, scene refinement, style reference generation. Port the system prompts and prompt construction logic.
- `src/lib/store.ts` — Zustand store with undo/redo history. Replaces with `@Observable` class + `UndoManager`.
- `src/components/sidebar/ChatTab.tsx` — The frame generation loop UX. Port the suggest→refine→generate→accept flow.

### External References

- **OpenAI OAuth endpoints**: Authorization at `https://auth.openai.com/oauth/authorize`, token exchange at `https://auth.openai.com/oauth/token`. Redirect URI: `http://localhost:1455/auth/callback`. Scopes: `openid profile email offline_access`.
- **Codex API endpoint**: `https://chatgpt.com/backend-api/codex/responses` (NOT `api.openai.com/v1`). Requires `store: false`, `stream: true`, `instructions` field.
- **Standard API endpoint**: `https://api.openai.com/v1` for API key auth path (uses normal `Authorization: Bearer sk-...` header).
- **OAuth client parameters**: Use the same `client_id` and redirect URI as Codex CLI. PKCE with S256 code challenge method.
- **macOS OAuth pattern**: `NWListener` (Network framework) to spin up a temporary HTTP server on `localhost:1455`. `ASWebAuthenticationSession` won't work because the redirect URI is HTTP localhost, not a custom URL scheme.
- **Token storage**: macOS Keychain via Security framework (`SecItemAdd`, `SecItemCopyMatching`).
- **PDF generation on macOS**: `CGContext` with `CGPDFContextCreate`. Draw images with `NSImage.draw(in:)` and text with `NSAttributedString.draw(in:)`.
- **SwiftOpenAI** (jamesrochabrun, 650+ stars) — Comprehensive Swift SDK for OpenAI. Alternative: raw URLSession with `Codable` request/response types (simpler, fewer dependencies).
- **Codex auth file**: `~/.codex/auth.json` contains `access_token`, `refresh_token`, `account_id`. Can be parsed with `Codable`.

## Key Technical Decisions

- **Raw URLSession over SwiftOpenAI SDK**: The app needs to hit two different API endpoints (Codex backend for OAuth users, standard API for API key users) with different request formats. A thin wrapper around URLSession gives full control without fighting a third-party SDK's assumptions. The prompt engineering from the web codebase ports directly.
- **`@Observable` + `UndoManager` over SwiftData**: SwiftData's document-based support has documented threading and corruption issues. The app's data model is simple enough for in-memory `@Observable` objects with JSON serialization for file persistence. `UndoManager` provides native undo/redo that integrates with the Edit menu.
- **`NWListener` over `ASWebAuthenticationSession` for OAuth**: The OAuth redirect goes to `http://localhost:1455/auth/callback`. `ASWebAuthenticationSession` expects a custom URL scheme callback. A temporary `NWListener` HTTP server captures the redirect, extracts the auth code, and shuts down — exactly how Codex CLI works.
- **Two API paths (Codex endpoint vs standard API)**: OAuth tokens hit `chatgpt.com/backend-api/codex/responses` (Responses API format). API keys hit `api.openai.com/v1/chat/completions` and `api.openai.com/v1/images/generations` (Chat Completions / Images API format). The OpenAI service layer abstracts this behind a common interface.
- **`.keyframe` file extension**: Projects save as JSON files with a `.keyframe` extension. Registered as a custom document type in the app's Info.plist so double-clicking opens the app.

## Open Questions

### Resolved During Planning

- **Which Swift package for OpenAI?** — Resolved: raw URLSession. Two endpoints with different formats make a third-party SDK more hindrance than help.
- **SwiftData vs Codable for persistence?** — Resolved: Codable JSON files. SwiftData document-based has known issues and the data model is simple.
- **How to handle the localhost OAuth redirect?** — Resolved: NWListener temporary HTTP server on port 1455, matching Codex CLI's approach.

### Deferred to Implementation

- **Exact Codex API request/response shapes**: The Responses API format (`input` array, `instructions` field, `store: false`) needs to be verified against actual API responses during implementation.
- **Token refresh timing**: The refresh token flow should be tested to determine when tokens expire and how aggressively to pre-refresh.
- **Image data handling**: Whether to store generated images as base64 in the project JSON or as separate files alongside the `.keyframe` file. Base64 is simpler but creates large files; a `.keyframe` bundle directory could separate images.

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```
┌─────────────────────────────────────────────────────┐
│                   KeyframeApp                        │
│  ┌───────────────────────────────────────────────┐  │
│  │               AppState (@Observable)           │  │
│  │  ┌─────────┐ ┌──────────┐ ┌───────────────┐  │  │
│  │  │AuthState│ │ Project  │ │  UndoManager  │  │  │
│  │  │(tokens/ │ │(template,│ │  (registered  │  │  │
│  │  │ apiKey) │ │ frames,  │ │   for all     │  │  │
│  │  │         │ │ style,   │ │   mutations)  │  │  │
│  │  │         │ │ cast)    │ │               │  │  │
│  │  └────┬────┘ └────┬─────┘ └───────────────┘  │  │
│  └───────┼──────────┼───────────────────────────┘  │
│          │          │                               │
│  ┌───────▼──────────▼───────────────────────────┐  │
│  │              Service Layer                    │  │
│  │  ┌─────────────────┐ ┌─────────────────────┐ │  │
│  │  │   AuthService   │ │  OpenAIService      │ │  │
│  │  │ ┌─────────────┐ │ │ ┌─────────────────┐ │ │  │
│  │  │ │ OAuthFlow   │ │ │ │ CodexEndpoint   │ │ │  │
│  │  │ │ (NWListener │ │ │ │ (OAuth tokens)  │ │ │  │
│  │  │ │  on :1455)  │ │ │ ├─────────────────┤ │ │  │
│  │  │ ├─────────────┤ │ │ │ StandardAPI     │ │ │  │
│  │  │ │ Keychain    │ │ │ │ (API key)       │ │ │  │
│  │  │ │ Storage     │ │ │ └─────────────────┘ │ │  │
│  │  │ ├─────────────┤ │ └─────────────────────┘ │  │
│  │  │ │ CodexAuth   │ │                         │  │
│  │  │ │ .json detect│ │                         │  │
│  │  │ └─────────────┘ │                         │  │
│  │  └─────────────────┘                         │  │
│  └──────────────────────────────────────────────┘  │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │                  UI Layer                     │  │
│  │  ┌────────┐ ┌─────────────┐ ┌─────────────┐ │  │
│  │  │ Header │ │ CanvasView  │ │SidebarView  │ │  │
│  │  │ (phase │ │ (frame grid │ │ ┌─────────┐ │ │  │
│  │  │  nav,  │ │  selection, │ │ │SetupTab │ │ │  │
│  │  │  undo, │ │  drag/drop, │ │ │StyleTab │ │ │  │
│  │  │  auth) │ │  captions)  │ │ │CastTab  │ │ │  │
│  │  └────────┘ └─────────────┘ │ │ChatTab  │ │ │  │
│  │                              │ └─────────┘ │ │  │
│  │                              └─────────────┘ │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

**Auth flow (OAuth path):**
1. User clicks "Sign in with ChatGPT"
2. App generates PKCE code_verifier + code_challenge
3. App starts NWListener on localhost:1455
4. App opens `auth.openai.com/oauth/authorize?...` in default browser
5. User authenticates at OpenAI
6. Browser redirects to `localhost:1455/auth/callback?code=...`
7. NWListener captures the code, shuts down
8. App exchanges code for tokens at `auth.openai.com/oauth/token`
9. Tokens stored in Keychain
10. API calls go to `chatgpt.com/backend-api/codex/responses`

**Auth flow (API key path):**
1. User enters API key in setup
2. Key validated via `api.openai.com/v1/models`
3. Key stored in Keychain
4. API calls go to `api.openai.com/v1/...`

## Implementation Units

- [ ] **Unit 1: Xcode project scaffolding and data models**

  **Goal:** Create the Xcode project with SwiftUI app lifecycle and port all data model types from TypeScript to Swift.

  **Requirements:** R5, R10

  **Dependencies:** None

  **Files:**
  - Create: `Keyframe/KeyframeApp.swift`
  - Create: `Keyframe/Models/Template.swift`
  - Create: `Keyframe/Models/Character.swift`
  - Create: `Keyframe/Models/StoryboardFrame.swift`
  - Create: `Keyframe/Models/StyleDefinition.swift`
  - Create: `Keyframe/Models/Project.swift`
  - Create: `Keyframe/Models/Phase.swift`
  - Create: `Keyframe/Data/BuiltInTemplates.swift`
  - Create: `Keyframe/Info.plist` (or configure via Xcode target settings)

  **Approach:**
  - Swift Package or Xcode project at repo root (alongside existing `src/`). Xcode project preferred since this is a macOS app with signing and entitlements.
  - All model types conform to `Codable` and `Identifiable`.
  - Port template data verbatim from `src/lib/templates.ts`: Raskin Pitch (5 frames), Hero's Journey (8 frames), Problem→Solution (3 frames).
  - `Project` is the root serializable type containing template selection, frames, style, characters, phase, and custom templates.
  - Register `.keyframe` as a custom document type (UTType) for file association.
  - Minimum deployment target: macOS 14.0 (Sonoma) for `@Observable` support.
  - Add `com.apple.security.network.client` entitlement for outbound network access.

  **Patterns to follow:**
  - The existing TypeScript types in `src/lib/types.ts` define the exact shapes. Port field-for-field, adjusting for Swift naming conventions (camelCase already matches).

  **Test scenarios:**
  - Happy path: Project encodes to JSON and decodes back with all fields preserved (templates, frames, style, characters)
  - Edge case: Empty project (no frames, no characters, no style) round-trips correctly
  - Edge case: Project with base64 image data in style.referenceImages encodes/decodes

  **Verification:**
  - App launches and shows an empty window
  - All model types compile with Codable conformance
  - Template data is accessible at runtime

- [ ] **Unit 2: App state management and undo/redo**

  **Goal:** Create the central `@Observable` app state with all mutations registered for undo/redo, mirroring the Zustand store's behavior.

  **Requirements:** R11

  **Dependencies:** Unit 1

  **Files:**
  - Create: `Keyframe/State/AppState.swift`
  - Create: `Keyframe/State/ProjectState.swift`
  - Test: `KeyframeTests/ProjectStateTests.swift`

  **Approach:**
  - `AppState` is the root `@Observable` object injected into the environment. Contains `ProjectState` (the project data), auth state, and current UI state (selected frame, phase).
  - `ProjectState` wraps the `Project` model and exposes mutation methods. Each mutation registers an undo action with `UndoManager`.
  - Undo/redo integrates with the macOS Edit menu automatically when `UndoManager` is set on the window.
  - Phase advancement gating: same logic as `canAdvanceToPhase` in `src/lib/store.ts`. Style must be locked before cast, at least one character before frames, at least one complete frame before export.

  **Patterns to follow:**
  - `src/lib/store.ts` lines 86-332 — all mutation methods and phase gating logic. Port the business logic, replace Zustand patterns with `@Observable` + `UndoManager`.

  **Test scenarios:**
  - Happy path: selectTemplate populates frames array matching template beat count
  - Happy path: addCharacter/removeCharacter modifies characters array
  - Happy path: updateFrame with partial updates merges correctly
  - Happy path: undo reverses the last mutation, redo re-applies it
  - Edge case: undo when history is empty does nothing
  - Edge case: new mutation after undo clears the redo stack
  - Integration: canAdvanceToPhase returns false for 'cast' when style is not locked

  **Verification:**
  - State mutations trigger SwiftUI view updates
  - Edit > Undo / Cmd+Z reverses the last project change

- [ ] **Unit 3: OAuth auth service with PKCE and Keychain storage**

  **Goal:** Implement the full "Sign in with ChatGPT" OAuth flow: PKCE challenge generation, NWListener callback server, browser launch, token exchange, Keychain persistence, token refresh, and Codex auth.json detection.

  **Requirements:** R1, R3, R4

  **Dependencies:** Unit 1

  **Files:**
  - Create: `Keyframe/Services/AuthService.swift`
  - Create: `Keyframe/Services/KeychainHelper.swift`
  - Create: `Keyframe/Services/OAuthCallbackServer.swift`
  - Test: `KeyframeTests/AuthServiceTests.swift`

  **Approach:**
  - `OAuthCallbackServer` uses `NWListener` to bind `localhost:1455`. On incoming connection, reads the HTTP request, extracts `code` and `state` from the query string, responds with a success HTML page ("You can close this tab"), and shuts down. The entire server lifecycle is scoped to the login attempt.
  - `AuthService` orchestrates: generate PKCE verifier/challenge → start callback server → open browser to `auth.openai.com/oauth/authorize` with all parameters → await callback → exchange code for tokens at `auth.openai.com/oauth/token` → store in Keychain → publish auth state.
  - PKCE parameters: 32-byte random verifier, SHA-256 challenge, S256 method.
  - OAuth parameters include `id_token_add_organizations=true`, `codex_cli_simplified_flow=true`, and `originator=pi` (matching Codex CLI).
  - `KeychainHelper` wraps Security framework calls for storing/retrieving/deleting access token, refresh token, and account ID.
  - On app launch, check Keychain for existing tokens. If found, validate by calling the API. If expired, attempt refresh.
  - Separately, check for `~/.codex/auth.json`. If found and no Keychain tokens exist, offer to import.
  - Token refresh: POST to `auth.openai.com/oauth/token` with `grant_type=refresh_token`.

  **Test scenarios:**
  - Happy path: PKCE verifier is 32 bytes, challenge is valid SHA-256 base64url
  - Happy path: OAuth URL contains all required parameters (client_id, redirect_uri, scope, code_challenge, state)
  - Happy path: Callback server extracts auth code from query string correctly
  - Happy path: Token exchange request contains code_verifier and correct grant_type
  - Happy path: Tokens stored in Keychain and retrievable
  - Edge case: Callback server handles malformed requests without crashing
  - Edge case: User cancels browser auth — server times out and cleans up
  - Error path: Token exchange returns error — surface to UI
  - Error path: Keychain write fails — fall back to in-memory tokens with warning
  - Integration: Codex auth.json parsing extracts access_token, refresh_token, account_id

  **Verification:**
  - Clicking "Sign in with ChatGPT" opens browser to OpenAI auth page
  - After authenticating, app shows signed-in state with user email
  - Tokens persist across app restart via Keychain
  - Existing Codex CLI users see option to reuse their credentials

- [ ] **Unit 4: OpenAI service layer (dual endpoint)**

  **Goal:** Create the OpenAI API service that routes requests to either the Codex backend endpoint (OAuth tokens) or the standard API (API key), abstracting the difference behind a common interface.

  **Requirements:** R2, R6, R8

  **Dependencies:** Unit 3

  **Files:**
  - Create: `Keyframe/Services/OpenAIService.swift`
  - Create: `Keyframe/Services/OpenAITypes.swift`
  - Test: `KeyframeTests/OpenAIServiceTests.swift`

  **Approach:**
  - `OpenAIService` takes an auth mode (`.oauth(accessToken)` or `.apiKey(key)`) and routes accordingly.
  - **Codex endpoint** (`chatgpt.com/backend-api/codex/responses`): Uses the Responses API format with `input` array, `instructions` field, `model`, `store: false`, `stream: true`. Auth via `Authorization: Bearer <oauth_token>`.
  - **Standard endpoint** (`api.openai.com/v1/chat/completions` and `/v1/images/generations`): Uses Chat Completions format for text and Images API for image generation. Auth via `Authorization: Bearer <api_key>`.
  - Port the prompt engineering from `src/lib/openai.ts`:
    - `suggestScene` — system prompt with style context and cast, user prompt with beat guidance and previous frames
    - `refineScene` — takes current scene + user feedback
    - `generateFrameImage` — combines style description, scene description, and character descriptions into image generation prompt
    - `generateStyleReference` — generates a reference sketch from text description
    - Style analysis — sends reference images with vision prompt (GPT-4o)
  - For image generation via Codex endpoint, the Responses API format may differ from the standard Images API. This needs verification during implementation — the Codex endpoint may not support image generation directly, in which case OAuth users may need to fall back to the standard Images API with a different auth header.
  - Streaming: support SSE parsing for text responses. Image generation is non-streaming.
  - Request/response types defined in `OpenAITypes.swift` as `Codable` structs.

  **Test scenarios:**
  - Happy path: Scene suggestion returns non-empty string with correct prompt construction
  - Happy path: Image generation returns base64 image data
  - Happy path: Style analysis returns style description from reference images
  - Edge case: Empty characters array produces valid prompt without character section
  - Edge case: No previous frames produces "This is the first frame" context
  - Error path: API returns 401 — triggers re-auth flow
  - Error path: API returns rate limit 429 — surfaces retry-after to UI
  - Error path: Network timeout — returns descriptive error
  - Integration: OAuth mode hits Codex endpoint; API key mode hits standard endpoint

  **Verification:**
  - Scene suggestions return coherent scene descriptions
  - Image generation produces viewable images
  - Both auth modes produce working API calls

- [ ] **Unit 5: App shell, sidebar, and phase navigation**

  **Goal:** Build the main window layout (header + canvas + sidebar), phase indicator with navigation gating, and sidebar tab switching (Setup, Style, Cast, Chat).

  **Requirements:** R1, R2, R5

  **Dependencies:** Unit 2, Unit 3

  **Files:**
  - Create: `Keyframe/Views/ContentView.swift`
  - Create: `Keyframe/Views/HeaderView.swift`
  - Create: `Keyframe/Views/SidebarView.swift`
  - Create: `Keyframe/Views/Setup/SetupView.swift`

  **Approach:**
  - `ContentView`: HSplitView with canvas on left, sidebar on right. Header as a toolbar or top bar.
  - `HeaderView`: App title, template name, phase indicator (Setup → Style → Cast → Frames → Export), undo/redo buttons, auth status (signed in email or "Sign in" button), Export PDF button.
  - Phase indicator: clickable steps with active/past/future styling. Gated by `canAdvanceToPhase`.
  - `SidebarView`: TabView with Setup, Style, Cast, Chat tabs. Active tab changes with phase.
  - `SetupView`: Two auth options — "Sign in with ChatGPT" button (triggers OAuth) and "Use API Key" with text field + validate button. Template selection cards below. "Continue to Style" button gated on auth.
  - Keyboard shortcuts: Cmd+Z undo, Cmd+Shift+Z redo, Cmd+E export.

  **Patterns to follow:**
  - `src/components/Header.tsx` for phase indicator layout and gating logic
  - `src/components/sidebar/SetupTab.tsx` for auth + template selection layout
  - `src/components/sidebar/SidebarPanel.tsx` for tab structure

  **Test scenarios:**
  - Happy path: Phase indicator shows correct active phase
  - Happy path: Clicking a past phase navigates back
  - Happy path: Clicking a future phase that is not yet accessible does nothing
  - Happy path: Template selection populates frames and advances phase indicator
  - Edge case: Window resizes maintain layout proportions

  **Verification:**
  - App shows three-panel layout matching the web version's structure
  - Phase navigation works with proper gating
  - Auth flow is accessible from SetupView

- [ ] **Unit 6: Style, cast, canvas, and chat views**

  **Goal:** Build the four core interaction views: style definition (upload + describe modes), cast management (character CRUD), canvas (frame grid with selection and drag-and-drop), and chat (per-frame generation loop).

  **Requirements:** R6, R7, R8

  **Dependencies:** Unit 4, Unit 5

  **Files:**
  - Create: `Keyframe/Views/Style/StyleView.swift`
  - Create: `Keyframe/Views/Cast/CastView.swift`
  - Create: `Keyframe/Views/Cast/CharacterFormView.swift`
  - Create: `Keyframe/Views/Canvas/CanvasView.swift`
  - Create: `Keyframe/Views/Canvas/FrameCardView.swift`
  - Create: `Keyframe/Views/Chat/ChatView.swift`
  - Test: `KeyframeTests/ViewModelTests.swift`

  **Approach:**
  - **StyleView**: Toggle between Upload and Describe modes. Upload mode: drag-and-drop or file picker for 1-3 reference images, "Analyze Style" button calls OpenAI vision. Describe mode: text input + "Generate Reference" calls image generation. Editable style description textarea. "Lock Style" button advances to cast phase.
  - **CastView**: List of characters with add/edit/delete. `CharacterFormView` as a sheet with name, role, visual description fields and optional image picker.
  - **CanvasView**: LazyVGrid of `FrameCardView` items. Each card shows image (or placeholder with frame number + beat title), generation status indicator, and editable caption. Selection highlight. Drag-and-drop reordering via `onDrag`/`onDrop` or `draggable`/`dropDestination`. Add frame button in freeform mode. Delete button on hover in freeform mode.
  - **ChatView**: Per-frame chat panel. "Suggest a Scene" button, message history (user/assistant), text input for refinement. Action buttons: "Generate Image" (when scene exists), "Accept"/"Try Again" (when image generated). Scrolls to latest message.
  - All views read from and mutate `AppState` via environment.

  **Patterns to follow:**
  - `src/components/sidebar/StyleTab.tsx` — upload/describe mode toggle, style analysis flow
  - `src/components/sidebar/CastTab.tsx` — character CRUD (read this file if not already loaded)
  - `src/components/canvas/CanvasPanel.tsx` — frame grid, drag-and-drop, caption editing
  - `src/components/sidebar/ChatTab.tsx` — chat message flow, suggest/generate/accept loop

  **Test scenarios:**
  - Happy path: Adding a reference image appears in the image strip
  - Happy path: Locking style advances phase to cast
  - Happy path: Adding a character appears in the cast list
  - Happy path: Selecting a frame in canvas highlights it and focuses chat on that frame
  - Happy path: "Suggest a Scene" populates the chat with a scene description
  - Happy path: "Generate Image" shows loading state then displays generated image
  - Happy path: "Accept" places image in canvas frame card and marks frame complete
  - Edge case: Drag-and-drop reorder updates frame indices correctly
  - Edge case: Chat resets when switching between frames
  - Error path: Image generation failure shows error message in chat without crashing
  - Integration: Style description from analysis flows into frame generation prompts

  **Verification:**
  - Full generation loop works: style lock → add character → select frame → suggest scene → generate image → accept
  - Canvas shows generated images in the correct frame positions

- [ ] **Unit 7: PDF export**

  **Goal:** Generate a downloadable PDF storyboard from the current project using Core Graphics.

  **Requirements:** R9

  **Dependencies:** Unit 6

  **Files:**
  - Create: `Keyframe/Services/PDFExporter.swift`
  - Test: `KeyframeTests/PDFExporterTests.swift`

  **Approach:**
  - Use `CGPDFContextCreate` / `CGPDFContextBeginPage` / `CGPDFContextEndPage` for PDF generation.
  - Page layout: US Letter (612x792 points). Title page with project name and template name. Content pages with 2 frames per page.
  - Each frame block: image (scaled to fit), frame number, beat title, caption below.
  - Handle frames without images (show placeholder text).
  - Export via `NSSavePanel` with suggested filename `storyboard-<template>.pdf`.
  - Triggered from Header "Export PDF" button and Cmd+E shortcut.

  **Patterns to follow:**
  - `src/components/export/PDFExport.tsx` — page layout logic, 2-per-page frame arrangement, metadata inclusion

  **Test scenarios:**
  - Happy path: PDF generates with correct page count (title + ceil(frames/2) content pages)
  - Happy path: Generated PDF contains all frame images and captions
  - Edge case: Frame with no image renders placeholder text instead of blank space
  - Edge case: Single frame produces title page + one content page
  - Edge case: Long captions wrap without overflowing frame block

  **Verification:**
  - Exported PDF opens in Preview with all frames and captions visible
  - PDF file size is reasonable (not bloated by uncompressed images)

- [ ] **Unit 8: Project file persistence and custom templates**

  **Goal:** Implement native macOS file save/open for `.keyframe` project files and custom template creation/persistence.

  **Requirements:** R10, R12

  **Dependencies:** Unit 2

  **Files:**
  - Create: `Keyframe/Services/ProjectPersistence.swift`
  - Modify: `Keyframe/State/AppState.swift`
  - Modify: `Keyframe/Views/Setup/SetupView.swift`
  - Create: `Keyframe/Views/Setup/CustomTemplateFormView.swift`
  - Test: `KeyframeTests/ProjectPersistenceTests.swift`

  **Approach:**
  - **File persistence**: `ProjectPersistence` serializes `Project` to JSON and writes via `NSSavePanel`. Opens via `NSOpenPanel` filtered to `.keyframe` files. Also supports `fileExporter`/`fileImporter` SwiftUI modifiers.
  - Register `com.keyframe.project` UTType for `.keyframe` files in the app's Info.plist / UTType declaration. Associate with the app so double-clicking opens Keyframe.
  - File menu integration: File > New, File > Open, File > Save, File > Save As with standard keyboard shortcuts.
  - **Custom templates**: `CustomTemplateFormView` with template name, description, and dynamic list of beats (title + guidance). Save adds to `AppState.customTemplates` array. Custom templates appear alongside built-in templates in SetupView. Persist custom templates in `~/Library/Application Support/Keyframe/custom-templates.json`.
  - On app launch: load custom templates from Application Support. On template save: write back.
  - Handle base64 image data in project files. For v1, images embed in the JSON. A future optimization could use a `.keyframe` bundle directory.

  **Patterns to follow:**
  - `src/lib/projectPersistence.ts` — serialization/hydration pattern
  - `src/components/sidebar/SetupTab.tsx` lines 284-367 — custom template creation form

  **Test scenarios:**
  - Happy path: Project saves to disk and loads back with all data intact
  - Happy path: Custom template persists across app restart
  - Happy path: Custom templates appear in template selection list
  - Edge case: Opening a corrupted/invalid .keyframe file shows error without crashing
  - Edge case: Saving when no save path set triggers Save As panel
  - Edge case: Custom template with no beats shows validation error
  - Integration: Double-clicking a .keyframe file opens the app and loads the project

  **Verification:**
  - File > Save writes a .keyframe file that File > Open restores completely
  - Custom templates survive app quit and relaunch

## System-Wide Impact

- **Interaction graph:** Auth state change triggers OpenAI service reconfiguration (endpoint switch). Frame generation depends on locked style + cast. Phase gating depends on auth + style + cast + frame states.
- **Error propagation:** Network errors from OpenAI surface as user-facing messages in chat or alert dialogs. Auth errors trigger re-auth prompt. File I/O errors surface via alert.
- **State lifecycle risks:** OAuth token expiry mid-session — refresh tokens before API calls. Large base64 images in project JSON — may cause slow save/load for large storyboards (acceptable for v1, flagged for future optimization).
- **Unchanged invariants:** The prompt engineering logic (system prompts, scene construction, style reinforcement) carries over verbatim from the web version. Template data (beats, guidance text) is identical.

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| OpenAI may change/revoke the Codex client_id or redirect URI | API key path works independently as fallback. Monitor OpenAI developer announcements. |
| Codex endpoint request format may differ from documented Responses API | Verify format during implementation by inspecting Codex CLI network traffic. Fall back to standard API endpoints if needed. |
| Base64 images in JSON create large project files | Acceptable for v1. Future: bundle directory format with separate image files. |
| Port 1455 may be occupied when user starts OAuth | Detect port conflict, show error with suggestion to close conflicting process. |
| macOS sandbox restrictions may block NWListener | Add `com.apple.security.network.server` entitlement. For App Store distribution, may need to use `ASWebAuthenticationSession` with a registered custom scheme instead. |

## Sources & References

- Related code: `src/lib/types.ts`, `src/lib/store.ts`, `src/lib/openai.ts`, `src/lib/templates.ts`
- Related PRDs: `tasks/prd-keyframe-mvp.md`, `tasks/prd-user-accounts-cloud-persistence.md`, `tasks/prd-chatgpt-app.md`
- External: [InnomightLabs OAuth writeup](https://www.bemyaficionado.com/openai-oauth-chatgpt-codex-integration-in-innomightlabs/)
- External: [openai-oauth (EvanZhouDev)](https://github.com/EvanZhouDev/openai-oauth) — reference implementation
- External: [Codex CLI auth source](https://github.com/openai/codex/blob/main/codex-rs/login/src/auth/manager.rs) — OAuth endpoint details
- External: [OpenAI Codex auth docs](https://developers.openai.com/codex/auth/)
