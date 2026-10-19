// source: https://github.com/sendbird/sendbird-uikit-react (README, verified 2026-06-09)
// Type-checked against @sendbird/uikit-react (v3.18.0, tsc --noEmit clean):
// the App default export from '@sendbird/uikit-react/App', appId/userId props, css subpath.
// App ID/user from env, never hard-code; access tokens are secrets.

import SendbirdApp from '@sendbird/uikit-react/App';
import '@sendbird/uikit-react/dist/index.css';

const APP_ID = process.env.NEXT_PUBLIC_SENDBIRD_APP_ID as string;
const USER_ID = process.env.NEXT_PUBLIC_SENDBIRD_USER_ID as string;

// accessToken: the token your server issued for this user, when the application requires one.
// The drop-in App has no configureSession prop, so it cannot renew an expired token; for that use
// SignedInChat.tsx (SendbirdProvider with configureSession). source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/modules/App/index.tsx#L20
export function ChatApp({ accessToken }: { accessToken?: string } = {}) {
  return <SendbirdApp appId={APP_ID} userId={USER_ID} accessToken={accessToken} theme="light" />;
}

// Granular UI instead of the full App: wrap your tree in <SendbirdProvider appId userId> from
// '@sendbird/uikit-react/SendbirdProvider' and compose <GroupChannelList /> + <GroupChannel />
// (subpath imports; see knowledge/curated/js/products/uikit.md "Compose your own UI").
