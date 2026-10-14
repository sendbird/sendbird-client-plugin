import { useSession } from './auth/session';
import { LoginScreen } from './screens/LoginScreen';
import { SignedInApp } from './screens/SignedInApp';

export default function App() {
  const session = useSession();
  if (session.status === 'signed-in') {
    // key: a different user gets a fresh provider and fresh UIKit state.
    return <SignedInApp key={session.userId} userId={session.userId} accessToken={session.accessToken} />;
  }
  return <LoginScreen notice={session.notice} />;
}
