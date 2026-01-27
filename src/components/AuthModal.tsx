'use client';

import { useState } from 'react';
import { supabase, isSupabaseConfigured } from '@/lib/supabase';

type AuthMode = 'sign-in' | 'sign-up';

type AuthModalProps = {
  open: boolean;
  onClose: () => void;
};

const isValidEmail = (email: string) => /\S+@\S+\.\S+/.test(email);

export function AuthModal({ open, onClose }: AuthModalProps) {
  const [mode, setMode] = useState<AuthMode>('sign-in');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  if (!open) return null;

  const handleSubmit = async () => {
    setError(null);

    if (!isValidEmail(email)) {
      setError('Please enter a valid email address.');
      return;
    }

    if (!password.trim()) {
      setError('Please enter a password.');
      return;
    }

    if (!isSupabaseConfigured || !supabase) {
      setError('Supabase is not configured. Add env vars to enable sign in.');
      return;
    }

    setLoading(true);
    try {
      if (mode === 'sign-in') {
        const { error: signInError } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (signInError) throw signInError;
      } else {
        const { error: signUpError } = await supabase.auth.signUp({
          email,
          password,
        });
        if (signUpError) throw signUpError;
      }

      setEmail('');
      setPassword('');
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Authentication failed.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4">
      <div className="w-full max-w-md rounded-lg bg-white p-6 shadow-xl">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h2 className="text-lg font-semibold text-zinc-900">
              {mode === 'sign-in' ? 'Sign in' : 'Create account'}
            </h2>
            <p className="text-sm text-zinc-500">
              {mode === 'sign-in'
                ? 'Use your email and password to sign in.'
                : 'Create an account to save projects to the cloud.'}
            </p>
          </div>
          <button
            onClick={onClose}
            className="min-h-[44px] min-w-[44px] rounded-full text-zinc-500 hover:bg-zinc-100"
            aria-label="Close"
          >
            ✕
          </button>
        </div>

        <div className="mt-4 space-y-3">
          <div>
            <label className="mb-1 block text-xs font-medium text-zinc-600">Email</label>
            <input
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              className="w-full rounded border border-zinc-300 px-3 py-2 text-sm focus:border-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-900/20"
              placeholder="you@example.com"
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-zinc-600">Password</label>
            <input
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              className="w-full rounded border border-zinc-300 px-3 py-2 text-sm focus:border-zinc-900 focus:outline-none focus:ring-2 focus:ring-zinc-900/20"
              placeholder="••••••••"
            />
          </div>

          {error && <p className="text-xs text-red-500">{error}</p>}

          <button
            onClick={handleSubmit}
            disabled={loading}
            className="min-h-[44px] w-full rounded bg-zinc-900 text-sm font-medium text-white hover:bg-zinc-800 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Working...' : mode === 'sign-in' ? 'Sign in' : 'Create account'}
          </button>
        </div>

        <div className="mt-4 flex items-center justify-between text-sm">
          <span className="text-zinc-500">
            {mode === 'sign-in' ? 'No account yet?' : 'Already have an account?'}
          </span>
          <button
            onClick={() => {
              setError(null);
              setMode(mode === 'sign-in' ? 'sign-up' : 'sign-in');
            }}
            className="min-h-[44px] px-2 text-zinc-900 underline"
          >
            {mode === 'sign-in' ? 'Sign up' : 'Sign in'}
          </button>
        </div>
      </div>
    </div>
  );
}
