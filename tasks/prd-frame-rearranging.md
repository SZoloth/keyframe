# PRD: Frame Rearranging

## Self-Clarification

1. **Problem/Goal:** Users often discover the optimal story order while creating, not before. Currently frames are locked to template order or append-only in freeform mode. Adding drag-and-drop reordering lets users iterate on narrative flow without starting over.

2. **Core Functionality:** 
   - Drag a frame card to a new position in the grid
   - Visual feedback during drag (placeholder, drop target indicator)
   - Order persists to store and localStorage

3. **Scope/Boundaries:** 
   - CSS grid-based drag-and-drop (not full tldraw canvas yet - that's B-020)
   - Works in both template and freeform modes
   - Does NOT include multi-select drag
   - Does NOT include drag between different views/panels
   - Keyboard reordering is out of scope for MVP

4. **Success Criteria:** 
   - User can drag any frame to any position
   - New order persists after page refresh
   - No regression in existing frame selection/editing

5. **Constraints:** 
   - Use native HTML5 drag-and-drop or lightweight library (no heavy dependencies)
   - Must work with existing Zustand store pattern
   - Maintain touch support for future mobile work

---

## Introduction

Frame Rearranging adds drag-and-drop reordering to the storyboard canvas. Users can grab any frame card and move it to a new position, allowing them to experiment with narrative structure without regenerating content.

---

## Goals

- Enable frame reordering via drag-and-drop
- Provide clear visual feedback during drag operations
- Persist new order to Zustand store (auto-saves to localStorage)
- Maintain compatibility with both template and freeform modes

---

## Tasks

### T-001: Add reorderFrames action to store
**Description:** Add a Zustand action to reorder frames array by moving a frame from one index to another.

**Acceptance Criteria:**
- [ ] Store has `reorderFrames(fromIndex: number, toIndex: number)` action
- [ ] Action correctly moves frame from source to destination index
- [ ] Other frames shift appropriately
- [ ] Run `npm run typecheck` - exits with code 0

---

### T-002: Add draggable attribute to frame cards
**Description:** Make frame cards draggable using HTML5 drag-and-drop.

**Acceptance Criteria:**
- [ ] Each frame card has `draggable="true"` attribute
- [ ] Cursor changes to grab/grabbing on hover/drag
- [ ] Run `npm run lint` - exits with code 0

---

### T-003: Implement onDragStart handler
**Description:** Store the dragged frame's index when drag begins.

**Acceptance Criteria:**
- [ ] onDragStart sets dragged frame index in component state
- [ ] Sets dataTransfer with frame id for compatibility
- [ ] Dragged frame gets visual feedback (opacity reduction)
- [ ] Run `npm run lint` - exits with code 0

---

### T-004: Implement onDragOver handler
**Description:** Allow dropping and show drop target indicator.

**Acceptance Criteria:**
- [ ] onDragOver calls preventDefault() to allow drop
- [ ] Drop target frame shows visual indicator (border highlight)
- [ ] Indicator clears when drag leaves
- [ ] Run `npm run lint` - exits with code 0

---

### T-005: Implement onDrop handler
**Description:** Complete the reorder when frame is dropped.

**Acceptance Criteria:**
- [ ] onDrop calls reorderFrames with correct indices
- [ ] Clears drag state after drop
- [ ] New order reflects immediately in UI
- [ ] Run `npm run lint` - exits with code 0

---

### T-006: Add onDragEnd cleanup
**Description:** Clean up drag state when drag ends (including cancel).

**Acceptance Criteria:**
- [ ] onDragEnd clears all drag-related state
- [ ] Works for both successful drop and cancelled drag
- [ ] No lingering visual artifacts
- [ ] Run `npm run lint` - exits with code 0

---

### T-007: Style dragging and drop target states
**Description:** Add visual polish to drag interactions.

**Acceptance Criteria:**
- [ ] Dragging frame has reduced opacity (opacity-50)
- [ ] Drop target has colored border (blue or primary color)
- [ ] Smooth transitions on state changes
- [ ] Run `npm run lint` - exits with code 0

---

### T-008: Test reorder in template mode
**Description:** Verify drag-and-drop works with template-based frames.

**Acceptance Criteria:**
- [ ] Start dev server on localhost
- [ ] Select a template (e.g., Problem → Solution)
- [ ] Go to Frames phase
- [ ] Drag frame 1 to position 3
- [ ] Verify frame order changed in UI
- [ ] Refresh page - order persists

---

### T-009: Test reorder in freeform mode
**Description:** Verify drag-and-drop works in freeform mode.

**Acceptance Criteria:**
- [ ] Select Freeform template
- [ ] Add 3+ frames
- [ ] Drag frame 2 to position 1
- [ ] Verify frame order changed
- [ ] Captions and images stay with their frames

---

### T-010: Verify no regression in frame selection
**Description:** Ensure clicking still selects frames (not just drags).

**Acceptance Criteria:**
- [ ] Single click on frame selects it (not drag)
- [ ] Selection syncs with chat panel
- [ ] Caption editing still works
- [ ] Delete button still works in freeform mode

---

## Functional Requirements

- FR-1: Store must have reorderFrames(fromIndex, toIndex) action
- FR-2: Frame cards must be draggable
- FR-3: Dragging frame must show reduced opacity
- FR-4: Drop target must show visual indicator
- FR-5: Dropping frame must update store order
- FR-6: New order must persist to localStorage
- FR-7: Frame content (image, caption, beat) must move with frame

---

## Non-Goals (Out of Scope)

- Multi-select and drag multiple frames
- Keyboard-based reordering (arrow keys)
- Drag frames between different panels
- Animation of other frames shifting
- tldraw infinite canvas (that's B-020)
- Touch gesture refinements (basic touch works via HTML5 DnD)

---

## Technical Considerations

### HTML5 Drag and Drop
- Use native HTML5 DnD API for simplicity
- No additional dependencies required
- Works on desktop; basic mobile support via polyfills if needed later

### Store Update
```typescript
reorderFrames: (fromIndex, toIndex) => set(state => {
  const frames = [...state.frames];
  const [movedFrame] = frames.splice(fromIndex, 1);
  frames.splice(toIndex, 0, movedFrame);
  return { frames };
})
```

### State Management
- `draggedIndex: number | null` - which frame is being dragged
- `dropTargetIndex: number | null` - which position is being hovered

---

## Success Metrics

- Drag and drop completes in < 500ms
- No layout shift or flickering during drag
- Frame order persists correctly after refresh
- No regression in existing functionality
