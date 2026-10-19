<!-- last-verified-against: @sendbird/uikit-react 3.19.1 / @sendbird/uikit-react-native 3.12.10 -->
<!-- verified-at: 2026-10-12 -->
<!-- verification-method: compile-check-js -->
<!-- status: populated -->
# js — theme (UIKit)

> Verified against the shipped types of `@sendbird/uikit-react` 3.19.1 and `@sendbird/uikit-react-native` / `-foundation` 3.12.10, the public source at tags `v3.19.1` and `v3.12.10`, and the UIKit v3 theme and localization pages on sendbird.com. Every example type-checks against the pinned and latest packages. Used by `/sendbird-client:ui-customize`. Do not invent API.

## React (`@sendbird/uikit-react`)

### Light / dark
```tsx
import App from '@sendbird/uikit-react/App';

<App userId={userId} appId={appId} theme="dark" />   // "light" | "dark"
```
The same `theme` prop works on `SendbirdProvider`. It is not read once: when the prop changes, the provider updates its theme and swaps the `sendbird-theme--light` / `sendbird-theme--dark` class on `<body>`. To follow the system setting, drive the prop from `prefers-color-scheme` (example below). (source: https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/theme-resources ; github.com/sendbird/sendbird-uikit-react v3.19.1 src/lib/Sendbird/context/SendbirdProvider.tsx:133-136,145-166 ; @sendbird/uikit-react@3.19.1 types/lib/Sendbird/types.d.ts:144)

### Brand colors (`colorSet`) and strings (`stringSet`)
- `colorSet` is a `Record<string, string>` of UIKit CSS variable names to values, such as `--sendbird-light-primary-500` or `--sendbird-dark-primary-300`. Each color family (`primary`, `secondary`, `error`, `information`, `background`, …) exists in a light and a dark variant, so set both if you support both themes. The descriptive suffixes `extra-light`, `light`, `main`, `dark`, and `extra-dark` are accepted as aliases for `100` to `500`.
- The provider applies `colorSet` in a layout effect that runs again whenever the object identity changes. Define it outside the component, or memoize it, so it isn't re-applied on every render.
- `stringSet` is a `Partial<StringSet>`; UIKit merges it over the English defaults, so you only list the keys you change. Key names (for example `MESSAGE_INPUT__PLACE_HOLDER`) are in `types/ui/Label/stringSet.d.ts` of the installed package.
- `dateLocale` takes a `date-fns` `Locale` for dates in the UI.

```tsx
import { useEffect, useState } from 'react';
import { SendbirdProvider } from '@sendbird/uikit-react/SendbirdProvider';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import '@sendbird/uikit-react/dist/index.css';

const colorSet = {
  '--sendbird-light-primary-500': '#00487c',
  '--sendbird-light-primary-400': '#4bb3fd',
  '--sendbird-light-primary-300': '#3e6680',
  '--sendbird-light-primary-200': '#0496ff',
  '--sendbird-light-primary-100': '#027bce',
};

const stringSet = {
  MESSAGE_INPUT__PLACE_HOLDER: 'Saisissez un message.',
  MESSAGE_INPUT__PLACE_HOLDER__DISABLED: 'Le chat est indisponible dans ce canal.',
};

function useSystemTheme(): 'light' | 'dark' {
  const query = '(prefers-color-scheme: dark)';
  const [dark, setDark] = useState(() => window.matchMedia(query).matches);
  useEffect(() => {
    const mql = window.matchMedia(query);
    const onChange = (event: MediaQueryListEvent) => setDark(event.matches);
    mql.addEventListener('change', onChange);
    return () => mql.removeEventListener('change', onChange);
  }, []);
  return dark ? 'dark' : 'light';
}

function ChatRoot() {
  const theme = useSystemTheme();
  return (
    <SendbirdProvider appId={APP_ID} userId={USER_ID} theme={theme} colorSet={colorSet} stringSet={stringSet}>
      <GroupChannel channelUrl={CHANNEL_URL} />
    </SendbirdProvider>
  );
}
```

(source: https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/localization-resources/text ; https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/color-resources ; github.com/sendbird/sendbird-uikit-react v3.19.1 src/lib/hooks/useTheme.ts:116-126 — `colorSet` merged over the defaults and applied with `css-vars-ponyfill` when the object changes ; src/lib/utils/colorMapper.ts:7-26 (descriptive aliases) ; src/lib/Sendbird/context/SendbirdProvider.tsx:96,413-420 (`stringSet` merged over `getStringSet('en')`) ; @sendbird/uikit-react@3.19.1 types/lib/Sendbird/types.d.ts:147-149 `colorSet`, `stringSet`, `dateLocale` ; types/ui/Label/stringSet.d.ts:8,132-133)

### Restyle one component (message input)
`colorSet` changes CSS variables that every component reads, so it can't color the input alone. UIKit's styles use BEM class names, and the docs say components can be customized by overriding the applicable rules in UIKit's stylesheet. The input's text area is `.sendbird-message-input--textarea` inside `.sendbird-message-input`, and its theme colors are applied under the theme class, `.sendbird-theme--light` or `.sendbird-theme--dark`. Repeat that full selector in your own CSS and load it after `@sendbird/uikit-react/dist/index.css`, so your rule has the same specificity and comes later.

<!-- compile: skip -->
```css
.sendbird-theme--light .sendbird-message-input .sendbird-message-input--textarea {
  background-color: #f4f1ff;
  border-color: #c9bdf5;
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/color-resources) (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/ui/MessageInput/index.scss#L3-L30 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/styles/_color-themes.scss#L166-L178 — `.sendbird-theme--#{$theme} &`)

### Date and time formats
`dateLocale` picks the language, and the `DATE_FORMAT__*` keys of `stringSet` pick the patterns. UIKit formats these dates with `date-fns` `format(date, pattern, { locale: dateLocale })`, so a pattern uses `date-fns` tokens. The defaults in 3.19.1 include `DATE_FORMAT__MESSAGE_CREATED_AT: 'p'` (the time under a message), `DATE_FORMAT__MESSAGE_LIST__DATE_SEPARATOR: 'MMMM dd, yyyy'`, and `DATE_FORMAT__LAST_MESSAGE_CREATED_AT__TODAY: 'p'` (the channel list).

```tsx
import type { ReactNode } from 'react';
import { SendbirdProvider } from '@sendbird/uikit-react/SendbirdProvider';
import { ko } from 'date-fns/locale';
import '@sendbird/uikit-react/dist/index.css';

const dateStrings = {
  DATE_FORMAT__MESSAGE_CREATED_AT: 'HH:mm',
  DATE_FORMAT__MESSAGE_LIST__DATE_SEPARATOR: 'yyyy. M. d. (EEE)',
};

function KoreanDatesApp({ children }: { children: ReactNode }) {
  return (
    <SendbirdProvider appId={APP_ID} userId={USER_ID} dateLocale={ko} stringSet={dateStrings}>
      {children}
    </SendbirdProvider>
  );
}
```
(source: https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/localization-resources/date) (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/ui/Label/stringSet.ts#L223-L231 — default patterns ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.19.1/src/ui/MessageStatus/index.tsx#L100 — `format(..., { locale: dateLocale })` ; @sendbird/uikit-react 3.19.1 types/ui/Label/stringSet.d.ts:201-208)

## React Native (`@sendbird/uikit-react-native`)

### Light / dark and custom colors
Pass a `UIKitTheme` to `SendbirdUIKitContainer` as `styles.theme`; without it the container uses `LightUIKitTheme`. `LightUIKitTheme`, `DarkUIKitTheme`, `createTheme`, and `Palette` come from `@sendbird/uikit-react-native-foundation`. To follow the device setting, choose the theme from `useColorScheme()`.

`createTheme({ colorScheme, palette?, colors, typography? })` builds a theme. `colors` is a function of the palette that returns the full `UIKitColors` object, including per-component colors under `colors.ui`. Spreading `LightUIKitTheme.colors` (or `DarkUIKitTheme.colors`) copies those per-component values as they are, so they don't follow a new palette; override the `ui` entries you need as well.

```tsx
import { useColorScheme } from 'react-native';
import { SendbirdUIKitContainer } from '@sendbird/uikit-react-native';
import { DarkUIKitTheme, LightUIKitTheme, Palette, createTheme } from '@sendbird/uikit-react-native-foundation';
import { createMMKV } from 'react-native-mmkv';

const mmkv = createMMKV();

const BrandLightTheme = createTheme({
  colorScheme: 'light',
  palette: { ...Palette, primary300: '#00487c' },
  colors: (palette) => ({ ...LightUIKitTheme.colors, primary: palette.primary300 }),
});

function App() {
  const scheme = useColorScheme();
  return (
    <SendbirdUIKitContainer
      appId={APP_ID}
      chatOptions={{ localCacheStorage: mmkv }}
      platformServices={platformServices}
      styles={{ theme: scheme === 'dark' ? DarkUIKitTheme : BrandLightTheme }}
    >
      {/* fragments / navigation */}
    </SendbirdUIKitContainer>
  );
}
```

(source: https://sendbird.com/docs/chat/uikit/v3/react-native/theme-and-style-resources/theme-resource ; github.com/sendbird/sendbird-uikit-react-native v3.12.10 packages/uikit-react-native/src/containers/SendbirdUIKitContainer.tsx:107-113 `styles`, 250 (default `LightUIKitTheme`) ; @sendbird/uikit-react-native-foundation@3.12.10 src/index.ts:57-60 ; src/theme/createTheme.ts:6-18 ; src/theme/LightUIKitTheme.ts:3-7 ; src/types.ts:23-31 `UIKitTheme`, 165-204 `UIKitColors`, 219-224 `UIKitPalette`)

### Strings and localization
`localization.stringSet` on the container takes a complete `StringSet`, not a partial one. Build it with `createBaseStringSet({ dateLocale, overrides })`, which fills every key you don't override, or start from the exported English set `StringSetEn`. `dateLocale` is a `date-fns` locale; `date-fns` is a peer dependency of `@sendbird/uikit-react-native`. Some entries are functions (for example `LABELS.TYPING_INDICATOR_TYPINGS(users)`), while `GROUP_CHANNEL_LIST.HEADER_TITLE` and `LABELS.CHANNEL_INPUT_PLACEHOLDER_ACTIVE` are plain strings.

```tsx
import { ko } from 'date-fns/locale';
import { SendbirdUIKitContainer, createBaseStringSet } from '@sendbird/uikit-react-native';
import { createMMKV } from 'react-native-mmkv';

const mmkv = createMMKV();

const StringSetKo = createBaseStringSet({
  dateLocale: ko,
  overrides: {
    GROUP_CHANNEL_LIST: { HEADER_TITLE: '채팅' },
    LABELS: { CHANNEL_INPUT_PLACEHOLDER_ACTIVE: '메시지를 입력하세요' },
  },
});

<SendbirdUIKitContainer
  appId={APP_ID}
  chatOptions={{ localCacheStorage: mmkv }}
  platformServices={platformServices}
  localization={{ stringSet: StringSetKo }}
>
  {/* fragments / navigation */}
</SendbirdUIKitContainer>
```

(source: https://sendbird.com/docs/chat/uikit/v3/react-native/theme-and-style-resources/string-resource ; github.com/sendbird/sendbird-uikit-react-native v3.12.10 packages/uikit-react-native/src/localization/createBaseStringSet.ts:22-34 ; src/localization/StringSet.type.ts:218-220,264-299 ; src/containers/SendbirdUIKitContainer.tsx:104-106,162 (falls back to `StringSetEn`) ; src/index.ts:70-71 ; @sendbird/uikit-react-native@3.12.10 package.json peerDependencies `date-fns`)

`dateLocale` is what localizes UIKit's dates. In the set that `createBaseStringSet` builds, the date separator (`GROUP_CHANNEL.LIST_DATE_SEPARATOR`), the message time (`GROUP_CHANNEL.MESSAGE_BUBBLE_TIME`), the channel list time (`GROUP_CHANNEL_LIST.CHANNEL_PREVIEW_TITLE_CAPTION`), and the matching open channel and thread entries format with `locale ?? dateLocale`. UIKit calls them without a `locale` argument, so they use your `dateLocale`. `StringSetEn` is `createBaseStringSet({ dateLocale: enUS })`, so the default set formats dates with the `enUS` locale.

(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/localization/createBaseStringSet.ts#L34-L43 lines 119, 130, 225 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.10/packages/uikit-react-native/src/localization/StringSet.en.ts#L5 ; packages/uikit-react-native/src/components/GroupChannelMessageRenderer/GroupChannelMessageDateSeparator.tsx:27 ; src/components/GroupChannelMessageRenderer/index.tsx:179 ; src/containers/GroupChannelPreviewContainer.tsx:100) (community context: https://github.com/sendbird/sendbird-uikit-react-native/issues/22 — a 2022 report in which a maintainer proposed this fallback)

### Status bar
UIKit for React Native does not set the status bar's color or style on its screens; the only `StatusBar` it renders is in the full-screen file viewer, with `barStyle={'light-content'}`. Set the status bar yourself with React Native's `StatusBar` component, for example to match your theme. What UIKit does read is `styles.statusBarTranslucent` on `SendbirdUIKitContainer` (default `true`): when it is `true`, UIKit headers add the top safe-area inset so they start below a translucent status bar. Set it to `false` if your status bar is not translucent and the header shows extra space at the top.

React Native 0.87 removed the `StatusBar` `backgroundColor` and `translucent` props and their static setters, so passing `backgroundColor` fails type-checking. They were Android-only and already had no effect under Android 15 edge-to-edge. The app now draws behind the status bar, so color that area with the background of your top view (the screen root or header) and use `barStyle` only to pick light or dark icons. (source: https://github.com/facebook/react-native/blob/main/CHANGELOG.md — v0.87.0 Breaking, "Remove deprecated `StatusBar` `backgroundColor` / `translucent`" ; https://reactnative.dev/docs/0.86/statusbar — `backgroundColor` warning)

```tsx
import type { ReactNode } from 'react';
import { StatusBar } from 'react-native';
import { SendbirdUIKitContainer } from '@sendbird/uikit-react-native';
import { createMMKV } from 'react-native-mmkv';

const mmkv = createMMKV();

function ChatRoot({ children }: { children: ReactNode }) {
  return (
    <SendbirdUIKitContainer
      appId={APP_ID}
      chatOptions={{ localCacheStorage: mmkv }}
      platformServices={platformServices}
    >
      <StatusBar barStyle="dark-content" />
      {children}
    </SendbirdUIKitContainer>
  );
}
```
(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/containers/SendbirdUIKitContainer.tsx#L254-L257 — `statusBarTranslucent ?? true` ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native-foundation/src/styles/HeaderStyleContext.tsx#L39 — `topInset: statusBarTranslucent ? top : 0` ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.9/packages/uikit-react-native/src/components/FileViewer/index.tsx#L113 ; @sendbird/uikit-react-native 3.12.9 lib/typescript/src/containers/SendbirdUIKitContainer.d.ts:55-61 ; https://reactnative.dev/docs/statusbar)

## Pitfalls
- React: import the UIKit CSS (`@sendbird/uikit-react/dist/index.css`) or theming has nothing to style.
- React: a `colorSet` object created inside the render function is re-applied on every render.
- React Native: `localization.stringSet` must be a full `StringSet`; passing only the keys you change fails type-checking.
- React Native 0.87+: `StatusBar` has no `backgroundColor` or `translucent` prop; color the top view behind the status bar instead (see Status bar).
- Drive `theme` (React) or `styles.theme` (React Native) from your app state to follow system dark mode.

## Related
- UIKit: knowledge/curated/js/products/uikit.md
- AI Agent theme: knowledge/curated/js/cross-cutting/ai-agent-theme.md
