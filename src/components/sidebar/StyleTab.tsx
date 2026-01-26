'use client';

import { useRef, useState } from 'react';
import { useStore, useStyle, useCurrentPhase, useApiKey } from '@/lib/store';
import OpenAI from 'openai';

export function StyleTab() {
  const apiKey = useApiKey();
  const style = useStyle();
  const currentPhase = useCurrentPhase();
  const addReferenceImage = useStore(state => state.addReferenceImage);
  const removeReferenceImage = useStore(state => state.removeReferenceImage);
  const setStyleDescription = useStore(state => state.setStyleDescription);
  const lockStyle = useStore(state => state.lockStyle);
  
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [analyzing, setAnalyzing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files) return;
    
    Array.from(files).forEach(file => {
      if (style.referenceImages.length >= 3) return;
      
      const reader = new FileReader();
      reader.onload = () => {
        const base64 = reader.result as string;
        addReferenceImage(base64);
      };
      reader.readAsDataURL(file);
    });
    
    // Reset input
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };
  
  const analyzeStyle = async () => {
    if (!apiKey || style.referenceImages.length === 0) return;
    
    setAnalyzing(true);
    setError(null);
    
    try {
      const client = new OpenAI({ 
        apiKey,
        dangerouslyAllowBrowser: true,
      });
      
      const imageContents = style.referenceImages.map(img => ({
        type: 'image_url' as const,
        image_url: { url: img },
      }));
      
      const response = await client.chat.completions.create({
        model: 'gpt-4o',
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: `Analyze these reference images and describe the visual style in detail. Focus on:
- Line quality (bold, sketchy, clean, rough)
- Shading technique (cross-hatching, gradients, flat)
- Color palette (if any) or monochrome approach
- Level of detail and abstraction
- Overall mood and aesthetic

Provide a concise but complete style description that could be used to generate consistent images in this style. Write it as a direct instruction, e.g., "Hand-drawn pencil sketch style with bold outlines..."`,
              },
              ...imageContents,
            ],
          },
        ],
        max_tokens: 500,
      });
      
      const description = response.choices[0]?.message?.content || '';
      setStyleDescription(description);
    } catch (err) {
      setError('Failed to analyze style. Please try again.');
      console.error(err);
    } finally {
      setAnalyzing(false);
    }
  };
  
  const canLock = style.referenceImages.length > 0 && style.description.length > 0;
  
  if (style.locked) {
    return (
      <div className="flex-1 p-4 overflow-auto">
        <div className="flex items-center gap-2 mb-4">
          <span className="text-green-600">✓</span>
          <h3 className="text-sm font-medium text-zinc-700">Style Locked</h3>
        </div>
        
        {/* Thumbnails */}
        <div className="flex gap-2 mb-4">
          {style.referenceImages.map((img, i) => (
            <img 
              key={i} 
              src={img} 
              alt={`Reference ${i + 1}`}
              className="w-16 h-16 object-cover rounded border border-zinc-200"
            />
          ))}
        </div>
        
        {/* Description */}
        <div className="p-3 bg-zinc-50 rounded text-sm text-zinc-700">
          {style.description}
        </div>
      </div>
    );
  }
  
  return (
    <div className="flex-1 flex flex-col">
      <div className="flex-1 p-4 overflow-auto">
        <h3 className="text-sm font-medium text-zinc-700 mb-4">Define Your Style</h3>
        
        {/* Upload section */}
        <div className="mb-4">
          <p className="text-xs text-zinc-500 mb-2">
            Upload 1-3 reference sketches to establish your visual style.
          </p>
          
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            multiple
            onChange={handleFileSelect}
            className="hidden"
          />
          
          <div className="flex gap-2 mb-3">
            {style.referenceImages.map((img, i) => (
              <div key={i} className="relative">
                <img 
                  src={img} 
                  alt={`Reference ${i + 1}`}
                  className="w-20 h-20 object-cover rounded border border-zinc-200"
                />
                <button
                  onClick={() => removeReferenceImage(i)}
                  className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white rounded-full text-xs flex items-center justify-center hover:bg-red-600"
                >
                  ×
                </button>
              </div>
            ))}
            
            {style.referenceImages.length < 3 && (
              <button
                onClick={() => fileInputRef.current?.click()}
                className="w-20 h-20 border-2 border-dashed border-zinc-300 rounded flex items-center justify-center text-zinc-400 hover:border-zinc-400 hover:text-zinc-500"
              >
                +
              </button>
            )}
          </div>
        </div>
        
        {/* Analyze button */}
        {style.referenceImages.length > 0 && !style.description && (
          <button
            onClick={analyzeStyle}
            disabled={analyzing}
            className="w-full px-3 py-2 bg-zinc-900 text-white rounded text-sm hover:bg-zinc-800 disabled:opacity-50 mb-4"
          >
            {analyzing ? 'Analyzing...' : 'Analyze Style'}
          </button>
        )}
        
        {error && (
          <p className="text-xs text-red-500 mb-4">{error}</p>
        )}
        
        {/* Style description */}
        {style.description && (
          <div className="mb-4">
            <label className="block text-xs font-medium text-zinc-600 mb-1">
              Style Description
            </label>
            <textarea
              value={style.description}
              onChange={(e) => setStyleDescription(e.target.value)}
              rows={6}
              className="w-full px-3 py-2 border border-zinc-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900 resize-none"
            />
            <p className="text-xs text-zinc-500 mt-1">
              Edit if needed. This will be used for all generated frames.
            </p>
          </div>
        )}
      </div>
      
      {/* Lock button */}
      {currentPhase === 'style' && (
        <div className="p-4 border-t border-zinc-200">
          <button
            onClick={lockStyle}
            disabled={!canLock}
            className="w-full px-4 py-3 bg-zinc-900 text-white rounded text-sm font-medium hover:bg-zinc-800 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Lock Style & Continue →
          </button>
        </div>
      )}
    </div>
  );
}
