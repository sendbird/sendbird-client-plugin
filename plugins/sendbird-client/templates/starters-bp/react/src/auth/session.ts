// BP16: one app-wide session. The sign-in screen, a deep link, or a test all call signIn/signOut
// here, and every screen reads the state through useSession(), so a sign-in from any path
// re-renders the app.
import { useSyncExternalStore } from 'react';
import { fetchSessionToken } from './token';

export type SessionState =
  | { status: 'signed-out'; notice?: string }
  | { status: 'signed-in'; userId: string; accessToken?: string };

let state: SessionState = { status: 'signed-out' };
const listeners = new Set<() => void>();

function setState(next: SessionState) {
  state = next;
  listeners.forEach((listener) => listener());
}

export function getSession(): SessionState {
  return state;
}

export function subscribeSession(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function useSession(): SessionState {
  return useSyncExternalStore(subscribeSession, getSession);
}

// Sign-out work that needs the connected SDK instance (see SessionBridge in SignedInApp.tsx).
type SignOutWork = () => Promise<void>;
let signOutWork: SignOutWork | null = null;

export function setSignOutWork(work: SignOutWork): () => void {
  signOutWork = work;
  return () => {
    if (signOutWork === work) signOutWork = null;
  };
}

// BP03: connect only after the app's own sign-in succeeded. Rendering the signed-in tree mounts
// SendbirdProvider, which connects with this user ID (and token, when your server issues one).
export async function signIn(userId: string): Promise<void> {
  const id = userId.trim();
  if (!id) throw new Error('Enter a user ID.');
  if (state.status === 'signed-in' && state.userId === id) return;
  if (state.status === 'signed-in') await signOut();
  const accessToken = await fetchSessionToken(id);
  setState({ status: 'signed-in', userId: id, accessToken });
}

export async function signOut(notice?: string): Promise<void> {
  const work = signOutWork;
  try {
    if (work) await work();
  } finally {
    setState({ status: 'signed-out', notice });
  }
}
