# Keyframe

AI-powered storyboard generator for pitching products and concepts.

**[Try it live →](https://keyframe-app.netlify.app)**

![Keyframe Screenshot](https://via.placeholder.com/800x450?text=Keyframe+Screenshot)

## What is this?

Keyframe implements the "keyframe model" for AI-assisted storyboard creation:

1. **Upload reference sketches** - Hand-drawn keyframes that establish your visual style
2. **Define your cast** - Characters with consistent visual descriptions
3. **Generate frames** - AI creates remaining frames matching your style
4. **Export PDF** - Professional storyboard ready for stakeholder presentations

Based on the workflow described by Dave McMahon, who used this approach to pitch AI initiatives to Chick-fil-A. The entire visual production took half a day.

## Features

- **Storytelling templates** - Raskin Pitch, Hero's Journey, Problem→Solution, or Freeform
- **Style lock** - Upload sketches, AI analyzes and maintains consistency
- **Character persistence** - Define once, referenced in every frame
- **Iterative generation** - Refine scenes via chat before generating
- **PDF export** - Frames + captions ready for presentation

## Quick Start

```bash
# Clone the repo
git clone https://github.com/SZoloth/keyframe.git
cd keyframe

# Install dependencies
npm install

# Start dev server
npm run dev

# Open http://localhost:3000
```

You'll need an OpenAI API key with GPT-4o access.

## Tech Stack

- **Next.js 15** - App Router, React Server Components
- **TypeScript** - Strict mode
- **Tailwind CSS** - Styling
- **Zustand** - State management with localStorage persistence
- **OpenAI GPT-4o** - Style analysis and image generation
- **@react-pdf/renderer** - PDF export

## Project Structure

```
keyframe/
├── src/
│   ├── app/                 # Next.js pages
│   ├── components/
│   │   ├── canvas/          # Storyboard grid
│   │   ├── sidebar/         # Chat, Cast, Style tabs
│   │   └── export/          # PDF generation
│   └── lib/
│       ├── store.ts         # Zustand store
│       ├── templates.ts     # Storytelling frameworks
│       ├── openai.ts        # API calls
│       └── types.ts         # TypeScript interfaces
├── tasks/
│   ├── prd-keyframe-mvp.md  # Original PRD
│   └── backlog.md           # Post-MVP features
└── README.md
```

## Templates

### Raskin Pitch (5 frames)
Andy Raskin's proven pitch structure:
1. The Old World - Status quo
2. The Shift - External change
3. Winners & Losers - Contrast
4. The Promised Land - Solution in action
5. Proof - Evidence it works

### Hero's Journey (8 frames)
Classic narrative arc for customer stories.

### Problem → Solution (3 frames)
Quick and effective: Before → During → After

### Freeform
Create your own structure. Add/remove frames as needed.

## Contributing

We welcome contributions! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

Check [tasks/backlog.md](./tasks/backlog.md) for post-MVP features to work on.

## Inspiration

> "The people who are actually deciding whether to pursue these things or not, they don't give a shit what the technology is. They hire someone to give a shit about the technology. What they want to know is how is this going to improve the actual experience of anybody involved."
> 
> — Dave McMahon

## License

MIT - see [LICENSE](./LICENSE)
