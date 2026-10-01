<!-- last-verified-against: @sendbird/uikit-react 3.19.1 / @sendbird/uikit-react-native 3.12.9 -->
<!-- verified-at: 2026-09-22 -->
<!-- verification-method: compile-check-js -->
<!-- status: populated -->
# js — theme (UIKit)

> Verified against official UIKit theme resources and pinned/latest React and React Native template type-checks on 2026-09-22. Used by `/sendbird-client:ui-customize`. Do not invent API.

## Light / dark (React)
```tsx
<App userId={userId} appId={appId} theme="dark" />   // "light" | "dark"
```
The same `theme` prop works on `SendBirdProvider`. (source: sendbird.com/docs UIKit v3 react theme-and-style-resources)

## Custom colors
UIKit React exposes CSS custom properties (`--sendbird-*`) and a color set; override them in your stylesheet or via the provider's color configuration. See the React color-resources guide. (source: sendbird.com/docs UIKit v3 react color-resources)

## React Native
`@sendbird/uikit-react-native` themes via `@sendbird/uikit-react-native-foundation` (`LightUIKitTheme` / `DarkUIKitTheme`) passed to the container's styles. (source: sendbird-uikit-react-native sample App.tsx imports `LightUIKitTheme`/`DarkUIKitTheme` from `@sendbird/uikit-react-native-foundation`)

## Pitfalls
- React: import the UIKit CSS (`@sendbird/uikit-react/dist/index.css`) or theming has nothing to style.
- Drive `theme` from your app state to follow system/dark mode.

## Related
- UIKit: knowledge/curated/js/products/uikit.md
- AI Agent theme: knowledge/curated/js/cross-cutting/ai-agent-theme.md
