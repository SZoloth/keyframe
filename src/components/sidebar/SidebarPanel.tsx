'use client';

import { useState } from 'react';
import { useCurrentPhase } from '@/lib/store';
import { ChatTab } from './ChatTab';
import { CastTab } from './CastTab';
import { StyleTab } from './StyleTab';
import { SetupTab } from './SetupTab';

type TabId = 'chat' | 'cast' | 'style';

export function SidebarPanel() {
  const currentPhase = useCurrentPhase();
  const [activeTab, setActiveTab] = useState<TabId>('chat');
  
  // During setup phase, show setup content instead of tabs
  if (currentPhase === 'setup') {
    return (
      <div className="w-96 border-l border-zinc-200 bg-white flex flex-col">
        <SetupTab />
      </div>
    );
  }
  
  const tabs: { id: TabId; label: string }[] = [
    { id: 'chat', label: 'Chat' },
    { id: 'cast', label: 'Cast' },
    { id: 'style', label: 'Style' },
  ];
  
  return (
    <div className="w-96 border-l border-zinc-200 bg-white flex flex-col">
      {/* Tab navigation */}
      <div className="flex border-b border-zinc-200">
        {tabs.map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`
              flex-1 px-4 py-3 text-sm font-medium transition-colors
              ${activeTab === tab.id 
                ? 'text-zinc-900 border-b-2 border-zinc-900' 
                : 'text-zinc-500 hover:text-zinc-700'
              }
            `}
          >
            {tab.label}
          </button>
        ))}
      </div>
      
      {/* Tab content */}
      <div className="flex-1 overflow-hidden">
        {activeTab === 'chat' && <ChatTab />}
        {activeTab === 'cast' && <CastTab />}
        {activeTab === 'style' && <StyleTab />}
      </div>
    </div>
  );
}
