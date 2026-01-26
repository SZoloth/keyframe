import { createServer, IncomingMessage, ServerResponse } from 'node:http';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { z } from 'zod';
import OpenAI from 'openai';
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

// OpenAI client for image generation
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

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

const generateFrameImageSchema = {
  frameId: z.string().min(1, 'Frame ID is required'),
  sceneDescription: z.string().min(10, 'Scene description must be at least 10 characters'),
};

// Helper to create structured content response
function replyWithState(sessionId: string, message?: string) {
  const state = getState(sessionId);
  return {
    content: message ? [{ type: 'text' as const, text: message }] : [],
    structuredContent: state,
  };
}

function createKeyframeServer() {
  const server = new McpServer({ name: 'keyframe', version: '0.1.0' });

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
      description: 'Set the visual style description for the storyboard. This style will be used for all generated frames.',
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
      description: 'Add a character to the storyboard cast. Characters help maintain visual consistency across frames.',
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
      description: 'Add a new frame to the storyboard. The frame starts empty and can be filled with a generated image.',
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
      
      return replyWithState(sessionId, `Added frame: ${title}`);
    }
  );

  // Tool: generate_frame_image
  server.registerTool(
    'generate_frame_image',
    {
      title: 'Generate Frame Image',
      description: 'Generate an image for a specific frame using AI. Uses the storyboard style and character descriptions for consistency.',
      inputSchema: generateFrameImageSchema,
      _meta: {
        'openai/outputTemplate': 'ui://widget/keyframe.html',
        'openai/toolInvocation/invoking': 'Generating image...',
        'openai/toolInvocation/invoked': 'Image generated',
      },
    },
    async (args, extra) => {
      const sessionId = extra?.sessionId ?? 'default';
      const frameId = args?.frameId ?? '';
      const sceneDescription = args?.sceneDescription?.trim() ?? '';
      
      const state = getState(sessionId);
      const frameIndex = state.frames.findIndex((f) => f.id === frameId);
      
      if (frameIndex === -1) {
        return replyWithState(sessionId, `Frame with ID ${frameId} not found.`);
      }
      
      if (!sceneDescription || sceneDescription.length < 10) {
        return replyWithState(sessionId, 'Scene description must be at least 10 characters.');
      }
      
      // Update frame status to generating
      const updatedFrames = [...state.frames];
      updatedFrames[frameIndex] = { ...updatedFrames[frameIndex], status: 'generating' };
      updateState(sessionId, { frames: updatedFrames });
      
      try {
        // Build prompt with style and characters
        const styleContext = state.style.description 
          ? `Style: ${state.style.description}\n\n` 
          : '';
        
        const characterContext = state.characters.length > 0
          ? `Characters:\n${state.characters.map((c) => 
              `- ${c.name} (${c.role}): ${c.visualDescription}`
            ).join('\n')}\n\n`
          : '';
        
        const prompt = `${styleContext}${characterContext}Scene: ${sceneDescription}

Create a storyboard frame illustration for this scene. The image should be clear, focused, and suitable for a presentation storyboard.`;

        const response = await openai.images.generate({
          model: 'gpt-image-1',
          prompt,
          n: 1,
          size: '1024x1024',
        });
        
        const imageData = response.data?.[0];
        if (!imageData) {
          throw new Error('No image data returned');
        }
        
        const imageUrl = imageData.b64_json 
          ? `data:image/png;base64,${imageData.b64_json}`
          : imageData.url ?? '';
        
        // Update frame with generated image
        const finalFrames = [...getState(sessionId).frames];
        finalFrames[frameIndex] = {
          ...finalFrames[frameIndex],
          imageUrl,
          status: 'complete',
        };
        updateState(sessionId, { frames: finalFrames });
        
        return replyWithState(sessionId, `Generated image for frame: ${finalFrames[frameIndex].title}`);
      } catch (error) {
        // Revert status on error
        const errorFrames = [...getState(sessionId).frames];
        errorFrames[frameIndex] = { ...errorFrames[frameIndex], status: 'empty' };
        updateState(sessionId, { frames: errorFrames });
        
        const message = error instanceof Error ? error.message : 'Unknown error';
        return replyWithState(sessionId, `Failed to generate image: ${message}`);
      }
    }
  );

  return server;
}

const port = Number(process.env.PORT ?? 8787);
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
    res.writeHead(200, { 'content-type': 'text/plain' }).end('Keyframe MCP server');
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
