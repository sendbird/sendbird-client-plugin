<!-- status: populated -->
# templates/js/react-native/uikit

Sendbird UIKit on React Native (`@sendbird/uikit-react-native`). Container usage from the
public sample + docs-validation (verified 2026-06-09). `SendbirdUIKitContainer`,
`chatOptions.localCacheStorage`, and the public sample's native-service factory are type-checked by `compile-check-js.sh`.

## Files
- `App.tsx` — `<SendbirdUIKitContainer appId platformServices>`.
- `factory.ts` — native clipboard, notification, file, media, player, and recorder services from the public sample.

## How to splice
1. Install the package + its peers/native modules per the quickstart (foundation, chat, RN modules).
2. Build `platformServices` from the SDK's `createNative*Service` factories — follow the quickstart, do not guess.
3. App ID read per the profile `tier2.appIdSource` (knowledge/curated/js/setup.md "App ID") — never ask the customer to add a bundler; tokens are secrets.

## Variations (see knowledge/curated/js/products/uikit.md, all cited)
- Add UIKit fragments (e.g. group channel list) inside the container with navigation.
