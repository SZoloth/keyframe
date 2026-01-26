'use client';

import { useState } from 'react';
import { useStore, useCharacters, useCurrentPhase } from '@/lib/store';
import { Character } from '@/lib/types';

interface CharacterFormProps {
  character?: Character;
  onSave: (data: Omit<Character, 'id'>) => void;
  onCancel: () => void;
}

function CharacterForm({ character, onSave, onCancel }: CharacterFormProps) {
  const [name, setName] = useState(character?.name || '');
  const [role, setRole] = useState(character?.role || '');
  const [visualDescription, setVisualDescription] = useState(character?.visualDescription || '');
  
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !role.trim() || !visualDescription.trim()) return;
    
    onSave({ name, role, visualDescription });
  };
  
  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      <div>
        <label className="block text-xs font-medium text-zinc-600 mb-1">Name</label>
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="e.g., Sarah"
          className="w-full px-3 py-2 border border-zinc-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900"
        />
      </div>
      <div>
        <label className="block text-xs font-medium text-zinc-600 mb-1">Role</label>
        <input
          type="text"
          value={role}
          onChange={(e) => setRole(e.target.value)}
          placeholder="e.g., Restaurant manager"
          className="w-full px-3 py-2 border border-zinc-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900"
        />
      </div>
      <div>
        <label className="block text-xs font-medium text-zinc-600 mb-1">Visual Description</label>
        <textarea
          value={visualDescription}
          onChange={(e) => setVisualDescription(e.target.value)}
          placeholder="e.g., 32-year-old woman with dark hair, wearing a polo shirt and apron"
          rows={3}
          className="w-full px-3 py-2 border border-zinc-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900 resize-none"
        />
      </div>
      <div className="flex gap-2">
        <button
          type="submit"
          disabled={!name.trim() || !role.trim() || !visualDescription.trim()}
          className="flex-1 px-3 py-2 bg-zinc-900 text-white rounded text-sm hover:bg-zinc-800 disabled:opacity-50"
        >
          {character ? 'Update' : 'Add Character'}
        </button>
        <button
          type="button"
          onClick={onCancel}
          className="px-3 py-2 border border-zinc-300 rounded text-sm hover:bg-zinc-50"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}

export function CastTab() {
  const characters = useCharacters();
  const currentPhase = useCurrentPhase();
  const addCharacter = useStore(state => state.addCharacter);
  const updateCharacter = useStore(state => state.updateCharacter);
  const removeCharacter = useStore(state => state.removeCharacter);
  const setPhase = useStore(state => state.setPhase);
  
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  
  const handleAdd = (data: Omit<Character, 'id'>) => {
    addCharacter(data);
    setShowForm(false);
  };
  
  const handleEdit = (data: Omit<Character, 'id'>) => {
    if (editingId) {
      updateCharacter(editingId, data);
      setEditingId(null);
    }
  };
  
  const handleProceed = () => {
    if (characters.length > 0) {
      setPhase('frames');
    }
  };
  
  const editingCharacter = editingId ? characters.find(c => c.id === editingId) : undefined;
  
  return (
    <div className="flex-1 flex flex-col">
      <div className="flex-1 p-4 overflow-auto">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-medium text-zinc-700">Cast of Characters</h3>
          {!showForm && !editingId && (
            <button
              onClick={() => setShowForm(true)}
              className="text-xs text-zinc-600 hover:text-zinc-900"
            >
              + Add Character
            </button>
          )}
        </div>
        
        {/* Form */}
        {(showForm || editingId) && (
          <div className="mb-4 p-3 bg-zinc-50 rounded-lg">
            <CharacterForm
              character={editingCharacter}
              onSave={editingId ? handleEdit : handleAdd}
              onCancel={() => {
                setShowForm(false);
                setEditingId(null);
              }}
            />
          </div>
        )}
        
        {/* Character list */}
        {characters.length === 0 && !showForm ? (
          <div className="text-center py-8">
            <p className="text-sm text-zinc-500 mb-3">
              No characters yet. Add your first character to maintain consistency across frames.
            </p>
            <button
              onClick={() => setShowForm(true)}
              className="px-4 py-2 bg-zinc-900 text-white rounded text-sm hover:bg-zinc-800"
            >
              Add Character
            </button>
          </div>
        ) : (
          <div className="space-y-2">
            {characters.map(char => (
              <div 
                key={char.id}
                className="p-3 border border-zinc-200 rounded-lg"
              >
                <div className="flex items-start justify-between">
                  <div>
                    <div className="text-sm font-medium text-zinc-900">{char.name}</div>
                    <div className="text-xs text-zinc-500">{char.role}</div>
                  </div>
                  <div className="flex gap-1">
                    <button
                      onClick={() => setEditingId(char.id)}
                      className="text-xs text-zinc-500 hover:text-zinc-700"
                    >
                      Edit
                    </button>
                    <button
                      onClick={() => removeCharacter(char.id)}
                      className="text-xs text-red-500 hover:text-red-700"
                    >
                      Delete
                    </button>
                  </div>
                </div>
                <p className="text-xs text-zinc-600 mt-2">{char.visualDescription}</p>
              </div>
            ))}
          </div>
        )}
      </div>
      
      {/* Proceed button */}
      {currentPhase === 'cast' && characters.length > 0 && (
        <div className="p-4 border-t border-zinc-200">
          <button
            onClick={handleProceed}
            className="w-full px-4 py-3 bg-zinc-900 text-white rounded text-sm font-medium hover:bg-zinc-800"
          >
            Continue to Frame Generation →
          </button>
        </div>
      )}
    </div>
  );
}
