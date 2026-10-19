// source: https://sendbird.com/docs/chat/uikit/v3/react-native/essentials/authentication (useConnection().connect(userId, { nickname, accessToken }))
// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/hooks/useConnection.ts#L10-L36 (ConnectOptions.accessToken passed to sdk.connect)
// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/containers/SendbirdUIKitContainer.tsx#L87-L91 (chatOptions.onInitialized, called right after SendbirdChat.init at lines 296-314)
// source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication (SessionHandler, setSessionHandler before connect)
// source: knowledge/curated/js/products/uikit.md ("Session tokens: `connect(userId, { accessToken })` and `onInitialized`")
// Type-checked by tools/templates/compile-check-js.sh against the pinned and latest packages.
//
// Session tokens for UIKit React Native. SendbirdUIKitContainer initializes the Chat SDK but does
// not connect: set the token refresh handler in chatOptions.onInitialized, then connect with the
// token your server issued, from a component inside the container. Tokens are secrets: fetch them
// from your server, never hard-code or log them.
//
//   <SendbirdUIKitContainer
//     appId={APP_ID}
//     chatOptions={{ localCacheStorage: mmkv, onInitialized: withSessionHandler(sessionOptions) }}
//     platformServices={platformServices}
//   >
import { SessionHandler } from '@sendbird/chat';
import { useConnection, type SendbirdUIKitContainerProps } from '@sendbird/uikit-react-native';

type OnInitialized = NonNullable<SendbirdUIKitContainerProps['chatOptions']['onInitialized']>;

// The container calls onInitialized only when it creates the SDK instance (on mount and when appId
// changes), so the handler keeps these functions for the life of the instance, across sign-in and
// sign-out. Make each one read the current state at call time (your auth store, a module variable,
// or a ref you update on render), never a React state value captured when App rendered: a
// captured `() => user?.id` stays null after sign-in and the first renewal gives up the session.
export type SessionOptions = {
  /** The user your app signed in, or null after sign-out. Read at call time. */
  getUserId: () => string | null;
  /** Asks your server for a new token for this user; called when the current one expired or was revoked. */
  fetchToken: (userId: string) => Promise<string>;
  /** The session cannot be renewed: send the user back to your sign-in screen. */
  onSessionClosed: () => void;
};

export function createSessionHandler({ getUserId, fetchToken, onSessionClosed }: SessionOptions): SessionHandler {
  const handler = new SessionHandler();
  handler.onSessionTokenRequired = (resolve, reject) => {
    const userId = getUserId();
    if (!userId) return resolve(null); // signed out: give up the session
    fetchToken(userId).then(resolve, reject);
  };
  handler.onSessionClosed = onSessionClosed;
  return handler;
}

/** For chatOptions.onInitialized: sets the handler on the new instance before any connect. */
export function withSessionHandler(options: SessionOptions): OnInitialized {
  return (sdk) => {
    sdk.setSessionHandler(createSessionHandler(options));
    return sdk;
  };
}

/** Use inside SendbirdUIKitContainer. signIn after your own sign-in returned the user ID and a token. */
export function useSendbirdSession() {
  const { connect, disconnect } = useConnection();
  return {
    signIn: (userId: string, accessToken: string) => connect(userId, { accessToken }),
    // With automatic push token registration on (the default), UIKit's disconnect unregisters this
    // device's push token first, then disconnects (useConnection.ts lines 91-101 at the tag above).
    signOut: () => disconnect(),
  };
}
