# PRD: Describe Mode (Text-to-Keyframe)

## Self-Clarification

1. **Problem/Goal:** Users currently must upload reference sketches to establish style before generating frames. Many users (PMs, consultants, non-designers) don't have sketches ready, creating friction that prevents them from using the tool. Describe Mode lets users describe their desired style in text, and AI generates a reference sketch that establishes the visual style.

2. **Core Functionality:** 
   - User enters a text description of their desired visual style
   - AI generates a reference sketch image based on the description
   - Generated image becomes the style reference (same as if uploaded)
   - User can regenerate if not satisfied, or proceed with the style

3. **Scope/Boundaries:** 
   - This is an alternative path to Style Definition, not a replacement
   - User chooses either "Upload" or "Describe" mode
   - Does NOT change the downstream Cast or Frame generation flows
   - Does NOT support hybrid (upload + describe) in MVP
   - Does NOT include style presets or style library (that's B-012)

4. **Success Criteria:** 
   - User can go from zero sketches to locked style in < 5 minutes
   - Generated style reference maintains consistency through frame generation
   - No changes needed to Cast or Frame generation flows

5. **Constraints:** 
   - Uses existing GPT-4o image generation (gpt-image-1)
   - Client-side only, uses user's API key
   - Must integrate with existing Zustand store structure
   - StyleTab component already exists - needs modification not replacement

---

## Introduction

Describe Mode is an alternative path through the Style Definition phase that allows users to describe their desired visual style in text rather than uploading reference images. An AI generates a reference sketch based on the description, which then serves as the style foundation for all frame generation.

This removes the biggest barrier to entry: needing sketches ready before starting.

---

## Goals

- Enable users without sketches to establish a visual style through text description
- Generate high-quality style reference images via GPT-4o
- Maintain consistency with existing style lock and frame generation workflows
- Provide regeneration capability if initial result isn't satisfactory

---

## User Flow

```
[Setup] → [Style Definition]
              ↓
        ┌─────────────┐
        │ Upload Mode │  ← existing flow
        └─────────────┘
              OR
        ┌──────────────┐
        │ Describe Mode│  ← NEW
        │   ↓          │
        │ Text Input   │
        │   ↓          │
        │ Generate Ref │
        │   ↓          │
        │ Accept/Retry │
        └──────────────┘
              ↓
        [Style Locked] → [Cast] → [Frames] → [Export]
```

---

## Tasks

### T-001: Add mode toggle to StyleTab
**Description:** Add a toggle at the top of StyleTab to switch between "Upload" and "Describe" modes.

**Acceptance Criteria:**
- [ ] Two-option toggle (radio buttons or segmented control) at top of StyleTab
- [ ] Default mode is "Upload" (existing behavior)
- [ ] Selecting "Describe" hides upload UI, shows text input
- [ ] Selecting "Upload" hides describe UI, shows upload UI
- [ ] Mode selection persists in component state
- [ ] Run `npm run lint` - exits with code 0
- [ ] Verify in browser: toggle switches UI modes

---

### T-002: Create Describe Mode UI
**Description:** Add text input UI for describing the desired visual style.

**Acceptance Criteria:**
- [ ] Textarea for style description (placeholder: "Describe your desired visual style...")
- [ ] Helper text explaining what to describe (line quality, colors, mood, etc.)
- [ ] "Generate Reference" button below textarea
- [ ] Button disabled when textarea is empty
- [ ] Run `npm run lint` - exits with code 0
- [ ] Verify in browser: can enter text and button enables

---

### T-003: Add style generation API function
**Description:** Create OpenAI function to generate a style reference image from text description.

**Acceptance Criteria:**
- [ ] New function `generateStyleReference(client, description)` in `lib/openai.ts`
- [ ] Uses gpt-image-1 model with appropriate prompt structure
- [ ] Returns base64 image data or URL
- [ ] Prompt emphasizes: single reference sketch, clear style demonstration
- [ ] Run `npm run typecheck` - exits with code 0
- [ ] Run `npm run lint` - exits with code 0

---

### T-004: Connect Describe Mode to generation API
**Description:** Wire up the Generate Reference button to call the API and show loading state.

**Acceptance Criteria:**
- [ ] Clicking "Generate Reference" calls `generateStyleReference` with textarea value
- [ ] Loading state shown during generation (button disabled, spinner or text)
- [ ] Error state shown if generation fails
- [ ] On success, generated image displayed below textarea
- [ ] Run `npm run lint` - exits with code 0
- [ ] Verify in browser: generation shows loading then displays image

---

### T-005: Add Accept/Regenerate controls
**Description:** Add buttons to accept the generated reference or regenerate a new one.

**Acceptance Criteria:**
- [ ] Generated image shows with "Accept" and "Try Again" buttons
- [ ] "Try Again" triggers new generation with same description
- [ ] "Accept" proceeds to style analysis flow
- [ ] Buttons match existing UI style (zinc-900 primary, bordered secondary)
- [ ] Run `npm run lint` - exits with code 0
- [ ] Verify in browser: can accept or regenerate

---

### T-006: Integrate with style analysis flow
**Description:** When user accepts generated reference, pass it to existing style analysis logic.

**Acceptance Criteria:**
- [ ] Accepting generated image adds it to `style.referenceImages` in store
- [ ] Existing "Analyze Style" flow triggers automatically or with button
- [ ] Style description generated from the AI-created reference
- [ ] User can edit style description same as upload flow
- [ ] "Lock Style" button available after analysis
- [ ] Run `npm run typecheck` - exits with code 0
- [ ] Verify in browser: full flow from describe → generate → analyze → lock

---

### T-007: Handle empty reference images edge case
**Description:** Ensure describe mode works when no reference images exist (user didn't upload anything first).

**Acceptance Criteria:**
- [ ] Describe mode works without any prior uploads
- [ ] If user switches from Upload to Describe with images, show warning
- [ ] Generated reference image becomes sole reference
- [ ] Style analysis works with single AI-generated reference
- [ ] Run `npm run lint` - exits with code 0
- [ ] Verify in browser: fresh session → describe mode → full flow works

---

### T-008: Persist mode selection
**Description:** Save the selected mode (Upload/Describe) to localStorage so it persists across sessions.

**Acceptance Criteria:**
- [ ] Mode selection saved to localStorage
- [ ] On page load, restore last used mode
- [ ] Default to "Upload" if no saved preference
- [ ] Run `npm run lint` - exits with code 0
- [ ] Verify in browser: refresh preserves mode selection

---

## Functional Requirements

- FR-1: StyleTab must show toggle between "Upload" and "Describe" modes
- FR-2: In Describe mode, user must see textarea for style description input
- FR-3: User must be able to generate a reference image from text description
- FR-4: System must display loading state during image generation
- FR-5: Generated reference must be displayed with Accept/Regenerate options
- FR-6: Accepted reference must integrate with existing style analysis flow
- FR-7: User must be able to lock style after describe mode flow
- FR-8: Frame generation must work identically regardless of Upload vs Describe origin

---

## Non-Goals (Out of Scope)

- Style presets or templates (future B-012)
- Hybrid mode (upload + describe together)
- Multiple generated references at once
- Custom prompt tuning beyond description
- Saving generated references as reusable assets
- Mobile-specific layout changes (future B-004)

---

## Technical Considerations

### API Usage
- Uses existing `createOpenAIClient` from user's API key
- New function in `lib/openai.ts` for style reference generation
- Image generation uses gpt-image-1 (consistent with frame generation)

### State Management
- Mode toggle is local state (useState) - doesn't need global store
- Mode preference persisted to localStorage directly (not through Zustand)
- Generated reference uses existing `addReferenceImage` store action

### Image Prompt Structure
```
Generate a single reference sketch that demonstrates this visual style:
[user description]

This image will be used as a style reference for a storyboard. 
Create a simple scene that clearly shows: line quality, shading technique, level of detail, and overall aesthetic.
```

---

## Success Metrics

- User can complete describe mode flow in < 5 minutes
- Generated style references are usable for frame generation (subjective quality)
- No increase in user confusion (same downstream flow)
- API errors handled gracefully with retry option

---

## Open Questions

1. Should we offer style examples/prompts to help users describe styles?
2. Should generated reference show before or after user can edit?
3. What happens if user partially completes one mode then switches? (Current plan: show warning)
