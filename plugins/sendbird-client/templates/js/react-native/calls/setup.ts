// source: https://github.com/sendbird/sendbird-calls-sdk-react-native (README, verified 2026-06-09)
// Symbols quoted from the RN quickstart; full RN tsc not run in-repo (needs a react-native env).
// App ID/user from env; tokens are secrets.

import { SendbirdCalls } from '@sendbird/calls-react-native';

const APP_ID = process.env.SENDBIRD_APP_ID as string;

export function initCalls() {
  SendbirdCalls.initialize(APP_ID);
}

export async function authenticate(userId: string, accessToken?: string) {
  await SendbirdCalls.authenticate({ userId, accessToken });
  // Background calls: SendbirdCalls.registerPushToken(fcmToken) (Android/APNs)
  //                   SendbirdCalls.ios_registerVoIPPushToken(voipToken) (iOS VoIP)
}
