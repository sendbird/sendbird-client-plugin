# Sendbird Client plugin for Claude Code

`sendbird-client` helps you add Sendbird Chat (including authentication and sessions), UIKit, and Calls to iOS (UIKit and SwiftUI), Android (View and Compose), and JavaScript (React and React Native) apps from Claude Code. It writes setup and feature code from verified documentation and templates, reads the Sendbird SDK you have installed, and never invents an API name.

## Install

```bash
claude plugin marketplace add sendbird/sendbird-client-plugin
claude plugin install sendbird-client@sendbird
```

Then, in your project:

```text
/sendbird-client:setup --product chat
```

To use it for one run without installing (for example from a script or another CLI), download
`sendbird-client-<version>.zip` from [Releases](https://github.com/sendbird/sendbird-client-plugin/releases)
and pass it to Claude Code; nothing is installed and the next session does not load it:

```bash
claude -p --model claude-sonnet-5-5 --plugin-dir sendbird-client-<version>.zip "/sendbird-client:setup --product chat"
```

Each release lists the zip's sha256. `--model` is optional; `claude-sonnet-5-5` is the model the release checks run on.

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
      "source": { "source": "github", "repo": "sendbird/sendbird-client-plugin" },
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

## What runs on your machine

This plugin runs inside Claude Code with your user account's permissions. Three kinds of code run locally:

**Hooks** — shell scripts Claude Code runs automatically at the points below.

| When | Script | What it reads | What it can change | Network |
|---|---|---|---|---|
| Session start | `hooks/welcome.sh` | plugin files | adds the plugin's rules to the model's context | none |
| Before a file write or shell command | `hooks/credential-guard.sh` | the content or command about to run | blocks it if it contains a credential | none |
| Before a shell command | `hooks/destructive-command-guard.sh` | the command about to run | asks you to approve a Sendbird CLI `delete`, `revoke`, or `deactivate` run with `--yes`; in a `-p` run it is denied | none |
| Before a file write | `hooks/source-claim-guard.sh` | the content about to be written, local files it cites | blocks Sendbird API code without a verifiable source | fetches the cited page if it is on `sendbird.com/docs` or `github.com/sendbird` |
| After an agent finishes | `hooks/unsourced-claim-warn.sh` | the agent's reply | adds a warning when an API claim has no source | none |
| When the answer ends | `hooks/final-answer-gate.sh` | the session transcript file (it checks only the last answer) | asks the model to revise an unsourced answer | same as `source-claim-guard.sh` |
| Before and after an agent runs | `hooks/telemetry-start.sh`, `hooks/telemetry-end.sh` | agent name, duration, outcome | nothing; writes a local log only if you opted in | none |

The two fetching hooks send a plain request for the cited public page (8-second timeout); nothing from your project or conversation is sent.

**Scripts the agent runs** through Claude Code's Bash tool, under your Claude Code permission settings: project detection (reads manifests such as `package.json`, `Podfile`, `Package.swift`, `build.gradle`) and the installed-SDK reader (reads `node_modules/@sendbird/*`, `Pods/`, `.build/`, this project's Xcode `DerivedData`, and the Gradle cache).

**Instructions** — skills and agents that tell Claude how to work. They change what Claude does in your session.

**Network requests made through Claude Code's tools.** Besides the two fetching hooks, the plugin's instructions lead to three kinds of requests, both under your Claude Code permission settings:

- **Installing the SDK.** When you ask for setup, the agent runs the package manager your project already uses (npm, yarn, or pnpm; Swift Package Manager, or CocoaPods only when the project already has a `Podfile`; Gradle), which downloads the Sendbird packages from npm, GitHub, the CocoaPods trunk, and Sendbird's Maven repository (`repo.sendbird.com`).
- **Looking up docs.** Agents and skills read official pages on `sendbird.com/docs` and `github.com/sendbird` with Claude Code's web fetch tool. The plugin does not limit which domains that tool can reach; your Claude Code permission settings do.
- **Searching public Sendbird repositories.** Agents may run the GitHub CLI (`gh search code`, `gh api` for public discussions) through Claude Code's Bash tool. These send your search terms, such as a Sendbird API name, to the GitHub API under your own `gh` login.

None of them sends your project files or conversation to Sendbird. Claude Code itself sends your conversation, and the files it reads, to its model provider under your Claude Code terms; that is outside this plugin.

**Files it writes:** `.sendbird-client/profile.json` and `.sendbird-client/cache/` in your project, and `~/.claude/sendbird-client-telemetry.jsonl` only when telemetry is on.

**Updates replace all of the above.** When the plugin updates — by `claude plugin update` or through auto-update — the new version's hooks, scripts and instructions replace the old ones and run from your next session (or after `/reload-plugins`). With auto-update on, Claude Code installs new versions without asking for each one. Each release is a pull request in the plugin's repository that lists the changed paths; review them before turning auto-update on for `sendbird`.

## What is in this repository

- `plugins/sendbird-client/` — the plugin (skills, agents, hooks, knowledge, templates)
- `.claude-plugin/marketplace.json` — the `sendbird` marketplace

This repository is published automatically; every change arrives as a release pull request. Please open an issue for bugs or wrong answers — pull requests are not merged here.

## License

Apache-2.0; see `LICENSE`.
