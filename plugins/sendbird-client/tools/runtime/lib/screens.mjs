// Finds the chat screens of a React app for hosts/react.mjs: Sendbird UIKit's screens, or an app's
// own screens built on the Chat SDK (run.sh --chat-screens, RT_CHAT_SCREENS=1). The page logic lives
// here, apart from the driver, so tests/runtime/chat-screens runs it on local pages in Chromium
// without a Sendbird application.
//
// Every function takes a Playwright page; nothing here imports Playwright.

// UIKit's channel list, by its class names.
const UIKIT_LIST = '.sendbird-channel-list, [class*="sendbird-channel-list"]';
// The stable test ids the plugin's starters give these controls
// (templates/starters-bp/BEST_PRACTICES.md, "Stable identifiers").
const TAGGED_LIST = '[data-testid="sb_channel_list"]';
const TAGGED_OPEN = '[data-testid="sb_open_channels"]';
// An app's own channel list without a test id: a list element, or the line an empty list shows
// (a new test user has no channels yet when the screen opens).
const ANY_LIST = 'ul, ol, [role="list"], [role="listbox"]';
const EMPTY_LIST = /\bno (channels|conversations|chats)\b|(채널|대화|채팅방?)(이|가)? ?없/i;
// The button or link that opens the chat screens from a home screen.
const ENTRY_NAME = /chat|channel|message|inbox|채팅|채널|메시지|대화/i;
// Buttons an own list screen also has, which must not be taken for the entry.
const NOT_ENTRY = /\b(new|create|add|sign ?out|log ?out|close)\b|만들기|새 |로그아웃/i;

async function firstVisible(locator, max = 20) {
  const n = Math.min(await locator.count().catch(() => 0), max);
  for (let i = 0; i < n; i++) if (await locator.nth(i).isVisible().catch(() => false)) return locator.nth(i);
  return null;
}

// The channel list markers of an app's own screens, strongest first, each with what the step says.
function ownListMarkers(page) {
  return [
    { what: 'the UIKit channel list', loc: page.locator(UIKIT_LIST) },
    { what: 'sb_channel_list', loc: page.locator(TAGGED_LIST) },
    { what: 'a list on the screen', loc: page.locator(ANY_LIST), weak: true },
    { what: 'the empty channel list', loc: page.getByText(EMPTY_LIST), weak: true },
  ];
}

async function shownMarker(markers, strongOnly) {
  for (const m of markers) {
    if (strongOnly && m.weak) continue;
    if (await firstVisible(m.loc)) return m.what;
  }
  return null;
}

// The entry an own-screens app shows on its home screen: sb_open_channels first, then a button or
// link named for chat, passing over ones that create something or sign out.
async function ownEntry(page) {
  const tagged = await firstVisible(page.locator(TAGGED_OPEN));
  if (tagged) return tagged;
  for (const role of ['button', 'link']) {
    const all = page.getByRole(role, { name: ENTRY_NAME });
    const n = Math.min(await all.count().catch(() => 0), 20);
    for (let i = 0; i < n; i++) {
      const el = all.nth(i);
      if (!(await el.isVisible().catch(() => false)) || !(await el.isEnabled().catch(() => false))) continue;
      const label = ((await el.getAttribute('aria-label').catch(() => null)) || (await el.innerText().catch(() => '')) || '').trim();
      if (!NOT_ENTRY.test(label)) return el;
    }
  }
  return null;
}

// Opens the channel list and returns what showed it. The prebuilt screens sit behind a button on the
// app's home screen in most outputs. Throws when no list shows within `ms`.
export async function openChatScreen(page, chatScreens, ms = 30000) {
  if (!chatScreens) {
    const list = page.locator(UIKIT_LIST);
    if (await list.first().isVisible().catch(() => false)) return 'the UIKit channel list';
    const entry = page.getByRole('button', { name: /chat|channel|message|inbox/i }).first();
    if (await entry.isVisible().catch(() => false)) await entry.click();
    else {
      const link = page.getByRole('link', { name: /chat|channel|message|inbox/i }).first();
      if (await link.isVisible().catch(() => false)) await link.click();
    }
    await list.first().waitFor({ timeout: ms });
    return 'the UIKit channel list';
  }
  // own screens: a tagged or UIKit list counts at once; a plain list or an empty-list line counts
  // only after the entry button, when the home screen has one (its menu can be a list too)
  const markers = ownListMarkers(page);
  const strong = await shownMarker(markers, true);
  if (strong) return strong;
  const entry = await ownEntry(page);
  if (entry) await entry.click();
  const end = Date.now() + ms;
  for (;;) {
    const what = await shownMarker(markers, false);
    if (what) return what;
    if (Date.now() >= end) throw new Error(`no channel list within ${Math.round(ms / 1000)} s (UIKit list, sb_channel_list, a list element, or an empty-list line)`);
    await page.waitForTimeout(500);
  }
}

// Runs in the page (page.evaluate). True when `text` is on screen in the open conversation. In
// UIKit that is the conversation pane. On own screens it is anywhere outside the channel list: the
// list's row for the channel (the row that also shows `rowText`, the channel name) and the
// sb_channel_list container show the last message as a preview, which does not count.
export function messageShown([text, rowText]) {
  const pane = document.querySelector('.sendbird-conversation__messages');
  const scope = pane || document.body;
  const hits = Array.from(scope.querySelectorAll('*')).filter((el) => (el.textContent || '').includes(text)
    && !Array.from(el.children).some((c) => (c.textContent || '').includes(text)));
  return hits.some((el) => {
    const r = el.getBoundingClientRect();
    const s = window.getComputedStyle(el);
    if (!(r.width > 0 && r.height > 0) || s.visibility === 'hidden' || s.display === 'none') return false;
    if (pane) return true;
    if (el.closest('[data-testid="sb_channel_list"], .sendbird-channel-list')) return false;
    const row = el.closest('li, [role="listitem"], [role="option"], a, button');
    return !(row && rowText && (row.textContent || '').includes(rowText));
  });
}

// Waits until `text` shows in the open conversation (messageShown); throws after `ms`. Without own
// screens it is UIKit's conversation pane only, as before --chat-screens existed.
export async function waitInConversation(page, text, { chatScreens, rowText, ms = 30000 }) {
  if (!chatScreens) {
    await page.locator('.sendbird-conversation__messages').getByText(text, { exact: false }).first().waitFor({ timeout: ms });
    return;
  }
  await page.waitForFunction(messageShown, [text, rowText || ''], { timeout: ms, polling: 500 });
}

// The message input of an open conversation: the input the app tags sb_message_input, UIKit's text
// area, a contenteditable or textarea, or a text input the app names as a message field (an app's
// own Chat SDK screen).
export const MESSAGE_INPUT = 'input[data-testid="sb_message_input"], textarea[data-testid="sb_message_input"], '
  + '[data-testid="sb_message_input"] input, [data-testid="sb_message_input"] textarea, '
  + '.sendbird-message-input--textarea, [contenteditable="true"], textarea, '
  + 'input[aria-label*="message" i], input[placeholder*="message" i], input[name*="message" i], input[id*="message" i]';

export async function typeAndSend(page, text) {
  const tagged = page.locator('input[data-testid="sb_message_input"], textarea[data-testid="sb_message_input"], [data-testid="sb_message_input"] :is(input, textarea)');
  const input = (await tagged.count().catch(() => 0)) ? tagged.first() : page.locator(MESSAGE_INPUT).first();
  await input.waitFor({ timeout: 30000 });
  await input.click();
  await page.keyboard.type(text);
  await page.keyboard.press('Enter');
  // Enter sends in UIKit and submits a form; an input that still holds the text after that has a
  // send button of its own (not an attachment button). UIKit in mobile mode (SendbirdProvider
  // `breakpoint` matching the screen) does not send on Enter and shows an icon-only send button
  // with no accessible name. (source: sendbird-uikit-react v3.20.0 src/ui/MessageInput/index.tsx
  // lines 600-602 `!isMobile` in the Enter path, line 671 `sendbird-message-input--send` with
  // testID `sendbird-message-input-send-button`; src/ui/IconButton/index.tsx line 44 `data-testid`)
  await page.waitForTimeout(1500);
  const left = await input.evaluate((el) => (el.isContentEditable ? el.textContent : el.value) || '').catch(() => '');
  if (left.includes(text)) {
    const own = page.locator('[data-testid="sb_send_button"], [data-testid="sendbird-message-input-send-button"], .sendbird-message-input--send').first();
    const send = (await own.isVisible().catch(() => false))
      ? own
      : page.getByRole('button', { name: /send|전송|보내기/i }).filter({ hasNotText: /image|file|photo|attach/i }).first();
    await send.click({ timeout: 5000 });
  }
}
