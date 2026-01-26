'use client';

import { useState } from 'react';
import { useStore, useApiKey } from '@/lib/store';
import { templates } from '@/lib/templates';
import OpenAI from 'openai';

export function SetupTab() {
  const apiKey = useApiKey();
  const selectedTemplateId = useStore(state => state.selectedTemplateId);
  const setApiKey = useStore(state => state.setApiKey);
  const selectTemplate = useStore(state => state.selectTemplate);
  const setPhase = useStore(state => state.setPhase);
  
  const [showKeyInput, setShowKeyInput] = useState(false);
  const [keyInput, setKeyInput] = useState('');
  const [validating, setValidating] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const validateApiKey = async () => {
    if (!keyInput.trim()) return;
    
    setValidating(true);
    setError(null);
    
    try {
      const client = new OpenAI({ 
        apiKey: keyInput.trim(),
        dangerouslyAllowBrowser: true,
      });
      
      // Test the key by listing models
      await client.models.list();
      
      setApiKey(keyInput.trim());
      setKeyInput('');
      setShowKeyInput(false);
    } catch (err) {
      setError('Invalid API key. Please check and try again.');
    } finally {
      setValidating(false);
    }
  };
  
  const canProceed = !!apiKey;
  
  const handleProceed = () => {
    if (canProceed) {
      setPhase('style');
    }
  };
  
  return (
    <div className="flex-1 p-4 overflow-auto">
      <h2 className="text-lg font-semibold text-zinc-900 mb-4">Setup</h2>
      
      {/* OpenAI Connection Section */}
      <div className="mb-6">
        <h3 className="text-sm font-medium text-zinc-700 mb-2">Connect OpenAI</h3>
        
        {apiKey ? (
          <div className="p-3 bg-green-50 border border-green-200 rounded-lg">
            <div className="flex items-center gap-2">
              <svg className="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
              </svg>
              <span className="text-sm font-medium text-green-800">OpenAI Connected</span>
            </div>
            <p className="text-xs text-green-700 mt-1">
              API key ending in ...{apiKey.slice(-4)}
            </p>
            <button
              onClick={() => {
                setApiKey('');
                setShowKeyInput(false);
              }}
              className="text-xs text-green-700 hover:text-green-900 mt-2 underline"
            >
              Disconnect
            </button>
          </div>
        ) : showKeyInput ? (
          <div className="space-y-3">
            <div className="p-3 bg-zinc-50 border border-zinc-200 rounded-lg">
              <p className="text-xs text-zinc-600 mb-3">
                Paste your OpenAI API key below. Your key is stored locally and never sent to our servers.
              </p>
              <input
                type="password"
                value={keyInput}
                onChange={(e) => setKeyInput(e.target.value)}
                placeholder="sk-..."
                className="w-full px-3 py-2 border border-zinc-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-zinc-900"
              />
              {error && (
                <p className="text-xs text-red-500 mt-2">{error}</p>
              )}
            </div>
            <div className="flex gap-2">
              <button
                onClick={validateApiKey}
                disabled={!keyInput.trim() || validating}
                className="flex-1 px-3 py-2 bg-zinc-900 text-white rounded text-sm hover:bg-zinc-800 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {validating ? 'Connecting...' : 'Connect'}
              </button>
              <button
                onClick={() => setShowKeyInput(false)}
                className="px-3 py-2 border border-zinc-300 rounded text-sm hover:bg-zinc-50"
              >
                Cancel
              </button>
            </div>
          </div>
        ) : (
          <div className="space-y-3">
            <button
              onClick={() => setShowKeyInput(true)}
              className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-zinc-900 text-white rounded-lg text-sm font-medium hover:bg-zinc-800 transition-colors"
            >
              <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
                <path d="M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.8956zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z"/>
              </svg>
              Connect OpenAI Account
            </button>
            
            <div className="text-center">
              <a
                href="https://platform.openai.com/api-keys"
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs text-zinc-500 hover:text-zinc-700 underline"
              >
                Get your API key from OpenAI →
              </a>
            </div>
            
            <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg">
              <p className="text-xs text-amber-800">
                <strong>Note:</strong> Keyframe uses GPT-4o for style analysis and image generation. 
                Make sure your OpenAI account has API access and sufficient credits.
              </p>
            </div>
          </div>
        )}
      </div>
      
      {/* Template Selection */}
      <div className="mb-6">
        <h3 className="text-sm font-medium text-zinc-700 mb-2">Choose Template (Optional)</h3>
        <p className="text-xs text-zinc-500 mb-3">
          Use a storytelling framework, or skip to create your own structure.
        </p>
        <div className="space-y-2">
          {/* Freeform option */}
          <button
            onClick={() => selectTemplate('freeform')}
            className={`
              w-full text-left p-3 rounded-lg border-2 transition-all
              ${selectedTemplateId === 'freeform' 
                ? 'border-zinc-900 bg-zinc-50' 
                : 'border-zinc-200 hover:border-zinc-400'
              }
            `}
          >
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-zinc-900">
                Freeform
              </span>
              <span className="text-xs text-zinc-500 bg-zinc-100 px-2 py-0.5 rounded">
                Custom
              </span>
            </div>
            <p className="text-xs text-zinc-500 mt-1">
              Create your own frames without a predefined structure.
            </p>
          </button>
          
          {templates.map(template => (
            <button
              key={template.id}
              onClick={() => selectTemplate(template.id)}
              className={`
                w-full text-left p-3 rounded-lg border-2 transition-all
                ${selectedTemplateId === template.id 
                  ? 'border-zinc-900 bg-zinc-50' 
                  : 'border-zinc-200 hover:border-zinc-400'
                }
              `}
            >
              <div className="flex items-center justify-between">
                <span className="text-sm font-medium text-zinc-900">
                  {template.name}
                </span>
                <span className="text-xs text-zinc-500 bg-zinc-100 px-2 py-0.5 rounded">
                  {template.frames.length} frames
                </span>
              </div>
              <p className="text-xs text-zinc-500 mt-1">
                {template.description}
              </p>
            </button>
          ))}
        </div>
      </div>
      
      {/* Proceed Button */}
      <button
        onClick={handleProceed}
        disabled={!apiKey}
        className="w-full px-4 py-3 bg-zinc-900 text-white rounded-lg text-sm font-medium hover:bg-zinc-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        {!apiKey 
          ? 'Connect OpenAI to continue' 
          : 'Continue to Style Definition →'
        }
      </button>
    </div>
  );
}
