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
        <p>Signed in as <b>{signedIn}</b> <button onClick={signOut}>Sign out</button></p>
      ) : (
        <p>
          <input id="user" placeholder="User ID" value={userId} onChange={(e) => setUserId(e.target.value)} />{' '}
          <button disabled={!userId} onClick={signIn}>Sign in</button>
        </p>
      )}
      {error && <p style={{ color: '#b42318' }}>{error}</p>}
    </main>
  );
}
