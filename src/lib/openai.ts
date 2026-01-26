import OpenAI from 'openai';
import { Character, StyleDefinition, StoryboardFrame } from './types';

// Client-side OpenAI client factory
export function createOpenAIClient(apiKey: string): OpenAI {
  return new OpenAI({
    apiKey,
    dangerouslyAllowBrowser: true,
  });
}

// Generate scene suggestion based on beat and context
export async function suggestScene(
  client: OpenAI,
  beatTitle: string,
  beatGuidance: string,
  style: StyleDefinition,
  characters: Character[],
  previousFrames: StoryboardFrame[]
): Promise<string> {
  const characterList = characters
    .map(c => `- ${c.name} (${c.role}): ${c.visualDescription}`)
    .join('\n');
  
  const previousContext = previousFrames
    .filter(f => f.sceneDescription)
    .map((f, i) => `Frame ${i + 1} "${f.beatTitle}": ${f.sceneDescription}`)
    .join('\n');
  
  const response = await client.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      {
        role: 'system',
        content: `You are a storyboard scene director. Your job is to suggest vivid, specific scene descriptions that will be turned into illustrations.

Style context:
${style.description}

Cast of characters:
${characterList}

Guidelines:
- Be specific about character positions, expressions, and actions
- Include environmental details that support the story beat
- Keep descriptions concise but visually rich
- Don't describe camera angles or technical film terminology
- Focus on what we SEE, not what we think or feel`,
      },
      {
        role: 'user',
        content: `Create a scene description for this storyboard beat:

Beat: "${beatTitle}"
Guidance: ${beatGuidance}

${previousContext ? `Previous frames for context:\n${previousContext}` : 'This is the first frame.'}

Describe the scene in 2-3 sentences. Be specific and visual.`,
      },
    ],
    max_tokens: 300,
  });
  
  return response.choices[0]?.message?.content || '';
}

// Generate image for a scene
export async function generateFrameImage(
  client: OpenAI,
  sceneDescription: string,
  style: StyleDefinition,
  characters: Character[]
): Promise<string> {
  const characterList = characters
    .map(c => `${c.name}: ${c.visualDescription}`)
    .join('. ');
  
  const prompt = `${style.description}

Scene: ${sceneDescription}

Characters in scene: ${characterList}

Create a storyboard illustration matching the style description exactly. The image should clearly depict the described scene with consistent character appearances.`;

  const response = await client.images.generate({
    model: 'gpt-image-1', // GPT-4o image generation
    prompt,
    n: 1,
    size: '1024x1024',
  });
  
  // Return the URL or base64
  const imageData = response.data?.[0];
  if (!imageData) {
    throw new Error('No image data returned from API');
  }
  if (imageData.b64_json) {
    return `data:image/png;base64,${imageData.b64_json}`;
  }
  return imageData.url || '';
}

// Refine scene based on user feedback
export async function refineScene(
  client: OpenAI,
  currentScene: string,
  userFeedback: string,
  style: StyleDefinition,
  characters: Character[]
): Promise<string> {
  const response = await client.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      {
        role: 'system',
        content: `You are a storyboard scene director. Refine the scene description based on the user's feedback while maintaining consistency with the established style and characters.`,
      },
      {
        role: 'user',
        content: `Current scene description:
${currentScene}

User feedback:
${userFeedback}

Provide an updated scene description that incorporates the feedback. Keep it to 2-3 sentences.`,
      },
    ],
    max_tokens: 300,
  });
  
  return response.choices[0]?.message?.content || currentScene;
}
