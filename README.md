# Sendbird Client plugin for Claude Code

`sendbird-client` helps you add Sendbird Chat (including authentication and sessions), UIKit, and Calls to iOS (UIKit and SwiftUI), Android (View and Compose), and JavaScript (React and React Native) apps from Claude Code. It writes setup and feature code from verified documentation and templates, reads the Sendbird SDK you have installed, and never invents an API name.

## Install

```bash
claude plugin marketplace add sendbird/sendbird-plugins
claude plugin install sendbird-client@sendbird
```

The `sendbird` marketplace in [sendbird/sendbird-plugins](https://github.com/sendbird/sendbird-plugins) lists this plugin and the Sendbird CLI plugin (`sendbird-cli@sendbird`); install either or both. This repository holds the plugin itself.

If you added the `sendbird` marketplace from this repository (`sendbird/sendbird-client-plugin`) before, remove it, add the new one, and install the plugin again:

```bash
claude plugin marketplace remove sendbird
claude plugin marketplace add sendbird/sendbird-plugins
claude plugin install sendbird-client@sendbird
```

Then, in your project:

```text
/sendbird-client:setup --product chat
```

For 1:1 voice and video calls, run `/sendbird-client:setup --product calls`, or ask in plain language, for example "Let the signed-in user place 1:1 voice and video calls to another user and accept or decline incoming calls with Sendbird Calls." On iOS, Android, and React Native, incoming calls need push credentials (VoIP or FCM) in the Sendbird dashboard even while the app is open; the plugin lists that as a manual step.

To use it for one run without installing (for example from a script or another CLI), download
`sendbird-client-<version>.zip` from [Releases](https://github.com/sendbird/sendbird-client-plugin/releases)
and pass it to Claude Code; nothing is installed and the next session does not load it:

```bash
claude -p --model claude-sonnet-5-5 --plugin-dir sendbird-client-<version>.zip "/sendbird-client:setup --product chat"
```

Each release lists the zip's sha256. `--model` is optional; `claude-sonnet-5-5` is the model the release checks run on.

## Use it in Codex

The same plugin installs in Codex from the same marketplace:

```bash
codex plugin marketplace add sendbird/sendbird-plugins
codex plugin add sendbird-client@sendbird
```

If you added it from `sendbird/sendbird-client-plugin` before, run `codex plugin marketplace remove sendbird` first.

Codex runs the same skills; call them as `$sendbird-client:setup`, `$sendbird-client:add-feature`, and so on. Codex plugins have no agent definitions, so each agent is a skill with the agent's name that runs the agent's instructions, for example `$sendbird-client:sendbird-ios-agent`.

We test the plugin in Codex with `gpt-6.1-sol` (`codex -m gpt-6.1-sol`, or `model = "gpt-6.1-sol"` in `~/.codex/config.toml`). An agent skill starts its subagent on `gpt-6.1-sol` and falls back to your session's model when that model is not available.

Codex does not run a plugin's hooks until you trust them. When a session starts after you install or update the plugin, Codex shows "Hooks need review"; choose **Review hooks** (each hook says what it does) and press `t` to trust them, or open `/hooks` later. Until then the credential, source, and destructive-command guards in "What runs on your machine" do not run, and the session rules are not added; the skills still work and can run the plugin's scripts listed there under "Scripts the agent runs", and the first of those scripts to run shows the notice about what runs on your machine in its output. A `codex exec` run uses trusted hooks only, unless you pass `--dangerously-bypass-hook-trust` for that run.

`codex plugin marketplace upgrade sendbird` refreshes the catalog.

## Keeping it up to date

An installed plugin is a snapshot: Claude Code replaces it only when the plugin version changes, and every change that ships to users bumps the patch version. Third-party marketplaces such as `sendbird` do not auto-update by default. Turn it on in any one of these places:

| Who it applies to | Where | How |
|---|---|---|
| You, on this machine | `/plugin` | **Marketplaces** tab → `sendbird` → **Enable auto-update**. The plugin's own page under **Installed** only offers one-off updates (**Update now**, **Mark for update**). |
| You, in every project | `~/.claude/settings.json` | Add the entry below. |
| Everyone who opens a repository | `.claude/settings.json` in that repository, committed | Add the entry below. It registers the marketplace and turns auto-update on, but does not install the plugin: each teammate runs `claude plugin install sendbird-client@sendbird --scope project` once. |
| Everyone in an organization | managed settings | An admin adds the entry below. |

```json
{
  "extraKnownMarketplaces": {
    "sendbird": {
      "source": { "source": "github", "repo": "sendbird/sendbird-plugins" },
      "autoUpdate": true
    }
  }
}
```

An `autoUpdate` value in a settings file takes precedence over the toggle in `/plugin`.

**When updates arrive.** In an interactive session, Claude Code waits up to ten minutes after your first message, then refreshes every marketplace with auto-update on. The running session keeps the old version and shows `Plugin updated … Run /reload-plugins to apply`; run it, or start a new session.

**If the toggle is missing.** `DISABLE_AUTOUPDATER=1`, `DISABLE_UPDATES=1`, or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` turns plugin auto-update off and hides the toggle. Set `FORCE_AUTOUPDATE_PLUGINS=1` as well to keep plugin updates on.

**Update by hand:**

```bash
claude plugin marketplace update sendbird               # refresh the catalog
claude plugin update sendbird-client@sendbird     # install the new version
```

Then run `/reload-plugins` or restart Claude Code. See the Claude Code docs: [keep plugins updated](https://code.claude.com/docs/en/plugins/install#keep-plugins-updated) and [which marketplaces auto-update](https://code.claude.com/docs/en/plugins/loading#which-marketplaces-and-plugins-auto-update).

## Uninstall

```bash
claude plugin uninstall sendbird-client@sendbird
claude plugin marketplace remove sendbird   # optional; it also lists the Sendbird CLI plugin
```

In Codex:

```bash
codex plugin remove sendbird-client@sendbird
```

The `.sendbird-client/` folder the plugin made in your project (its detection cache and run-check results) is yours; the plugin never deletes it. Delete it by hand if you no longer need it.

## What runs on your machine

This plugin runs inside Claude Code with your user account's permissions. Three kinds of code run locally:

**Hooks** — shell scripts Claude Code runs automatically at the points below. Codex runs the same scripts once you trust them (see "Use it in Codex"); there, file writes reach the guards as `apply_patch` or as a shell command that writes a source file.

| When | Script | What it reads | What it can change | Network |
|---|---|---|---|---|
| Session start | `hooks/welcome.sh` | plugin files, and the names of the files in the session's folder (to tell whether it is empty) | adds the plugin's rules to the model's context, and in an empty folder says to start a new app with setup | none |
| Session start, your prompt, before a file read or write, shell command, skill, or agent call, and when a skill runs one of the plugin's scripts | `hooks/first-run-notice.sh` | the plugin manifest, and its own mark in the plugin data folder (`~/.claude/plugins/data/<plugin>-<marketplace>/first-run-notice` in Claude Code, `~/.codex/plugins/data/<plugin>-<marketplace>/first-run-notice` in Codex) | shows you a short version of this section once, and again only when that notice changes; it is shown to you, not to the model. It also runs at your prompt and before a tool call so that you see it when the plugin was installed inside a running session or your editor does not show session-start messages; once it is marked shown it prints nothing. The plugin's own scripts ("Scripts the agent runs") call it too, so in Codex, before you trust the hooks, the first of them a skill runs prints the notice in that command's output, starting with a one-line summary and the link. A run nobody watches (`SENDBIRD_NONINTERACTIVE`, or `claude -p`) and the Desktop app, which does not show these messages, show it at session start without marking it shown | none |
| Session start, and when the Claude Desktop app or the VS Code extension connects to the session | `hooks/notice.js`, a Claude Code mod: JavaScript that Claude Code runs inside itself (Claude Code 2.1.287 or later; Codex does not load it) | the notice text, by running `hooks/first-run-notice.sh text`, and its own mark in the plugin's mod store | shows the same notice once as a line in the conversation, because these apps do not show a hook's message; in that session `first-run-notice.sh` stays quiet. In the terminal and in `claude -p` it does nothing | none |
| Before a file write or shell command | `hooks/credential-guard.sh` | the content or command about to run | blocks it if it contains a credential | none |
| Before a shell command | `hooks/destructive-command-guard.sh` | the command about to run | asks you to approve a Sendbird CLI `delete`, `revoke`, or `deactivate` run with `--yes`; in a `-p` run it is denied | none |
| Before a shell command, skill, or agent | `hooks/build-command-guard.sh` | the command about to run, and whether your request asked for a build | while the plugin's skills or agents work on your project, blocks a command that builds, compiles, or type-checks it (for example `npm run typecheck`, `xcodebuild`, `./gradlew assembleDebug`) unless you asked for a build; the plugin's own scripts, run-check among them, are not blocked | none |
| Before a file write, or a shell command that writes a source file | `hooks/source-claim-guard.sh` | the content about to be written, local files it cites | blocks Sendbird API code without a verifiable source: a plugin file, an installed SDK file (`node_modules/@sendbird`, `Pods`, `.build`, Xcode `SourcePackages` or `DerivedData`, the Gradle cache), or a public page; a file the model wrote in your project does not count | fetches the cited page if it is on `sendbird.com/docs` or is a file in a `github.com/sendbird` repository (a `/blob/` or `/raw/` link); issues, discussions, and pull requests are not fetched |
| Your prompt | `hooks/session-state.sh` | your prompt | when it pastes a token (a long value next to a word such as token, secret, or session key), writes that value's SHA-256 hash and length, never the value, to a file for this session in the plugin data folder, so the checks below can tell when the token is repeated; it also marks, in an empty file for this session, whether the prompt asks for a build, for `build-command-guard.sh` | none |
| Before a file read, shell command, or skill call | `hooks/session-state.sh` | the call's input | notes in a file for this session which skill the current request started, which of the plugin's curated knowledge files it read, and which registry lookups (`tools/local-sdk/latest-version.sh`) it ran: names only, nothing from your files. Your next prompt starts the file again. For `final-answer-gate.sh` and `upgrade-sdk-guard.sh` | none |
| Before an agent call | `hooks/upgrade-sdk-guard.sh` | the notes above, and the project profile the plugin wrote | during upgrade-sdk, stops the hand-off to the platform agent once until the curated setup, host, and UIKit files for your platform were read | none |
| Before a skill or agent call | `hooks/token-relay-guard.sh` | the call's input, and the hashes above | blocks a call that passes a token you pasted and asks the model to say "the token you provided" instead | none |
| When an agent starts and when it finishes | `hooks/session-state.sh` | the agent's ID, and its final reply | keeps in the plugin data folder which agents of this session are still running, and the check lines and symbol/source table of the reply, for `final-answer-gate.sh` and `run-summary-gate.sh` | none |
| After an agent finishes | `hooks/unsourced-claim-warn.sh` | the agent's reply | when an API claim has no source, sends the plugin's own agents back once to add sources (in Codex, every agent); for any other agent that ran in the foreground, adds a warning | none |
| When the answer ends | `hooks/final-answer-gate.sh` | the final answer (passed by Claude Code; older versions: the session transcript after your last prompt) | asks the model to revise an unsourced answer, an answer that repeats a token you pasted, or one that leaves out the checks and sources an agent reported; during upgrade-sdk, also an answer made without reading the curated files the skill names or without the `latestInMajor`, `latest`, and `source` values of the registry lookup | same as `source-claim-guard.sh` |
| When the answer ends, only when `SENDBIRD_NONINTERACTIVE` is `1`, `true`, or `yes` | `hooks/run-summary-gate.sh` | the final answer and the plugin's run summary schema | asks the model to fix a run summary that does not match the schema, that lists a build or a note that the run did not build under `manualSteps`, that changed app files without listing `checks`, or that asks you to call a helper this run added (or the sign-in function it wired), and to write the whole answer again | none |
| Before and after an agent runs | `hooks/telemetry-start.sh`, `hooks/telemetry-end.sh` | agent name, duration, outcome | nothing; writes a local log only if you opted in | none |

The two fetching hooks send a plain request for the cited public page (8-second timeout); nothing from your project or conversation is sent.

The hooks read their input with `jq`. When `jq` is not on your `PATH`, the credential, source, and destructive-command guards cannot check a call, so instead of blocking or allowing it they ask you to approve every file write and shell command, and the session start says that `jq` is missing. The other hooks then do nothing. Install `jq` to turn the checks back on.

**Scripts the agent runs** through Claude Code's Bash tool, under your Claude Code permission settings: project detection (reads manifests such as `package.json`, `Podfile`, `Package.swift`, `build.gradle`) the installed-SDK reader (reads `node_modules/@sendbird/*`, `Pods/`, `.build/`, this project's Xcode `DerivedData`, and the Gradle cache), the offline docs search `core/commands/search.sh` (reads the docs page index and curated knowledge shipped inside the plugin and, when given your project, its lockfiles to learn the installed SDK versions; it makes no network request and writes no file), and the docs page reader `core/commands/fetch-doc.sh` (one HTTPS request with `curl` for a `sendbird.com/docs` page that the plugin's page index lists; it prints the page and writes no file). The plugin ships no official page text; pages are read from `sendbird.com/docs` when they are needed.

**Instructions** — skills and agents that tell Claude how to work. They change what Claude does in your session.

**Network requests made through Claude Code's tools.** Besides the two fetching hooks, the plugin's instructions lead to four kinds of requests, all under your Claude Code permission settings:

- **Installing the SDK.** When you ask for setup, the agent runs the package manager your project already uses (npm, yarn, or pnpm; Swift Package Manager, or CocoaPods only when the project already has a `Podfile`; Gradle), which downloads the Sendbird packages from npm, GitHub, the CocoaPods trunk, and Sendbird's Maven repository (`repo.sendbird.com`).
- **Looking up docs.** Agents and skills read official pages on `sendbird.com/docs` with `core/commands/fetch-doc.sh` (only pages listed in the plugin's page index) or Claude Code's web fetch tool, and pages on `github.com/sendbird` with the web fetch tool. The plugin does not limit which domains that tool can reach; your Claude Code permission settings do.
- **Searching public Sendbird repositories.** Agents may run the GitHub CLI (`gh search code`, `gh api` for public discussions) through Claude Code's Bash tool. These send your search terms, such as a Sendbird API name, to the GitHub API under your own `gh` login.
- **Running your app (run check).** Only when you ask for a run check and agree to the build, `tools/runtime/run.sh` copies your project to a temporary folder (your project is never changed), installs its dependencies there with npm (and CocoaPods for a React Native app on iOS), and builds it with Xcode or Gradle, which download what the build needs. It installs its own pinned tools (Playwright with Chromium, Vite, and the Sendbird Chat SDK for the second test user) from npm into a temporary folder outside your project, then launches the app in a browser, a simulator, or an emulator, where two test users with generated IDs connect to your Sendbird application and exchange messages.

None of them sends your project files or conversation to Sendbird. Claude Code itself sends your conversation, and the files it reads, to its model provider under your Claude Code terms; that is outside this plugin.

**Files it writes:** `.sendbird-client/profile.json` and `.sendbird-client/cache/` in your project, and `~/.claude/sendbird-client-telemetry.jsonl` only when telemetry is on, plus the one-line mark of the session-start notice in Claude Code's data folder for the plugin.

**Updates replace all of the above.** When the plugin updates — by `claude plugin update` or through auto-update — the new version's hooks, scripts and instructions replace the old ones and run from your next session (or after `/reload-plugins`). With auto-update on, Claude Code installs new versions without asking for each one. Each release is a pull request in the plugin's repository that lists the changed paths; review them before turning auto-update on for `sendbird`.

## What is in this repository

- `plugins/sendbird-client/` — the plugin (skills, agents, hooks, knowledge, templates)

The `sendbird` marketplace that lists the plugin is in [sendbird/sendbird-plugins](https://github.com/sendbird/sendbird-plugins).

This repository is published automatically; every change arrives as a release pull request. Please open an issue for bugs or wrong answers — pull requests are not merged here.

## License

Apache-2.0; see `LICENSE`. Third-party files, and how the plugin's license relates to the Sendbird SDKs it installs, are
described in [`plugins/sendbird-client/NOTICE.md`](plugins/sendbird-client/NOTICE.md).

Terms of use: [Sendbird Terms of Service](https://sendbird.com/terms-of-service)
