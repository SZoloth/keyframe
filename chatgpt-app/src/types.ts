// Core types for Keyframe ChatGPT app

export interface Character {
  id: string;
  name: string;
  role: string;
  visualDescription: string;
}

export interface Frame {
  id: string;
  title: string;
  caption: string;
  imageUrl: string;
  status: 'empty' | 'generating' | 'complete';
}

export interface StyleDefinition {
  description: string;
  locked: boolean;
}

export interface ProjectState {
  style: StyleDefinition;
  characters: Character[];
  frames: Frame[];
  [key: string]: unknown;
}

export function createEmptyState(): ProjectState {
  return {
    style: {
      description: '',
      locked: false,
    },
    characters: [],
    frames: [],
  };
}
