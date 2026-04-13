# CLAUDE.md - Keyframe

## Project overview

Native macOS storyboard generator. In the current stabilization phase, users authenticate with ChatGPT/Codex, pick a narrative template, define a visual style, build a cast of characters, then generate consistent illustrated frames and export to PDF.

## Build and test

```bash
./scripts/build.sh               # xcodegen + build in one command
./scripts/test.sh                # xcodegen + run all tests
./scripts/build-release.sh       # Release build + DMG for distribution
```

Raw commands (if scripts aren't available):
```bash
xcodegen generate                 # Regenerate Xcode project from project.yml
xcodebuild build -project Keyframe.xcodeproj -scheme Keyframe -destination 'platform=macOS'
xcodebuild test  -project Keyframe.xcodeproj -scheme Keyframe -destination 'platform=macOS'
```

## Design tokens

Use `Theme.swift` for all design values. Never hardcode colors, spacing, or typography.

```swift
Text("Title")
    .font(Theme.Typography.title)
    .foregroundStyle(Theme.Colors.primary)
    .padding(Theme.Spacing.md)
```

macOS system colors: `Theme.Colors.background` (windowBackgroundColor), `Theme.Colors.separator` (separatorColor), `Theme.Colors.tertiaryBackground` (quaternarySystemFill).

## DialKit (live design tuning)

DialKit provides a runtime tuning overlay in debug builds. Tap the FAB to open the drawer, adjust Theme values live. `DesignDials.swift` defines the tunable properties. Compiles out entirely in release builds.

## Feature flags

Use `FeatureFlags.swift` to toggle experimental features without rebuilding.

## Architecture

### Core flow
```
Auth → Template → Style (upload/describe + lock) → Cast → Frame Generation (suggest → refine → generate image) → PDF Export
```

### State management
`AppState` (`@MainActor @Observable`) holds all project state with snapshot-based undo/redo (50-level history). Injected into SwiftUI views via `@Environment`.

### Authentication
Current product contract:
- **Sign in with ChatGPT** — OAuth PKCE via `auth.openai.com`, localhost:1455 callback (`OAuthService`) → routes to Codex Backend API (`chatgpt.com/backend-api/codex/responses`), bills against ChatGPT subscription
- **Codex token import** — reads `~/.codex/auth.json` if present (`CodexDetector`) → routes to Codex Backend API

The app no longer offers API-key auth in setup or app state during this phase. `OpenAIService` still retains a Platform endpoint as a lower-level compatibility seam, but it is not part of the supported UI contract.

See `docs/solutions/best-practices/chatgpt-subscription-via-codex-backend-api-2026-04-10.md` and `docs/solutions/best-practices/keyframe-chatgpt-codex-contract-2026-04-10.md` for the current contract and evidence hierarchy.

### AI services
`OpenAIService` (actor) handles chat completions, vision, and image generation. The supported app path uses the Responses API via the Codex Backend. Wrapped by `AIServiceProvider` (`@Observable`) for SwiftUI environment injection. Platform API helpers remain in the service layer, but they are not part of the current product auth contract.

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
KeyframeTests/                  # Swift Testing suites, including fixture-backed Codex contract coverage
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

Swift Testing framework (`@Test`, `#expect`, `@Suite`). Coverage centers on state mutations, undo/redo, ChatGPT/Codex auth flows, endpoint routing, Responses API parsing, SSE parsing, project serialization, frame operations, phase gating, and fixture-backed first-run Codex flow tests. Run with `xcodebuild test`.

## Important notes

- Never commit API keys or OAuth tokens
- Image data is stored as base64 `Data` in the `.keyframe` project file — watch for file size with many frames
- Frame order is template-defined for structured templates; freeform mode allows drag-and-drop reorder
- `docs/solutions/` contains documented solutions to past problems, organized by category with YAML frontmatter (`module`, `tags`, `problem_type`). Check when debugging or implementing in documented areas.
