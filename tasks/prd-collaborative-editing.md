# PRD: Collaborative Editing (B-007)

## Self-Clarification

1. **Problem/Goal:** Teams want to collaborate on storyboards together. Provide a minimal collaboration MVP that keeps multiple tabs in sync.
2. **Core Functionality:** (1) Cross-tab sync of project state, (2) automatic rehydrate on updates, (3) visible confirmation that sync is active.
3. **Scope/Boundaries:** Local-only collaboration (same browser profile). No real-time cursor presence, chat, or multi-user auth. No Liveblocks/Partykit integration yet.
4. **Success Criteria:** Changing template or frames in one tab updates the other tab within a second.
5. **Constraints:** Client-side only; use existing Zustand persist storage. Quality check: `npm run build`.

---

## Introduction

Implement a collaboration MVP by syncing persisted state across browser tabs using the `storage` event. This allows multiple tabs to stay in sync without backend infrastructure.

## Goals

- Sync project state across multiple tabs in the same browser profile
- Provide a lightweight indicator that sync is active
- Keep changes minimal and compatible with existing localStorage persistence

## Tasks

### T-001: Add CollaborationProvider
**Description:** Listen for `storage` events on `keyframe-storage` and trigger rehydrate.

**Acceptance Criteria:**
- [ ] `src/components/CollaborationProvider.tsx` exists
- [ ] Adds `window.addEventListener('storage', ...)` for `keyframe-storage`
- [ ] Calls `useStore.persist.rehydrate()` when data changes
- [ ] Run `npm run build` - exits with code 0

### T-002: Wire provider in layout
**Description:** Wrap the app with CollaborationProvider.

**Acceptance Criteria:**
- [ ] `src/app/layout.tsx` wraps children with CollaborationProvider
- [ ] Run `npm run build` - exits with code 0

### T-003: Add sync indicator in Header
**Description:** Show a subtle “Sync: On” indicator when collaboration provider is active.

**Acceptance Criteria:**
- [ ] Header shows a small “Sync: On” label
- [ ] Label is unobtrusive (text-xs, muted)
- [ ] Run `npm run build` - exits with code 0
- [ ] Verify in browser

### T-004: Browser test — cross-tab sync
**Description:** Verify selecting a template syncs across two tabs.

**Acceptance Criteria:**
- [ ] Start dev server and open two tabs on http://localhost:3000
- [ ] In tab A, connect OpenAI using `test-key-dev`
- [ ] Select “Problem → Solution” template
- [ ] In tab B, the template selection updates and frames reflect the new template

## Functional Requirements

- FR-1: On localStorage updates, other tabs must rehydrate state.
- FR-2: Sync applies to template selection and frames state.
- FR-3: UI shows a small sync indicator.

## Non-Goals

- Multi-user collaboration across devices
- Cursor presence or chat
- Server-based collaboration via Liveblocks/Partykit

## Technical Considerations

- Use `storage` event on `keyframe-storage` to trigger `useStore.persist.rehydrate()`
- Keep sync logic in a provider to avoid coupling to individual components

## Success Metrics

- Changes propagate across tabs within 1 second
- No console errors on sync
