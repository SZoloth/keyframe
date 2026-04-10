# CLAUDE.md - Keyframe

## Project overview

Native macOS storyboard generator. Users authenticate with OpenAI, pick a narrative template, define a visual style, build a cast of characters, then generate consistent illustrated frames via GPT-4o and gpt-image-1. Export to PDF.

## Build and test

```bash
xcodegen generate                 # Regenerate Xcode project from project.yml
xcodebuild build -project Keyframe.xcodeproj -scheme Keyframe -destination 'platform=macOS'
xcodebuild test  -project Keyframe.xcodeproj -scheme Keyframe -destination 'platform=macOS'
```

## Architecture

### Core flow
```
Auth → Template → Style (upload/describe + lock) → Cast → Frame Generation (suggest → refine → generate image) → PDF Export
```

### State management
`AppState` (`@MainActor @Observable`) holds all project state with snapshot-based undo/redo (50-level history). Injected into SwiftUI views via `@Environment`.

### Authentication
Three paths with dual API routing:
- **Sign in with ChatGPT** — OAuth PKCE via `auth.openai.com`, localhost:1455 callback (`OAuthService`) → routes to Codex Backend API (`chatgpt.com/backend-api/codex/responses`), bills against ChatGPT subscription
- **API key** — direct entry, stored in macOS Keychain (`KeychainService`) → routes to Platform API (`api.openai.com/v1`)
- **Codex token import** — reads `~/.codex/auth.json` if present (`CodexDetector`) → routes to Codex Backend API

See `docs/solutions/best-practices/chatgpt-subscription-via-codex-backend-api-2026-04-10.md` for the dual routing pattern.

### AI services
`OpenAIService` (actor) handles chat completions, vision, and image generation. API-key users hit the Chat Completions API; OAuth users hit the Responses API via the Codex Backend. Wrapped by `AIServiceProvider` (`@Observable`) for SwiftUI environment injection. Images use `response_format: "b64_json"` for Platform API — see `docs/solutions/` for why.

### File persistence
Custom `.keyframe` JSON format via `Codable`. Native `NSSavePanel`/`NSOpenPanel` for file dialogs. `UTType` registered for the custom file type.

## File layout

```
Keyframe/
  KeyframeApp.swift             # App entry point, environment setup
  State/AppState.swift          # Central state, undo/redo, phase gating
  Models/                       # Project, StoryboardFrame, Template, Character, etc.
  Data/BuiltInTemplates.swift   # Predefined narrative templates
  Services/
    OpenAIService.swift         # OpenAI API (chat, vision, image gen)
    AIServiceProvider.swift     # @Observable wrapper for environment injection
    OAuthService.swift          # OAuth PKCE flow
    AuthManager.swift           # Auth orchestration
    CodexDetector.swift         # Codex CLI token import
    KeychainService.swift       # macOS Keychain access
    PDFExporter.swift           # PDF generation via PDFKit
    ProjectFileManager.swift    # .keyframe file save/load
  Views/                        # SwiftUI views (Setup, Style, Cast, Canvas, Chat, etc.)
KeyframeTests/                  # 160 tests across 14 suites
docs/
  plans/                        # Implementation plans with YAML frontmatter
  solutions/                    # Documented solutions and learnings (YAML frontmatter, searchable by module/tags/problem_type)
project.yml                     # XcodeGen project definition
```

## Key decisions

1. **Native Swift/SwiftUI** over web stack — better macOS integration, Keychain, file system access
2. **`b64_json` over URL** for image generation — OpenAI image URLs expire after ~60 minutes; inline base64 eliminates the persistence race
3. **Actor for OpenAIService** — thread-safe API access without manual locking
4. **Snapshot undo/redo** — simple, reliable; captures full project state per mutation
5. **OAuth PKCE with localhost callback** — no backend needed; same flow as Codex CLI

## Style guide

- Swift 6, strict concurrency
- `@MainActor` for all UI-facing state
- `@Observable` (not ObservableObject) for SwiftUI reactivity
- Actor isolation for service objects with async APIs
- Two-space indentation, named exports

## Testing

Swift Testing framework (`@Test`, `#expect`, `@Suite`). 160 tests across 14 suites covering state mutations, undo/redo, auth flows, endpoint routing, Responses API parsing, SSE stream parsing, project serialization, frame operations, phase gating, and end-to-end flow tests (both Platform API and Codex Backend paths). Run with `xcodebuild test`.

## Important notes

- Never commit API keys or OAuth tokens
- Image data is stored as base64 `Data` in the `.keyframe` project file — watch for file size with many frames
- Frame order is template-defined for structured templates; freeform mode allows drag-and-drop reorder
- `docs/solutions/` contains documented solutions to past problems, organized by category with YAML frontmatter (`module`, `tags`, `problem_type`). Check when debugging or implementing in documented areas.
