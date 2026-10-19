// source: https://sendbird.com/docs/chat/uikit/v3/react/essentials/handlers ("Session handlers": configureSession + accessToken on SendbirdProvider)
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/lib/Sendbird/types.ts#L47 (ConfigureSessionTypes; SendbirdProviderProps accessToken/configureSession at lines 205, 208)
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/lib/Sendbird/context/hooks/useSendbird.tsx#L234-L241 (setSessionHandler before sdk.connect(userId, accessToken))
// source: knowledge/curated/js/products/uikit.md ("Session tokens: `accessToken` and `configureSession`")
// source: knowledge/curated/js/products/auth.md ("Token refresh — SessionHandler (set before connect)")
// Type-checked by tools/templates/compile-check-js.sh against the pinned and latest packages.
//
// SendbirdProvider for an app whose users connect with an access or session token. Render it
// after your own sign-in, with the token your server issued for this user, and put the UIKit
// components (GroupChannelList, GroupChannel, ...) inside it. The token is a secret: fetch it
// from your server, never hard-code or log it.
import { useEffect, useRef, type ReactNode } from 'react';
import { SessionHandler } from '@sendbird/chat';
import { SendbirdProvider, type SendbirdProviderProps } from '@sendbird/uikit-react/SendbirdProvider';
import '@sendbird/uikit-react/dist/index.css';

const APP_ID = process.env.NEXT_PUBLIC_SENDBIRD_APP_ID as string;

export type SignedInChatProps = {
  userId: string;
  /** The token your server issued for this user. */
  accessToken: string;
  /** Asks your server for a new token for this user; called when the current one expired or was revoked. */
  fetchToken: (userId: string) => Promise<string>;
  /** The session cannot be renewed: send the user back to your sign-in screen. */
  onSessionClosed: () => void;
  children: ReactNode;
};

export function SignedInChat({ userId, accessToken, fetchToken, onSessionClosed, children }: SignedInChatProps) {
  // The handler is installed once per connect and outlives later renders, so it reads the
  // callbacks through a ref that always holds the latest props.
  const callbacks = useRef({ fetchToken, onSessionClosed });
  useEffect(() => {
    callbacks.current = { fetchToken, onSessionClosed };
  });

  // SendbirdProvider calls this and sets the handler right before it connects.
  const configureSession: SendbirdProviderProps['configureSession'] = () => {
    const handler = new SessionHandler();
    handler.onSessionTokenRequired = (resolve, reject) => {
      callbacks.current.fetchToken(userId).then(resolve, reject); // resolve(null) instead gives up the session
    };
    handler.onSessionClosed = () => callbacks.current.onSessionClosed();
    return handler;
  };

  // The provider connects again only when appId or userId changes; a new accessToken value
  // alone does not reconnect, so token renewal goes through configureSession.
  return (
    <SendbirdProvider appId={APP_ID} userId={userId} accessToken={accessToken} configureSession={configureSession}>
      {children}
    </SendbirdProvider>
  );
}
