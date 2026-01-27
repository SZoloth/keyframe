'use client';

import { useEffect } from 'react';
import { useStore } from '@/lib/store';

type CollaborationProviderProps = {
  children: React.ReactNode;
};

export function CollaborationProvider({ children }: CollaborationProviderProps) {
  useEffect(() => {
    const handleStorage = (event: StorageEvent) => {
      if (event.key !== 'keyframe-storage') return;
      useStore.persist.rehydrate();
    };

    window.addEventListener('storage', handleStorage);
    return () => window.removeEventListener('storage', handleStorage);
  }, []);

  return <>{children}</>;
}
