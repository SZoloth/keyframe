# CLAUDE.md - Keyframe

## Project Overview

AI-powered storyboard generator using the "keyframe model" - upload reference sketches, define characters, generate consistent frames via GPT-4o.

## Commands

```bash
npm install      # Install dependencies
npm run dev      # Start dev server (http://localhost:3000)
npm run build    # Production build
npm run lint     # Run ESLint
```

## Architecture

### Core Flow
```
API Key → Template → Style (upload + lock) → Cast → Frame Generation → PDF Export
```

### State (Zustand)
- `auth` - OpenAI API key
- `project` - template, current phase, frames array
- `style` - reference images, locked style description
- `cast` - characters array
- `chat` - per-frame message history

### Key Decisions
1. **GPT-4o over DALL-E 3** - Better character consistency, text rendering
2. **tldraw for canvas** - Purpose-built for React, infinite canvas
3. **Vercel AI SDK** - Native generative UI support
4. **Client-side only** - No backend, user provides API key
5. **localStorage persistence** - Survives refresh, no accounts needed

## File Patterns

- Components: `components/{feature}/{ComponentName}.tsx`
- Hooks: `hooks/use{Name}.ts`
- Utils: `lib/{name}.ts`
- Types: Colocate with usage or `types/{name}.ts` if shared

## Style Guide

- TypeScript strict mode
- Tailwind for styling
- Prefer `interface` over `type` for object shapes
- Use Zustand selectors to prevent unnecessary re-renders
- All OpenAI calls go through `lib/openai.ts`

## Current Tasks

See `tasks/prd-keyframe-mvp.md` for full PRD.

Priority order:
1. T-001: Project setup
2. T-002: API key management
3. T-003: Template system
4. T-004: Canvas layout
5. T-005: Chat panel

## Testing

Manual testing for MVP. Verify each task in browser per acceptance criteria.

## Important Notes

- Never commit API keys
- All images stored as base64 in localStorage (watch for size limits)
- tldraw is read-only for MVP (no user drawing)
- Frame order is fixed (template defines sequence)
