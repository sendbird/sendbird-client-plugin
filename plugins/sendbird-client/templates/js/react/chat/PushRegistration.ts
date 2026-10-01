// source: @sendbird/chat 4.22.12 shipped type declarations
import type SendbirdChat from '@sendbird/chat';

export async function registerFcmToken(sb: SendbirdChat, token: string) {
  return sb.registerFCMPushTokenForCurrentUser(token);
}

export async function registerApnsToken(sb: SendbirdChat, token: string) {
  return sb.registerAPNSPushTokenForCurrentUser(token);
}

export async function unregisterPushTokens(sb: SendbirdChat, fcmToken: string, apnsToken: string) {
  await sb.unregisterFCMPushTokenForCurrentUser(fcmToken);
  await sb.unregisterAPNSPushTokenForCurrentUser(apnsToken);
}
