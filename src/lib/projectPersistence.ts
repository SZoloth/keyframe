import type { ProjectState } from './types';
import { useStore } from './store';

export type SerializedProject = {
  version: 1;
  currentPhase: ProjectState['currentPhase'];
  selectedTemplateId: ProjectState['selectedTemplateId'];
  frames: ProjectState['frames'];
  selectedFrameId: ProjectState['selectedFrameId'];
  style: ProjectState['style'];
  characters: ProjectState['characters'];
};

export function serializeProject(state: ProjectState): SerializedProject {
  return {
    version: 1,
    currentPhase: state.currentPhase,
    selectedTemplateId: state.selectedTemplateId,
    frames: state.frames,
    selectedFrameId: state.selectedFrameId,
    style: state.style,
    characters: state.characters,
  };
}

export function hydrateProject(serialized: SerializedProject): void {
  const apiKey = useStore.getState().apiKey;

  useStore.setState({
    apiKey,
    currentPhase: serialized.currentPhase,
    selectedTemplateId: serialized.selectedTemplateId,
    frames: serialized.frames,
    selectedFrameId: serialized.selectedFrameId,
    style: serialized.style,
    characters: serialized.characters,
  });
}
