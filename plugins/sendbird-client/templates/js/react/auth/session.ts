// source: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication
//   (verified 2026-06-10). Type-checked against @sendbird/chat (tsc --noEmit clean):
//   SessionHandler import + onSession* callbacks + sb.connect / sb.setSessionHandler / sb.disconnect.
// Auth is part of Chat. App ID/user from env; tokens are secrets — never hard-code.

import type SendbirdChat from '@sendbird/chat';
import { SessionHandler } from '@sendbird/chat';

// Set the session handler before connecting.
export function installSessionHandler(sb: SendbirdChat, refresh: () => Promise<string>) {
  const handler = new SessionHandler();
  handler.onSessionTokenRequired = (resolve, reject) => {
    refresh().then(resolve).catch(reject);   // resolve(NEW_TOKEN); resolve(null) to skip
  };
  handler.onSessionClosed = () => { /* route to login */ };
  handler.onSessionRefreshed = () => {};
  handler.onSessionError = () => {};
  sb.setSessionHandler(handler);
}

export async function connect(sb: SendbirdChat, userId: string, accessToken?: string) {
  return accessToken ? sb.connect(userId, accessToken) : sb.connect(userId);
}

export async function logout(sb: SendbirdChat) {
  await sb.disconnect();
}
