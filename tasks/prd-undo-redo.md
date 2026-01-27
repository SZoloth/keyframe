# PRD: Undo/Redo (B-008)

## Self-Clarification

1. **Problem/Goal:** Users need confidence when editing storyboards and want to revert changes easily.
2. **Core Functionality:** (1) Maintain undo/redo history for project edits, (2) expose Undo/Redo controls.
3. **Scope/Boundaries:** Local-only history; no multi-device sync of undo stack. Keep history size bounded.
4. **Success Criteria:** Users can undo/redo template switches and frame edits without losing progress.
5. **Constraints:** Use existing Zustand store; keep UI minimal; quality check is `npm run build`.

---

## Introduction

Add undo/redo support for project changes (templates, frames, style, cast) using a bounded history stack in the Zustand store. Provide simple controls in the Header to trigger undo/redo.

## Goals

- Track history of project edits in memory
- Allow undo/redo across project updates
- Provide visible Undo/Redo controls with disabled states

## Tasks

### T-001: Add undo/redo state and actions
**Description:** Add history/future stacks and undo/redo actions to the store.

**Acceptance Criteria:**
- [ ] Store includes `history` and `future` stacks
- [ ] Store exposes `undo()` and `redo()` actions
- [ ] Store exposes `canUndo` and `canRedo` selectors
- [ ] Run `npm run build` - exits with code 0

### T-002: Record history for project mutations
**Description:** Capture snapshots before project edits and clear redo stack.

**Acceptance Criteria:**
- [ ] Template/frames/style/cast mutations push to history
- [ ] Undo/redo restores prior project state
- [ ] Redo stack clears on new edits
- [ ] Run `npm run build` - exits with code 0

### T-003: Add Undo/Redo controls to Header
**Description:** Add buttons and wire them to the store.

**Acceptance Criteria:**
- [ ] Header shows Undo and Redo buttons
- [ ] Buttons disable when no history/future
- [ ] Run `npm run build` - exits with code 0
- [ ] Verify in browser

### T-004: Browser test — undo/redo template changes
**Description:** Verify template switch can be undone and redone.

**Acceptance Criteria:**
- [ ] Open http://localhost:3000
- [ ] Select “Problem → Solution” template
- [ ] Click Undo — frames revert to previous template state
- [ ] Click Redo — frames return to “Problem → Solution”

## Functional Requirements

- FR-1: History captures project edits (template selection, frames, style, cast)
- FR-2: Undo restores the previous project snapshot
- FR-3: Redo reapplies the undone snapshot
- FR-4: History is bounded (avoid unlimited growth)

## Non-Goals

- Syncing undo history across devices
- Collaborative undo/redo for multi-user editing
- Keyboard shortcuts (can be added later)

## Technical Considerations

- Snapshot only `ProjectState` to avoid undoing auth session data
- Use a maximum stack size (e.g., 25–50 snapshots)

## Success Metrics

- Undo/redo works for template switches without errors
- UI clearly indicates when undo/redo is available
