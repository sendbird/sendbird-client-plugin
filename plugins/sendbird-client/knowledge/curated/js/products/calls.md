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

## Error codes (1800xxx range)
Web: callbacks are typed `(…, error?: Error)`, and the bundled runtime builds that error with a numeric `code` property, so compare `error.code` with the numbers below. React Native: `SendbirdError` exposes `code` and the static `SendbirdError.ErrorCode` map. (source: `sendbird-calls` 1.10.21 `SendBirdCall.min.d.ts` lines 104-173 (`ErrorCode`) and 388-397 (handlers), `SendBirdCall.min.js` (the error class sets `this.code`); `@sendbird/calls-react-native` 1.2.0 `lib/typescript/libs/SendbirdError.d.ts`; all read on 2026-10-19)

Web names are from the typings; where the runtime enum in `SendBirdCall.min.js` uses another name, or has a code the typings omit, the cell says so. React Native names are verbatim from `SendbirdError.ErrorCode`. Meanings come from the public JavaScript and React Native error-codes pages; "No public description" means neither page has an entry for that code. (source: https://sendbird.com/docs/calls/sdk/v1/javascript/features/error-codes; https://sendbird.com/docs/calls/sdk/v1/react-native/error-codes)

| Code | Web (`sendbird-calls` 1.10.21) | React Native (`SendbirdError.ErrorCode`, 1.2.0) | Meaning / typical cause |
|------|-------------------------------|-----------------------------------------------|--------------------------|
| 1800100 | `DIAL_CANCELED` | `DIAL_CANCELED` | The dialing has been canceled before receiving a callback. |
| 1800101 | `MY_USER_ID_NOT_ALLOWED` | `MY_USER_ID_NOT_ALLOWED` | The caller can't call their own user ID. |
| 1800200 | `ERR_REQUEST_FAILED` | `ERR_REQUEST_FAILED` | The request failed due to an error from the HTTP library. |
| 1800201 | `WS_NOT_CONNECTED` (typings); `ERR_WEBSOCKET_CONNECTION_NOT_OPENED` (bundle) | `ERR_WEBSOCKET_CONNECTION_NOT_OPENED` | No public description |
| 1800202 | `WS_CONNECTION_FAILED` (typings); `ERR_WEBSOCKET_CONNECTION_FAILED` (bundle) | `ERR_WEBSOCKET_CONNECTION_FAILED` | No public description |
| 1800203 | `ERR_NO_RESPONSE_DUE_TO_TIMEOUT` | `ERR_NO_RESPONSE_DUE_TO_TIMEOUT` | The request failed to receive a response due to timeout. |
| 1800204 | `ERR_REQUEST_FAILED_DUE_TO_WEBSOCKET_CONNECTION_LOST` | `ERR_REQUEST_FAILED_DUE_TO_WEBSOCKET_CONNECTION_LOST` | The request failed because the websocket connection is lost. |
| 1800205 | `ERR_WRONG_RESPONSE` | `ERR_WRONG_RESPONSE` | The response contains an unexpected object type of data. |
| 1800206 | `ERR_QUERY_IN_PROGRESS` | `ERR_QUERY_IN_PROGRESS` | The previous query is still in progress. |
| 1800207 | `INTERNAL_SERVER_ERROR` | `INTERNAL_SERVER_ERROR` | An internal server error has occurred. |
| 1800208 | `ERR_MALFORMED_DATA` | `ERR_MALFORMED_DATA` | The data format of the response is invalid. |
| 1800300 | `INVALID_PARAMETER_VALUE` | `INVALID_PARAMETER_VALUE` | The parameter specifies an invalid or empty value. |
| 1800301 | `INVALID_PARAMETER_TYPE` | `INVALID_PARAMETER_TYPE` | The data type of the parameter is invalid. |
| 1800302 | `INSTANCE_NOT_INITIALIZED` | `INSTANCE_NOT_INITIALIZED` | A SendBirdCall instance is not initialized. |
| 1800303 | `USER_NOT_AUTHENTICATED` | `USER_NOT_AUTHENTICATED` | The user is not authenticated. |
| 1800400 | `CAMERA_ALREADY_SWITCHING` (bundle only) | `CAMERA_ALREADY_SWITCHING` | No public description |
| 1800401 | `ERR_CAMERA_SWITCH` (bundle only) | `ERR_CAMERA_SWITCH` | No public description |
| 1800402 | `ERR_CHANGING_AUDIO_DEVICE` (bundle only) | `ERR_CHANGING_AUDIO_DEVICE` | No public description |
| 1800600 | `ERR_CAPTURE_NOT_ALLOWED_ON_AUDIO_CALL` | `ERR_CAPTURE_NOT_ALLOWED_ON_AUDIO_CALL` | Capturing a video view isn't allowed while on an audio call. |
| 1800601 | `ERR_VIDEO_VIEW_NOT_READY` | `ERR_VIDEO_VIEW_NOT_READY` | A video view isn't ready to be captured. |
| 1800602 | `ERR_VIDEO_CALL_NOT_CONNECTED_YET` | `ERR_VIDEO_CALL_NOT_CONNECTED_YET` | A video call isn't connected yet therefore can't capture a video view. |
| 1800603 | `ERR_FAILED_TO_GET_IMAGE_FROM_VIDEO_STREAM` | `ERR_FAILED_TO_GET_IMAGE_FROM_VIDEO_STREAM` | An error occurred while getting an image from the video stream. (docs name: `FAILED_TO_GET_IMAGE_FROM_THE_MEDIA_STREAM`) |
| 1800610 | `ERR_CALL_NOT_CONNECTED_YET` | `ERR_CALL_NOT_CONNECTED_YET` | A call isn't connected yet therefore can't start media recording. |
| 1800611 | `ERR_WRONG_RECORDING_TYPE_FOR_AUDIO_CALL` | `ERR_WRONG_RECORDING_TYPE_FOR_AUDIO_CALL` | A wrong recording type is selected in an audio call. |
| 1800612 | `ERR_RECORDING_ALREADY_IN_PROGRESS` | `ERR_RECORDING_ALREADY_IN_PROGRESS` | An ongoing recording session is already in progress. |
| 1800613 | `ERR_FAILED_TO_OPEN_FILE` | `ERR_FAILED_TO_OPEN_FILE` | A recording file cannot be opened due to an error. |
| 1800614 | `ERR_FAILED_TO_START_RECORDING` | `ERR_FAILED_TO_START_RECORDING` | A recording session cannot be started due to an error. |
| 1800615 | `ERR_FAILED_TO_STOP_RECORDING` | `ERR_FAILED_TO_STOP_RECORDING` | A recording session cannot be stopped due to an error. |
| 1800616 | `ERR_NOT_SUPPORTED_BROWSER_FOR_RECORDING` | `ERR_NOT_SUPPORTED_BROWSER_FOR_RECORDING` | Media recording is not supported on the browser. |
| 1800617 | `ERR_INVALID_RECORDING_TYPE` | `ERR_INVALID_RECORDING_TYPE` | The selected recording type is invalid. |
| 1800618 | `ERR_NOT_SUPPORTED_OS_VERSION_FOR_RECORDING` | `ERR_NOT_SUPPORTED_OS_VERSION_FOR_RECORDING` | Media recording is not supported on the operating system version. (React Native docs: Android only) |
| 1800620 | `ERR_SCREEN_SHARE_RESTRICTED_FROM_AUDIO_CALL` | `ERR_SCREEN_SHARE_RESTRICTED_FROM_AUDIO_CALL` | Screen share is restricted from audio calls. |
| 1800621 | `ERR_SCREEN_SHARE_REQUEST_BEFORE_CALL_IS_CONNECTED` | `ERR_SCREEN_SHARE_REQUEST_BEFORE_CALL_IS_CONNECTED` | A call isn't connected yet, but the request for screen share has been made. |
| 1800622 | `ERR_SCREEN_SHARE_ALREADY_IN_PROGRESS` | `ERR_SCREEN_SHARE_ALREADY_IN_PROGRESS` | The user is trying to share the screen while the previous request is still in progress. |
| 1800623 | `ERR_NO_SCREEN_SHARE_EXISTS` | `ERR_NO_SCREEN_SHARE_EXISTS` | Screen share doesn't exist but the request to stop sharing the screen has been made. |
| 1800624 | - | `ERR_NOT_SUPPORTED_OS_VERSION_FOR_SCREEN_SHARE` | The operating system version doesn't support screen share. (React Native docs: Android only) |
| 1800625 | `ERR_NOT_SUPPORTED_BROWSER_FOR_SCREEN_SHARE` | `ERR_NOT_SUPPORTED_BROWSER_FOR_SCREEN_SHARE` | The browser doesn't support screen share. |
| 1800626 | `ERR_SCREEN_SHARE_FAILED_DUE_TO_UNKNOWN_REASON` | `ERR_SCREEN_SHARE_FAILED_DUE_TO_UNKNOWN_REASON` | Screen share failed due to unknown reason. |
| 1800627 | `ERR_NOT_SUPPORTED_APP_STATE_FOR_SCREEN_SHARE` | `ERR_NOT_SUPPORTED_APP_STATE_FOR_SCREEN_SHARE` | The application state doesn't support screen share. |
| 1800628 | `ERR_PERMISSION_DENIED_FOR_SCREEN_SHARE` | `ERR_PERMISSION_DENIED_FOR_SCREEN_SHARE` | An access permission denied for screen share. |
| 1800629 | `ERR_SELECTED_CONTENT_NOT_EXIST` | `ERR_SELECTED_CONTENT_NOT_EXIST` | The selected content for screen share doesn't exist. |
| 1800630 | `ERR_SELECTED_CONTENT_INACCESSIBLE` | `ERR_SELECTED_CONTENT_INACCESSIBLE` | The selected content for screen share is inaccessible by the system. |
| 1800631 | `ERR_MEDIA_STREAM_NOT_ALLOWED_ON_HOLD` (bundle only) | `ERR_MEDIA_STREAM_NOT_ALLOWED_ON_HOLD` | No public description |
| 1800700 | `ERR_PARTICIPANT_ALREADY_IN_ROOM` | `ERR_PARTICIPANT_ALREADY_IN_ROOM` | The participant is trying to enter the same room they're already in. |
| 1800701 | `ERR_ENTERING_ROOM_STILL_IN_PROGRESS` | `ERR_ENTERING_ROOM_STILL_IN_PROGRESS` | The participant is trying to enter the room while the previous request is still in progress. |
| 1800702 | `ERR_PARTICIPANT_NOT_IN_ROOM` | `ERR_PARTICIPANT_NOT_IN_ROOM` | The participant is not in the room and the request can't be processed. |
| 1800703 | `ERR_EXITING_ROOM_STILL_IN_PROGRESS` | `ERR_EXITING_ROOM_STILL_IN_PROGRESS` | No public description |
| 1800704 | `ERR_FAILED_TO_ESTABLISH_CONNECTION_TO_SEND_STREAM` | `ERR_FAILED_TO_ESTABLISH_CONNECTION_TO_SEND_STREAM` | No public description |
| 1800705 | `ERR_FAILED_TO_ESTABLISH_CONNECTION_TO_RECEIVE_STREAM` | `ERR_FAILED_TO_ESTABLISH_CONNECTION_TO_RECEIVE_STREAM` | No public description |
| 1800706 | `ERR_LOCAL_PARTICIPANT_LOST_CONNECTION` | `ERR_LOCAL_PARTICIPANT_LOST_CONNECTION` | The local participant exited the room due to lost connection. |
| 1800707 | `ERR_LOCAL_PARTICIPANT_KICKED_OUT` (bundle only) | - | No public description |
| 1800801 | `ERR_CALL_ALREADY_ON_HOLD` (bundle only) | `ERR_CALL_ALREADY_ON_HOLD` | No public description |
| 1800802 | `ERR_ACTIVE_CALL_IN_PROGRESS` (bundle only) | `ERR_ACTIVE_CALL_IN_PROGRESS` | No public description |
| 1800803 | `ERR_ANOTHER_CALL_IN_PROGRESS` (bundle only) | `ERR_ANOTHER_CALL_IN_PROGRESS` | No public description |

- On Web, compare the number in `error.code`: the typings and the runtime enum disagree on the names for 1800201 and 1800202, and the typings omit 1800400-1800402, 1800631, 1800707 and 1800801-1800803. (source: the files above)
- The JavaScript page names 1800603 `FAILED_TO_GET_IMAGE_FROM_THE_MEDIA_STREAM`; both SDKs ship `ERR_FAILED_TO_GET_IMAGE_FROM_VIDEO_STREAM`.
- 1800616, 1800618, 1800624 and 1800625 are platform specific: browser recording and browser screen share are Web only, and the OS-version codes are Android only, per the React Native page. (source: https://sendbird.com/docs/calls/sdk/v1/react-native/error-codes)
- The same number can mean something else on another platform. 1800802 is `ERR_ACTIVE_CALL_IN_PROGRESS` here, and `callNotPutOnHoldByLocalUser` / `ERR_CALL_NOT_PUT_ON_HOLD_BY_LOCAL_USER` in the iOS and Android SDKs. Interpret a code with the enum of the platform that raised it.
- The same pages list the server-side codes (for example 400100, 1400126, 500999) in a second table; those are outside the 1800xxx range and are not repeated here. (source: https://sendbird.com/docs/calls/sdk/v1/javascript/features/error-codes)

## Pitfalls
- Web: call `connectWebSocket()` after `authenticate`, or events won't arrive.
- App ID from env; access token is a secret — never hard-code. React Native incoming calls need push tokens even while the app is open, because the iOS and Android SDKs underneath deliver new incoming calls only through push (see knowledge/curated/ios/products/calls.md and knowledge/curated/android/products/calls.md).

## Related
- Web repo: https://github.com/sendbird/sendbird-calls-javascript
- React Native repo: https://github.com/sendbird/sendbird-calls-sdk-react-native
