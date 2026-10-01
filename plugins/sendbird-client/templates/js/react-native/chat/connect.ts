// source: https://sendbird.com/docs/chat/sdk/v4/javascript/getting-started/send-first-message (verified 2026-06-09)
// The core @sendbird/chat package is platform-agnostic — identical init/connect on React Native.
// Type-checked against @sendbird/chat. app_id from env, never hard-code; tokens are secrets.
//   - SendbirdChat.init({ appId, modules: [new GroupChannelModule()] })
//   - sb.connect(userId) / sb.connect(userId, accessToken)

import SendbirdChat from '@sendbird/chat';
import { GroupChannelModule } from '@sendbird/chat/groupChannel';

const APP_ID = process.env.SENDBIRD_APP_ID as string;

export const sb = SendbirdChat.init({
  appId: APP_ID,
  modules: [new GroupChannelModule()],
});

export async function connectUser(userId: string, accessToken?: string) {
  return accessToken ? sb.connect(userId, accessToken) : sb.connect(userId);
}

// Send: const channel = ...; channel.sendUserMessage({ message: TEXT })
//   .onSucceeded((m) => {}).onFailed((err, m) => {});
