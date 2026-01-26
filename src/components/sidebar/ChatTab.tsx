'use client';

import { useState, useEffect, useRef } from 'react';
import { 
  useSelectedFrame, 
  useCurrentPhase, 
  useStore, 
  useApiKey,
  useStyle,
  useCharacters 
} from '@/lib/store';
import { getTemplateById } from '@/lib/templates';
import { createOpenAIClient, suggestScene, generateFrameImage, refineScene } from '@/lib/openai';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  imageUrl?: string;
}

export function ChatTab() {
  const selectedFrame = useSelectedFrame();
  const currentPhase = useCurrentPhase();
  const apiKey = useApiKey();
  const style = useStyle();
  const characters = useCharacters();
  const frames = useStore(state => state.frames);
  const selectedTemplateId = useStore(state => state.selectedTemplateId);
  const updateFrame = useStore(state => state.updateFrame);
  
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [currentScene, setCurrentScene] = useState('');
  const [generatedImage, setGeneratedImage] = useState<string | null>(null);
  
  const messagesEndRef = useRef<HTMLDivElement>(null);
  
  // Scroll to bottom when messages change
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);
  
  // Reset chat when frame changes
  useEffect(() => {
    if (selectedFrame) {
      setMessages([]);
      setCurrentScene(selectedFrame.sceneDescription || '');
      setGeneratedImage(selectedFrame.imageUrl || null);
    }
  }, [selectedFrame?.id]);
  
  if (currentPhase === 'style') {
    return (
      <div className="flex-1 p-4 flex items-center justify-center">
        <p className="text-sm text-zinc-500 text-center">
          Complete the Style tab first to begin chatting about frames.
        </p>
      </div>
    );
  }
  
  if (currentPhase === 'cast') {
    return (
      <div className="flex-1 p-4 flex items-center justify-center">
        <p className="text-sm text-zinc-500 text-center">
          Add at least one character in the Cast tab to continue.
        </p>
      </div>
    );
  }
  
  if (!selectedFrame) {
    return (
      <div className="flex-1 p-4 flex items-center justify-center">
        <p className="text-sm text-zinc-500 text-center">
          Select a frame on the canvas to start generating.
        </p>
      </div>
    );
  }
  
  const isFreeform = selectedTemplateId === 'freeform';
  const template = selectedTemplateId && !isFreeform ? getTemplateById(selectedTemplateId) : null;
  const beat = template?.frames.find(f => f.id === selectedFrame.beatId);
  const previousFrames = frames.slice(0, frames.findIndex(f => f.id === selectedFrame.id));
  
  const addMessage = (role: 'user' | 'assistant', content: string, imageUrl?: string) => {
    setMessages(prev => [...prev, {
      id: `msg-${Date.now()}`,
      role,
      content,
      imageUrl,
    }]);
  };
  
  const handleSuggestScene = async () => {
    if (!apiKey) return;
    
    setLoading(true);
    addMessage('assistant', 'Let me suggest a scene...');
    
    try {
      const client = createOpenAIClient(apiKey);
      const beatTitle = beat?.title || selectedFrame.beatTitle;
      const beatGuidance = beat?.guidance || 'Create an engaging scene that fits the storyboard narrative.';
      
      const suggestion = await suggestScene(
        client,
        beatTitle,
        beatGuidance,
        style,
        characters,
        previousFrames
      );
      
      setCurrentScene(suggestion);
      setMessages(prev => prev.slice(0, -1)); // Remove "thinking" message
      addMessage('assistant', `Here's my suggestion:\n\n"${suggestion}"\n\nDoes this work, or would you like to refine it?`);
    } catch (err) {
      console.error(err);
      setMessages(prev => prev.slice(0, -1));
      addMessage('assistant', 'Sorry, I had trouble generating a suggestion. Please try again.');
    } finally {
      setLoading(false);
    }
  };
  
  const handleGenerateImage = async () => {
    if (!apiKey || !currentScene) return;
    
    setLoading(true);
    updateFrame(selectedFrame.id, { status: 'generating' });
    addMessage('assistant', 'Generating image... This may take a moment.');
    
    try {
      const client = createOpenAIClient(apiKey);
      const imageUrl = await generateFrameImage(client, currentScene, style, characters);
      
      setGeneratedImage(imageUrl);
      setMessages(prev => prev.slice(0, -1));
      addMessage('assistant', 'Here\'s the generated image. Accept it to add to your storyboard, or try again for a variation.', imageUrl);
    } catch (err) {
      console.error(err);
      setMessages(prev => prev.slice(0, -1));
      addMessage('assistant', 'Sorry, image generation failed. Please try again.');
      updateFrame(selectedFrame.id, { status: 'empty' });
    } finally {
      setLoading(false);
    }
  };
  
  const handleAcceptImage = () => {
    if (generatedImage) {
      updateFrame(selectedFrame.id, {
        imageUrl: generatedImage,
        sceneDescription: currentScene,
        status: 'complete',
      });
      addMessage('assistant', 'Image added to your storyboard. Select another frame to continue, or export when ready.');
    }
  };
  
  const handleSend = async () => {
    if (!input.trim() || !apiKey) return;
    
    const userMessage = input.trim();
    setInput('');
    addMessage('user', userMessage);
    
    // If we have a current scene, treat this as a refinement
    if (currentScene) {
      setLoading(true);
      addMessage('assistant', 'Refining the scene...');
      
      try {
        const client = createOpenAIClient(apiKey);
        const refined = await refineScene(client, currentScene, userMessage, style, characters);
        
        setCurrentScene(refined);
        setMessages(prev => prev.slice(0, -1));
        addMessage('assistant', `Updated scene:\n\n"${refined}"\n\nReady to generate, or want to refine further?`);
      } catch (err) {
        console.error(err);
        setMessages(prev => prev.slice(0, -1));
        addMessage('assistant', 'Sorry, I had trouble refining. Please try again.');
      } finally {
        setLoading(false);
      }
    } else {
      // Treat as initial scene description
      setCurrentScene(userMessage);
      addMessage('assistant', `Got it. I'll use this as the scene description:\n\n"${userMessage}"\n\nReady to generate the image?`);
    }
  };
  
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };
  
  return (
    <div className="flex-1 flex flex-col">
      {/* Frame context */}
      <div className="p-4 border-b border-zinc-100 bg-zinc-50">
        <div className="text-xs text-zinc-500 mb-1">Currently editing</div>
        <div className="text-sm font-medium text-zinc-900">
          {selectedFrame.beatTitle}
        </div>
        {beat ? (
          <p className="text-xs text-zinc-500 mt-1">{beat.guidance}</p>
        ) : isFreeform ? (
          <p className="text-xs text-zinc-500 mt-1">Describe the scene you want to create.</p>
        ) : null}
      </div>
      
      {/* Chat messages */}
      <div className="flex-1 p-4 overflow-auto">
        <div className="space-y-4">
          {messages.length === 0 && (
            <div className="text-center py-8">
              <p className="text-sm text-zinc-500 mb-4">
                Let's create the "{selectedFrame.beatTitle}" frame.
              </p>
              <button
                onClick={handleSuggestScene}
                disabled={loading}
                className="px-4 py-2 bg-zinc-900 text-white rounded text-sm hover:bg-zinc-800 disabled:opacity-50"
              >
                Suggest a Scene
              </button>
              <p className="text-xs text-zinc-400 mt-2">
                Or describe the scene yourself below
              </p>
            </div>
          )}
          
          {messages.map(msg => (
            <div
              key={msg.id}
              className={`${msg.role === 'user' ? 'ml-8' : 'mr-8'}`}
            >
              <div
                className={`rounded-lg p-3 ${
                  msg.role === 'user'
                    ? 'bg-zinc-900 text-white'
                    : 'bg-zinc-100 text-zinc-700'
                }`}
              >
                <p className="text-sm whitespace-pre-wrap">{msg.content}</p>
                {msg.imageUrl && (
                  <img
                    src={msg.imageUrl}
                    alt="Generated frame"
                    className="mt-3 rounded-lg w-full"
                  />
                )}
              </div>
            </div>
          ))}
          
          <div ref={messagesEndRef} />
        </div>
      </div>
      
      {/* Action buttons */}
      {currentScene && !generatedImage && (
        <div className="px-4 py-2 border-t border-zinc-100 flex gap-2">
          <button
            onClick={handleGenerateImage}
            disabled={loading}
            className="flex-1 px-4 py-2 bg-zinc-900 text-white rounded text-sm hover:bg-zinc-800 disabled:opacity-50"
          >
            {loading ? 'Generating...' : 'Generate Image'}
          </button>
        </div>
      )}
      
      {generatedImage && selectedFrame.status !== 'complete' && (
        <div className="px-4 py-2 border-t border-zinc-100 flex gap-2">
          <button
            onClick={handleAcceptImage}
            className="flex-1 px-4 py-2 bg-green-600 text-white rounded text-sm hover:bg-green-700"
          >
            Accept
          </button>
          <button
            onClick={handleGenerateImage}
            disabled={loading}
            className="flex-1 px-4 py-2 border border-zinc-300 rounded text-sm hover:bg-zinc-50 disabled:opacity-50"
          >
            Try Again
          </button>
        </div>
      )}
      
      {/* Input */}
      <div className="p-4 border-t border-zinc-200">
        <div className="flex gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={currentScene ? "Refine the scene..." : "Describe the scene..."}
            disabled={loading}
            className="flex-1 px-3 py-2 border border-zinc-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900 disabled:opacity-50"
          />
          <button
            onClick={handleSend}
            disabled={loading || !input.trim()}
            className="px-4 py-2 bg-zinc-900 text-white rounded text-sm hover:bg-zinc-800 disabled:opacity-50"
          >
            Send
          </button>
        </div>
      </div>
    </div>
  );
}
