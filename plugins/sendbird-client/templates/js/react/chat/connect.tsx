// source: https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/send-first-message (verified 2026-06-08)
// Cross-checked: https://sendbird.com/docs/chat/sdk/v4/javascript/application/authenticating-a-user/authentication (verified 2026-06-08)
//
// Sendbird Chat JavaScript SDK v4 — init + connect (React).
// app_id comes from the environment (e.g. process.env.NEXT_PUBLIC_SENDBIRD_APP_ID),
// never hard-code it. Symbols below are taken verbatim from the docs above:
//   - default import `SendbirdChat` from '@sendbird/chat'
//   - `GroupChannelModule` from '@sendbird/chat/groupChannel'
//   - `SendbirdChat.init({ appId, modules })`
//   - `sb.connect(userId)` / `sb.connect(userId, accessToken)`

import SendbirdChat from '@sendbird/chat';
import { GroupChannelModule } from '@sendbird/chat/groupChannel';

const APP_ID = process.env.NEXT_PUBLIC_SENDBIRD_APP_ID as string;

// Initialize once and reuse the returned instance.
export const sb = SendbirdChat.init({
  appId: APP_ID,
  modules: [
    new GroupChannelModule(),
  ],
});

// Connect a user. Pass an access/session token as the optional second arg for
// authenticated apps: sb.connect(userId, accessToken).
export async function connectUser(userId: string, accessToken?: string) {
  try {
    const user = accessToken
      ? await sb.connect(userId, accessToken)
      : await sb.connect(userId);
    return user;
  } catch (err) {
    // Handle error (e.g. surface to UI, retry, or log).
    throw err;
  }
}
