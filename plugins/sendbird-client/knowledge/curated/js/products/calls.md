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

## React Native (`@sendbird/calls-react-native`)
```ts
import { SendbirdCalls } from '@sendbird/calls-react-native';

SendbirdCalls.initialize(APP_ID);
await SendbirdCalls.authenticate({ userId: USER_ID, accessToken: ACCESS_TOKEN });
// push: SendbirdCalls.registerPushToken(fcmToken) (Android/APNs) / SendbirdCalls.ios_registerVoIPPushToken(voipToken) (iOS VoIP)
```
(source: sendbird-calls-sdk-react-native README §authenticate)

## Pitfalls
- Web: call `connectWebSocket()` after `authenticate`, or events won't arrive.
- App ID from env; access token is a secret — never hard-code. RN background calls need push tokens.

## Related
- Web repo: https://github.com/sendbird/sendbird-calls-javascript
- React Native repo: https://github.com/sendbird/sendbird-calls-sdk-react-native
