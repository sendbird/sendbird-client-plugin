// User B for the runtime harness: a second Sendbird user driven from Node with the Chat SDK,
// so a test can check from the server's side what the app under test did.
// source: knowledge/curated/js/products/chat.md (SendbirdChat.init, GroupChannelModule, connect,
//   groupChannel.createChannel, sendUserMessage); @sendbird/chat@4.22.13 lib/__definition.d.ts
//   (createApplicationUserListQuery, UserOnlineState, createPreviousMessageListQuery).
// run.sh copies this file next to its own node_modules (RUNTIME_TOOLS_DIR) before running it.
//
//   node peer.mjs presence <userId> <online|offline> [timeoutSec]  wait until the user has that status
//   node peer.mjs seed <userB> <userA> <channelName> <text> [customType]
//                                                                  B opens a 1:1 channel with A and sends text
//   node peer.mjs send <userB> <channelUrl> <text>                 B sends text in the channel
//   node peer.mjs expect <userB> <channelUrl> <senderId> <text> [timeoutSec]
//   node peer.mjs touch <userB>                                     connect once so the user exists
//   node peer.mjs find-expect <userB> <userA> <text> [timeoutSec]  find B's channel with A, wait for A's text
//                                                                  wait until senderId's message with text arrives
//   node peer.mjs inspect <userB> <channelUrl> [limit]             the channel's messages with reactions, edits, files
//   node peer.mjs expect-file <userB> <channelUrl> <senderId> [timeoutSec]  wait until senderId's file message arrives
//   node peer.mjs search <userB> <channelUrl> <keyword> [timeoutSec]  the server's message search in the channel
//   node peer.mjs appinfo <userB>                                   reaction and search switches of the application
// The App ID comes from RT_APP_ID only. Prints one JSON line; exit 0 = done, 1 = failed.
import '@sendbird/chat/node';
import SendbirdChat from '@sendbird/chat';
import { GroupChannelModule } from '@sendbird/chat/groupChannel';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const out = (o) => process.stdout.write(JSON.stringify(o) + '\n');

export async function connectAs(userId) {
  const appId = process.env.RT_APP_ID;
  if (!appId) throw new Error('RT_APP_ID is not set');
  const chat = SendbirdChat.init({ appId, modules: [new GroupChannelModule()], localCacheEnabled: false, newInstance: true });
  try {
    await chat.connect(userId);
  } catch (e) {
    // The code tells the caller why, for example an application that requires an access token.
    throw new Error(`connect as ${userId} with a user ID only failed (code ${e && e.code ? e.code : 'none'}: ${e && e.message ? e.message : e})`);
  }
  return chat;
}

export async function presence(chat, userId, want, timeoutSec = 90) {
  const end = Date.now() + timeoutSec * 1000;
  let last = 'unknown';
  while (Date.now() < end) {
    const users = await chat.createApplicationUserListQuery({ userIdsFilter: [userId] }).next();
    last = users[0] ? users[0].connectionStatus : 'no-such-user';
    if (last === want) return { ok: true, status: last };
    await sleep(1500);
  }
  return { ok: false, status: last };
}

export async function seed(chat, otherId, name, text, customType) {
  const ch = await chat.groupChannel.createChannel({ invitedUserIds: [otherId], name, isDistinct: false });
  const msg = await sendText(ch, text, customType);
  return { channelUrl: ch.url, messageId: msg.messageId };
}

export function sendText(ch, text, customType) {
  return new Promise((resolve, reject) => {
    ch.sendUserMessage(customType ? { message: text, customType } : { message: text }).onSucceeded(resolve).onFailed((e) => reject(e));
  });
}

// One line per message, as the server has it now: what the rich-feature checks compare
// (reactions, an edited text, a deleted message that is gone, a file message).
export async function inspect(chat, channelUrl, limit = 50) {
  const ch = await chat.groupChannel.getChannel(channelUrl);
  const list = await ch.createPreviousMessageListQuery({ limit, includeReactions: true }).load();
  return list.map((m) => ({
    messageId: m.messageId,
    kind: m.isFileMessage() ? 'file' : m.isUserMessage() ? 'user' : 'admin',
    sender: m.sender ? m.sender.userId : null,
    message: typeof m.message === 'string' ? m.message : null,
    name: m.isFileMessage() ? m.name : null,
    type: m.isFileMessage() ? m.type : null,
    size: m.isFileMessage() ? m.size : null,
    createdAt: m.createdAt,
    updatedAt: m.updatedAt,
    reactions: (m.reactions || []).map((r) => ({ key: r.key, userIds: r.sampledUserIds, count: r.count })),
  }));
}

export async function expectMessage(chat, channelUrl, senderId, text, timeoutSec = 90) {
  const end = Date.now() + timeoutSec * 1000;
  const ch = await chat.groupChannel.getChannel(channelUrl);
  while (Date.now() < end) {
    const list = await ch.createPreviousMessageListQuery({ limit: 30 }).load();
    const hit = list.find((m) => m.sender && m.sender.userId === senderId && typeof m.message === 'string' && m.message.includes(text));
    if (hit) return { ok: true, messageId: hit.messageId };
    await sleep(1500);
  }
  return { ok: false };
}

// Direct chat: the app under test opened the 1:1 channel itself, so its URL is not known. Finds the
// channel of the connected user (B) that has otherId (A) as a member, then waits for A's text there.
export async function findExpect(chat, otherId, text, timeoutSec = 90) {
  const end = Date.now() + timeoutSec * 1000;
  let url = null;
  while (!url && Date.now() < end) {
    const list = await chat.groupChannel.createMyGroupChannelListQuery({ includeEmpty: true, limit: 50 }).next();
    const hit = list.find((c) => c.members.some((m) => m.userId === otherId));
    if (hit) url = hit.url; else await sleep(1500);
  }
  if (!url) return { ok: false, error: `no channel of ${chat.currentUser ? chat.currentUser.userId : 'user B'} has ${otherId} as a member` };
  const r = await expectMessage(chat, url, otherId, text, Math.max(5, Math.round((end - Date.now()) / 1000)));
  return { ...r, channelUrl: url };
}

async function main(argv) {
  const [cmd, ...a] = argv;
  const t0 = Date.now();
  let chat;
  try {
    switch (cmd) {
      case 'presence': {
        // Watch as a throwaway observer so the watched user's own presence is not touched.
        chat = await connectAs(`rt-observer-${Math.random().toString(36).slice(2, 8)}`);
        const r = await presence(chat, a[0], a[1], Number(a[2] || 90));
        out({ cmd, ...r, ms: Date.now() - t0 });
        return r.ok ? 0 : 1;
      }
      case 'seed': {
        chat = await connectAs(a[0]);
        const r = await seed(chat, a[1], a[2], a[3], a[4]);
        out({ cmd, ok: true, ...r, ms: Date.now() - t0 });
        return 0;
      }
      case 'send': {
        chat = await connectAs(a[0]);
        const ch = await chat.groupChannel.getChannel(a[1]);
        const m = await sendText(ch, a[2]);
        out({ cmd, ok: true, messageId: m.messageId, ms: Date.now() - t0 });
        return 0;
      }
      case 'expect': {
        chat = await connectAs(a[0]);
        const r = await expectMessage(chat, a[1], a[2], a[3], Number(a[4] || 90));
        out({ cmd, ...r, ms: Date.now() - t0 });
        return r.ok ? 0 : 1;
      }
      case 'touch': {
        // connect once so the user exists before the app opens a 1:1 channel with them
        chat = await connectAs(a[0]);
        out({ cmd, ok: true, ms: Date.now() - t0 });
        return 0;
      }
      case 'find-expect': {
        // direct chat: the app opened the channel itself; find B's channel with A, then wait for A's text
        chat = await connectAs(a[0]);
        const r = await findExpect(chat, a[1], a[2], Number(a[3] || 90));
        out({ cmd, ...r, ms: Date.now() - t0 });
        return r.ok ? 0 : 1;
      }
      case 'inspect': {
        chat = await connectAs(a[0]);
        out({ cmd, ok: true, messages: await inspect(chat, a[1], Number(a[2] || 50)), ms: Date.now() - t0 });
        return 0;
      }
      case 'expect-file': {
        // wait until senderId's file message is in the channel (an upload can take a while)
        chat = await connectAs(a[0]);
        const end = Date.now() + Number(a[3] || 90) * 1000;
        let hit = null;
        while (!hit && Date.now() < end) {
          hit = (await inspect(chat, a[1], 30)).find((m) => m.kind === 'file' && m.sender === a[2]);
          if (!hit) await sleep(2000);
        }
        out({ cmd, ok: !!hit, ...(hit ? { message: hit } : {}), ms: Date.now() - t0 });
        return hit ? 0 : 1;
      }
      case 'search': {
        // the server's message search (what an app's search screen asks for), retried while the
        // new message is indexed
        chat = await connectAs(a[0]);
        const end = Date.now() + Number(a[3] || 60) * 1000;
        let hits = [];
        let error = null;
        while (Date.now() < end) {
          try {
            hits = await chat.createMessageSearchQuery({ keyword: a[2], channelUrl: a[1], limit: 20 }).next();
            error = null;
          } catch (e) { error = `${e && e.code ? e.code + ' ' : ''}${e && e.message ? e.message : e}`; }
          if (hits.length > 0) break;
          await sleep(3000);
        }
        const found = hits.map((m) => ({ messageId: m.messageId, sender: m.sender ? m.sender.userId : null, message: m.message }));
        out({ cmd, ok: found.length > 0, hits: found, ...(error ? { error } : {}), ms: Date.now() - t0 });
        return found.length > 0 ? 0 : 1;
      }
      case 'appinfo': {
        // the application's switches the rich features depend on (UIKit hides reactions and
        // message search when they are off)
        chat = await connectAs(a[0]);
        const info = chat.appInfo || {};
        out({ cmd, ok: true, useReaction: info.useReaction, applicationAttributes: info.applicationAttributes,
          premiumFeatureList: info.premiumFeatureList, uploadSizeLimit: info.uploadSizeLimit, ms: Date.now() - t0 });
        return 0;
      }
      default:
        out({ cmd, ok: false, error: 'usage: peer.mjs presence|seed|send|expect|touch|find-expect|inspect|expect-file|search|appinfo ...' });
        return 64;
    }
  } catch (e) {
    out({ cmd, ok: false, error: `${e && e.code ? e.code + ' ' : ''}${e && e.message ? e.message : e}` });
    return 1;
  } finally {
    if (chat) await chat.disconnect().catch(() => {});
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main(process.argv.slice(2)).then((code) => process.exit(code));
}
