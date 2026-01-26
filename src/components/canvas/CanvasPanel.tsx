'use client';

import { useState } from 'react';
import { useFrames, useStore, useCurrentPhase } from '@/lib/store';

export function CanvasPanel() {
  const frames = useFrames();
  const currentPhase = useCurrentPhase();
  const selectedFrameId = useStore(state => state.selectedFrameId);
  const selectedTemplateId = useStore(state => state.selectedTemplateId);
  const selectFrame = useStore(state => state.selectFrame);
  const updateFrame = useStore(state => state.updateFrame);
  const addFrame = useStore(state => state.addFrame);
  const removeFrame = useStore(state => state.removeFrame);
  const reorderFrames = useStore(state => state.reorderFrames);
  
  const [editingCaptionId, setEditingCaptionId] = useState<string | null>(null);
  const [captionInput, setCaptionInput] = useState('');
  
  // Drag and drop state
  const [draggedIndex, setDraggedIndex] = useState<number | null>(null);
  const [dropTargetIndex, setDropTargetIndex] = useState<number | null>(null);
  
  const isFreeform = selectedTemplateId === 'freeform';
  const canEditFrames = isFreeform && currentPhase === 'frames';
  
  if (frames.length === 0 && currentPhase === 'setup') {
    return (
      <div className="flex-1 bg-zinc-50 flex items-center justify-center">
        <p className="text-zinc-400">Connect OpenAI to begin</p>
      </div>
    );
  }
  
  if (frames.length === 0) {
    return (
      <div className="flex-1 bg-zinc-50 flex flex-col items-center justify-center gap-4">
        <p className="text-zinc-400">No frames yet</p>
        {canEditFrames && (
          <button
            onClick={addFrame}
            className="px-4 py-2 bg-zinc-900 text-white rounded text-sm hover:bg-zinc-800"
          >
            Add First Frame
          </button>
        )}
      </div>
    );
  }
  
  const handleCaptionClick = (frameId: string, currentCaption: string) => {
    setEditingCaptionId(frameId);
    setCaptionInput(currentCaption);
  };
  
  const handleCaptionSave = (frameId: string) => {
    updateFrame(frameId, { caption: captionInput });
    setEditingCaptionId(null);
  };
  
  const handleCaptionKeyDown = (e: React.KeyboardEvent, frameId: string) => {
    if (e.key === 'Enter') {
      handleCaptionSave(frameId);
    } else if (e.key === 'Escape') {
      setEditingCaptionId(null);
    }
  };
  
  // Drag handlers
  const handleDragStart = (e: React.DragEvent, index: number) => {
    setDraggedIndex(index);
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', index.toString());
  };
  
  const handleDragOver = (e: React.DragEvent, index: number) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    if (dropTargetIndex !== index) {
      setDropTargetIndex(index);
    }
  };
  
  const handleDragLeave = () => {
    setDropTargetIndex(null);
  };
  
  const handleDrop = (e: React.DragEvent, toIndex: number) => {
    e.preventDefault();
    if (draggedIndex !== null && draggedIndex !== toIndex) {
      reorderFrames(draggedIndex, toIndex);
    }
    setDraggedIndex(null);
    setDropTargetIndex(null);
  };
  
  const handleDragEnd = () => {
    setDraggedIndex(null);
    setDropTargetIndex(null);
  };
  
  return (
    <div className="flex-1 bg-zinc-50 p-8 overflow-auto">
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-6 max-w-4xl mx-auto">
        {frames.map((frame, index) => (
          <div 
            key={frame.id} 
            className={`flex flex-col group transition-opacity ${
              draggedIndex === index ? 'opacity-50' : 'opacity-100'
            }`}
            draggable
            onDragStart={(e) => handleDragStart(e, index)}
            onDragOver={(e) => handleDragOver(e, index)}
            onDragLeave={handleDragLeave}
            onDrop={(e) => handleDrop(e, index)}
            onDragEnd={handleDragEnd}
          >
            <div className="relative">
              <button
                onClick={() => selectFrame(frame.id)}
                className={`
                  w-full aspect-[4/3] rounded-lg border-2 transition-all
                  flex flex-col items-center justify-center p-4 overflow-hidden
                  ${selectedFrameId === frame.id 
                    ? 'border-zinc-900 bg-white shadow-lg' 
                    : 'border-zinc-200 bg-white hover:border-zinc-400'
                  }
                  ${frame.status === 'complete' ? 'ring-2 ring-green-500 ring-offset-2' : ''}
                  ${dropTargetIndex === index && draggedIndex !== index 
                    ? 'border-blue-500 border-2' 
                    : ''
                  }
                `}
              >
                {frame.imageUrl ? (
                  <img 
                    src={frame.imageUrl} 
                    alt={frame.caption}
                    className="w-full h-full object-cover rounded"
                  />
                ) : (
                  <>
                    <span className="text-2xl font-bold text-zinc-300 mb-2">
                      {index + 1}
                    </span>
                    <span className="text-sm text-zinc-500 text-center">
                      {frame.beatTitle}
                    </span>
                    {frame.status === 'generating' && (
                      <span className="mt-2 text-xs text-blue-500 animate-pulse">
                        Generating...
                      </span>
                    )}
                  </>
                )}
              </button>
              
              {/* Delete button for freeform mode */}
              {canEditFrames && frames.length > 1 && (
                <button
                  onClick={() => removeFrame(frame.id)}
                  className="absolute -top-2 -right-2 w-6 h-6 bg-red-500 text-white rounded-full text-xs opacity-0 group-hover:opacity-100 transition-opacity hover:bg-red-600 flex items-center justify-center"
                  title="Remove frame"
                >
                  ×
                </button>
              )}
            </div>
            
            {/* Caption */}
            <div className="mt-2">
              {editingCaptionId === frame.id ? (
                <input
                  type="text"
                  value={captionInput}
                  onChange={(e) => setCaptionInput(e.target.value)}
                  onBlur={() => handleCaptionSave(frame.id)}
                  onKeyDown={(e) => handleCaptionKeyDown(e, frame.id)}
                  autoFocus
                  className="w-full px-2 py-1 text-xs border border-zinc-300 rounded focus:outline-none focus:ring-2 focus:ring-zinc-900"
                />
              ) : (
                <button
                  onClick={() => handleCaptionClick(frame.id, frame.caption)}
                  className="w-full text-left px-2 py-1 text-xs text-zinc-600 hover:bg-zinc-100 rounded truncate"
                  title="Click to edit caption"
                >
                  {index + 1}. {frame.caption}
                </button>
              )}
            </div>
          </div>
        ))}
        
        {/* Add frame button for freeform mode */}
        {canEditFrames && (
          <button
            onClick={addFrame}
            className="aspect-[4/3] rounded-lg border-2 border-dashed border-zinc-300 bg-white hover:border-zinc-400 hover:bg-zinc-50 transition-all flex flex-col items-center justify-center"
          >
            <span className="text-2xl text-zinc-400 mb-1">+</span>
            <span className="text-xs text-zinc-500">Add Frame</span>
          </button>
        )}
      </div>
    </div>
  );
}
