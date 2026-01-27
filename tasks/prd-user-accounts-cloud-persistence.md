# PRD: User Accounts & Cloud Persistence (B-005)

## Self-Clarification

1. **Problem/Goal:** Users can only store storyboards locally; they lose access across devices. Add authentication and cloud save/load to enable multi-device access.
2. **Core Functionality:** (1) Sign up/sign in/out, (2) Save current project to cloud, (3) Load a saved project from cloud.
3. **Scope/Boundaries:** No collaboration, no sharing links, no gallery UX beyond a simple list, no OAuth providers beyond email/password for now.
4. **Success Criteria:** Auth UI works, users can save/load project data when Supabase is configured, and logged-out users see disabled cloud actions.
5. **Constraints:** Client-side only; uses Supabase JS client with `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`; quality check is `npm run build`.

---

## Introduction

Introduce user accounts and cloud persistence so storyboards are accessible across devices. This phase adds basic email/password auth with Supabase and minimal save/load capabilities.

## Goals

- Allow users to sign up/sign in/out with email + password
- Enable saving the current project state to Supabase
- Enable loading a saved project into the app
- Keep UI simple and functional without introducing a full gallery experience

## Tasks

### T-001: Add Supabase client wrapper
**Description:** Install Supabase JS and create a client utility.

**Acceptance Criteria:**
- [ ] `@supabase/supabase-js` is added to dependencies
- [ ] `src/lib/supabase.ts` exports a configured client
- [ ] Missing env variables result in a clear error message in console (non-throwing)
- [ ] Run `npm run build` - exits with code 0

### T-002: Add auth state to store
**Description:** Track current user/session state in Zustand.

**Acceptance Criteria:**
- [ ] Store includes `authUser` and `authSession` (or equivalent)
- [ ] Store includes `setAuthSession` and `clearAuthSession` actions
- [ ] Selectors/hooks exist for auth state
- [ ] Run `npm run build` - exits with code 0

### T-003: Add AuthProvider session sync
**Description:** Sync Supabase auth session into Zustand on app load.

**Acceptance Criteria:**
- [ ] New `AuthProvider` component listens for auth changes
- [ ] On load, provider fetches current session and updates store
- [ ] Provider is wired in `src/app/layout.tsx`
- [ ] Run `npm run build` - exits with code 0

### T-004: Create AuthModal component
**Description:** Build a modal for email/password sign up and sign in.

**Acceptance Criteria:**
- [ ] New `AuthModal` component exists and renders in UI
- [ ] Supports sign in and sign up flows with Supabase
- [ ] Shows validation errors inline
- [ ] Uses 44px min tap targets for buttons
- [ ] Run `npm run build` - exits with code 0
- [ ] Verify in browser

### T-005: Add Account button to Header
**Description:** Add UI entry point to open Auth modal and sign out.

**Acceptance Criteria:**
- [ ] Header shows “Sign in” when logged out
- [ ] Header shows user email and “Sign out” when logged in
- [ ] Sign out clears auth state and closes modal
- [ ] Run `npm run build` - exits with code 0
- [ ] Verify in browser

### T-006: Add project serialization helpers
**Description:** Create helpers to serialize/deserialize project state for cloud save.

**Acceptance Criteria:**
- [ ] New `src/lib/projectPersistence.ts` defines `serializeProject` and `hydrateProject`
- [ ] Serialization includes: template, frames, style, characters, selectedFrameId, currentPhase
- [ ] Hydration updates store via existing actions
- [ ] Run `npm run build` - exits with code 0

### T-007: Implement cloud save/load
**Description:** Save/load project records in Supabase.

**Acceptance Criteria:**
- [ ] Save function writes project JSON to a `projects` table
- [ ] Load function fetches list of projects for current user
- [ ] Load function can hydrate a selected project into store
- [ ] Handles missing Supabase config with disabled UI state
- [ ] Run `npm run build` - exits with code 0

### T-008: Add Save/Load UI controls
**Description:** Add minimal UI controls for saving/loading in Header.

**Acceptance Criteria:**
- [ ] “Save to Cloud” button shown when logged in
- [ ] “Open from Cloud” button shows a dropdown list of projects
- [ ] Buttons disabled when logged out or Supabase not configured
- [ ] Run `npm run build` - exits with code 0
- [ ] Verify in browser

### T-009: Browser test — logged-out state
**Description:** Verify cloud actions are gated when logged out.

**Acceptance Criteria:**
- [ ] Start dev server and open app
- [ ] “Sign in” visible in header
- [ ] Save/Load controls disabled or hidden
- [ ] No console errors related to Supabase config

### T-010: Browser test — auth modal
**Description:** Verify auth modal opens and validates inputs.

**Acceptance Criteria:**
- [ ] Click “Sign in” → modal opens
- [ ] Toggle between sign in and sign up views
- [ ] Invalid email shows inline error

## Functional Requirements

- FR-1: Users must be able to sign up and sign in with email/password.
- FR-2: Authenticated users must be able to save current project state.
- FR-3: Authenticated users must be able to load a saved project.
- FR-4: Cloud actions must be disabled when logged out or Supabase env missing.

## Non-Goals (Out of Scope)

- OAuth provider setup (Google, GitHub, etc.)
- Real-time collaboration
- Sharing links or public gallery
- Offline support beyond existing local persistence

## Technical Considerations

- Supabase env vars must be `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `projects` table expected with `id`, `user_id`, `name`, `data`, `updated_at`
- App currently uses Zustand + persist; cloud save should serialize state separately

## Success Metrics

- Users can sign in and see cloud save/load controls
- Projects are accessible on another device when Supabase configured

## Open Questions

- Should we prompt users for a project name on save or auto-generate?
- Where should the project list live long-term (Header vs Gallery)?
