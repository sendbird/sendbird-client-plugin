// source: knowledge/curated/js/products/uikit.md ("Compose your own UI: channel list + conversation", "After a reconnect")
// source: knowledge/curated/js/products/auth.md ("Token refresh — SessionHandler (set before connect)")
// source: knowledge/curated/js/cross-cutting/push.md ("Logout: unregister this device before disconnecting")
// source: knowledge/curated/js/hosts/react.md ("Integration notes")
// source: knowledge/curated/js/products/chat.md ("Connection state and reconnection")
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/hooks/useConnectionState.ts#L8-L31
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/GroupChannelList/context/GroupChannelListProvider.tsx#L141-L146
// source: knowledge/curated/js/cross-cutting/troubleshooting.md ("selecting a channel always opens the first one")
//
// Everything below SendbirdProvider: it initializes the Chat SDK once (it reuses the cached
// instance), connects with the signed-in user, and hosts the UIKit channel list and conversation.
import { useEffect, useMemo, useState } from 'react';
import { ConnectionHandler, ConnectionState, SessionHandler } from '@sendbird/chat';
import { SendbirdProvider, type SendbirdProviderProps } from '@sendbird/uikit-react/SendbirdProvider';
import { GroupChannelList } from '@sendbird/uikit-react/GroupChannelList';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import useSendbirdStateContext from '@sendbird/uikit-react/useSendbirdStateContext';
import '@sendbird/uikit-react/dist/index.css';
import { setSignOutWork, signOut } from '../auth/session';
import { fetchSessionToken } from '../auth/token';
import { SENDBIRD_APP_ID } from '../sendbird/config';
import { describeError, type ErrorView } from '../sendbird/errors';
import { SDK_INIT_PARAMS, UIKIT_BREAKPOINT, UIKIT_COLOR_SET, UIKIT_THEME } from '../sendbird/uikit';

export function SignedInApp({ userId, accessToken }: { userId: string; accessToken?: string }) {
  const [connectError, setConnectError] = useState<ErrorView | null>(null);

  // BP04: the token refresh hook. SendbirdProvider sets this handler before it connects.
  const configureSession = useMemo<NonNullable<SendbirdProviderProps['configureSession']>>(
    () => () => {
      const handler = new SessionHandler();
      handler.onSessionTokenRequired = (resolve, reject) => {
        fetchSessionToken(userId).then((token) => resolve(token ?? null), reject);
      };
      handler.onSessionClosed = () => {
        void signOut('Your session ended. Sign in again.');
      };
      return handler;
    },
    [userId],
  );

  // BP13: a failed connect shows its code; token errors send the user back to sign-in.
  const eventHandlers = useMemo<SendbirdProviderProps['eventHandlers']>(
    () => ({
      connection: {
        onConnected: () => setConnectError(null),
        onFailed: (error) => {
          const view = describeError(error, accessToken !== undefined);
          if (view.signInAgain) void signOut(view.text);
          else setConnectError(view);
        },
      },
    }),
    [accessToken],
  );

  // BP01 / BP03 / BP05: one provider at the root of the signed-in tree; it connects as this user.
  return (
    <SendbirdProvider
      appId={SENDBIRD_APP_ID}
      userId={userId}
      accessToken={accessToken}
      configureSession={configureSession}
      sdkInitParams={SDK_INIT_PARAMS}
      theme={UIKIT_THEME}
      colorSet={UIKIT_COLOR_SET}
      breakpoint={UIKIT_BREAKPOINT}
      eventHandlers={eventHandlers}
    >
      <SignOutBridge />
      <Home userId={userId} connectError={connectError} />
    </SendbirdProvider>
  );
}

// BP09: sign-out work that needs the connected instance. Unregister this device's push token first,
// then disconnect. A browser app holds no FCM or APNs token (browser web push is a separate
// service-worker setup), so it only disconnects. disconnect() also clears this user's local cache.
function SignOutBridge() {
  const { stores } = useSendbirdStateContext();
  const { sdk, initialized } = stores.sdkStore;
  useEffect(() => {
    if (!initialized) return undefined;
    return setSignOutWork(async () => {
      await sdk.disconnect();
    });
  }, [sdk, initialized]);
  return null;
}

// BP07 / BP08: one connection handler on the provider's instance, added when the instance is ready
// and removed on unmount or sign-out. The SDK reconnects by itself; the handler only drives the
// status line. UIKit's useConnectionState() takes sdk.connectionState only on its first render
// (src/hooks/useConnectionState.ts at v3.19.1), before the provider has its instance, so the
// starter reads the state from the instance when it arrives.
const CONNECTION_HANDLER_ID = 'starter-connection-status';

function useConnection(): ConnectionState {
  const { stores } = useSendbirdStateContext();
  const { sdk, initialized } = stores.sdkStore;
  const [state, setState] = useState<ConnectionState>(ConnectionState.CLOSED);
  useEffect(() => {
    if (!initialized) return undefined;
    setState(sdk.connectionState);
    sdk.addConnectionHandler(
      CONNECTION_HANDLER_ID,
      new ConnectionHandler({
        onConnected: () => setState(ConnectionState.OPEN),
        onReconnectStarted: () => setState(ConnectionState.CONNECTING),
        onReconnectSucceeded: () => setState(ConnectionState.OPEN),
        onReconnectFailed: () => setState(ConnectionState.CLOSED),
        onDisconnected: () => setState(ConnectionState.CLOSED),
      }),
    );
    return () => sdk.removeConnectionHandler(CONNECTION_HANDLER_ID);
  }, [sdk, initialized]);
  return state;
}

// True below UIKIT_BREAKPOINT, where the screen shows one pane at a time.
function useNarrowScreen(): boolean {
  const query = `(max-width: ${UIKIT_BREAKPOINT})`;
  const [narrow, setNarrow] = useState(() => window.matchMedia(query).matches);
  useEffect(() => {
    const mq = window.matchMedia(query);
    const update = () => setNarrow(mq.matches);
    update();
    mq.addEventListener('change', update);
    return () => mq.removeEventListener('change', update);
  }, [query]);
  return narrow;
}

function Home({ userId, connectError }: { userId: string; connectError: ErrorView | null }) {
  const connectionState = useConnection();
  const [connectedOnce, setConnectedOnce] = useState(false);
  const [channelUrl, setChannelUrl] = useState<string | null>(null);
  const narrow = useNarrowScreen();

  useEffect(() => {
    if (connectionState === ConnectionState.OPEN) setConnectedOnce(true);
  }, [connectionState]);

  return (
    <div className="app">
      <header className="bar">
        <span>
          Signed in as <b>{userId}</b>
        </span>
        <ConnectionStatus state={connectionState} error={connectError} />
        <button type="button" data-testid="sb_logout_button" onClick={() => void signOut()}>
          Sign out
        </button>
      </header>
      {/* BP06: the UIKit screens mount after the first successful connect; with the local cache
          they keep working while the SDK reconnects. */}
      {connectedOnce ? (
        <div className={channelUrl ? 'panes has-channel' : 'panes'}>
          <section className="list" data-testid="sb_channel_list">
            {/* On a phone the list opens first: auto-selecting the newest channel would hide it
                right after sign-in and again after every back tap. */}
            <GroupChannelList
              selectedChannelUrl={channelUrl ?? undefined}
              disableAutoSelect={narrow}
              onChannelSelect={(channel) => setChannelUrl(channel?.url ?? null)}
              onChannelCreated={(channel) => setChannelUrl(channel.url)}
            />
          </section>
          <section className="conversation">
            {channelUrl ? (
              <GroupChannel channelUrl={channelUrl} onBackClick={() => setChannelUrl(null)} />
            ) : (
              <p className="empty">Nothing selected.</p>
            )}
          </section>
        </div>
      ) : (
        <p className="waiting">Waiting for the connection…</p>
      )}
    </div>
  );
}

function ConnectionStatus({ state, error }: { state: ConnectionState; error: ErrorView | null }) {
  const text = error
    ? error.text
    : state === ConnectionState.OPEN
      ? 'Connected'
      : state === ConnectionState.CONNECTING
        ? 'Connecting…'
        : 'Offline';
  return (
    <span className="status" role="status" data-testid="sb_connection_status" data-state={state}>
      {text}
    </span>
  );
}
