# PRD: Keyframe ChatGPT App

## Introduction

Build Keyframe as a ChatGPT app using the OpenAI Apps SDK. Users can create storyboards directly inside ChatGPT without needing an API key - they already have a ChatGPT account.

**Architecture:**
- MCP server with Keyframe tools (Node.js)
- Widget (HTML/CSS/JS) rendered in iframe
- ChatGPT handles conversation, we handle the storyboard state

---

## Goals

- Zero friction onboarding (no API key required)
- Leverage ChatGPT's existing user base
- Maintain feature parity with standalone app for core flow
- Submit to ChatGPT app store for distribution

---

## Tasks

### T-001: MCP Server Setup
**Description:** Create Node.js MCP server with basic structure using @modelcontextprotocol/sdk.

**Acceptance Criteria:**
- [ ] Create `chatgpt-app/` directory in keyframe repo
- [ ] Initialize Node.js project with TypeScript
- [ ] Install @modelcontextprotocol/sdk and zod
- [ ] Create basic server.ts with health check endpoint
- [ ] Server runs on port 8787 with `/mcp` endpoint
- [ ] CORS headers configured for ChatGPT

---

### T-002: Widget HTML Shell
**Description:** Create the widget HTML that will be rendered in ChatGPT iframe.

**Acceptance Criteria:**
- [ ] Create `chatgpt-app/public/keyframe-widget.html`
- [ ] Basic layout: header, frame grid, action buttons
- [ ] Styled with inline CSS (Tailwind-like utility classes)
- [ ] window.openai integration for tool communication
- [ ] Responsive within iframe constraints

---

### T-003: State Management
**Description:** Implement server-side state for storyboard data.

**Acceptance Criteria:**
- [ ] Define TypeScript types for Character, Frame, Style, Project
- [ ] In-memory state store (session-based)
- [ ] State returned in structuredContent from each tool
- [ ] Widget reads state from window.openai.toolOutput

---

### T-004: Tool - set_style
**Description:** Tool to set the style description for the storyboard.

**Acceptance Criteria:**
- [ ] Register `set_style` tool with MCP server
- [ ] Input: style description (string)
- [ ] Stores style in session state
- [ ] Returns updated state in structuredContent
- [ ] Widget updates to show style is set

---

### T-005: Tool - add_character
**Description:** Tool to add a character to the cast.

**Acceptance Criteria:**
- [ ] Register `add_character` tool
- [ ] Input: name, role, visualDescription
- [ ] Generates unique ID for character
- [ ] Adds to characters array in state
- [ ] Returns updated state
- [ ] Widget shows character in cast list

---

### T-006: Tool - add_frame
**Description:** Tool to add a frame to the storyboard.

**Acceptance Criteria:**
- [ ] Register `add_frame` tool
- [ ] Input: title, caption
- [ ] Creates frame with empty imageUrl
- [ ] Adds to frames array
- [ ] Returns updated state
- [ ] Widget shows frame placeholder

---

### T-007: Tool - generate_frame_image
**Description:** Tool to generate an image for a specific frame.

**Acceptance Criteria:**
- [ ] Register `generate_frame_image` tool
- [ ] Input: frameId, sceneDescription
- [ ] Calls OpenAI image generation API (server-side)
- [ ] Updates frame with generated imageUrl
- [ ] Returns updated state with image
- [ ] Widget displays generated image

---

### T-008: Tool - export_pdf
**Description:** Tool to generate and return a PDF of the storyboard.

**Acceptance Criteria:**
- [ ] Register `export_pdf` tool
- [ ] Generates PDF using pdfkit or similar (server-side)
- [ ] Returns PDF as base64 or download URL
- [ ] Widget shows download button/link

---

### T-009: Widget - Frame Grid
**Description:** Implement the frame grid display in the widget.

**Acceptance Criteria:**
- [ ] Grid layout for frames (2-3 columns)
- [ ] Each frame shows image or placeholder
- [ ] Caption visible below each frame
- [ ] Visual indicator for selected frame
- [ ] Responds to state updates from tools

---

### T-010: Widget - Character List
**Description:** Implement the character list display.

**Acceptance Criteria:**
- [ ] Collapsible section showing cast
- [ ] Each character shows name, role
- [ ] Visual description shown on hover/expand

---

### T-011: Widget - Style Indicator
**Description:** Show current style status.

**Acceptance Criteria:**
- [ ] Badge or indicator showing if style is set
- [ ] Display style description summary
- [ ] Visual feedback when style is locked

---

### T-012: Local Development Setup
**Description:** Set up local development with ngrok for testing.

**Acceptance Criteria:**
- [ ] npm run dev starts MCP server
- [ ] npm run tunnel starts ngrok
- [ ] README with setup instructions
- [ ] Works with ChatGPT Developer Mode

---

### T-013: Deploy to Production
**Description:** Deploy MCP server to a hosting provider.

**Acceptance Criteria:**
- [ ] Deploy to Vercel, Railway, or similar
- [ ] Environment variables for OpenAI API key
- [ ] HTTPS endpoint for ChatGPT
- [ ] Health check endpoint returns 200

---

### T-014: ChatGPT App Submission
**Description:** Prepare and submit app to ChatGPT app store.

**Acceptance Criteria:**
- [ ] App name, description, icon prepared
- [ ] Privacy policy URL
- [ ] Terms of service URL
- [ ] App submission guidelines reviewed
- [ ] Submitted for review

---

## Functional Requirements

- FR-1: MCP server must respond to /mcp endpoint with proper CORS
- FR-2: Tools must return structuredContent with current state
- FR-3: Widget must update reactively from window.openai.toolOutput
- FR-4: Image generation must use server-side OpenAI API key
- FR-5: PDF export must work without client-side dependencies
- FR-6: State must persist within a conversation session

---

## Non-Goals

- User accounts (ChatGPT handles auth)
- Cloud persistence (state lives in conversation)
- Style upload (text description only for v1)
- Templates (freeform only for v1)

---

## Technical Considerations

### MCP Server Stack
- Node.js + TypeScript
- @modelcontextprotocol/sdk
- Zod for input validation
- OpenAI SDK for image generation
- pdfkit for PDF generation

### Widget Stack
- Vanilla HTML/CSS/JS (no build step)
- window.openai for ChatGPT communication
- Inline styles for iframe compatibility

### Deployment
- Vercel Edge Functions or Railway
- Environment: OPENAI_API_KEY

---

## Success Metrics

- App approved in ChatGPT store
- Users can complete full storyboard flow
- < 30 second image generation time
- PDF export works on first try
