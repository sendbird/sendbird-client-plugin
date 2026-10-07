<!-- status: populated -->
# templates/js/react-native/calls

Sendbird Calls (voice/video) on React Native (`@sendbird/calls-react-native`). From the
public RN README (verified 2026-06-09). Symbols quoted from the quickstart; full RN `tsc`
not run in-repo (needs a react-native env).

## Files
- `setup.ts` — `initCalls()` / `authenticate(...)`.

## How to splice
1. Install `@sendbird/calls-react-native` + its native peers per the quickstart.
2. `initCalls()`, then `authenticate(...)`.
3. Background calls: `registerPushToken(fcmToken)` (Android/APNs) / `ios_registerVoIPPushToken(voipToken)` (iOS VoIP).
4. App ID read per the profile `tier2.appIdSource` (knowledge/curated/js/setup.md "App ID") — never ask the customer to add a bundler; access token is a secret.

## Variations (see knowledge/curated/js/products/calls.md, all cited)
- Direct call dial + listeners follow the RN quickstart.
