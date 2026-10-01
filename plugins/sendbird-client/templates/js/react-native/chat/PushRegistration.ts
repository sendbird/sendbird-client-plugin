// source: @sendbird/chat 4.22.12 shipped type declarations
import type SendbirdChat from '@sendbird/chat';

export async function registerNativePushToken(
  sb: SendbirdChat,
  platform: 'android' | 'ios',
  token: string,
) {
  return platform === 'android'
    ? sb.registerFCMPushTokenForCurrentUser(token)
    : sb.registerAPNSPushTokenForCurrentUser(token);
}

export async function unregisterAllNativePushTokens(sb: SendbirdChat, platform: 'android' | 'ios') {
  return platform === 'android'
    ? sb.unregisterFCMPushTokenAllForCurrentUser()
    : sb.unregisterAPNSPushTokenAllForCurrentUser();
}
