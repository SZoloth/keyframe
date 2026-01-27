# PRD: Custom Template Creation (B-006)

## Self-Clarification

1. **Problem/Goal:** Users want to define their own storytelling frameworks instead of being limited to the built-in templates.
2. **Core Functionality:** (1) Create a custom template with name + beats, (2) see it in the template list, (3) select it to generate frames.
3. **Scope/Boundaries:** No edit/delete for now, no sharing, no cloud sync; local persistence only.
4. **Success Criteria:** A user can create a custom template in Setup, select it, and the canvas reflects its beats. Data persists across reloads via local storage.
5. **Constraints:** Use existing Zustand persistence; keep UI simple in `SetupTab`; quality check is `npm run build`.

---

## Introduction

Add a lightweight custom template creator in the Setup phase so users can define their own beats and guidance. The new templates should persist locally and behave like built-in templates when selected.

## Goals

- Allow creating a custom template (name + beats + guidance)
- Show custom templates alongside built-in templates
- Selecting a custom template generates frames based on its beats
- Persist custom templates locally

## Tasks

### T-001: Add customTemplates to store
**Description:** Add a custom template array and actions in Zustand with persistence.

**Acceptance Criteria:**
- [ ] Store includes `customTemplates: Template[]`
- [ ] Add `addCustomTemplate(template: Template)` action
- [ ] `partialize` persists customTemplates
- [ ] Run `npm run build` - exits with code 0

### T-002: Update template lookup to include custom templates
**Description:** Allow `selectTemplate` to resolve custom template ids.

**Acceptance Criteria:**
- [ ] `selectTemplate` checks customTemplates before built-in templates
- [ ] `getTemplateById` supports optional custom template list
- [ ] Run `npm run build` - exits with code 0

### T-003: Add custom template form state in SetupTab
**Description:** Track name, description, and beats locally in SetupTab.

**Acceptance Criteria:**
- [ ] SetupTab has state for template name and description
- [ ] SetupTab has beats state with title + guidance fields
- [ ] Add handlers to add/remove beats
- [ ] Run `npm run build` - exits with code 0

### T-004: Render custom template creation UI
**Description:** Add a UI section in SetupTab to create templates.

**Acceptance Criteria:**
- [ ] Inputs for template name + optional description
- [ ] Beat editor list (title + guidance fields)
- [ ] Button to add another beat
- [ ] Run `npm run build` - exits with code 0
- [ ] Verify in browser

### T-005: Save custom template and auto-select
**Description:** On save, create a custom Template and select it.

**Acceptance Criteria:**
- [ ] Clicking “Save Template” calls addCustomTemplate
- [ ] New template appears in list immediately
- [ ] The new template is selected and frames are created
- [ ] Run `npm run build` - exits with code 0
- [ ] Verify in browser

### T-006: Validate required fields
**Description:** Ensure name and at least one beat are required.

**Acceptance Criteria:**
- [ ] Save button disabled until name + one beat title exist
- [ ] Inline error shown if fields missing
- [ ] Run `npm run build` - exits with code 0

### T-007: Browser test — create custom template
**Description:** Verify the create flow works end-to-end.

**Acceptance Criteria:**
- [ ] Open http://localhost:3000
- [ ] Enter name “My Template”
- [ ] Add beat title + guidance
- [ ] Click “Save Template”
- [ ] New template appears and is selected

### T-008: Browser test — select custom template
**Description:** Verify selecting a custom template changes frames.

**Acceptance Criteria:**
- [ ] Select custom template from list
- [ ] Canvas shows beats matching custom template titles
- [ ] Refresh page and template still appears

## Functional Requirements

- FR-1: Users can create a template with name, description, and beats
- FR-2: Custom templates appear in template selection list
- FR-3: Selecting a custom template creates frames based on its beats
- FR-4: Custom templates persist locally across reloads

## Non-Goals

- Editing or deleting templates
- Sharing templates or cloud sync
- Collaboration on templates

## Technical Considerations

- `templates.ts` currently exports static templates; add a helper to merge custom templates
- Store persistence uses `partialize` — update it for customTemplates
- Template IDs should be unique (e.g., `custom-${Date.now()}`)

## Success Metrics

- Users can create and reuse a custom template in <2 minutes
- No data loss on reload

## Open Questions

- Should we allow reordering beats during creation?
