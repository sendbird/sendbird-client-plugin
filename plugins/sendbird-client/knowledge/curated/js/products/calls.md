<!-- last-verified-against: sendbird-calls 1.10.21 / @sendbird/calls-react-native 1.2.0 -->
<!-- status: populated -->
# js calls

> Verified against the public mirrors `sendbird/sendbird-calls-javascript` + `sendbird/sendbird-calls-sdk-react-native` (README implementation guides, verified 2026-06-09). Web init + authenticate type-checked against `sendbird-calls`. React Native quoted from the RN README. Cite each symbol; do not add API from memory.
> Sources: https://github.com/sendbird/sendbird-calls-javascript , https://github.com/sendbird/sendbird-calls-sdk-react-native

## Web (`sendbird-calls`)
Install: `npm install sendbird-calls`.
```ts
import SendBirdCall from 'sendbird-calls';   // needs esModuleInterop; else: import * as SendBirdCall from 'sendbird-calls'

SendBirdCall.init(APP_ID);

const authOption = { userId: USER_ID, accessToken: ACCESS_TOKEN };
SendBirdCall.authenticate(authOption, (res, error) => {
  if (!error) SendBirdCall.connectWebSocket();   // required after auth
});

SendBirdCall.addListener(UNIQUE_HANDLER_ID, {
  onRinging: (call) => { /* incoming */ },
});

const dialParams = { userId: CALLEE_ID, isVideoCall: false, callOption: {} };
const call = SendBirdCall.dial(dialParams, /* (call, error) => {} */);
```
The browser prompts for mic/camera on first call / `SendBirdCall.useMedia()`. (source: sendbird-calls-javascript README §authenticate/dial; init + authenticate type-checked)

### Web: receive, accept, and end a call
Accept or decline in `onRinging` with `call.accept(...)` or `call.end()`. Give the call a remote media element (a `<video>` or `<audio>` element that plays automatically): "The remoteMediaView is required for the remote media stream to be displayed."

```ts
import SendBirdCall from 'sendbird-calls';

SendBirdCall.addListener(UNIQUE_HANDLER_ID, {
  onRinging: (call) => {
    call.onConnected = () => { /* media connected */ };
    call.onEnded = () => { /* ended on either side */ };
    call.accept({
      callOption: {
        localMediaView: document.getElementById('local_video') as HTMLMediaElement,
        remoteMediaView: document.getElementById('remote_video') as HTMLMediaElement,
        audioEnabled: true,
        videoEnabled: call.isVideoCall,
      },
    }); // call.end() declines instead
  },
});
```

(source: sendbird-calls 1.10.21 README.md "Receive a call" and "media viewer") (sendbird-calls 1.10.21 `SendBirdCall.min.d.ts`: `AcceptParams { callOption }`, `DirectCallOption { localMediaView, remoteMediaView, audioEnabled, videoEnabled }`, `DirectCall.accept(params)`, `end()`, `isVideoCall`, `onConnected`, `onEnded`)

`call.end()` also hangs up a connected call and cancels an outgoing one. Things seen when running two browsers against a test application (2026-10-08 and 2026-10-17):
- Use the default import shown above. A browser run that used `import * as SendBirdCall from 'sendbird-calls'` type-checked but failed at runtime: `SendBirdCall.init` was not a function on the namespace import.
- Dial only after the callee has authenticated: a dial right after the callee signed in failed with an error saying the callee had not authenticated to Calls yet, and the same dial a few seconds later rang.
- `templates/js/react/calls/` has these calls wrapped (`setup.ts`) and a ready call screen (`DirectCallPanel.tsx`); with them, a voice call and a video call between two browsers rang, connected with live remote audio (and video), and ended on both sides.

## React Native (`@sendbird/calls-react-native`)
```ts
import { SendbirdCalls } from '@sendbird/calls-react-native';

SendbirdCalls.initialize(APP_ID);
await SendbirdCalls.authenticate({ userId: USER_ID, accessToken: ACCESS_TOKEN });
// push: SendbirdCalls.registerPushToken(fcmToken) (Android/APNs) / SendbirdCalls.ios_registerVoIPPushToken(voipToken) (iOS VoIP)
```
(source: sendbird-calls-sdk-react-native README §authenticate)

### React Native: dial, receive, accept, and end a call
The SDK hands over call properties; get the `DirectCall` with `SendbirdCalls.getDirectCall()` before calling `accept()` or `end()`.

```ts
import { SendbirdCalls } from '@sendbird/calls-react-native';

SendbirdCalls.setListener({
  async onRinging(callProps) {
    const directCall = await SendbirdCalls.getDirectCall(callProps.callId);
    directCall.addListener({ onEnded: () => { /* ended on either side */ } });
    await directCall.accept({ audioEnabled: true, videoEnabled: directCall.isVideoCall }); // directCall.end() declines
  },
});

const callProps = await SendbirdCalls.dial(CALLEE_ID, false, { audioEnabled: true, videoEnabled: false });
const outgoing = await SendbirdCalls.getDirectCall(callProps.callId);
await outgoing.end(); // hang up or cancel
```

(source: @sendbird/calls-react-native 1.2.0 README.md "Receive a call", "Make a call") (@sendbird/calls-react-native 1.2.0 `lib/typescript`: `SendbirdCallsModule.d.ts` `setListener` 237, `getDirectCall` 127, `dial` 179; `DirectCall.d.ts` `addListener` 52, `accept(options?, holdActiveCall?)` 58, `end()` 66; `types/Call.d.ts` `CallOptions` 325)

### React Native: camera and microphone permissions
Calls needs system permission for the camera and microphone. On iOS, add `NSMicrophoneUsageDescription` and `NSCameraUsageDescription` to the app's `Info.plist`. On Android the permissions are declared in the React Native module's `AndroidManifest.xml`, and the docs request them at runtime with `react-native-permissions`, including `BLUETOOTH_CONNECT` on Android. Ask before the first dial or accept.

```ts
import { Platform } from 'react-native';
import Permissions, { PERMISSIONS } from 'react-native-permissions';

const CALL_PERMISSIONS = Platform.select({
  android: [PERMISSIONS.ANDROID.CAMERA, PERMISSIONS.ANDROID.RECORD_AUDIO, PERMISSIONS.ANDROID.BLUETOOTH_CONNECT],
  ios: [PERMISSIONS.IOS.CAMERA, PERMISSIONS.IOS.MICROPHONE],
  default: [],
});

const result = await Permissions.requestMultiple(CALL_PERMISSIONS);
```
(source: https://sendbird.com/docs/calls/sdk/v1/react-native/getting-started/make-first-call — Step 2)

## Sign out
"When users log out of their call client apps, they must be deauthenticated with `SendBirdCall.deauthenticate()` method." (source: sendbird-calls 1.10.21 README.md:656)

```ts
import SendBirdCall from 'sendbird-calls';

SendBirdCall.deauthenticate();
```

On the web it returns `void` (source: sendbird-calls 1.10.21 `SendBirdCall.min.d.ts:7`). In React Native it returns a promise:

```ts
import { SendbirdCalls } from '@sendbird/calls-react-native';

await SendbirdCalls.deauthenticate();
```

(source: @sendbird/calls-react-native 1.2.0 `lib/typescript/libs/SendbirdCallsModule.d.ts:146`)

## Manual steps (what a Calls hand-off may list)
Only these Calls steps need something outside the project, and each has a source:
- **App ID:** create a Sendbird application and copy its App ID from the dashboard; it is case-sensitive. (source: https://sendbird.com/docs/calls/sdk/v1/javascript/getting-started/make-first-call , https://sendbird.com/docs/calls/sdk/v1/react-native/getting-started/make-first-call)
- **Token server, only when the app signs users in with tokens:** access or session tokens are issued through the Chat Platform API, not the dashboard. (source: https://sendbird.com/docs/calls/sdk/v1/javascript/features/authentication)
- **Push credentials, React Native only, to receive calls:** the APNs certificate (iOS) and the FCM credential (Android) in the dashboard under Settings > Calls > Push notifications > Add credential, tested on real devices. (source: https://sendbird.com/docs/calls/sdk/v1/react-native/getting-started/make-first-call , https://sendbird.com/docs/calls/sdk/v1/react-native/direct-call/adding-push-notifications/add-push-notifications) The web SDK needs no push to receive calls while its WebSocket is connected.

None of these pages, nor the Authentication pages, has a dashboard step that enables or activates Calls (checked 2026-10-17). Do not tell the customer to "enable Calls in the dashboard", and do not add any other dashboard step that no page cited here lists.

## Pitfalls
- Web: call `connectWebSocket()` after `authenticate`, or events won't arrive.
- App ID from env; access token is a secret — never hard-code. React Native incoming calls need push tokens even while the app is open, because the iOS and Android SDKs underneath deliver new incoming calls only through push (see knowledge/curated/ios/products/calls.md and knowledge/curated/android/products/calls.md).

## Related
- Web repo: https://github.com/sendbird/sendbird-calls-javascript
- React Native repo: https://github.com/sendbird/sendbird-calls-sdk-react-native
