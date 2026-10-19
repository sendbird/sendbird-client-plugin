// source: https://github.com/sendbird/sendbird-calls-sdk-react-native/blob/v1.2.0/README.md (README: initialize, authenticate,
//   setListener/onRinging + getDirectCall, dial + getDirectCall, directCall.accept()/end(), deauthenticate; verified 2026-10-17)
// source: https://sendbird.com/docs/calls/sdk/v1/react-native/getting-started/make-first-call (Step 2: camera, microphone,
//   and BLUETOOTH_CONNECT permissions with react-native-permissions)
// @sendbird/calls-react-native 1.2.0 lib/typescript (verified 2026-10-17): SendbirdCallsModule.d.ts initialize 133,
//   authenticate 140, deauthenticate 146, getDirectCall 127, dial 179, setListener 237; DirectCall.d.ts accept 58, end 66;
//   types/Call.d.ts SendbirdCallListener.onRinging 12, DirectCallProperties.callId / isVideoCall, CallOptions 325.
// Type-checked with tools/templates/compile-check-js.sh. App ID/user from env; tokens are secrets.

import { Platform } from 'react-native';
import Permissions, { PERMISSIONS } from 'react-native-permissions';
import { SendbirdCalls, type DirectCall } from '@sendbird/calls-react-native';

const APP_ID = process.env.SENDBIRD_APP_ID as string;

export type { DirectCall };

export function initCalls() {
  SendbirdCalls.initialize(APP_ID);
}

// Call from the app's sign-in code (onLoginSucceeded), after the Chat connect when the app uses Chat.
export async function authenticate(userId: string, accessToken?: string) {
  await SendbirdCalls.authenticate({ userId, accessToken });
  // Background calls: SendbirdCalls.registerPushToken(fcmToken) (Android/APNs)
  //                   SendbirdCalls.ios_registerVoIPPushToken(voipToken) (iOS VoIP)
}

// Call from the app's sign-out code (onLogout) so this device stops ringing for the user.
export async function signOut() {
  await SendbirdCalls.deauthenticate();
}

// Ask before the first dial or accept (docs "Make first call", Step 2). iOS also needs
// NSMicrophoneUsageDescription and NSCameraUsageDescription in Info.plist.
export async function requestCallPermissions() {
  const permissions = Platform.select({
    android: [PERMISSIONS.ANDROID.CAMERA, PERMISSIONS.ANDROID.RECORD_AUDIO, PERMISSIONS.ANDROID.BLUETOOTH_CONNECT],
    ios: [PERMISSIONS.IOS.CAMERA, PERMISSIONS.IOS.MICROPHONE],
    default: [],
  });
  return Permissions.requestMultiple(permissions);
}

// The SDK hands over call properties; getDirectCall turns them into a DirectCall with accept/end/addListener
// (README: "you need to get DirectCall using SendbirdCalls.getDirectCall()"). Add it once at startup.
export function listenForCalls(onRinging: (call: DirectCall) => void) {
  SendbirdCalls.setListener({
    async onRinging(callProps) {
      onRinging(await SendbirdCalls.getDirectCall(callProps.callId));
    },
  });
}

// Make a 1:1 direct call; isVideoCall == false makes a voice call.
export async function dial(calleeId: string, isVideoCall = false) {
  const callProps = await SendbirdCalls.dial(calleeId, isVideoCall, { audioEnabled: true, videoEnabled: isVideoCall });
  return SendbirdCalls.getDirectCall(callProps.callId);
}

// Accept a ringing call, with video when the caller placed a video call.
export function accept(call: DirectCall) {
  return call.accept({ audioEnabled: true, videoEnabled: call.isVideoCall });
}

// Hang up, cancel an outgoing call, or decline a ringing one.
export function end(call: DirectCall) {
  return call.end();
}
