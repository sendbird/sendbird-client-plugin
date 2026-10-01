// source: https://github.com/sendbird/sendbird-uikit-react (README, verified 2026-06-09)
// Type-checked against @sendbird/uikit-react (v3.18.0, tsc --noEmit clean):
// the App default export from '@sendbird/uikit-react/App', appId/userId props, css subpath.
// App ID/user from env, never hard-code; access tokens are secrets.

import SendbirdApp from '@sendbird/uikit-react/App';
import '@sendbird/uikit-react/dist/index.css';

const APP_ID = process.env.NEXT_PUBLIC_SENDBIRD_APP_ID as string;
const USER_ID = process.env.NEXT_PUBLIC_SENDBIRD_USER_ID as string;

export function ChatApp() {
  return <SendbirdApp appId={APP_ID} userId={USER_ID} theme="light" />;
}

// Granular UI instead of the full App: wrap your tree in <SendBirdProvider appId userId>
// and compose <ChannelList /> + <Channel /> (from '@sendbird/uikit-react').
