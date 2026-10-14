// BP16: one app-wide session. The sign-in screen, a deep link, or a test all call signIn/signOut
// here, and every screen reads the state through useSession(), so a sign-in from any path
// re-renders the app. The connect itself runs in SessionBridge, inside the UIKit container.
import { useSyncExternalStore } from 'react';
import { fetchSessionToken } from './token';

export type Connection = 'connected' | 'reconnecting' | 'offline';

export type SessionState =
  | { status: 'signed-out'; notice?: string }
  | { status: 'connecting'; userId: string; accessToken?: string }
  | { status: 'signed-in'; userId: string; connection: Connection };

let state: SessionState = { status: 'signed-out' };
const listeners = new Set<() => void>();

function setState(next: SessionState) {
  state = next;
  listeners.forEach((listener) => listener());
}

export function getSession(): SessionState {
  return state;
}

export function useSession(): SessionState {
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },
    getSession,
  );
}

// Sign-out work that needs the UIKit container (unregister push, disconnect); see SessionBridge.
type SignOutWork = () => Promise<void>;
let signOutWork: SignOutWork | null = null;

export function setSignOutWork(work: SignOutWork): () => void {
  signOutWork = work;
  return () => {
    if (signOutWork === work) signOutWork = null;
  };
}

/** BP03: called once the app's own sign-in succeeded; SessionBridge then connects as this user. */
export async function signIn(userId: string): Promise<void> {
  const id = userId.trim();
  if (!id) throw new Error('Enter a user ID.');
  if (state.status !== 'signed-out' && 'userId' in state && state.userId === id) return;
  if (state.status !== 'signed-out') await signOut();
  const accessToken = await fetchSessionToken(id);
  setState({ status: 'connecting', userId: id, accessToken });
}

export async function signOut(notice?: string): Promise<void> {
  const work = signOutWork;
  try {
    if (work && state.status !== 'signed-out') await work();
  } finally {
    setState({ status: 'signed-out', notice });
  }
}

export function markConnected(userId: string, connection: Connection) {
  if (state.status === 'connecting' && state.userId === userId) setState({ status: 'signed-in', userId, connection });
}

export function markConnectFailed(userId: string, notice: string) {
  if (state.status === 'connecting' && state.userId === userId) setState({ status: 'signed-out', notice });
}

export function setConnection(connection: Connection) {
  if (state.status === 'signed-in') setState({ ...state, connection });
}
