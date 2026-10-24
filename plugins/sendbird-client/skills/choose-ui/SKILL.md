---
name: choose-ui
description: Help the customer choose between Sendbird UIKit (prebuilt screens they can theme and customize) and their own UI built on the Chat SDK. Reads the project and the requirements (how custom the design is, the timeline, the features, the platform and host), compares the two options from the plugin's curated knowledge with cited sections, and recommends one with the next skill to run. Changes no files. Use when the customer asks whether to use UIKit or build their own chat UI.
argument-hint: ""
allowed-tools: Read, Bash, Grep, Glob, Agent, AskUserQuestion
---

# /sendbird-client:choose-ui

Resolve every plugin-owned path below from `${CLAUDE_PLUGIN_ROOT}`. Where that variable is empty (Codex does not set it for shell commands), the plugin root is the folder two levels above this SKILL.md.
For a fact the curated files below do not cover, resolve the docs agent with `bash "${CLAUDE_PLUGIN_ROOT}/tools/routing/route-agent.sh" <project-dir> docs` and ask it once.

A recommendation, not a code change. Read only; write no files.

## Steps
1. **Project.** Run `bash "${CLAUDE_PLUGIN_ROOT}/tools/detection/detect.sh" <project-dir>` (skip it when there is no project yet) and note platform, host, and whether UIKit or the Chat SDK is already installed.
2. **Requirements.** Take them from the request: how custom the design is (theme and colors only; restyled or replaced parts such as message bubbles, the input bar, the channel list item, or the header; or a design unlike a standard chat screen), the timeline, and the features needed. The platform and host come from step 1; do not ask for them. Ask once, in one question, for what is missing and changes the answer, and stop there: no comparison or recommendation until the customer answers.
   - Non-interactive (`SENDBIRD_NONINTERACTIVE`): do not ask. Use what the request says and state each assumption in the answer.
3. **Compare from curated knowledge only.** Read these files for the detected platform and host and cite the section (file and heading) behind every point:
   - UIKit and how it is customized: `knowledge/curated/<platform>/products/uikit.md` — iOS "How customization is wired", Android "Customization model (View host)", JS "Compose your own UI: channel list + conversation" and the render-prop sections; theming in `knowledge/curated/<platform>/cross-cutting/theme.md`.
   - The host: `knowledge/curated/<platform>/hosts/<host>.md` — SwiftUI "Customizing SendbirdSwiftUI views", Compose "UIKit for Jetpack Compose — customization", React Native "Version compatibility checklist", and the integration notes of the others.
   - Your own UI on the Chat SDK: `knowledge/curated/<platform>/products/chat.md` — what the app then builds itself, for example "Create and list group channels", "List and receive messages", "Local caching and offline messages", "Connection state and reconnection".
   Compare on the customer's requirements: how much of the design each option can change, how much the app has to build and keep up to date, and whether each needed feature is covered. A feature or a limit the files do not mention is "not covered by the plugin's knowledge", not a yes or a no.
4. **Recommend** one of: UIKit as it is, UIKit with customization, or the Chat SDK with the app's own UI (a mix is possible, for example UIKit screens with some parts replaced). Give the reasons tied to the requirements, then the next skill:
   - nothing installed yet → `/sendbird-client:setup` with `--product uikit` or `--product chat`;
   - UIKit already installed and the design needs changes → `/sendbird-client:ui-customize`;
   - the Chat SDK already installed and a screen or feature is next → `/sendbird-client:add-feature`.
5. **Report.** A short comparison table with exactly these four rows, in this order, each with its own citation, then the recommendation and the next skill:

   | | UIKit | Chat SDK with your own UI | Source |
   |---|---|---|---|
   | Design freedom | ... | ... | file and heading |
   | Work for the app | ... | ... | file and heading |
   | Features the request needs | ... | ... | file and heading |
   | Host notes | ... | ... | file and heading |

   The "Features the request needs" row names each feature from step 2 and whether each option has it, citing the section that says so; it is never left out, also when the request names no feature (then it says the request names none). In a non-interactive run, end with the run summary (`core/schemas/run-summary.schema.json`, `skill: "choose-ui"`, `status: "completed"`, empty `changes`).

## Wired knowledge
- `knowledge/curated/<platform>/products/uikit.md`, `knowledge/curated/<platform>/cross-cutting/theme.md`
- `knowledge/curated/<platform>/hosts/*.md`
- `knowledge/curated/<platform>/products/chat.md`

## No-Fabrication
Every claim about what UIKit or the Chat SDK can do cites a curated section. Never estimate effort in days or name an API that is not in those sections. If the files do not answer a requirement, say "I don't know — here's what I checked" for that requirement and name the files.
