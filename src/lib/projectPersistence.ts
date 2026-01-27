import type { ProjectState } from './types';
import { useStore } from './store';
import { supabase, isSupabaseConfigured } from './supabase';

export type SerializedProject = {
  version: 1;
  currentPhase: ProjectState['currentPhase'];
  selectedTemplateId: ProjectState['selectedTemplateId'];
  frames: ProjectState['frames'];
  selectedFrameId: ProjectState['selectedFrameId'];
  style: ProjectState['style'];
  characters: ProjectState['characters'];
};

export type CloudProjectSummary = {
  id: string;
  name: string;
  updatedAt: string;
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

export async function saveProject(
  name: string,
  state: ProjectState
): Promise<{ data: CloudProjectSummary | null; error: string | null }> {
  if (!isSupabaseConfigured || !supabase) {
    return { data: null, error: 'Supabase is not configured.' };
  }

  const user = useStore.getState().authUser;
  if (!user) {
    return { data: null, error: 'User is not authenticated.' };
  }

  const payload = {
    user_id: user.id,
    name,
    data: serializeProject(state),
    updated_at: new Date().toISOString(),
  };

  const { data, error } = await supabase
    .from('projects')
    .insert(payload)
    .select('id, name, updated_at')
    .single();

  if (error) {
    return { data: null, error: error.message };
  }

  return {
    data: {
      id: data.id,
      name: data.name,
      updatedAt: data.updated_at,
    },
    error: null,
  };
}

export async function listProjects(): Promise<{
  data: CloudProjectSummary[];
  error: string | null;
}> {
  if (!isSupabaseConfigured || !supabase) {
    return { data: [], error: 'Supabase is not configured.' };
  }

  const user = useStore.getState().authUser;
  if (!user) {
    return { data: [], error: 'User is not authenticated.' };
  }

  const { data, error } = await supabase
    .from('projects')
    .select('id, name, updated_at')
    .eq('user_id', user.id)
    .order('updated_at', { ascending: false });

  if (error) {
    return { data: [], error: error.message };
  }

  return {
    data: data.map((project) => ({
      id: project.id,
      name: project.name,
      updatedAt: project.updated_at,
    })),
    error: null,
  };
}

export async function loadProject(
  projectId: string
): Promise<{ data: SerializedProject | null; error: string | null }> {
  if (!isSupabaseConfigured || !supabase) {
    return { data: null, error: 'Supabase is not configured.' };
  }

  const user = useStore.getState().authUser;
  if (!user) {
    return { data: null, error: 'User is not authenticated.' };
  }

  const { data, error } = await supabase
    .from('projects')
    .select('data')
    .eq('id', projectId)
    .eq('user_id', user.id)
    .single();

  if (error) {
    return { data: null, error: error.message };
  }

  return { data: data.data as SerializedProject, error: null };
}
