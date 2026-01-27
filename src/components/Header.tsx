'use client';

import { useState } from 'react';
import { useStore, useCurrentPhase, useSelectedTemplate, useFrames, useAuthUser } from '@/lib/store';
import { Phase } from '@/lib/types';
import { generatePDF, downloadPDF } from './export/PDFExport';
import { AuthModal } from './AuthModal';
import { supabase, isSupabaseConfigured } from '@/lib/supabase';

const phases: { id: Phase; label: string }[] = [
  { id: 'setup', label: 'Setup' },
  { id: 'style', label: 'Style' },
  { id: 'cast', label: 'Cast' },
  { id: 'frames', label: 'Frames' },
  { id: 'export', label: 'Export' },
];

export function Header() {
  const currentPhase = useCurrentPhase();
  const template = useSelectedTemplate();
  const frames = useFrames();
  const authUser = useAuthUser();
  const canAdvanceToPhase = useStore(state => state.canAdvanceToPhase);
  const setPhase = useStore(state => state.setPhase);
  const clearAuthSession = useStore(state => state.clearAuthSession);
  
  const [exporting, setExporting] = useState(false);
  const [authModalOpen, setAuthModalOpen] = useState(false);
  
  const allFramesComplete = frames.length > 0 && frames.every(f => f.status === 'complete');
  const hasAnyFrames = frames.some(f => f.status === 'complete');
  
  const handleExport = async () => {
    if (!template) return;
    
    setExporting(true);
    try {
      const blob = await generatePDF('Storyboard', template.name, frames);
      downloadPDF(blob, `storyboard-${template.id}.pdf`);
    } catch (err) {
      console.error('Export failed:', err);
      alert('Export failed. Please try again.');
    } finally {
      setExporting(false);
    }
  };
  
  const handlePhaseClick = (phase: Phase) => {
    if (canAdvanceToPhase(phase)) {
      setPhase(phase);
    }
  };

  const handleSignOut = async () => {
    if (!supabase || !isSupabaseConfigured) {
      clearAuthSession();
      return;
    }

    await supabase.auth.signOut();
    clearAuthSession();
  };
  
  return (
    <header className="h-14 border-b border-zinc-200 bg-white flex items-center justify-between px-4">
      {/* Logo */}
      <div className="flex items-center gap-3">
        <h1 className="text-lg font-semibold text-zinc-900">Keyframe</h1>
        {template ? (
          <span className="text-sm text-zinc-500">
            {template.name}
          </span>
        ) : useStore.getState().selectedTemplateId === 'freeform' ? (
          <span className="text-sm text-zinc-500">
            Freeform
          </span>
        ) : null}
      </div>
      
      {/* Phase indicator */}
      <nav className="flex items-center gap-1">
        {phases.map((phase, index) => {
          const isActive = currentPhase === phase.id;
          const isPast = phases.findIndex(p => p.id === currentPhase) > index;
          const isAccessible = canAdvanceToPhase(phase.id);
          
          return (
            <div key={phase.id} className="flex items-center">
              {index > 0 && (
                <div className={`w-6 h-px mx-1 ${isPast ? 'bg-zinc-900' : 'bg-zinc-200'}`} />
              )}
              <button
                onClick={() => handlePhaseClick(phase.id)}
                disabled={!isAccessible}
                className={`
                  text-sm px-2 py-1 rounded transition-colors
                  ${isActive ? 'bg-zinc-900 text-white' : ''}
                  ${isPast && !isActive ? 'text-zinc-900' : ''}
                  ${!isActive && !isPast ? 'text-zinc-400' : ''}
                  ${isAccessible && !isActive ? 'hover:bg-zinc-100 cursor-pointer' : ''}
                  ${!isAccessible ? 'cursor-not-allowed' : ''}
                `}
              >
                {phase.label}
              </button>
            </div>
          );
        })}
      </nav>
      
      {/* Actions */}
      <div className="flex items-center gap-2">
        {authUser ? (
          <>
            <span className="text-sm text-zinc-600 max-w-[180px] truncate">
              {authUser.email}
            </span>
            <button
              onClick={handleSignOut}
              className="px-3 py-1.5 min-h-[44px] text-sm border border-zinc-300 rounded hover:bg-zinc-50"
            >
              Sign out
            </button>
          </>
        ) : (
          <button
            onClick={() => setAuthModalOpen(true)}
            className="px-3 py-1.5 min-h-[44px] text-sm border border-zinc-300 rounded hover:bg-zinc-50"
          >
            Sign in
          </button>
        )}
        <button
          onClick={handleExport}
          disabled={!hasAnyFrames || exporting}
          className="px-3 py-1.5 min-h-[44px] text-sm bg-zinc-900 text-white rounded hover:bg-zinc-800 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {exporting ? 'Exporting...' : 'Export PDF'}
        </button>
      </div>
      <AuthModal open={authModalOpen} onClose={() => setAuthModalOpen(false)} />
    </header>
  );
}
