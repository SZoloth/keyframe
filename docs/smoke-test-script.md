# Keyframe smoke test script

## Goal
Create a complete 3-frame storyboard end-to-end. Log every friction point, error, or surprise.

## Setup
- Auth method to test: **Sign in with ChatGPT** and, if available on the machine, **Use Codex CLI session**
- Template: Pick any structured template (e.g., "Raskin Pitch" or "Three Act")

## Test flow

### 1. Launch and auth
- [ ] App launches without crash
- [ ] Setup screen renders correctly (auth options visible)
- [ ] Sign in with ChatGPT completes (browser opens, redirects back, header shows "ChatGPT")
- [ ] OR: Codex CLI session import works, header shows "ChatGPT"
- [ ] Phase indicator shows correct state

### 2. Template selection
- [ ] Templates display with titles and descriptions
- [ ] Selecting a template populates frames on canvas
- [ ] Frame count matches template beats
- [ ] Can switch templates (frames reset)

### 3. Style definition
- [ ] Can type a style description
- [ ] Can upload 1-3 reference images (drag or file picker)
- [ ] "Analyze style" button calls AI and returns a description
- [ ] "Lock style" advances to Cast phase
- [ ] Going back shows style is locked

### 4. Cast
- [ ] Can add a character (name, role, visual description)
- [ ] Can add character reference image
- [ ] Can edit/remove characters
- [ ] Adding first character enables Frames phase

### 5. Frame generation (repeat for 3 frames)
- [ ] Selecting a frame in canvas shows it in chat panel
- [ ] "Suggest a scene" calls AI and returns text
- [ ] Can refine scene via chat input
- [ ] "Generate image" produces a visible image in chat
- [ ] "Accept" saves image to frame, frame shows as complete on canvas
- [ ] Selecting next frame resets chat appropriately

### 6. Export
- [ ] Export to PDF button enabled after at least one complete frame
- [ ] PDF save dialog appears
- [ ] PDF opens and shows frames with images and captions

### 7. File operations
- [ ] Save project (File > Save or Cmd+S)
- [ ] Close and reopen project — all state preserved (style, cast, frames, images)

### 8. Edge cases to probe
- [ ] Undo/redo during any phase
- [ ] Cancel mid-generation (if possible)
- [ ] Very long style description
- [ ] Special characters in character names
- [ ] Rapid clicking while AI is loading

## Issue log format
For each issue found:
```
### Issue N: [Short title]
- **Phase**: Setup / Style / Cast / Frames / Export / File
- **Severity**: Blocker / Major / Minor / Polish
- **Steps**: What you did
- **Expected**: What should happen
- **Actual**: What happened
- **Screenshot**: (if applicable)
```
