# Agent execution contract

Every platform and documentation agent follows this contract before applying its platform-specific rules.

## 1. Establish the task envelope

Run the detector for the current project. Record these values before reading or writing integration code:

- project root
- platform and host
- package manager and resolved SDK versions
- detected products
- requested product and feature
- existing integration state
- lifecycle entry point that owns initialization and cleanup

For a code task, resolve the platform agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> code`. For a documentation task, use the same command with `docs`. Do not maintain a second routing table in prose.

Resolve the active product scope with `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/resolve-products.sh" <project-dir>`. If the requested product is not in that list, say it is out of the configured scope and stop instead of writing code for it.

If one unknown value changes the code that would be emitted, ask one focused question. Do not guess. If it does not change the output, state the limitation and continue. In a non-interactive run, do not ask; follow section 7.

## 2. Build an evidence ledger

For every Sendbird symbol that will be emitted, record:

```text
symbol -> exact source -> source version -> verification method
```

Accepted sources, in order:

1. shipped curated knowledge
2. the customer's resolved SDK entrypoint or binary surface
3. imported public knowledge when present
4. a public Sendbird source file or version-matched official documentation

The source must contain the symbol or exact signature. A related page is not evidence. If a symbol cannot be verified, do not emit it. Report what was checked.

## 3. Change the customer project conservatively

- Preserve the project's package manager, architecture, naming, state management, and navigation choices.
- Do not introduce a second SDK instance, initialization path, listener owner, or token store.
- Keep secrets out of source, commands, logs, and generated files. Application IDs are not secrets.
- Preserve the template's `source:` comment when code is copied so the write-boundary guard can validate it.
- Limit edits to the requested product and the lifecycle code required to support it.

### Finish what the project allows

Do every step that can be done inside the customer project before reporting. A step goes to the customer only when it needs something outside the project.

- Read the App ID through the mechanism the project already has. On JS, follow `tier2.appIdSource` and `knowledge/curated/js/setup.md` "App ID"; when it is `config`, write a config module. Never require a new bundler or env loader.
- If the app already has a sign-out or logout function, disconnect there and clean up the handlers you added. Add a standalone helper only when no such function exists, and name the helper in the hand-off.
- When the project already gets a Sendbird token from its own backend, register the session handler with that call. Without such a call, leave it out; do not add a placeholder endpoint.
- A hand-off step is allowed only for work that needs something the project does not contain: a token-issuing server, a dashboard setting, a signing key or certificate, a device or simulator run, or a value nobody supplied. Each step says what is missing and why the plugin could not do it.

## 4. Verify the result

Verification must exercise the edited path, not only inspect text:

- dependency resolves at the selected version
- generated source compiles or type-checks with the customer's toolchain when available
- initialization occurs once at the detected lifecycle entry
- session and token refresh handlers are registered before connection
- listeners, delegates, and handlers have matching cleanup
- host-specific requirements are present

Report each check as pass, fail, or not run. Never describe a skipped check as passed.

## 5. Delegate once

A platform agent may ask the docs agent one factual question. The docs agent may ask one platform agent for platform-specific code analysis. Include the task envelope, evidence already checked, and `[delegation-hop: 1]` in that request. A delegated agent that receives this marker must not delegate again.

## 6. Return a complete result

Return:

1. detected task envelope
2. changed files and why each changed
3. verification commands and their actual results
4. symbol-to-source evidence
5. anything not verified and the exact next action; only steps that "Finish what the project allows" (section 3) could not complete

## 7. Non-interactive runs

When `SENDBIRD_NONINTERACTIVE` is set (for example `SENDBIRD_NONINTERACTIVE=1 claude -p ...` in CI or a script), nobody can answer a question during the run.

- Never ask the user a question, and never end the answer with one.
- For a value you would otherwise ask for, use the environment (`SENDBIRD_APP_ID`, `SENDBIRD_PRODUCTS`, `SENDBIRD_REGION`) or the project's `profile.json` when they have it.
- Adding the Sendbird dependency that the request clearly needs is allowed: the request is the consent. List it under `changes`.
- If a value that changes the emitted code is still unknown, change nothing and stop with `status: "needs_input"` and one `questions` entry per missing value. Examples: the host is `hybrid` or `unknown`; there is no App ID for setup; the request assumes an integration the project does not have, such as theming UIKit screens in an app without UIKit.
- End the final answer with one fenced `json` block that validates against `core/schemas/run-summary.schema.json`. Paths in `changes` are relative to the project root.

The caller answers by running again with the value in the environment or in the prompt (for example `host: swiftui`).

