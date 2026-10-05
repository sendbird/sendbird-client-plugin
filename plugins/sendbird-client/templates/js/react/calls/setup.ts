// source: https://github.com/sendbird/sendbird-calls-javascript (README implementation guide, verified 2026-06-09)
// Type-checked against sendbird-calls (tsc --noEmit clean). App ID/user from env; tokens are secrets.
// Needs esModuleInterop=true for the default import (else: import * as SendBirdCall from 'sendbird-calls').

import SendBirdCall from 'sendbird-calls';

const APP_ID = process.env.NEXT_PUBLIC_SENDBIRD_APP_ID as string;

export function initCalls() {
  SendBirdCall.init(APP_ID);
}

export function authenticate(userId: string, accessToken?: string) {
  return new Promise<void>((resolve, reject) => {
    SendBirdCall.authenticate({ userId, accessToken }, (_res, error) => {
      if (error) return reject(error);
      SendBirdCall.connectWebSocket().then(resolve).catch(reject);  // required after auth
    });
  });
}

// Make a 1:1 direct call.
export function dial(calleeId: string, isVideoCall = false) {
  return SendBirdCall.dial({ userId: calleeId, isVideoCall, callOption: {} }, (call, error) => {
    if (error) console.error('dial failed', error);
  });
}
