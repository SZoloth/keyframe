import { createServer, IncomingMessage, ServerResponse } from 'node:http';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';
import { getState, updateState, generateId } from './state.js';
import type { Character, Frame } from './types.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load widget HTML
const widgetPath = join(__dirname, '..', 'public', 'keyframe-widget.html');
let widgetHtml: string;
try {
  widgetHtml = readFileSync(widgetPath, 'utf8');
} catch {
  widgetHtml = '<html><body><h1>Widget not found</h1></body></html>';
}

// Tool input schemas
const setStyleSchema = {
  style: z.string().min(10, 'Style description must be at least 10 characters'),
};

const addCharacterSchema = {
  name: z.string().min(1, 'Name is required'),
  role: z.string().min(1, 'Role is required'),
  visualDescription: z.string().min(10, 'Visual description must be at least 10 characters'),
};

const addFrameSchema = {
  title: z.string().min(1, 'Title is required'),
  caption: z.string().optional(),
};

const setFrameImageSchema = {
  frameId: z.string().min(1, 'Frame ID is required'),
  imageUrl: z
    .string()
    .min(1, 'Image URL or data URI is required')
    .refine((value) => {
      if (value.startsWith('data:image/')) {
        return true;
      }
      try {
        const url = new URL(value);
        return url.protocol === 'http:' || url.protocol === 'https:';
      } catch {
        return false;
      }
    }, 'Must be an http(s) URL or data:image/... base64 URI'),
};

const setFrameImageBase64Schema = {
  frameId: z.string().min(1, 'Frame ID is required'),
  imageBase64: z.string().min(10, 'Image base64 is required'),
  mimeType: z.string().optional(),
};

const updateFrameCaptionSchema = {
  frameId: z.string().min(1, 'Frame ID is required'),
  caption: z.string(),
};

// Helper to create structured content response
function replyWithState(sessionId: string, message?: string) {
  const state = getState(sessionId);
  return {
    content: message ? [{ type: 'text' as const, text: message }] : [],
    structuredContent: state,
  };
}

function attachImageToFrame(sessionId: string, frameId: string, imageUrl: string) {
  const state = getState(sessionId);
  const frameIndex = state.frames.findIndex((f) => f.id === frameId);

  if (frameIndex === -1) {
    return replyWithState(
      sessionId,
      `Frame with ID "${frameId}" not found. Available frames: ${state.frames
        .map((f) => `${f.title} (${f.id})`)
        .join(', ')}`
    );
  }

  if (!imageUrl) {
    return replyWithState(sessionId, 'Image URL is required.');
  }

  const updatedFrames = [...state.frames];
  updatedFrames[frameIndex] = {
    ...updatedFrames[frameIndex],
    imageUrl,
    status: 'complete',
  };
  updateState(sessionId, { frames: updatedFrames });

  return replyWithState(sessionId, `Image attached to frame: ${updatedFrames[frameIndex].title}`);
}

function createKeyframeServer() {
  const server = new McpServer({ name: 'keyframe', version: '0.2.0' });

  // Register widget resource
  server.registerResource(
    'keyframe-widget',
    'ui://widget/keyframe.html',
    {},
    async () => ({
      contents: [
        {
          uri: 'ui://widget/keyframe.html',
          mimeType: 'text/html+skybridge',
          text: widgetHtml,
          _meta: {
            'openai/widgetPrefersBorder': true,
          },
        },
      ],
    })
  );

  // Tool: set_style
  server.registerTool(
    'set_style',
    {
      title: 'Set Style',
      description: 'Set the visual style description for the storyboard. This style guides how images should be generated.',
      inputSchema: setStyleSchema,
      _meta: {
        'openai/outputTemplate': 'ui://widget/keyframe.html',
        'openai/toolInvocation/invoking': 'Setting storyboard style...',
        'openai/toolInvocation/invoked': 'Style set',
      },
    },
    async (args, extra) => {
      const sessionId = extra?.sessionId ?? 'default';
      const style = args?.style?.trim() ?? '';
      
      if (!style || style.length < 10) {
        return replyWithState(sessionId, 'Style description must be at least 10 characters.');
      }
      
      updateState(sessionId, {
        style: { description: style, locked: true },
      });
      
      return replyWithState(sessionId, `Style set: "${style.slice(0, 50)}..."`);
    }
  );

  // Tool: add_character
  server.registerTool(
    'add_character',
    {
      title: 'Add Character',
      description: 'Add a character to the storyboard cast. Include name, role, and visual description for consistency across frames.',
      inputSchema: addCharacterSchema,
      _meta: {
        'openai/outputTemplate': 'ui://widget/keyframe.html',
        'openai/toolInvocation/invoking': 'Adding character...',
        'openai/toolInvocation/invoked': 'Character added',
      },
    },
    async (args, extra) => {
      const sessionId = extra?.sessionId ?? 'default';
      const name = args?.name?.trim() ?? '';
      const role = args?.role?.trim() ?? '';
      const visualDescription = args?.visualDescription?.trim() ?? '';
      
      if (!name || !role || visualDescription.length < 10) {
        return replyWithState(sessionId, 'Name, role, and visual description (10+ chars) are required.');
      }
      
      const character: Character = {
        id: generateId(),
        name,
        role,
        visualDescription,
      };
      
      const state = getState(sessionId);
      updateState(sessionId, {
        characters: [...state.characters, character],
      });
      
      return replyWithState(sessionId, `Added character: ${name} (${role})`);
    }
  );

  // Tool: add_frame
  server.registerTool(
    'add_frame',
    {
      title: 'Add Frame',
      description: 'Add a new frame to the storyboard. Returns the frame ID which you can use with set_frame_image after generating an image.',
      inputSchema: addFrameSchema,
      _meta: {
        'openai/outputTemplate': 'ui://widget/keyframe.html',
        'openai/toolInvocation/invoking': 'Adding frame...',
        'openai/toolInvocation/invoked': 'Frame added',
      },
    },
    async (args, extra) => {
      const sessionId = extra?.sessionId ?? 'default';
      const title = args?.title?.trim() ?? '';
      const caption = args?.caption?.trim() ?? '';
      
      if (!title) {
        return replyWithState(sessionId, 'Frame title is required.');
      }
      
      const frame: Frame = {
        id: generateId(),
        title,
        caption,
        imageUrl: '',
        status: 'empty',
      };
      
      const state = getState(sessionId);
      updateState(sessionId, {
        frames: [...state.frames, frame],
      });
      
      return replyWithState(sessionId, `Added frame "${title}" with ID: ${frame.id}. Generate an image and use set_frame_image to attach it.`);
    }
  );

  // Tool: set_frame_image
  // ChatGPT generates the image, then calls this tool to store it
  server.registerTool(
    'set_frame_image',
    {
      title: 'Set Frame Image',
      description: 'Attach a generated image to a frame. Use after generating an image with DALL-E. Pass the frame ID and the image URL.',
      inputSchema: setFrameImageSchema,
      _meta: {
        'openai/outputTemplate': 'ui://widget/keyframe.html',
        'openai/toolInvocation/invoking': 'Attaching image to frame...',
        'openai/toolInvocation/invoked': 'Image attached',
      },
    },
    async (args, extra) => {
      const sessionId = extra?.sessionId ?? 'default';
      const frameId = args?.frameId ?? '';
      const imageUrl = args?.imageUrl ?? '';

      return attachImageToFrame(sessionId, frameId, imageUrl);
    }
  );

  // Tool: set_frame_image_from_base64
  // Use when the model returns raw base64 instead of a URL.
  server.registerTool(
    'set_frame_image_from_base64',
    {
      title: 'Set Frame Image (Base64)',
      description:
        'Attach a generated image to a frame using raw base64 data. Provide frameId, base64 data, and optional mimeType (image/png, image/jpeg, image/webp).',
      inputSchema: setFrameImageBase64Schema,
      _meta: {
        'openai/outputTemplate': 'ui://widget/keyframe.html',
        'openai/toolInvocation/invoking': 'Attaching image to frame...',
        'openai/toolInvocation/invoked': 'Image attached',
      },
    },
    async (args, extra) => {
      const sessionId = extra?.sessionId ?? 'default';
      const frameId = args?.frameId ?? '';
      const imageBase64 = (args?.imageBase64 ?? '').replace(/\s+/g, '');
      const mimeType = (args?.mimeType ?? 'image/png').trim();

      if (!imageBase64) {
        return replyWithState(sessionId, 'Image base64 is required.');
      }

      if (!mimeType.startsWith('image/')) {
        return replyWithState(sessionId, 'mimeType must start with "image/".');
      }

      const imageUrl = `data:${mimeType};base64,${imageBase64}`;
      return attachImageToFrame(sessionId, frameId, imageUrl);
    }
  );

  // Tool: update_frame_caption
  server.registerTool(
    'update_frame_caption',
    {
      title: 'Update Frame Caption',
      description: 'Update the caption text for a frame.',
      inputSchema: updateFrameCaptionSchema,
      _meta: {
        'openai/outputTemplate': 'ui://widget/keyframe.html',
        'openai/toolInvocation/invoking': 'Updating caption...',
        'openai/toolInvocation/invoked': 'Caption updated',
      },
    },
    async (args, extra) => {
      const sessionId = extra?.sessionId ?? 'default';
      const frameId = args?.frameId ?? '';
      const caption = args?.caption ?? '';
      
      const state = getState(sessionId);
      const frameIndex = state.frames.findIndex((f) => f.id === frameId);
      
      if (frameIndex === -1) {
        return replyWithState(sessionId, `Frame with ID "${frameId}" not found.`);
      }
      
      const updatedFrames = [...state.frames];
      updatedFrames[frameIndex] = {
        ...updatedFrames[frameIndex],
        caption,
      };
      updateState(sessionId, { frames: updatedFrames });
      
      return replyWithState(sessionId, `Caption updated for frame: ${updatedFrames[frameIndex].title}`);
    }
  );

  // Tool: get_storyboard_summary
  server.registerTool(
    'get_storyboard_summary',
    {
      title: 'Get Storyboard Summary',
      description: 'Get a text summary of the current storyboard state including style, characters, and frames.',
      inputSchema: {},
      _meta: {
        'openai/outputTemplate': 'ui://widget/keyframe.html',
        'openai/toolInvocation/invoking': 'Getting summary...',
        'openai/toolInvocation/invoked': 'Summary ready',
      },
    },
    async (_args, extra) => {
      const sessionId = extra?.sessionId ?? 'default';
      const state = getState(sessionId);
      
      const styleSummary = state.style.description 
        ? `Style: ${state.style.description}` 
        : 'Style: Not set';
      
      const charSummary = state.characters.length > 0
        ? `Characters (${state.characters.length}):\n${state.characters.map(c => `- ${c.name}: ${c.role}`).join('\n')}`
        : 'Characters: None';
      
      const frameSummary = state.frames.length > 0
        ? `Frames (${state.frames.length}):\n${state.frames.map((f, i) => 
            `${i + 1}. ${f.title} [${f.status}] - ID: ${f.id}`
          ).join('\n')}`
        : 'Frames: None';
      
      const summary = `${styleSummary}\n\n${charSummary}\n\n${frameSummary}`;
      
      return replyWithState(sessionId, summary);
    }
  );

  return server;
}

const port = Number(process.env.PORT ?? 8080);
const MCP_PATH = '/mcp';

const httpServer = createServer(async (req: IncomingMessage, res: ServerResponse) => {
  if (!req.url) {
    res.writeHead(400).end('Missing URL');
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host ?? 'localhost'}`);

  // CORS preflight
  if (req.method === 'OPTIONS' && url.pathname === MCP_PATH) {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
      'Access-Control-Allow-Headers': 'content-type, mcp-session-id',
      'Access-Control-Expose-Headers': 'Mcp-Session-Id',
    });
    res.end();
    return;
  }

  // Health check
  if (req.method === 'GET' && url.pathname === '/') {
    res.writeHead(200, { 'content-type': 'text/plain' }).end('Keyframe MCP server v0.2.0');
    return;
  }

  // MCP endpoint
  const MCP_METHODS = new Set(['POST', 'GET', 'DELETE']);
  if (url.pathname === MCP_PATH && req.method && MCP_METHODS.has(req.method)) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Expose-Headers', 'Mcp-Session-Id');

    const server = createKeyframeServer();
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: undefined, // stateless mode
      enableJsonResponse: true,
    });

    res.on('close', () => {
      transport.close();
      server.close();
    });

    try {
      await server.connect(transport);
      await transport.handleRequest(req, res);
    } catch (error) {
      console.error('Error handling MCP request:', error);
      if (!res.headersSent) {
        res.writeHead(500).end('Internal server error');
      }
    }
    return;
  }

  res.writeHead(404).end('Not Found');
});

httpServer.listen(port, () => {
  console.log(`Keyframe MCP server listening on http://localhost:${port}${MCP_PATH}`);
});
