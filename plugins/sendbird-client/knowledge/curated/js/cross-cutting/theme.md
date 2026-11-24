<!-- last-verified-against: @sendbird/uikit-react 3.20.1 / @sendbird/uikit-react-native 3.12.11 -->
<!-- verified-at: 2026-11-23 -->
<!-- verification-method: compile-check-js -->
<!-- status: populated -->
# js — theme (UIKit)

> Verified against the shipped types of `@sendbird/uikit-react` 3.19.1 and `@sendbird/uikit-react-native` / `-foundation` 3.12.10, the public source at tags `v3.19.1` and `v3.12.10`, and the UIKit v3 theme and localization pages on sendbird.com. Re-checked on 2026-11-23 against the source at `v3.20.1` and `v3.12.11` and the shipped 3.20.1 stylesheet; the fonts, bubble colors, icons, default profile image, date pattern, and RTL sections were added then. Every example type-checks against the pinned and latest packages. Used by `/sendbird-client:ui-customize`. Do not invent API.

## React (`@sendbird/uikit-react`)

### Light / dark
```tsx
import App from '@sendbird/uikit-react/App';

<App userId={userId} appId={appId} theme="dark" />   // "light" | "dark"
```
The same `theme` prop works on `SendbirdProvider`. It is not read once: when the prop changes, the provider updates its theme and swaps the `sendbird-theme--light` / `sendbird-theme--dark` class on `<body>`. To follow the system setting, drive the prop from `prefers-color-scheme` (example below). (source: https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/theme-resources ; github.com/sendbird/sendbird-uikit-react v3.19.1 src/lib/Sendbird/context/SendbirdProvider.tsx:133-136,145-166 ; @sendbird/uikit-react@3.19.1 types/lib/Sendbird/types.d.ts:144)

When the dark theme goes on `SendbirdProvider` around screens you compose yourself, `GroupChannelList` needs both `onChannelSelect` and `onChannelCreated`; without `onChannelCreated` the app does not compile. Copy the list and channel pair from knowledge/curated/js/products/uikit.md "Compose your own UI". (source: @sendbird/uikit-react@3.19.1 types/modules/GroupChannelList/context/GroupChannelListProvider.d.ts:35 — `PartialRequired<ContextBaseType, 'onChannelSelect' | 'onChannelCreated'>`)

### Brand colors (`colorSet`) and strings (`stringSet`)
- `colorSet` is a `Record<string, string>` of UIKit CSS variable names to values, such as `--sendbird-light-primary-500` or `--sendbird-dark-primary-300`. Each color family (`primary`, `secondary`, `error`, `information`, `background`, …) exists in a light and a dark variant, so set both if you support both themes. The descriptive suffixes `extra-light`, `light`, `main`, `dark`, and `extra-dark` are accepted as aliases for `100` to `500`.
- `300` (`main`) is the shade UIKit uses as the color itself: buttons, links, your own message bubbles. `500` is the darkest and `100` the lightest (the default light primary runs from #491389 at 500 to #dbd1ff at 100, with #742ddd at 300). So a single brand color goes on `300`, and the other four are a darker-to-lighter ramp around it; a shade you leave out keeps UIKit's default purple. The values in the `colorMapper.ts` doc comment only illustrate the key mapping and are not a palette, so don't copy them.
- The provider applies `colorSet` in a layout effect that runs again whenever the object identity changes. Define it outside the component, or memoize it, so it isn't re-applied on every render.
- `stringSet` is a `Partial<StringSet>`; UIKit merges it over the English defaults, so you only list the keys you change. Key names (for example `MESSAGE_INPUT__PLACE_HOLDER`) are in `types/ui/Label/stringSet.d.ts` of the installed package.
- `dateLocale` takes a `date-fns` `Locale` for dates in the UI.

```tsx
import { useEffect, useState } from 'react';
import { SendbirdProvider } from '@sendbird/uikit-react/SendbirdProvider';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import '@sendbird/uikit-react/dist/index.css';

// Brand color #00487c on 300 (main); 500 and 400 darker, 200 and 100 lighter.
const colorSet = {
  '--sendbird-light-primary-500': '#002c4d',
  '--sendbird-light-primary-400': '#003a66',
  '--sendbird-light-primary-300': '#00487c',
  '--sendbird-light-primary-200': '#99b6cb',
  '--sendbird-light-primary-100': '#d9e4ec',
};

const stringSet = {
  MESSAGE_INPUT__PLACE_HOLDER: 'Saisissez un message.',
  MESSAGE_INPUT__PLACE_HOLDER__DISABLED: 'Le chat est indisponible dans ce canal.',
};

// Starts light and reads the device setting after mount, so server rendering never touches window.
function useSystemTheme(): 'light' | 'dark' {
  const query = '(prefers-color-scheme: dark)';
  const [dark, setDark] = useState(false);
  useEffect(() => {
    const mql = window.matchMedia(query);
    setDark(mql.matches);
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

(source: https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/localization-resources/text ; https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/color-resources ; github.com/sendbird/sendbird-uikit-react v3.19.1 src/lib/hooks/useTheme.ts:116-126 — `colorSet` merged over the defaults and applied with `css-vars-ponyfill` when the object changes ; src/lib/utils/colorMapper.ts:7-26 (descriptive aliases) ; src/styles/_light-theme.scss:4-8 (default light primary 500 to 100) ; src/lib/Sendbird/context/SendbirdProvider.tsx:96,413-420 (`stringSet` merged over `getStringSet('en')`) ; @sendbird/uikit-react@3.19.1 types/lib/Sendbird/types.d.ts:147-149 `colorSet`, `stringSet`, `dateLocale` ; types/ui/Label/stringSet.d.ts:8,132-133)

The dark theme does not read the same steps of the primary ramp as the light theme. In light mode the accent (outgoing bubble, buttons) is `--sendbird-light-primary-300` and its hover is `-400`. In dark mode the accent is `--sendbird-dark-primary-200` and its hover is `-300`. A brand color set only on `--sendbird-dark-primary-300` therefore changes the dark hover color but not the dark accent; set `--sendbird-dark-primary-200` too. (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/styles/_color-themes.scss#L86-L87 — dark `primary-4` and `primary-3` ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/styles/_color-themes.scss#L6-L7 — light)

UIKit ships only an English string set (`getStringSet` has one `'en'` entry). Every other language comes from your own `stringSet`. (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/Label/stringSet.ts#L259-L261 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/Label/stringSet.ts#L12)

### Fonts
No prop sets the font. UIKit's stylesheet declares one CSS variable, `--sendbird-font-family-default`, on `:root` with the value Roboto plus a sans-serif fallback, and the text of labels (message text, names, headers), buttons, inputs, the message input, and tooltips read their font from it. Set the variable on `body` (an element nearer than `:root` wins by inheritance, whatever the stylesheet order) and load the font yourself, for example from your own `@font-face` or a font service. Do not put fonts in `colorSet`: it is documented for colors only.

Two rules name Roboto directly and do not read the variable: the initials inside an avatar without a picture (`.sendbird-avatar .sendbird-avatar-text`) and the mention label (`.sendbird-mention-user-label.purple`). Override those selectors as well if they must use your font.

<!-- compile: skip -->
```css
body {
  --sendbird-font-family-default: 'Inter', system-ui, sans-serif;
}
.sendbird-avatar .sendbird-avatar-text,
.sendbird-mention-user-label.purple {
  font-family: 'Inter', system-ui, sans-serif;
}
```
(source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/styles/_misc-colors.scss#L1-L12 — the variable declared on the root ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/Label/index.scss#L11 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/MessageInput/index.scss#L24 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/Button/index.scss#L7 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/Avatar/index.scss#L92-L93 — Roboto written directly ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/MentionUserLabel/index.scss#L31-L32 — Roboto written directly ; https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/color-resources — components are customized by overriding UIKit's stylesheet)

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

### Message bubble colors
There is no bubble color prop and no bubble-only CSS variable. The outgoing bubble takes the accent color and the incoming bubble takes a background color, and both tokens are shared with the rest of the UI, so `colorSet` recolors every surface that uses them. To change only the text bubbles, override the bubble's own rules the same way as the message input above. The text bubble is `.sendbird-text-message-item-body` with `.outgoing` or `.incoming`, and its hover states add `.mouse-hover`, the hover pseudo-class, and `.disable-hover`. The message text inherits the bubble's `color`; links, mentions, and the "(edited)" label keep their own colors.

<!-- compile: skip -->
```css
/* load after @sendbird/uikit-react/dist/index.css */
.sendbird-theme--light .sendbird-text-message-item-body.outgoing,
.sendbird-theme--light .sendbird-text-message-item-body.mouse-hover.outgoing,
.sendbird-theme--light .sendbird-text-message-item-body.outgoing:hover {
  background-color: #0b5cff;
  color: #ffffff;
}
.sendbird-theme--light .sendbird-text-message-item-body.disable-hover.mouse-hover.outgoing,
.sendbird-theme--light .sendbird-text-message-item-body.disable-hover.outgoing:hover {
  background-color: #0b5cff;
}
.sendbird-theme--light .sendbird-text-message-item-body.incoming,
.sendbird-theme--light .sendbird-text-message-item-body.mouse-hover.incoming,
.sendbird-theme--light .sendbird-text-message-item-body.incoming:hover {
  background-color: #eef1f6;
  color: #111827;
}
/* repeat with .sendbird-theme--dark for dark mode */
```
File, link preview, quote, and template messages have their own `.outgoing` and `.incoming` rules in their own components, so these rules recolor text messages only. (source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/TextMessageItemBody/index.scss#L16-L41 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/TextMessageItemBody/index.tsx#L51-L60 — `outgoing` or `incoming` and `mouse-hover` classes ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/modules/Message/components/TextFragment/index.tsx#L78-L85 — links keep their own color ; https://sendbird.com/docs/chat/uikit/v3/react/theme-and-style-resources/color-resources)

### Icons and the default profile image
React UIKit has no way to replace its icons everywhere: each icon is an SVG imported into the icon component, and the provider takes no icon setting. Replace an icon where UIKit offers a render prop for it, such as the send, voice, and file buttons of the message input (knowledge/curated/js/products/uikit.md, "Message input: icons, attach button, disabling, file types"), or restyle icons with CSS on `.sendbird-icon`.

A user without a profile picture gets a gray circle with a person icon (`.sendbird-avatar-img--default`). No prop replaces it for the whole UI. Override it with CSS, replace the avatar with a message render prop (knowledge/curated/js/products/uikit.md, "Customize how messages render"), or give users a `profileUrl`.

<!-- compile: skip -->
```css
.sendbird-theme--light .sendbird-avatar .sendbird-avatar-img--default,
.sendbird-theme--dark .sendbird-avatar .sendbird-avatar-img--default {
  background: url('/img/default-avatar.png') center / cover no-repeat;
}
.sendbird-avatar .sendbird-avatar-img--default .sendbird-icon {
  display: none;
}
```
(source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/Icon/index.tsx#L11-L40 — static SVG imports ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/Icon/index.tsx#L156-L176 — `sendbird-icon` class ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/Avatar/AvatarDefault.tsx#L24-L41 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/ImageRenderer/index.tsx#L137 — the default shows when there is no image or it fails to load ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/ui/Avatar/index.scss#L78-L90)

### Right-to-left (RTL) layout
`SendbirdProvider` takes `htmlTextDirection` (`'ltr'` or `'rtl'`, default `'ltr'`), which sets `dir` on UIKit's top element, and `forceLeftToRightMessageLayout` (default `false`). With `forceLeftToRightMessageLayout` set, the message list stays left to right inside an RTL page, so your own messages stay on the right. UIKit does not change the `dir` of your `<html>`. Pair RTL with a matching `dateLocale` and `stringSet`. Both props were added in 3.14.12 and 3.14.14.

```tsx
import { SendbirdProvider } from '@sendbird/uikit-react/SendbirdProvider';
import { GroupChannel } from '@sendbird/uikit-react/GroupChannel';
import { ar } from 'date-fns/locale';
import '@sendbird/uikit-react/dist/index.css';

function ArabicChat() {
  return (
    <SendbirdProvider appId={APP_ID} userId={USER_ID} htmlTextDirection="rtl" forceLeftToRightMessageLayout={false} dateLocale={ar}>
      <GroupChannel channelUrl={CHANNEL_URL} />
    </SendbirdProvider>
  );
}
```
(source: https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/lib/Sendbird/types.ts#L227-L228 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/lib/Sendbird/context/SendbirdProvider.tsx#L79-L80 — defaults ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/hooks/useHTMLTextDirection.tsx#L5-L15 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/src/modules/GroupChannel/components/MessageList/index.tsx#L299-L304 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/CHANGELOG.md#L723 ; https://github.com/sendbird/sendbird-uikit-react/blob/v3.20.1/CHANGELOG.md#L795)

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

`styles.theme` goes straight into the theme context, so changing it re-themes the open screens. UIKit has no "follow the system" mode of its own: pick the theme from `useColorScheme()`, or from a setting in your app, as above. (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native/src/containers/SendbirdUIKitContainer.tsx#L250 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/theme/UIKitThemeProvider.tsx#L10-L12)

### Fonts (`typography`)
`createTheme` takes `typography`, with one entry per text style and a `shared` entry for all of them. The styles are `h1`, `h2`, `subtitle1`, `subtitle2`, `body1`, `body2`, `body3`, `button`, `caption1`, `caption2`, `caption3`, and `caption4`. Each takes `fontFamily`, `fontSize`, `lineHeight`, `letterSpacing`, and `fontWeight`. `shared` is applied after each style's own entry, so `shared.fontFamily` wins over a `fontFamily` set on one style. Without `typography`, `createTheme` uses `{ shared: { fontFamily: 'System' } }`. The font itself must be linked into the iOS and Android apps under the same family name; that is a React Native step, not a UIKit setting.

```tsx
import { LightUIKitTheme, createTheme } from '@sendbird/uikit-react-native-foundation';

const InterLightTheme = createTheme({
  colorScheme: 'light',
  colors: () => LightUIKitTheme.colors,
  typography: {
    shared: { fontFamily: 'Inter' },
    h1: { fontSize: 24, lineHeight: 28 },
  },
});
```
(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/types.ts#L5-L20 — the 12 styles and their attributes ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/styles/createTypography.ts#L4-L100 — `shared` applied last ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/theme/createTheme.ts#L17 — default `'System'` ; https://sendbird.com/docs/chat/uikit/v3/react-native/theme-and-style-resources/typography-resource)

### Message bubble colors
Bubble colors are under `colors.ui.groupChannelMessage`, split into `incoming` and `outgoing`, each with an `enabled` and a `pressed` state. Each state has ten colors: `textMsg`, `textEdited`, `textSenderName`, `textTime`, `textVoicePlaytime`, `background`, `voiceSpinner`, `voiceProgressTrack`, `voiceActionIcon`, and `voiceActionIconBackground`. Text, file, video, link preview, and unknown message bubbles in group channels use them; open channels use `colors.ui.openChannelMessage`. The `colors` function must return the whole object, so spread the default entries and change only what you need.

```tsx
import { LightUIKitTheme, Palette, createTheme } from '@sendbird/uikit-react-native-foundation';

const BubbleTheme = createTheme({
  colorScheme: 'light',
  palette: { ...Palette, primary300: '#0b5cff', primary400: '#0a47a8' },
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
            pressed: { ...bubble.incoming.pressed },
          },
        },
      },
    };
  },
});
```
A misspelled key inside the spread object is not a type error, so check the names against the list above. (source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/types.ts#L63-L115 — variants, states, and the ten colors ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/types.ts#L196 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/theme/LightUIKitTheme.ts#L125-L178 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/ui/GroupChannelMessage/MessageBubbleWithText.tsx#L32 ; https://sendbird.com/docs/chat/uikit/v3/react-native/theme-and-style-resources/color-resource)

### Icons and the default profile image (`Icon.Assets`)
`Icon.Assets` maps each icon name to an image, and UIKit's icon component reads it when it draws. Assign your own image to a name before UIKit renders, and that icon changes everywhere. UIKit tints every icon with a theme color, so use a single-color PNG with a transparent background; a full-color image comes out as one flat color.

A user without a profile picture is drawn as the `user` icon on a gray circle, so replacing `Icon.Assets['user']` replaces that placeholder. For a full-color placeholder, replace the avatar through a message or channel preview render prop instead.

```tsx
import { Icon } from '@sendbird/uikit-react-native-foundation';

Icon.Assets['send'] = require('./assets/my-send.png');
Icon.Assets['user'] = require('./assets/my-avatar-silhouette.png');
```
(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/components/Icon/index.tsx#L29-L64 — reads the asset at render and sets `tintColor` ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/components/Icon/index.tsx#L101-L104 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/ui/Avatar/index.tsx#L22-L48 — the `user` icon when there is no image ; https://sendbird.com/docs/chat/uikit/v3/react-native/theme-and-style-resources/icon-resource)

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

To change a date pattern, not only its language, override those entries: they are functions, so give your own function in `overrides`. `GROUP_CHANNEL.MESSAGE_BUBBLE_TIME` receives the message, `GROUP_CHANNEL.LIST_DATE_SEPARATOR` receives a `Date`, and `GROUP_CHANNEL_LIST.CHANNEL_PREVIEW_TITLE_CAPTION` receives the channel; each also receives an optional locale. The defaults are the `date-fns` pattern `'p'` for the message time, and `'MMM dd, yyyy'` or `'E, MMM dd'` for the date separator depending on whether the date is in the current year.

```tsx
import { format } from 'date-fns';
import { ko } from 'date-fns/locale';
import { createBaseStringSet } from '@sendbird/uikit-react-native';

const StringSetKoDates = createBaseStringSet({
  dateLocale: ko,
  overrides: {
    GROUP_CHANNEL: {
      MESSAGE_BUBBLE_TIME: (message) => format(new Date(message.createdAt), 'HH:mm', { locale: ko }),
      LIST_DATE_SEPARATOR: (date) => format(date, 'yyyy. M. d. (EEE)', { locale: ko }),
    },
    GROUP_CHANNEL_LIST: {
      CHANNEL_PREVIEW_TITLE_CAPTION: (channel) =>
        format(new Date(channel.lastMessage?.createdAt ?? channel.createdAt), 'M/d HH:mm', { locale: ko }),
    },
  },
});
```
(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native/src/localization/StringSet.type.ts#L113-L124 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native/src/localization/StringSet.type.ts#L218-L224 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native/src/localization/createBaseStringSet.ts#L117-L130 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-utils/src/ui-format/common.ts#L63-L77 — default patterns)

### Right-to-left (RTL)
UIKit for React Native has no RTL prop; it follows React Native's `I18nManager.isRTL`. Text aligns to the right and direction icons (send, reply, back arrows, chevrons) are mirrored in RTL. Your app turns RTL on with React Native's `I18nManager.allowRTL(true)` at startup, or `I18nManager.forceRTL(true)` to force it, and React Native applies the change only after the app restarts. The public UIKit sample calls `allowRTL(true)` at startup.

```tsx
import { I18nManager } from 'react-native';

I18nManager.allowRTL(true); // RTL follows the device language; takes effect after a restart
```
(source: https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/components/Text/index.tsx#L11-L52 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/packages/uikit-react-native-foundation/src/components/Icon/index.tsx#L13-L49 — mirrored icons ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/sample/index.js#L15 ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/sample/src/screens/UIKitLocalConfigsScreen.tsx#L24-L32 — restart note ; https://github.com/sendbird/sendbird-uikit-react-native/blob/v3.12.11/CHANGELOG.md#L271-L285 — 3.8.0 RTL entries ; https://reactnative.dev/docs/i18nmanager)

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
- React: the dark accent is `--sendbird-dark-primary-200`, not `-300` (see Brand colors).
- React: fonts and bubble colors are CSS overrides, not props; load your CSS after UIKit's and repeat UIKit's full selector.
- React Native: an icon replaced through `Icon.Assets` is tinted, so a full-color image turns into one color.
- React Native: RTL needs an app restart after `I18nManager.allowRTL` or `forceRTL`.
- React: a `colorSet` object created inside the render function is re-applied on every render.
- React Native: `localization.stringSet` must be a full `StringSet`; passing only the keys you change fails type-checking.
- React Native 0.87+: `StatusBar` has no `backgroundColor` or `translucent` prop; color the top view behind the status bar instead (see Status bar).
- Drive `theme` (React) or `styles.theme` (React Native) from your app state to follow system dark mode.

## Related
- UIKit: knowledge/curated/js/products/uikit.md
