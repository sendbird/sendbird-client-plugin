// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/theme/createTheme.ts#L6-L40 (createTheme)
// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/styles/createTypography.ts#L4-L100 (typography, shared applied last)
// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/types.ts#L63-L115 (groupChannelMessage bubble colors)
// source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native/src/containers/SendbirdUIKitContainer.tsx#L250 (styles.theme goes to the theme context)
// Type-checked against @sendbird/uikit-react-native and -foundation (compile-check-js.sh, pinned and latest).
// Guide: knowledge/curated/js/cross-cutting/theme.md ("Light / dark and custom colors", "Fonts (`typography`)", "Message bubble colors").
// The App ID comes in as a prop from the app's own config module; never hard-code it. Access tokens are secrets.
//
// Dark mode that follows the device or the app's own setting, brand colors, a custom font, and
// message bubble colors. The font must be linked into the iOS and Android apps under the same name.

import type { ReactNode } from 'react';
import { useColorScheme } from 'react-native';
import { SendbirdUIKitContainer } from '@sendbird/uikit-react-native';
import {
  DarkUIKitTheme,
  LightUIKitTheme,
  Palette,
  createTheme,
  type UIKitPalette,
} from '@sendbird/uikit-react-native-foundation';
import { createMMKV } from 'react-native-mmkv';
import { platformServices } from './factory'; // build per the quickstart (createNative*Service)

const mmkv = createMMKV();

const BrandPalette: UIKitPalette = {
  ...Palette,
  primary100: '#dbe6ff',
  primary200: '#6f9dff',
  primary300: '#0b5cff',
  primary400: '#0a47a8',
  primary500: '#062a66',
};

// `shared` is applied after each style's own entry, so its fontFamily wins everywhere.
const typography = { shared: { fontFamily: 'Inter' } };

// Spreading the default colors copies their per-component values as they are, so the bubble
// entries are set again from the new palette.
const BrandLightTheme = createTheme({
  colorScheme: 'light',
  palette: BrandPalette,
  typography,
  colors: (palette) => {
    const base = LightUIKitTheme.colors;
    const bubble = base.ui.groupChannelMessage;
    return {
      ...base,
      primary: palette.primary300,
      ui: {
        ...base.ui,
        groupChannelMessage: {
          outgoing: {
            enabled: { ...bubble.outgoing.enabled, background: palette.primary300, textMsg: '#FFFFFF' },
            pressed: { ...bubble.outgoing.pressed, background: palette.primary400, textMsg: '#FFFFFF' },
          },
          incoming: {
            enabled: { ...bubble.incoming.enabled, background: '#EEF1F6', textMsg: '#111827' },
            pressed: { ...bubble.incoming.pressed, background: palette.primary100, textMsg: '#111827' },
          },
        },
      },
    };
  },
});

const BrandDarkTheme = createTheme({
  colorScheme: 'dark',
  palette: BrandPalette,
  typography,
  colors: (palette) => {
    const base = DarkUIKitTheme.colors;
    const bubble = base.ui.groupChannelMessage;
    return {
      ...base,
      primary: palette.primary200,
      ui: {
        ...base.ui,
        groupChannelMessage: {
          outgoing: {
            enabled: { ...bubble.outgoing.enabled, background: palette.primary200, textMsg: palette.onBackgroundLight01 },
            pressed: { ...bubble.outgoing.pressed, background: palette.primary300, textMsg: palette.onBackgroundLight01 },
          },
          incoming: {
            enabled: { ...bubble.incoming.enabled, background: palette.background500 },
            pressed: { ...bubble.incoming.pressed },
          },
        },
      },
    };
  },
});

export type ThemeChoice = 'system' | 'light' | 'dark';

// Pass `choice` from the app's own setting; 'system' follows the device. Changing it re-themes the
// open screens, because styles.theme is a plain context value.
export function BrandThemedUIKit({
  appId,
  choice = 'system',
  children,
}: {
  appId: string;
  choice?: ThemeChoice;
  children: ReactNode;
}) {
  const scheme = useColorScheme();
  const dark = choice === 'system' ? scheme === 'dark' : choice === 'dark';
  return (
    <SendbirdUIKitContainer
      appId={appId}
      chatOptions={{ localCacheStorage: mmkv }}
      platformServices={platformServices}
      styles={{ theme: dark ? BrandDarkTheme : BrandLightTheme }}
    >
      {children}
    </SendbirdUIKitContainer>
  );
}
