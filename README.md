# Keyframe

AI-powered storyboard generator for pitching products and concepts.

## What is this?

Keyframe implements the "keyframe model" for AI-assisted storyboard creation:

1. **Upload reference sketches** - Hand-drawn keyframes that establish your visual style
2. **Define your cast** - Characters with consistent visual descriptions
3. **Generate frames** - AI creates remaining frames matching your style
4. **Export PDF** - Professional storyboard ready for stakeholder presentations

Based on the workflow described by Dave McMahon at Amdocs, who used this approach to pitch AI initiatives to Chick-fil-A. The entire visual production took half a day.

## Key Features

- **Storytelling templates** - Raskin Pitch, Hero's Journey, Problem→Solution
- **Style lock** - Upload sketches, AI analyzes and maintains consistency
- **Character persistence** - Define once, referenced in every frame
- **Generative UI chat** - Cursor-like interface with structured inputs
- **PDF export** - Frames + captions ready for presentation

## Tech Stack

- **Next.js 15** - App Router, React Server Components
- **tldraw** - Infinite canvas for frame layout
- **Vercel AI SDK 6** - Streaming chat with generative UI
- **GPT-4o** - Image generation with better consistency than DALL-E 3
- **@react-pdf/renderer** - High-quality PDF export
- **Zustand** - Lightweight state management

## Getting Started

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Open http://localhost:3000
```

You'll need an OpenAI API key with access to GPT-4o.

## Project Structure

```
keyframe/
├── app/
│   ├── layout.tsx
│   ├── page.tsx
│   └── api/
│       └── chat/
│           └── route.ts
├── components/
│   ├── canvas/
│   │   └── StoryboardCanvas.tsx
│   ├── chat/
│   │   ├── ChatPanel.tsx
│   │   └── GenerativeUI.tsx
│   ├── cast/
│   │   └── CastPanel.tsx
│   ├── style/
│   │   └── StylePanel.tsx
│   └── export/
│       └── PDFExport.tsx
├── lib/
│   ├── store.ts
│   ├── templates.ts
│   ├── openai.ts
│   └── prompts.ts
├── tasks/
│   └── prd-keyframe-mvp.md
└── README.md
```

## Templates

### Raskin Pitch (5 frames)
1. The Old World - Status quo
2. The Shift - External change
3. Winners & Losers - Contrast
4. The Promised Land - Solution in action
5. Proof - Evidence it works

### Hero's Journey (8 frames)
1. Ordinary World
2. Call to Adventure
3. Refusal
4. Meeting the Mentor
5. Crossing Threshold
6. Tests & Allies
7. Ordeal
8. Return with Elixir

### Problem → Solution (3 frames)
1. Before - Frustration
2. During - Solution in action
3. After - Outcome

## Inspiration

> "The people who are actually deciding whether to pursue these things or not, they don't give a shit what the technology is. They hire someone to give a shit about the technology. What they want to know is how is this going to improve the actual experience of anybody involved."
> 
> — Dave McMahon, Amdocs

## License

MIT
