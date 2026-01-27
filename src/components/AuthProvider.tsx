'use client';

import { useEffect } from 'react';
import type { ReactNode } from 'react';
import { supabase, isSupabaseConfigured } from '@/lib/supabase';
import { useStore } from '@/lib/store';

type AuthProviderProps = {
  children: ReactNode;
};

export function AuthProvider({ children }: AuthProviderProps) {
  const setAuthSession = useStore(state => state.setAuthSession);
  const clearAuthSession = useStore(state => state.clearAuthSession);

  useEffect(() => {
    if (!isSupabaseConfigured || !supabase) {
      clearAuthSession();
      return;
    }

    let mounted = true;

    supabase.auth.getSession().then(({ data }) => {
      if (!mounted) return;
      if (data.session) {
        setAuthSession(data.session);
      } else {
        clearAuthSession();
      }
    });

    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) {
        setAuthSession(session);
      } else {
        clearAuthSession();
      }
    });

    return () => {
      mounted = false;
      data.subscription.unsubscribe();
    };
  }, [setAuthSession, clearAuthSession]);

  return <>{children}</>;
}
