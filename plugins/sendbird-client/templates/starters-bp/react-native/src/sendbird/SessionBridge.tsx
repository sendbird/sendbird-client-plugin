// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/hooks/useConnection.ts#L29-L104
// source: knowledge/curated/js/products/auth.md ("Token refresh — SessionHandler (set before connect)")
// source: knowledge/curated/js/products/chat.md ("Connection state and reconnection")
// source: knowledge/curated/js/cross-cutting/push.md ("Logout: unregister this device before disconnecting")
//
// Connects and disconnects through UIKit, inside SendbirdUIKitContainer, following the session.
import { useEffect } from 'react';
import { ConnectionHandler, ConnectionState, SessionHandler } from '@sendbird/chat';
import { useConnection, useSendbirdChat } from '@sendbird/uikit-react-native';
import { getSession, markConnectFailed, markConnected, setConnection, setSignOutWork, signOut, useSession } from '../auth/session';
import { fetchSessionToken } from '../auth/token';
import { describeError } from './errors';

/** BP04: the token refresh hook, set on the instance before UIKit connects (chatOptions.onInitialized). */
export function createSessionHandler(): SessionHandler {
  const handler = new SessionHandler();
  handler.onSessionTokenRequired = (resolve, reject) => {
    const current = getSession();
    if (current.status === 'signed-out') return resolve(null);
    fetchSessionToken(current.userId).then((token) => resolve(token ?? null), reject);
  };
  handler.onSessionClosed = () => {
    void signOut('Your session ended. Sign in again.');
  };
  return handler;
}

const CONNECTION_HANDLER_ID = 'starter-connection';

export function SessionBridge() {
  const session = useSession();
  const { connect, disconnect } = useConnection();
  const { sdk } = useSendbirdChat();
  const connectingUserId = session.status === 'connecting' ? session.userId : null;
  const accessToken = session.status === 'connecting' ? session.accessToken : undefined;
  const signedIn = session.status === 'signed-in';

  // BP03 / BP05: connect through UIKit once the app's own sign-in succeeded. UIKit's connect also
  // registers this device's push token for the user (BP10).
  useEffect(() => {
    if (!connectingUserId) return undefined;
    let cancelled = false;
    connect(connectingUserId, { accessToken })
      .then(() => {
        if (cancelled) return;
        markConnected(connectingUserId, sdk.connectionState === ConnectionState.OPEN ? 'connected' : 'reconnecting');
      })
      .catch((error: unknown) => {
        if (!cancelled) markConnectFailed(connectingUserId, describeError(error, accessToken !== undefined).text); // BP13
      });
    return () => {
      cancelled = true;
    };
  }, [connectingUserId, accessToken, connect, sdk]);

  // BP09: UIKit's disconnect unregisters this device's push token first, then disconnects.
  useEffect(() => setSignOutWork(() => disconnect()), [disconnect]);

  // BP07 / BP08: one connection handler while signed in, removed on sign-out.
  useEffect(() => {
    if (!signedIn) return undefined;
    sdk.addConnectionHandler(
      CONNECTION_HANDLER_ID,
      new ConnectionHandler({
        onConnected: () => setConnection('connected'),
        onReconnectStarted: () => setConnection('reconnecting'),
        onReconnectSucceeded: () => setConnection('connected'),
        onReconnectFailed: () => setConnection('offline'),
      }),
    );
    return () => sdk.removeConnectionHandler(CONNECTION_HANDLER_ID);
  }, [sdk, signedIn]);

  return null;
}
