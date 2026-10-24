import { useState } from 'react';
import { onLoginSucceeded, onLogout } from './auth/login';

// A sign-in form to start from. Add the app's screens below it.
export default function App() {
  const [userId, setUserId] = useState('');
  const [signedIn, setSignedIn] = useState<string | null>(null);
  const [error, setError] = useState('');

  const signIn = async () => {
    setError('');
    try { await onLoginSucceeded(userId); setSignedIn(userId); }
    catch (e) { setError(e instanceof Error ? e.message : String(e)); }
  };
  const signOut = async () => { await onLogout(); setSignedIn(null); };

  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', maxWidth: 480, margin: '48px auto', padding: '0 16px' }}>
      {signedIn ? (
        <p>Signed in as <b>{signedIn}</b> <button data-testid="sb_logout_button" onClick={signOut}>Sign out</button></p>
      ) : (
        // A form, so Enter signs in; the test ids are the stable identifiers in
        // templates/starters-bp/BEST_PRACTICES.md, which the run check looks for first.
        <form onSubmit={(e) => { e.preventDefault(); void signIn(); }}>
          <input id="user" data-testid="sb_login_user_id" autoComplete="username" placeholder="User ID" value={userId} onChange={(e) => setUserId(e.target.value)} />{' '}
          <button type="submit" data-testid="sb_login_button" disabled={!userId}>Sign in</button>
        </form>
      )}
      {error && <p style={{ color: '#b42318' }}>{error}</p>}
    </main>
  );
}
