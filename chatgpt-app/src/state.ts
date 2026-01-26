// Session-based state management for Keyframe ChatGPT app

import { ProjectState, createEmptyState } from './types.js';

// In-memory store keyed by session ID
const sessions = new Map<string, ProjectState>();

export function getState(sessionId: string): ProjectState {
  if (!sessions.has(sessionId)) {
    sessions.set(sessionId, createEmptyState());
  }
  return sessions.get(sessionId)!;
}

export function updateState(
  sessionId: string,
  updates: Partial<ProjectState>
): ProjectState {
  const current = getState(sessionId);
  const updated = { ...current, ...updates };
  sessions.set(sessionId, updated);
  return updated;
}

export function resetState(sessionId: string): ProjectState {
  const fresh = createEmptyState();
  sessions.set(sessionId, fresh);
  return fresh;
}

// Helper to generate unique IDs
export function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}
