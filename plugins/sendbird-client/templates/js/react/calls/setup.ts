// source: https://github.com/sendbird/sendbird-calls-javascript/blob/1.10.21/README.md (README implementation guide:
//   authenticate + connectWebSocket, addListener/onRinging, dial, accept/end, deauthenticate; verified 2026-10-17)
// sendbird-calls 1.10.21 SendBirdCall.min.d.ts (verified 2026-10-17): init, authenticate, deauthenticate (returns void),
//   connectWebSocket, addListener, removeListener, dial(DialParams, DialHandler): DirectCall,
//   DialParams { userId, isVideoCall, callOption }, AcceptParams { callOption },
//   DirectCallOption { localMediaView, remoteMediaView, audioEnabled, videoEnabled },
//   DirectCall.accept(AcceptParams) / end() / isVideoCall / onEstablished / onConnected / onEnded.
// Type-checked against sendbird-calls (tools/templates/compile-check-js.sh). App ID/user from env; tokens are secrets.
// Use the default import: the browser build exposes the API on the default export only
// (with `import * as`, SendBirdCall.init is not a function at runtime). Needs esModuleInterop=true.

import SendBirdCall from 'sendbird-calls';
import type { DirectCall } from 'sendbird-calls';

const APP_ID = process.env.NEXT_PUBLIC_SENDBIRD_APP_ID as string;

export type { DirectCall };

/** The <video> or <audio> elements that show a call. `remote` is required to hear or see the other side. */
export type CallMediaViews = { local?: HTMLMediaElement | null; remote?: HTMLMediaElement | null };

export function initCalls() {
  SendBirdCall.init(APP_ID);
}

// Call from the app's sign-in code (onLoginSucceeded), after the Chat connect when the app uses Chat.
export function authenticate(userId: string, accessToken?: string) {
  return new Promise<void>((resolve, reject) => {
    SendBirdCall.authenticate({ userId, accessToken }, (_res, error) => {
      if (error) return reject(error);
      SendBirdCall.connectWebSocket().then(resolve).catch(reject);  // required after auth
    });
  });
}

// Call from the app's sign-out code (onLogout) so this browser stops ringing for the user.
export function signOut() {
  SendBirdCall.deauthenticate();
}

// Incoming calls arrive only while the WebSocket is connected; add the listener right after initCalls().
export function listenForCalls(handlerId: string, onRinging: (call: DirectCall) => void) {
  SendBirdCall.addListener(handlerId, { onRinging });
  return () => SendBirdCall.removeListener(handlerId);
}

function callOption(isVideoCall: boolean, views: CallMediaViews) {
  return {
    localMediaView: views.local ?? undefined,
    remoteMediaView: views.remote ?? undefined,
    audioEnabled: true,
    videoEnabled: isVideoCall,
  };
}

// Make a 1:1 direct call. The browser asks for the microphone (and camera for video) on the first call.
export function dial(calleeId: string, isVideoCall = false, views: CallMediaViews = {}) {
  return SendBirdCall.dial({ userId: calleeId, isVideoCall, callOption: callOption(isVideoCall, views) }, (_call, error) => {
    if (error) console.error('dial failed', error);
  });
}

// Accept a ringing call, with video when the caller placed a video call.
export function accept(call: DirectCall, views: CallMediaViews = {}) {
  call.accept({ callOption: callOption(call.isVideoCall, views) });
}

// Hang up, cancel an outgoing call, or decline a ringing one.
export function end(call: DirectCall) {
  call.end();
}
