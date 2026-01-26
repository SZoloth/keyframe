'use client';

import { Header } from '@/components/Header';
import { CanvasPanel } from '@/components/canvas/CanvasPanel';
import { SidebarPanel } from '@/components/sidebar/SidebarPanel';

export default function Home() {
  return (
    <div className="h-screen flex flex-col bg-white">
      <Header />
      <div className="flex-1 flex overflow-hidden">
        <CanvasPanel />
        <SidebarPanel />
      </div>
    </div>
  );
}
