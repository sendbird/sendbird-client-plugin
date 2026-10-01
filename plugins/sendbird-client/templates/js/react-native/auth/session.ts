// source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication
//   (verified 2026-06-10). The @sendbird/chat core is platform-agnostic — identical on React Native.
//   Type-checked against @sendbird/chat; full RN tsc not run in-repo. Tokens are secrets.

import type SendbirdChat from '@sendbird/chat';
import { SessionHandler } from '@sendbird/chat';

export function installSessionHandler(sb: SendbirdChat, refresh: () => Promise<string>) {
  const handler = new SessionHandler();
  handler.onSessionTokenRequired = (resolve, reject) => {
    refresh().then(resolve).catch(reject);
  };
  handler.onSessionClosed = () => { /* route to login */ };
  sb.setSessionHandler(handler);
}

export async function connect(sb: SendbirdChat, userId: string, accessToken?: string) {
  return accessToken ? sb.connect(userId, accessToken) : sb.connect(userId);
}

export async function logout(sb: SendbirdChat) {
  await sb.disconnect();
}
