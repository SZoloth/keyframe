# Contributing to Keyframe

Thanks for your interest in contributing! Keyframe is an open source project and we welcome contributions of all kinds.

## Ways to Contribute

- **Bug reports** - Found something broken? Open an issue.
- **Feature requests** - Have an idea? Check the [backlog](./tasks/backlog.md) first, then open an issue if it's new.
- **Code contributions** - Pick up an issue or backlog item and submit a PR.
- **Documentation** - Improve the README, add examples, fix typos.

## Getting Started

1. Fork the repo
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/keyframe.git`
3. Install dependencies: `npm install`
4. Start dev server: `npm run dev`
5. Open http://localhost:3000

You'll need an OpenAI API key with GPT-4o access to test the full flow.

## Development

### Tech Stack

- Next.js 15 (App Router)
- TypeScript
- Tailwind CSS
- Zustand (state management)
- OpenAI SDK (GPT-4o for images)
- @react-pdf/renderer (PDF export)

### Project Structure

```
src/
├── app/              # Next.js app router pages
├── components/       # React components
│   ├── canvas/       # Storyboard canvas
│   ├── sidebar/      # Chat, Cast, Style tabs
│   └── export/       # PDF generation
└── lib/              # Utilities, store, types
```

### Code Style

- TypeScript strict mode
- Prefer `interface` over `type` for objects
- Use Zustand selectors to prevent re-renders
- Keep components focused (single responsibility)

## Submitting a PR

1. Create a branch: `git checkout -b feat/your-feature`
2. Make your changes
3. Run `npm run build` to check for errors
4. Commit with a clear message
5. Push and open a PR

### PR Guidelines

- Keep PRs focused on one thing
- Include screenshots for UI changes
- Reference related issues
- Update docs if needed

## Backlog

Check [tasks/backlog.md](./tasks/backlog.md) for post-MVP features. High priority items are great first contributions:

- B-001: Describe mode (text-to-keyframe)
- B-002: Frame rearranging
- B-003: More export formats
- B-004: Mobile responsiveness

## Questions?

Open an issue or reach out. We're happy to help!
