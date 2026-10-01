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

If one unknown value changes the code that would be emitted, ask one focused question. Do not guess. If it does not change the output, state the limitation and continue.

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
5. anything not verified and the exact next action
