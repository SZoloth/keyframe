// ============================================================
// Core Types for Keyframe
// ============================================================

export type Phase = 'setup' | 'style' | 'cast' | 'frames' | 'export';

export interface Character {
  id: string;
  name: string;
  role: string;
  visualDescription: string;
  referenceImage?: string; // base64
}

export interface FrameBeat {
  id: string;
  title: string;
  guidance: string;
}

export interface Template {
  id: string;
  name: string;
  description: string;
  frames: FrameBeat[];
}

export interface StoryboardFrame {
  id: string;
  beatId: string;
  beatTitle: string;
  caption: string;
  sceneDescription?: string;
  imageUrl?: string; // base64 or URL
  status: 'empty' | 'generating' | 'complete';
}

export interface StyleDefinition {
  referenceImages: string[]; // base64 encoded
  description: string;
  locked: boolean;
}

export interface ProjectState {
  // Auth
  apiKey: string | null;
  
  // Project
  currentPhase: Phase;
  selectedTemplateId: string | null;
  frames: StoryboardFrame[];
  selectedFrameId: string | null;
  customTemplates: Template[];
  
  // Style
  style: StyleDefinition;
  
  // Cast
  characters: Character[];
}

export interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
  uiComponent?: GenerativeUIComponent;
}

export type GenerativeUIComponent = 
  | { type: 'multipleChoice'; options: string[]; selected?: string }
  | { type: 'multiSelect'; options: string[]; selected?: string[] }
  | { type: 'textInput'; placeholder: string; value?: string }
  | { type: 'confirm'; message: string; confirmed?: boolean }
  | { type: 'imagePreview'; imageUrl: string; accepted?: boolean };
