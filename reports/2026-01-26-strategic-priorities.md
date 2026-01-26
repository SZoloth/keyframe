# Strategic Priorities Report - 2026-01-26

## Current State

Keyframe MVP is live at https://keyframe-app.netlify.app with core functionality:
- Style upload and analysis
- Character definition
- Frame generation via GPT-4o
- PDF export
- 3 templates + freeform mode

**Primary friction:** Users must provide their own OpenAI API key. This blocks:
- Non-technical users who don't know what an API key is
- Users who don't want to manage API costs themselves
- Casual users who want to try before committing

## User Segments

| Segment | Size | API Key Comfort | Willingness to Pay |
|---------|------|-----------------|-------------------|
| Power users (designers, PMs) | Small | High | Yes |
| ChatGPT subscribers | Large | N/A (already paying) | Already paying |
| Casual explorers | Large | Low | Try before buy |

## Priority Options

### Option A: ChatGPT App
Build Keyframe as a ChatGPT app that runs inside ChatGPT.

**Pros:**
- Zero friction (users already have ChatGPT accounts)
- No API key management
- Built-in distribution via ChatGPT app store
- ChatGPT handles all AI costs

**Cons:**
- Limited to ChatGPT Plus/Pro users
- Iframe UI constraints
- Platform dependency

**Effort:** Medium (MCP server + widget)

### Option B: Credits System
Add backend with user accounts and credit-based billing.

**Pros:**
- Works for all users
- Revenue opportunity
- Full control over UX

**Cons:**
- Requires backend infrastructure
- Payment integration complexity
- Must manage API costs

**Effort:** High (Supabase + Stripe + proxy API)

## Recommendation

**Do both, but sequence them:**

1. **ChatGPT App first** - Faster to ship, validates demand with ChatGPT's existing user base
2. **Credits system second** - Once validated, add for broader reach and monetization

## Acceptance Criteria for ChatGPT App

1. User can install Keyframe from ChatGPT app directory
2. User can upload style reference images via widget
3. User can define characters through conversation
4. ChatGPT generates frames using Keyframe's MCP tools
5. User can export PDF from widget
6. App works for ChatGPT Plus and Pro users

## Technical Requirements

### MCP Server Tools
- `analyze_style` - Analyze uploaded images for style description
- `add_character` - Add character to cast
- `suggest_scene` - Suggest scene for a frame
- `generate_frame` - Generate image for a frame
- `export_pdf` - Generate and return PDF

### Widget
- Frame grid display
- Upload zone for reference images
- Character list
- Export button

## Issues

1. **No MCP server** - Need to create MCP server with Keyframe tools
2. **No widget** - Need to create embeddable widget for ChatGPT
3. **OAuth setup** - Need to register with OpenAI as app developer
4. **No backend** - Currently all client-side, MCP needs server

## Metrics

- Installs from ChatGPT app store
- Storyboards created per user
- Completion rate (started → exported)
- User retention (returns within 7 days)
