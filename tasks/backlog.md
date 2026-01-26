# Keyframe Backlog

Post-MVP features and enhancements.

---

## High Priority

### B-001: Describe Mode (Text-to-Keyframe)
**Description:** Allow users to describe a keyframe in text instead of uploading an image. AI generates a reference sketch that establishes the style.

**Value:** Removes friction for users who don't have sketches ready.

---

### B-002: Frame Rearranging
**Description:** Enable drag-and-drop reordering of frames on the canvas. Consider using tldraw for this.

**Value:** Users often discover the right order while creating, not before.

---

### B-003: Export Formats
**Description:** Add additional export options beyond PDF:
- PNG zip (individual frames)
- Figma file (.fig or paste-able)
- Shareable web link (hosted preview)
- PowerPoint/Keynote

**Value:** Different stakeholders prefer different formats.

---

### B-004: Mobile Responsiveness
**Description:** Make the app usable on tablets and phones. May require collapsible sidebar, touch-friendly controls.

**Value:** Users often want to demo storyboards on iPads.

---

## Medium Priority

### B-005: User Accounts & Cloud Persistence
**Description:** Add authentication (email/password or OAuth) and save projects to a database (Supabase, Planetscale).

**Value:** Users can access projects from multiple devices, share with team.

---

### B-006: Custom Template Creation
**Description:** Let users create their own templates with custom beats and guidance.

**Value:** Power users have their own storytelling frameworks.

---

### B-007: Collaborative Editing
**Description:** Real-time collaboration on storyboards (like Figma). Use Liveblocks or Partykit.

**Value:** Teams often create storyboards together.

---

### B-008: Undo/Redo
**Description:** Full undo/redo stack for all actions (scene edits, image regeneration, caption changes).

**Value:** Reduces fear of making changes.

---

### B-009: Project Gallery
**Description:** Show all user's projects in a gallery view. Quick preview, duplicate, delete.

**Value:** Users create multiple storyboards over time.

---

## Lower Priority

### B-010: Animation/Video Export
**Description:** Generate animated storyboard as video (Ken Burns effect on frames, transitions). Use Remotion.

**Value:** More engaging for presentations.

---

### B-011: Voiceover Integration
**Description:** Record or upload voiceover, sync to frames, export as video with audio.

**Value:** Complete pitch package.

---

### B-012: Style Library
**Description:** Save and reuse styles across projects. Browse community-submitted styles.

**Value:** Faster iteration, inspiration.

---

### B-013: Character Library
**Description:** Save characters across projects. Import characters from previous storyboards.

**Value:** Consistency across multiple storyboards for same product/brand.

---

### B-014: AI Scene Director
**Description:** More sophisticated scene suggestions that consider:
- Visual composition (rule of thirds, leading lines)
- Emotional beats
- Contrast between frames
- Pacing

**Value:** Higher quality output for non-designers.

---

### B-015: Batch Generation
**Description:** Generate all frames at once after scene descriptions are confirmed. Show progress, allow cancellation.

**Value:** Faster workflow for confident users.

---

## Technical Debt / Improvements

### B-016: IndexedDB for Image Storage
**Description:** Move image storage from localStorage to IndexedDB to handle larger projects.

**Value:** Prevents localStorage quota errors.

---

### B-017: Rate Limit Handling
**Description:** Graceful handling of OpenAI rate limits with queue, retry, and user feedback.

**Value:** Better UX when API is throttled.

---

### B-018: Style Reinforcement
**Description:** Periodically re-inject style description into prompts to prevent drift over many generations.

**Value:** Better consistency in long storyboards.

---

### B-019: Streaming Image Generation
**Description:** Show partial image as it generates (if OpenAI supports progressive rendering).

**Value:** Faster perceived performance.

---

### B-020: tldraw Integration
**Description:** Replace CSS grid canvas with full tldraw canvas for:
- Infinite canvas
- Zoom/pan
- Frame rearranging
- Annotations

**Value:** More professional canvas experience.

---

## Ideas from Original Meeting

### B-021: Lookalike Suggestions
**Description:** After generating a storyboard, suggest "similar" story structures or scenes based on what worked.

**Value:** Learning from patterns.

---

### B-022: White-Label Version
**Description:** Configurable branding, custom templates, embed in other products.

**Value:** B2B opportunity for agencies/enterprises.

---

### B-023: Skeleton UI Mode
**Description:** Option to generate abstract/skeleton UI overlays instead of detailed interfaces (like Matt Ralfman's approach).

**Value:** Avoids premature UI fixation.
