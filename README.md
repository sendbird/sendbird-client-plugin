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

## Keep it up to date

Claude Code keeps the installed copy until the plugin version changes. Third-party marketplaces do not auto-update by default. To turn auto-update on for everyone who opens your project, add this to the project's `.claude/settings.json`:

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

Or update by hand:

```bash
claude plugin update sendbird-client@sendbird
```

## What is in this repository

- `plugins/sendbird-client/` — the plugin (skills, agents, hooks, knowledge, templates)
- `.claude-plugin/marketplace.json` — the `sendbird` marketplace

This repository is published automatically; every change arrives as a release pull request. Please open an issue for bugs or wrong answers — pull requests are not merged here.

## License

Apache-2.0; see `LICENSE`.
