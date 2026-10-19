// React (web) host driver for tools/runtime/run.sh. Serves the project with Vite, drives user A
// and user B in two Chromium contexts with Playwright, and uses the Node peer (peer.mjs) as the
// server-side check: A's presence, the channel B opens with A, and the messages each side sends.
// run.sh copies this file into RUNTIME_TOOLS_DIR (next to playwright, vite, @sendbird/chat).
//
// Environment (set by run.sh): RT_WORK (project copy), RT_OUT (results), RT_USER_A, RT_USER_B,
// RT_CHAT_UI (1 when the project has a Sendbird UIKit dependency), RT_EXPECT_TEXT /
// RT_EXPECT_SELECTOR (customization markers, newline-separated), RT_ENV_NAMES (env var names
// that receive the App ID), RT_APP_ID.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
import { connectAs, presence, seed, expectMessage } from './peer.mjs';
import { describeButtons, pickSubmit } from './signin.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const work = process.env.RT_WORK;
const outDir = process.env.RT_OUT;
const userA = process.env.RT_USER_A;
const userB = process.env.RT_USER_B;
const chatUI = process.env.RT_CHAT_UI === '1';
const expectTexts = (process.env.RT_EXPECT_TEXT || '').split('\n').filter(Boolean);
const expectSelectors = (process.env.RT_EXPECT_SELECTOR || '').split('\n').filter(Boolean);
// digits only: a letter tag hit the test app's profanity filter (server stored asterisks, 2026-10-14)
const tag = String(Math.floor(Math.random() * 1e6)).padStart(6, '0');
const channelName = `rt-chan-${tag}`;
const textB1 = `hello A from B ${tag}`;
const textA1 = `hello B from A ${tag}`;
const SHOTS = path.join(outDir, 'screens');
fs.mkdirSync(SHOTS, { recursive: true });

const stepsFile = path.join(outDir, 'steps.jsonl');
let shotN = 0;
function step(name, ok, detail = '', shot = null) {
  fs.appendFileSync(stepsFile, JSON.stringify({ step: name, ok, detail, screenshot: shot }) + '\n');
  console.log(`step ${name}: ${ok === null ? 'n/a' : ok ? 'ok' : 'FAIL'}${detail ? ' — ' + detail : ''}`);
}
async function shot(page, name) {
  const file = `${String(++shotN).padStart(2, '0')}-${name}.png`;
  await page.screenshot({ path: path.join(SHOTS, file), fullPage: false }).catch(() => {});
  return `screens/${file}`;
}

function freePort() {
  return new Promise((resolve) => {
    const s = net.createServer();
    s.listen(0, '127.0.0.1', () => { const { port } = s.address(); s.close(() => resolve(port)); });
  });
}

// --- the page that hosts the app -----------------------------------------------------------
// A project that already has index.html (a starter) is served as is and signed in through its
// own sign-in form. A project without one (the e2e fixtures have no page and no sign-in screen)
// gets a harness page whose entry first loads the sign-in module, then the app's entry, waits until
// the app has drawn its first screen, and then calls the app's own onLoginSucceeded(userId): the
// same call a sign-in screen makes after the user taps "Sign in". Signing in before the first render
// would hide an app whose screen never updates when the user signs in.
function findFile(cands) { return cands.find((c) => fs.existsSync(path.join(work, c))); }
function findLoginModule() {
  const stack = ['src'];
  while (stack.length) {
    const d = stack.pop();
    const abs = path.join(work, d);
    if (!fs.existsSync(abs)) continue;
    for (const e of fs.readdirSync(abs, { withFileTypes: true })) {
      const rel = path.join(d, e.name);
      if (e.isDirectory()) stack.push(rel);
      else if (/\.(t|j)sx?$/.test(e.name) && /export\s+(async\s+)?function\s+onLoginSucceeded\b|export\s+const\s+onLoginSucceeded\b/.test(fs.readFileSync(path.join(work, rel), 'utf8'))) return rel;
    }
  }
  return null;
}

function preparePage() {
  if (fs.existsSync(path.join(work, 'index.html'))) return { mode: 'project-page' };
  const entry = findFile(['src/main.tsx', 'src/main.ts', 'src/main.jsx', 'src/index.tsx', 'src/index.ts', 'src/index.jsx']);
  const login = findLoginModule();
  if (!entry || !login) return { mode: 'none', why: `no app entry (${entry}) or onLoginSucceeded module (${login})` };
  fs.writeFileSync(path.join(work, '__rt_entry.js'), [
    '// runtime harness entry (not part of the app): load the sign-in module, run the app entry,',
    '// wait for its first screen, then sign in with the user from ?rtUser= the way the app\'s',
    '// sign-in screen would.',
    `const login = await import('/${login}');`,
    `await import('/${entry}');`,
    "const root = document.getElementById('root');",
    'for (let i = 0; i < 100 && !(root && root.childElementCount); i++) await new Promise((r) => setTimeout(r, 100));',
    'await new Promise((r) => setTimeout(r, 300));',
    "window.__rtFirstScreen = root && root.childElementCount ? 'drawn' : 'empty';",
    "const user = new URLSearchParams(location.search).get('rtUser');",
    'window.__rtSignIn = user ? Promise.resolve(login.onLoginSucceeded(user)).then(() => "ok", (e) => "error: " + (e && e.message ? e.message : e)) : Promise.resolve("no user");',
    '',
  ].join('\n'));
  fs.writeFileSync(path.join(work, 'index.html'),
    '<!doctype html><html><head><meta charset="utf-8"><title>runtime</title></head>' +
    '<body><div id="root"></div><script type="module" src="/__rt_entry.js"></script></body></html>\n');
  return { mode: 'harness-page', entry, login };
}

async function startVite() {
  const port = await freePort();
  const own = ['vite.config.ts', 'vite.config.js', 'vite.config.mjs'].find((c) => fs.existsSync(path.join(work, c)))
    && fs.existsSync(path.join(work, 'node_modules/.bin/vite'));
  const viteBin = own ? path.join(work, 'node_modules/.bin/vite') : path.join(HERE, 'node_modules/.bin/vite');
  const args = own ? ['--port', String(port), '--strictPort', '--host', '127.0.0.1']
    : ['--config', path.join(HERE, 'vite.harness.config.mjs'), '--port', String(port), '--strictPort', '--host', '127.0.0.1'];
  const env = { ...process.env, RT_APP_ROOT: work, BROWSER: 'none' };
  for (const n of (process.env.RT_ENV_NAMES || '').split(' ').filter(Boolean)) env[n] = process.env.RT_APP_ID;
  const log = fs.openSync(path.join(outDir, 'vite.log.raw'), 'a');
  const child = spawn(viteBin, args, { cwd: work, env, stdio: ['ignore', log, log] });
  const url = `http://127.0.0.1:${port}/`;
  for (let i = 0; i < 120; i++) {
    try { const r = await fetch(url); if (r.ok) return { child, url, own }; } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 500));
  }
  child.kill();
  throw new Error('vite did not start (vite.log)');
}

function watchErrors(page, who, sink) {
  page.on('pageerror', (e) => sink.push({ who, kind: 'uncaught', text: String(e && e.stack || e).slice(0, 600) }));
  page.on('console', (m) => {
    if (m.type() !== 'error') return;
    const loc = m.location() && m.location().url || '';
    sink.push({ who, kind: 'console.error', text: m.text().slice(0, 600), from: loc });
  });
}

async function signIn(page, user, pageMode) {
  await page.goto(`${baseUrl}?rtUser=${encodeURIComponent(user)}`);
  if (pageMode === 'harness-page') {
    await page.waitForFunction(() => window.__rtSignIn !== undefined, null, { timeout: 30000 });
    return page.evaluate(() => window.__rtSignIn);
  }
  // starter page: its own sign-in form (the user ID input, USER_FIELD, and the button that submits
  // it). The button is found by its place in the form, not by its label, so an app in any language
  // signs in (lib/signin.mjs); a button that turns enabled only after typing gets up to 10 s.
  const field = page.locator(USER_FIELD).first();
  await field.waitFor({ timeout: 30000 });
  await field.fill(user);
  let pick = null;
  let buttons = [];
  for (let i = 0; i < 20 && pick === null; i++) {
    if (i) await page.waitForTimeout(500);
    buttons = await page.evaluate(describeButtons, USER_FIELD);
    pick = pickSubmit(buttons);
  }
  if (pick === null) {
    const seen = buttons.filter((b) => b.visible).map((b) => `"${b.text}"${b.disabled ? ' (disabled)' : ''}`).join(', ') || 'none';
    throw new Error(`no button submits the sign-in form (visible buttons: ${seen})`);
  }
  await page.locator(`[data-rt-btn="${pick}"]`).click();
  await page.getByText(user, { exact: false }).first().waitFor({ timeout: 30000 });
  return 'ok';
}

// The user ID input of an app's own sign-in form: the starters' input#user, the best-practice
// starters' test id, or the input the page marks for a user name (autocomplete="username", the HTML
// autofill token), so a generated form that renamed the input is still found. Document order decides.
const USER_FIELD = '#user, [data-testid="sb_login_user_id"], input[autocomplete="username"]';

// The prebuilt screens sit behind a button on the app's home screen in most outputs.
async function openChatScreen(page) {
  const list = page.locator('.sendbird-channel-list, [class*="sendbird-channel-list"]');
  if (await list.first().isVisible().catch(() => false)) return true;
  const entry = page.getByRole('button', { name: /chat|channel|message|inbox/i }).first();
  if (await entry.isVisible().catch(() => false)) await entry.click();
  else {
    const link = page.getByRole('link', { name: /chat|channel|message|inbox/i }).first();
    if (await link.isVisible().catch(() => false)) await link.click();
  }
  await list.first().waitFor({ timeout: 30000 });
  return true;
}

// Message text inside the open conversation. The channel list on the left shows the last message
// of each channel as a preview, so a page-wide text search can find a message there while the
// conversation never shows it.
function inConversation(page, text) {
  return page.locator('.sendbird-conversation__messages').getByText(text, { exact: false }).first();
}

async function openChannel(page, name) {
  const item = page.getByText(name, { exact: false }).first();
  await item.waitFor({ timeout: 60000 });
  await item.click();
}

async function typeAndSend(page, text) {
  const input = page.locator('.sendbird-message-input--textarea, [contenteditable="true"], textarea').first();
  await input.waitFor({ timeout: 30000 });
  await input.click();
  await page.keyboard.type(text);
  await page.keyboard.press('Enter');
}

let baseUrl = '';
async function main() {
  const errors = [];
  const page0 = preparePage();
  if (page0.mode === 'none') { step('launch', false, page0.why); return 1; }
  let vite;
  try { vite = await startVite(); } catch (e) { step('launch', false, e.message); return 1; }
  baseUrl = vite.url;
  const browser = await chromium.launch();
  let rc = 0;
  const fail = (name, detail, s) => { step(name, false, detail, s); rc = 1; };
  try {
    const ctxA = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    const a = await ctxA.newPage();
    watchErrors(a, 'A', errors);
    const signed = await signIn(a, userA, page0.mode).catch((e) => `error: ${e.message}`);
    const s1 = await shot(a, 'a-signed-in');
    if (signed !== 'ok') { fail('sign-in', `A: ${signed}`, s1); return rc; }
    step('sign-in', true, `A=${userA} via ${page0.mode === 'harness-page' ? 'onLoginSucceeded (harness page)' : 'the sign-in form'}`, s1);

    if (chatUI) {
      try { await openChatScreen(a); step('chat-screen', true, 'A reached the channel list', await shot(a, 'a-channel-list')); }
      catch (e) { fail('chat-screen', `A: no channel list (${e.message.split('\n')[0]})`, await shot(a, 'a-no-channel-list')); }
    } else step('chat-screen', null, 'no Sendbird UIKit dependency: the app has no chat screen to open');

    const observer = await connectAs(`rt-observer-${tag}`).catch((e) => { fail('connect', e.message); return null; });
    if (!observer) return rc;
    const pres = await presence(observer, userA, 'online', 60);
    await observer.disconnect().catch(() => {});
    if (pres.ok) step('connect', true, `server reports ${userA} online`, await shot(a, 'a-connected'));
    else { fail('connect', `server reports ${userA} ${pres.status} after 60s`, await shot(a, 'a-not-connected')); return rc; }

    if (!chatUI || rc) {
      if (!chatUI) { step('channel', null, 'no chat screen'); step('message-a-receives', null, 'no chat screen'); step('message-a-sends', null, 'no chat screen'); }
      return rc;
    }

    // user B: a second browser context running the same app
    const ctxB = await browser.newContext({ viewport: { width: 1280, height: 800 } });
    const b = await ctxB.newPage();
    watchErrors(b, 'B', errors);
    const signedB = await signIn(b, userB, page0.mode).catch((e) => `error: ${e.message}`);
    if (signedB === 'ok') await openChatScreen(b).catch(() => {});

    const peerB = await connectAs(userB);
    const seeded = await seed(peerB, userA, channelName, textB1, process.env.RT_B_CUSTOM_TYPE || undefined);
    try {
      await openChannel(a, channelName);
      step('channel', true, `B opened "${channelName}" with A; it appeared in A's list and A opened it`, await shot(a, 'a-channel-open'));
    } catch (e) { fail('channel', `A's list never showed "${channelName}" (${e.message.split('\n')[0]})`, await shot(a, 'a-no-channel')); }
    if (!rc) {
      try {
        await inConversation(a, textB1).waitFor({ timeout: 30000 });
        step('message-a-receives', true, `A sees "${textB1}"`, await shot(a, 'a-received'));
      } catch (e) { fail('message-a-receives', `A never showed "${textB1}"`, await shot(a, 'a-not-received')); }
    }
    if (!rc) {
      await typeAndSend(a, textA1).catch((e) => fail('message-a-sends', `could not type in A's input (${e.message.split('\n')[0]})`));
      const got = rc ? { ok: false } : await expectMessage(peerB, seeded.channelUrl, userA, textA1, 45);
      if (got.ok) step('message-a-sends', true, `server has A's "${textA1}"`, await shot(a, 'a-sent'));
      else if (!rc) fail('message-a-sends', `B never received "${textA1}"`, await shot(a, 'a-not-sent'));
    }
    if (!rc && signedB === 'ok') {
      try {
        await openChannel(b, channelName);
        await inConversation(b, textA1).waitFor({ timeout: 30000 });
        step('message-b-screen', true, `B's screen shows "${textA1}"`, await shot(b, 'b-received'));
      } catch (e) { step('message-b-screen', false, `B's screen did not show "${textA1}" (${e.message.split('\n')[0]})`, await shot(b, 'b-not-received')); rc = 1; }
    }
    await peerB.disconnect().catch(() => {});

    for (const t of expectTexts) {
      const seen = await a.getByText(t, { exact: false }).first().isVisible().catch(() => false)
        || await a.getByText(t, { exact: false }).first().waitFor({ timeout: 10000 }).then(() => true, () => false);
      if (seen) step('custom', true, `text "${t}" is on screen`, await shot(a, 'a-custom'));
      else fail('custom', `text "${t}" is not on screen`, await shot(a, 'a-custom-missing'));
    }
    for (const sel of expectSelectors) {
      const seen = await a.locator(sel).first().waitFor({ timeout: 10000 }).then(() => true, () => false);
      if (seen) step('custom', true, `element ${sel} is on screen`, await shot(a, 'a-custom'));
      else fail('custom', `element ${sel} is not on screen`, await shot(a, 'a-custom-missing'));
    }
  } catch (e) {
    fail('driver', e.message.split('\n')[0]);
  } finally {
    // errors raised by Sendbird code fail the run; others are listed for the reader
    const sendbirdErrors = errors.filter((x) => x.kind === 'uncaught' || /sendbird/i.test(`${x.from || ''} ${x.text}`));
    fs.writeFileSync(path.join(outDir, 'console-errors.json'), JSON.stringify(errors, null, 1));
    if (sendbirdErrors.length) { step('errors', false, `${sendbirdErrors.length} uncaught or Sendbird error(s): ${sendbirdErrors[0].text.slice(0, 200)}`); rc = 1; }
    else step('errors', true, `no uncaught or Sendbird errors (${errors.length} other console error(s))`);
    await browser.close().catch(() => {});
    vite.child.kill();
  }
  return rc;
}

main().then((code) => process.exit(code), (e) => { console.error(e); process.exit(1); });
