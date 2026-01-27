import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { Session, User } from '@supabase/supabase-js';
import { 
  Phase, 
  Character, 
  StoryboardFrame, 
  StyleDefinition,
  ProjectState 
} from './types';
import { getTemplateById } from './templates';

interface KeyframeStore extends ProjectState {
  // Undo/redo state
  history: ProjectState[];
  future: ProjectState[];
  undo: () => void;
  redo: () => void;

  // Cloud auth state
  authSession: Session | null;
  authUser: User | null;
  setAuthSession: (session: Session | null) => void;
  clearAuthSession: () => void;

  // Auth actions
  setApiKey: (key: string) => void;
  clearApiKey: () => void;
  
  // Phase actions
  setPhase: (phase: Phase) => void;
  canAdvanceToPhase: (phase: Phase) => boolean;
  
  // Template actions
  selectTemplate: (templateId: string) => void;
  
  // Frame actions
  selectFrame: (frameId: string | null) => void;
  updateFrame: (frameId: string, updates: Partial<StoryboardFrame>) => void;
  addFrame: () => void;
  removeFrame: (frameId: string) => void;
  reorderFrames: (fromIndex: number, toIndex: number) => void;
  
  // Style actions
  addReferenceImage: (base64: string) => void;
  removeReferenceImage: (index: number) => void;
  setStyleDescription: (description: string) => void;
  lockStyle: () => void;
  
  // Cast actions
  addCharacter: (character: Omit<Character, 'id'>) => void;
  updateCharacter: (id: string, updates: Partial<Character>) => void;
  removeCharacter: (id: string) => void;
  
  // Project actions
  resetProject: () => void;
}

const MAX_HISTORY = 50;

const snapshotProjectState = (state: ProjectState): ProjectState => ({
  apiKey: state.apiKey,
  currentPhase: state.currentPhase,
  selectedTemplateId: state.selectedTemplateId,
  frames: state.frames.map(frame => ({ ...frame })),
  selectedFrameId: state.selectedFrameId,
  style: {
    ...state.style,
    referenceImages: [...state.style.referenceImages],
  },
  characters: state.characters.map(character => ({ ...character })),
});

const initialState: ProjectState = {
  apiKey: null,
  currentPhase: 'setup',
  selectedTemplateId: null,
  frames: [],
  selectedFrameId: null,
  style: {
    referenceImages: [],
    description: '',
    locked: false,
  },
  characters: [],
};

export const useStore = create<KeyframeStore>()(
  persist(
    (set, get) => ({
      ...initialState,

      // Undo/redo state
      history: [],
      future: [],
      undo: () => set(state => {
        if (state.history.length === 0) return state;
        const previous = state.history[state.history.length - 1];
        const history = state.history.slice(0, -1);
        const future = [
          snapshotProjectState(state),
          ...state.future,
        ].slice(0, MAX_HISTORY);
        return {
          ...previous,
          history,
          future,
        };
      }),
      redo: () => set(state => {
        if (state.future.length === 0) return state;
        const next = state.future[0];
        const future = state.future.slice(1);
        const history = [
          ...state.history,
          snapshotProjectState(state),
        ].slice(-MAX_HISTORY);
        return {
          ...next,
          history,
          future,
        };
      }),

      // Cloud auth state
      authSession: null,
      authUser: null,
      setAuthSession: (session) => set({ 
        authSession: session,
        authUser: session?.user ?? null,
      }),
      clearAuthSession: () => set({ authSession: null, authUser: null }),
      
      // Auth actions
      setApiKey: (key) => set({ apiKey: key }),
      clearApiKey: () => set({ apiKey: null }),
      
      // Phase actions
      setPhase: (phase) => set({ currentPhase: phase }),
      
      canAdvanceToPhase: (phase) => {
        const state = get();
        switch (phase) {
          case 'setup':
            return true;
          case 'style':
            return !!state.apiKey;
          case 'cast':
            return state.style.locked;
          case 'frames':
            return state.characters.length > 0;
          case 'export':
            return state.frames.some(f => f.status === 'complete');
          default:
            return false;
        }
      },
      
      // Template actions
      selectTemplate: (templateId) => {
        // Handle freeform mode
        if (templateId === 'freeform') {
          const initialFrame: StoryboardFrame = {
            id: `frame-${Date.now()}`,
            beatId: 'custom',
            beatTitle: 'Frame 1',
            caption: 'Frame 1',
            status: 'empty',
          };
          set({ 
            selectedTemplateId: 'freeform', 
            frames: [initialFrame],
            selectedFrameId: initialFrame.id,
          });
          return;
        }
        
        const template = getTemplateById(templateId);
        if (!template) return;
        
        const frames: StoryboardFrame[] = template.frames.map(beat => ({
          id: `frame-${beat.id}`,
          beatId: beat.id,
          beatTitle: beat.title,
          caption: beat.title, // Default caption is beat title
          status: 'empty',
        }));
        
        set({ 
          selectedTemplateId: templateId, 
          frames,
          selectedFrameId: frames[0]?.id || null,
        });
      },
      
      // Frame actions
      selectFrame: (frameId) => set({ selectedFrameId: frameId }),
      
      updateFrame: (frameId, updates) => set(state => ({
        frames: state.frames.map(f => 
          f.id === frameId ? { ...f, ...updates } : f
        ),
      })),
      
      addFrame: () => set(state => {
        const newIndex = state.frames.length + 1;
        const newFrame: StoryboardFrame = {
          id: `frame-${Date.now()}`,
          beatId: 'custom',
          beatTitle: `Frame ${newIndex}`,
          caption: `Frame ${newIndex}`,
          status: 'empty',
        };
        return {
          frames: [...state.frames, newFrame],
          selectedFrameId: newFrame.id,
        };
      }),
      
      removeFrame: (frameId) => set(state => {
        const newFrames = state.frames.filter(f => f.id !== frameId);
        return {
          frames: newFrames,
          selectedFrameId: state.selectedFrameId === frameId 
            ? newFrames[0]?.id || null 
            : state.selectedFrameId,
        };
      }),
      
      reorderFrames: (fromIndex, toIndex) => set(state => {
        if (fromIndex === toIndex) return state;
        const frames = [...state.frames];
        const [movedFrame] = frames.splice(fromIndex, 1);
        frames.splice(toIndex, 0, movedFrame);
        return { frames };
      }),
      
      // Style actions
      addReferenceImage: (base64) => set(state => ({
        style: {
          ...state.style,
          referenceImages: [...state.style.referenceImages, base64].slice(0, 3),
        },
      })),
      
      removeReferenceImage: (index) => set(state => ({
        style: {
          ...state.style,
          referenceImages: state.style.referenceImages.filter((_, i) => i !== index),
        },
      })),
      
      setStyleDescription: (description) => set(state => ({
        style: { ...state.style, description },
      })),
      
      lockStyle: () => set(state => ({
        style: { ...state.style, locked: true },
        currentPhase: 'cast',
      })),
      
      // Cast actions
      addCharacter: (character) => set(state => ({
        characters: [
          ...state.characters,
          { ...character, id: `char-${Date.now()}` },
        ],
      })),
      
      updateCharacter: (id, updates) => set(state => ({
        characters: state.characters.map(c => 
          c.id === id ? { ...c, ...updates } : c
        ),
      })),
      
      removeCharacter: (id) => set(state => ({
        characters: state.characters.filter(c => c.id !== id),
      })),
      
      // Project actions
      resetProject: () => set(initialState),
    }),
    {
      name: 'keyframe-storage',
      partialize: (state) => ({
        apiKey: state.apiKey,
        currentPhase: state.currentPhase,
        selectedTemplateId: state.selectedTemplateId,
        frames: state.frames,
        style: state.style,
        characters: state.characters,
      }),
    }
  )
);

// Selectors
export const useApiKey = () => useStore(state => state.apiKey);
export const useCurrentPhase = () => useStore(state => state.currentPhase);
export const useSelectedTemplate = () => {
  const templateId = useStore(state => state.selectedTemplateId);
  return templateId ? getTemplateById(templateId) : undefined;
};
export const useFrames = () => useStore(state => state.frames);
export const useSelectedFrame = () => {
  const frames = useStore(state => state.frames);
  const selectedId = useStore(state => state.selectedFrameId);
  return frames.find(f => f.id === selectedId);
};
export const useStyle = () => useStore(state => state.style);
export const useCharacters = () => useStore(state => state.characters);
export const useAuthSession = () => useStore(state => state.authSession);
export const useAuthUser = () => useStore(state => state.authUser);
export const useCanUndo = () => useStore(state => state.history.length > 0);
export const useCanRedo = () => useStore(state => state.future.length > 0);
