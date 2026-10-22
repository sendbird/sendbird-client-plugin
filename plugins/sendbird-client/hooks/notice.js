// Claude Code mod: shows the plugin's first-run notice as a line in the conversation in the Desktop
// app and the VS Code extension. The Desktop app draws no hook systemMessage, and the VS Code
// extension none at session start, so first-run-notice.sh alone is not seen there; the terminal
// draws it, so the mod leaves the terminal to that script (a session-start hook and this mod start
// together, and both would show it). The text comes from that script, so it has one source.
// This file reads nothing else, sends nothing, and keeps one value (the shown notice's checksum) in
// this plugin's store. It sets SENDBIRD_NOTICE_BY_MOD so first-run-notice.sh stays quiet in this
// session; where mods do not load (Codex, Claude Code before 2.1.287, an organization that turns
// them off) that script shows the notice as before.
//
// An app can connect after the session started: the VS Code panel does, so at session.start
// $.session.surfaces() is still empty there and the notice waited for the first prompt. The same
// check therefore runs again on session.attach (the mods reference: "Another app connects to or
// disconnects from the session"); the stored checksum keeps it to one notice.
async function show($) {
  // The terminal shows the shell hook's systemMessage. No surface (claude -p, the Agent SDK, a
  // cloud session) draws nothing, and the shell hook keeps its rule for runs nobody watches.
  const surfaces = await $.session.surfaces()
  if (!surfaces || !surfaces.some((s) => s === 'desktop' || s === 'vscode')) return
  const out = await $.process.run(['bash', $.plugin.root + '/hooks/first-run-notice.sh', 'text'])
  const lines = out.stdout.split('\n')
  const sum = lines[0].trim()
  const text = lines.slice(1).join('\n').trim()
  if (out.exitCode !== 0 || !sum || !text) return
  await $.env.set('SENDBIRD_NOTICE_BY_MOD', '1')
  if ((await $.store.get('first-run-notice')) !== sum) {
    $.ui.log(text)
    await $.store.set('first-run-notice', sum)
  }
}

async function handle($, e, next) {
  try {
    await show($)
  } catch {
    // A failure leaves the shell hook in charge: it still shows the notice.
  }
  return next(e)
}

export function register(on) {
  on('session.start', handle)
  on('session.attach', handle)
}
