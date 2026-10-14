// The app's own sign-in calls these. Sendbird connects after onLoginSucceeded and disconnects in
// onLogout; both go through the one app-wide session in ./session.ts.
import { signIn, signOut } from './session';

export async function onLoginSucceeded(userId: string): Promise<void> {
  await signIn(userId);
}

export async function onLogout(): Promise<void> {
  await signOut();
}
