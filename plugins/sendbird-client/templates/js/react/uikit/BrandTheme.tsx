// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/lib/Sendbird/context/SendbirdProvider.tsx#L141-L174 (theme prop swaps the body class)
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/lib/hooks/useTheme.ts#L116-L126 (colorSet)
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/styles/_color-themes.scss#L86-L87 (dark accent reads primary-200)
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/styles/_misc-colors.scss#L1-L12 (font variable)
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/Avatar/index.scss#L92-L93 and https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/MentionUserLabel/index.scss#L31-L32 (Roboto written directly)
// source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/TextMessageItemBody/index.scss#L16-L41 (bubble selectors)
// Type-checked against @sendbird/uikit-react (compile-check-js.sh, pinned and latest).
// Guide: knowledge/curated/js/cross-cutting/theme.md ("Light / dark", "Brand colors", "Fonts", "Message bubble colors").
// App ID from env, never hard-code; access tokens are secrets.
//
// Dark mode that follows the system or the app's own setting, brand colors, a custom font, and
// text bubble colors. Font and bubble colors are CSS: UIKit has no prop for either.

import { useEffect, useState } from 'react';
import { SendbirdProvider } from '@sendbird/uikit-react/SendbirdProvider';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import '@sendbird/uikit-react/dist/index.css';

const APP_ID = process.env.NEXT_PUBLIC_SENDBIRD_APP_ID as string;
const USER_ID = process.env.NEXT_PUBLIC_SENDBIRD_USER_ID as string;

// Module level, so the provider does not apply it again on every render.
// Light mode's accent is primary-300; dark mode's accent is primary-200.
const colorSet = {
  '--sendbird-light-primary-500': '#062a66',
  '--sendbird-light-primary-400': '#0a47a8',
  '--sendbird-light-primary-300': '#0b5cff',
  '--sendbird-light-primary-200': '#6f9dff',
  '--sendbird-light-primary-100': '#dbe6ff',
  '--sendbird-dark-primary-500': '#062a66',
  '--sendbird-dark-primary-400': '#0a47a8',
  '--sendbird-dark-primary-300': '#0b5cff',
  '--sendbird-dark-primary-200': '#6f9dff',
  '--sendbird-dark-primary-100': '#dbe6ff',
};

// Load the font itself yourself. Most UIKit text reads the variable; avatar initials and the mention
// label name Roboto directly, so they get their own rule. The bubble rules repeat UIKit's selectors
// so they have the same specificity, and this style element comes after UIKit's stylesheet.
const themeCss = `
body { --sendbird-font-family-default: 'Inter', system-ui, sans-serif; }
.sendbird-avatar .sendbird-avatar-text,
.sendbird-mention-user-label.purple {
  font-family: 'Inter', system-ui, sans-serif;
}

.sendbird-theme--light .sendbird-text-message-item-body.outgoing,
.sendbird-theme--light .sendbird-text-message-item-body.mouse-hover.outgoing,
.sendbird-theme--light .sendbird-text-message-item-body:hover.outgoing,
.sendbird-theme--light .sendbird-text-message-item-body.disable-hover.mouse-hover.outgoing,
.sendbird-theme--light .sendbird-text-message-item-body.disable-hover:hover.outgoing {
  background-color: #0b5cff;
  color: #ffffff;
}
.sendbird-theme--light .sendbird-text-message-item-body.incoming,
.sendbird-theme--light .sendbird-text-message-item-body.mouse-hover.incoming,
.sendbird-theme--light .sendbird-text-message-item-body:hover.incoming,
.sendbird-theme--light .sendbird-text-message-item-body.disable-hover.mouse-hover.incoming,
.sendbird-theme--light .sendbird-text-message-item-body.disable-hover:hover.incoming {
  background-color: #eef1f6;
  color: #111827;
}
.sendbird-theme--dark .sendbird-text-message-item-body.outgoing,
.sendbird-theme--dark .sendbird-text-message-item-body.mouse-hover.outgoing,
.sendbird-theme--dark .sendbird-text-message-item-body:hover.outgoing,
.sendbird-theme--dark .sendbird-text-message-item-body.disable-hover.mouse-hover.outgoing,
.sendbird-theme--dark .sendbird-text-message-item-body.disable-hover:hover.outgoing {
  background-color: #6f9dff;
  color: #0b1220;
}
.sendbird-theme--dark .sendbird-text-message-item-body.incoming,
.sendbird-theme--dark .sendbird-text-message-item-body.mouse-hover.incoming,
.sendbird-theme--dark .sendbird-text-message-item-body:hover.incoming,
.sendbird-theme--dark .sendbird-text-message-item-body.disable-hover.mouse-hover.incoming,
.sendbird-theme--dark .sendbird-text-message-item-body.disable-hover:hover.incoming {
  background-color: #2c2c2c;
  color: rgba(255, 255, 255, 0.88);
}
`;

export type ThemeChoice = 'system' | 'light' | 'dark';

// Starts light and reads the device setting after mount, so server rendering (Next.js and others)
// never touches window and the first client render matches the server's HTML.
function useSystemDark(): boolean {
  const query = '(prefers-color-scheme: dark)';
  const [dark, setDark] = useState(false);
  useEffect(() => {
    const mql = window.matchMedia(query);
    setDark(mql.matches);
    const onChange = (event: MediaQueryListEvent) => setDark(event.matches);
    mql.addEventListener('change', onChange);
    return () => mql.removeEventListener('change', onChange);
  }, []);
  return dark;
}

// Pass `choice` from the app's own setting; 'system' follows the device. Changing `theme` swaps
// the sendbird-theme--light / --dark class on <body> while the screen is open.
export function BrandThemedChat({ channelUrl, choice = 'system' }: { channelUrl: string; choice?: ThemeChoice }) {
  const systemDark = useSystemDark();
  const theme: 'light' | 'dark' = choice === 'system' ? (systemDark ? 'dark' : 'light') : choice;
  return (
    <>
      <style>{themeCss}</style>
      <SendbirdProvider appId={APP_ID} userId={USER_ID} theme={theme} colorSet={colorSet}>
        <GroupChannel channelUrl={channelUrl} />
      </SendbirdProvider>
    </>
  );
}
