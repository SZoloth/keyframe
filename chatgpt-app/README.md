# Keyframe ChatGPT App

MCP server for running Keyframe inside ChatGPT.

## Prerequisites

- Node.js 18+
- OpenAI API key
- [ngrok](https://ngrok.com/) for local development

## Local Development

### 1. Install dependencies

```bash
npm install
```

### 2. Set up environment

```bash
cp .env.example .env
# Edit .env with your OpenAI API key
```

### 3. Start the server

```bash
npm run dev
```

The server will start at `http://localhost:8787/mcp`.

### 4. Expose with ngrok

In a separate terminal:

```bash
ngrok http 8787
```

Copy the HTTPS URL (e.g., `https://abc123.ngrok.app`).

## Connect to ChatGPT

1. Go to [ChatGPT Settings](https://chat.openai.com/)
2. Navigate to **Settings → Apps & Connectors → Advanced settings**
3. Enable **Developer mode**
4. Go to **Settings → Connectors**
5. Click **Create** and enter your ngrok URL + `/mcp` (e.g., `https://abc123.ngrok.app/mcp`)
6. Name it "Keyframe" and save

## Test with MCP Inspector

```bash
npx @modelcontextprotocol/inspector@latest --server-url http://localhost:8787/mcp --transport http
```

## Available Tools

| Tool | Description |
|------|-------------|
| `set_style` | Set the visual style for all frames |
| `add_character` | Add a character to the cast |
| `add_frame` | Add an empty frame to the storyboard |
| `generate_frame_image` | Generate an image for a frame |

## Scripts

- `npm run dev` - Start development server with hot reload
- `npm run build` - Build for production
- `npm run typecheck` - Type check without emitting
- `npm start` - Run production server
