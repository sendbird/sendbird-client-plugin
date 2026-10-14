// source: knowledge/curated/js/hosts/react-native.md ("App lifecycle (Chat SDK without UIKit)", "UIKit container: local cache storage")
// source: knowledge/curated/js/cross-cutting/theme.md ("React Native": styles.theme)
// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/containers/SendbirdUIKitContainer.tsx#L81-L95
import { useState } from 'react';
import { SendbirdUIKitContainer } from '@sendbird/uikit-react-native';
import { LightUIKitTheme } from '@sendbird/uikit-react-native-foundation';
import { createMMKV } from 'react-native-mmkv';
import { useSession } from './src/auth/session';
import { ChannelsScreen } from './src/screens/ChannelsScreen';
import { HomeScreen } from './src/screens/HomeScreen';
import { LoginScreen } from './src/screens/LoginScreen';
import { SENDBIRD_APP_ID } from './src/sendbird/config';
import { platformServices } from './src/sendbird/platformServices';
import { SessionBridge, createSessionHandler } from './src/sendbird/SessionBridge';

// BP11 / BP15: the local cache store the container requires. Do not clear or edit it yourself.
const mmkv = createMMKV();

export default function App() {
  if (SENDBIRD_APP_ID === '') return <LoginScreen />; // shows the missing App ID message

  // BP01 / BP15: one container at the app root initializes the Chat SDK once and follows the app
  // state (foreground / background) for it. BP12: the theme is set here.
  return (
    <SendbirdUIKitContainer
      appId={SENDBIRD_APP_ID}
      chatOptions={{
        localCacheStorage: mmkv,
        onInitialized: (sdk) => {
          sdk.setSessionHandler(createSessionHandler()); // BP04: before any connect
          return sdk;
        },
      }}
      platformServices={platformServices}
      styles={{ theme: LightUIKitTheme }}
    >
      <SessionBridge />
      <Screens />
    </SendbirdUIKitContainer>
  );
}

/** BP16: every screen follows the one app-wide session. */
function Screens() {
  const session = useSession();
  const [showChannels, setShowChannels] = useState(false);
  if (session.status === 'signed-out') return <LoginScreen notice={session.notice} />;
  if (showChannels && session.status === 'signed-in') return <ChannelsScreen onBack={() => setShowChannels(false)} />;
  return <HomeScreen session={session} onOpenChannels={() => setShowChannels(true)} />;
}
