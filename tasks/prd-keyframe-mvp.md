# PRD: Keyframe MVP

## Self-Clarification

1. **Problem/Goal:** Designers, PMs, and consultants struggle to create compelling AI storyboards for pitching ideas. Current workflow requires either manual illustration (slow) or direct ChatGPT prompting (inconsistent style, no structure). Keyframe solves this by providing a structured workflow with baked-in best practices from storytelling frameworks.

2. **Core Functionality:** 
   - Upload keyframe reference images to establish visual style
   - Define a cast of characters for consistency across frames
   - Generate storyboard frames iteratively via guided chat with generative UI

3. **Scope/Boundaries:** MVP is upload-only (no text-to-keyframe), fixed frame order (no rearranging), PDF export only, client-side only (no user accounts/persistence).

4. **Success Criteria:** User can go from 2-3 uploaded sketches to a complete 5-frame PDF storyboard in under 30 minutes.

5. **Constraints:** Uses user's OpenAI API key (no backend costs). All processing client-side. Must work with GPT-4o for image generation.

---

## Introduction

Keyframe is a web app that helps users create professional storyboards for pitching AI products and concepts. It implements the "keyframe model" where users provide reference sketches to establish style, then AI generates the remaining frames while maintaining visual consistency.

The app enforces storytelling best practices through templates based on proven frameworks (Andy Raskin's pitch structure, Hero's Journey) and guides users through a structured workflow: Style → Characters → Frames → Export.

---

## Goals

- Enable non-illustrators to create professional storyboards
- Maintain visual consistency across all generated frames
- Enforce storytelling structure through templates
- Reduce storyboard creation time from days to under 1 hour
- Provide Cursor-like generative UI for efficient iteration

---

## User Flow

```
[API Key] → [Template Selection] → [Upload Keyframes] → [Style Lock]
    → [Define Cast] → [Generate Frames] → [Export PDF]
```

---

## Tasks

### T-001: Project Setup
**Description:** Initialize Next.js 15 project with App Router, TypeScript, Tailwind CSS, and core dependencies.

**Acceptance Criteria:**
- [ ] Next.js 15 with App Router initialized
- [ ] TypeScript configured with strict mode
- [ ] Tailwind CSS 4 installed and configured
- [ ] tldraw SDK installed (`@tldraw/tldraw`)
- [ ] Vercel AI SDK 6 installed (`ai`)
- [ ] Zustand installed for state management
- [ ] @react-pdf/renderer installed
- [ ] OpenAI SDK installed
- [ ] Project runs with `npm run dev`
- [ ] Basic layout renders (header + two-panel split)

---

### T-002: API Key Management
**Description:** Create UI for entering and validating OpenAI API key. Store encrypted in localStorage.

**Acceptance Criteria:**
- [ ] API key input modal on first visit
- [ ] Key validation via test API call (list models)
- [ ] Success/error feedback
- [ ] Key stored in localStorage (base64 encoded minimum)
- [ ] "Change API Key" option in settings
- [ ] Key available to OpenAI client throughout app
- [ ] Verify in browser: can enter key and proceed

---

### T-003: Template System
**Description:** Create template data structures and selection UI for storytelling frameworks.

**Acceptance Criteria:**
- [ ] Template type definition with frames, beats, and guidance
- [ ] Three templates implemented:
  - Raskin Pitch (5 frames)
  - Hero's Journey (8 frames)
  - Problem → Solution (3 frames)
- [ ] Template selection UI (cards with descriptions)
- [ ] Selected template stored in app state
- [ ] Template frames render as placeholders on canvas
- [ ] Verify in browser: can select template and see frame placeholders

---

### T-004: Canvas Layout with tldraw
**Description:** Implement main canvas using tldraw SDK showing template frames in fixed positions.

**Acceptance Criteria:**
- [ ] tldraw canvas renders in left panel
- [ ] Frame placeholders positioned in grid layout
- [ ] Each placeholder shows frame number and beat title
- [ ] Clicking a frame selects it (visual indicator)
- [ ] Selected frame syncs with chat panel focus
- [ ] Canvas is read-only (no drawing/editing for MVP)
- [ ] Verify in browser: frames display and selection works

---

### T-005: Chat Panel with Generative UI
**Description:** Implement right-side chat panel using Vercel AI SDK with custom UI components.

**Acceptance Criteria:**
- [ ] Chat panel renders in right panel
- [ ] Tab navigation: Chat | Cast | Style
- [ ] Message history displays (user + assistant)
- [ ] Text input with send button
- [ ] Streaming responses work
- [ ] Generative UI components render:
  - Multiple choice (radio buttons)
  - Multi-select (checkboxes)
  - Text input fields
  - Confirmation buttons
- [ ] Verify in browser: can send message and receive streaming response

---

### T-006: Style Definition Phase
**Description:** Implement keyframe upload and style analysis workflow.

**Acceptance Criteria:**
- [ ] Upload zone for 1-3 reference images
- [ ] Images display as thumbnails after upload
- [ ] "Analyze Style" button triggers GPT-4o vision analysis
- [ ] AI returns style description (line quality, shading, color palette, etc.)
- [ ] User can edit/refine style description
- [ ] "Lock Style" button saves style and advances to Cast phase
- [ ] Style description stored in app state
- [ ] Verify in browser: can upload images and lock style

---

### T-007: Cast of Characters Panel
**Description:** Implement character definition CRUD interface.

**Acceptance Criteria:**
- [ ] Cast tab shows list of defined characters
- [ ] "Add Character" button opens form
- [ ] Character form fields:
  - Name (required)
  - Role (required)
  - Visual description (required, textarea)
  - Reference image (optional upload)
- [ ] Edit existing character
- [ ] Delete character with confirmation
- [ ] Characters stored in app state
- [ ] "Done with Cast" advances to Frame Generation phase
- [ ] Verify in browser: can add, edit, delete characters

---

### T-008: Frame Generation Loop
**Description:** Implement the core generation workflow for each frame.

**Acceptance Criteria:**
- [ ] Selecting a frame focuses chat on that frame's beat
- [ ] AI suggests scene description based on:
  - Template beat guidance
  - Locked style description
  - Defined cast
  - Previous frames context
- [ ] User can refine via chat (generative UI choices)
- [ ] "Generate Image" triggers GPT-4o image generation
- [ ] Loading state while generating
- [ ] Generated image displays in chat
- [ ] "Accept" places image in canvas frame
- [ ] "Try Again" generates variation
- [ ] Frame marked as complete after acceptance
- [ ] Verify in browser: full generation loop works for one frame

---

### T-009: Caption System
**Description:** Add editable captions to each frame.

**Acceptance Criteria:**
- [ ] Each frame has caption text field
- [ ] Default caption from template beat title
- [ ] User can edit caption inline or via chat
- [ ] Captions stored in app state
- [ ] Captions visible below frames on canvas
- [ ] Verify in browser: can edit captions

---

### T-010: PDF Export
**Description:** Generate downloadable PDF storyboard using @react-pdf/renderer.

**Acceptance Criteria:**
- [ ] "Export PDF" button in header
- [ ] PDF layout: title page + frames (2 per page)
- [ ] Each frame includes:
  - Frame number
  - Generated image (or placeholder if empty)
  - Caption
  - Beat title
- [ ] PDF metadata includes project name
- [ ] Download triggers browser save dialog
- [ ] Verify in browser: can export and open PDF with all frames

---

### T-011: Workflow Gating
**Description:** Enforce the phased workflow with gates between phases.

**Acceptance Criteria:**
- [ ] Phase indicator in header (Setup → Style → Cast → Frames → Export)
- [ ] Cannot proceed to Cast without locked style
- [ ] Cannot proceed to Frames without at least one character
- [ ] Cannot export without all frames generated
- [ ] Navigation to previous phases allowed (with warning if changes will reset)
- [ ] Verify in browser: gates prevent skipping phases

---

### T-012: Progress Persistence
**Description:** Save work-in-progress to localStorage to survive page refresh.

**Acceptance Criteria:**
- [ ] App state auto-saves to localStorage on changes
- [ ] On page load, restore state from localStorage
- [ ] "New Project" clears saved state (with confirmation)
- [ ] Works across browser sessions
- [ ] Verify in browser: refresh preserves progress

---

## Functional Requirements

- FR-1: User must provide OpenAI API key before using the app
- FR-2: System must validate API key before accepting it
- FR-3: User must select a storytelling template before proceeding
- FR-4: User must upload 1-3 reference images for style definition
- FR-5: System must analyze uploaded images and generate style description via GPT-4o
- FR-6: User must confirm/lock style before proceeding to character definition
- FR-7: User must define at least one character with name, role, and visual description
- FR-8: System must include locked style and cast in all image generation prompts
- FR-9: For each frame, system must suggest scene based on template beat
- FR-10: User must be able to refine scene description via chat before generation
- FR-11: System must generate images using GPT-4o image generation API
- FR-12: User must accept or request variation for each generated frame
- FR-13: User must be able to edit caption for each frame
- FR-14: System must export storyboard as PDF with all frames and captions
- FR-15: System must persist progress to localStorage

---

## Non-Goals (Out of Scope for MVP)

- User accounts and cloud persistence
- "Describe" mode (text-to-keyframe without reference images)
- Frame rearranging on canvas
- Export formats other than PDF (Figma, PNG, shareable link)
- Collaborative editing
- Custom template creation
- Animation/video export
- Mobile responsiveness
- Undo/redo beyond browser back button

---

## Technical Considerations

### OpenAI API Usage
- Style analysis: GPT-4o with vision (image input)
- Scene suggestions: GPT-4o text completion
- Image generation: GPT-4o image generation (not DALL-E 3)
- All calls made client-side using user's API key

### State Management
- Zustand store with slices for:
  - `auth` (API key)
  - `project` (template, phase, frames, captions)
  - `style` (reference images, locked description)
  - `cast` (characters array)
  - `chat` (message history per frame)

### Canvas
- tldraw in read-only mode
- Custom shapes for frame placeholders
- Frame selection broadcasts to global state

### Generative UI
- Vercel AI SDK `useChat` with tool calls for structured responses
- Custom components registered for each UI type
- Tool definitions for: `multipleChoice`, `textInput`, `confirm`

---

## Success Metrics

- User completes full storyboard in < 30 minutes
- Style consistency across frames (subjective but testable)
- PDF export works on first try
- No API errors due to prompt construction

---

## Open Questions

1. **Rate limiting:** How do we handle OpenAI rate limits gracefully? (Show queue position, retry logic)
2. **Image storage:** How large can localStorage get with base64 images? May need IndexedDB.
3. **Style drift:** If user generates many frames, does style drift? May need periodic style reinforcement in prompts.
