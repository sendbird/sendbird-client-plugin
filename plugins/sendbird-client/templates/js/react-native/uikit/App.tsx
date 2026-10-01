// source: sendbird-uikit-react-native sample/src/App.tsx + docs-validation SendbirdUIKitContainer.tsx
//   (github.com/sendbird/sendbird-uikit-react-native; verified 2026-06-10)
// Type-checked against the shipped types (compile-check-js.sh): SendbirdUIKitContainer requires
// `chatOptions.localCacheStorage` (mmkv) in addition to appId + platformServices.
// App ID from env, never hard-code; access tokens are secrets.
//
// platformServices (clipboard, notification, file, media, player, recorder) must be built from the
// SDK's createNative*Service factories per the quickstart — do NOT guess them. The sample assembles
// them in its ./factory module. See:
//   https://sendbird.com/docs/chat/uikit/v3/react-native/core-components/sendbirduikitcontainer

import { SendbirdUIKitContainer } from '@sendbird/uikit-react-native';
import { LightUIKitTheme } from '@sendbird/uikit-react-native-foundation';
import { createMMKV } from 'react-native-mmkv';
import { platformServices } from './factory'; // build per the quickstart (createNative*Service)

const APP_ID = process.env.SENDBIRD_APP_ID as string;
const mmkv = createMMKV();

export function App() {
  return (
    <SendbirdUIKitContainer
      appId={APP_ID}
      chatOptions={{ localCacheStorage: mmkv }}
      platformServices={platformServices}
      styles={{ theme: LightUIKitTheme }}
    >
      {/* navigation + UIKit fragments (e.g. GroupChannelListFragment) */}
    </SendbirdUIKitContainer>
  );
}
