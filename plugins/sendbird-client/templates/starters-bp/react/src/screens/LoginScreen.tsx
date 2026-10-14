import { useState, type FormEvent } from 'react';
import { onLoginSucceeded } from '../auth/login';
import { SENDBIRD_APP_ID } from '../sendbird/config';

// Sign-in screen. Replace the user ID field with your own sign-in; call onLoginSucceeded(userId)
// once it succeeds.
export function LoginScreen({ notice }: { notice?: string }) {
  const [userId, setUserId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const appIdMissing = SENDBIRD_APP_ID === '';

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      await onLoginSucceeded(userId);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="login">
      <h1>Sign in</h1>
      {appIdMissing && (
        <p className="alert" role="alert" data-testid="sb_app_id_missing">
          No App ID configured. Set VITE_SENDBIRD_APP_ID in .env.local (see .env.example) and restart.
        </p>
      )}
      {notice && <p className="alert" role="status">{notice}</p>}
      <form onSubmit={submit}>
        <label htmlFor="user">User ID</label>
        <input
          id="user"
          data-testid="sb_login_user_id"
          autoComplete="username"
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
        />
        <button type="submit" data-testid="sb_login_button" disabled={appIdMissing || busy || userId.trim() === ''}>
          Sign in
        </button>
      </form>
      {error && <p className="alert" role="alert">{error}</p>}
    </main>
  );
}
