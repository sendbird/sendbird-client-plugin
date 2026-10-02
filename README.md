# Sendbird Client plugin for Claude Code

`sendbird-client` helps you add Sendbird Chat (including authentication and sessions) and UIKit to iOS (UIKit and SwiftUI), Android (View and Compose), and JavaScript (React and React Native) apps from Claude Code. It writes setup and feature code from verified documentation and templates, reads the Sendbird SDK you have installed, and never invents an API name.

## Install

```bash
claude plugin marketplace add sendbird/sendbird-client-plugin
claude plugin install sendbird-client@sendbird
```

Then, in your project:

```text
/sendbird-client:setup --product chat
```

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

## What is in this repository

- `plugins/sendbird-client/` — the plugin (skills, agents, hooks, knowledge, templates)
- `.claude-plugin/marketplace.json` — the `sendbird` marketplace

This repository is published automatically; every change arrives as a release pull request. Please open an issue for bugs or wrong answers — pull requests are not merged here.

## License

Apache-2.0; see `LICENSE`.
