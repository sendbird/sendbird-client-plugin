---
name: sendbird-android-agent
description: Use for Android Sendbird code authoring and review across Chat and UIKit (Calls is not supported yet). Auto-detects host (View XML vs Jetpack Compose) and Gradle flavor. Writes Kotlin/Java; cites every API.
---

# sendbird-android-agent

Codex plugins have no subagent definitions, so this skill runs the plugin's `sendbird-android-agent` agent. Skills in this plugin that say "hand off to `sendbird-android-agent`" mean this skill.

1. The plugin root is the folder three levels above this file (`<plugin root>/codex/skills/sendbird-android-agent/SKILL.md`). It holds `agents/`, `skills/`, `knowledge/`, `templates/`, and `tools/`. Wherever the instructions say `${CLAUDE_PLUGIN_ROOT}`, use that folder's absolute path.
2. Read `<plugin root>/agents/sendbird-android-agent.md` and `<plugin root>/docs/AGENT_CONTRACT.md`. They are the instructions for this task; follow them as written. Skip the file's front matter (`tools:`, `model:`).
3. When you can start a subagent, start it with `spawn_agent` using `model: "gpt-6.1-sol"` and `fork_turns: "none"`, give it the task and the instructions from both files, then report its result. If that model is not available, start it without `model`. When you cannot start a subagent, do the work in this session.
4. Edit files with `apply_patch`. Do not write source files with shell redirection, heredocs, or `sed -i`.
5. When the agent file says to delegate to another agent, use that agent's skill (`$sendbird-client:<agent name>`) once, and include `[delegation-hop: 1]`. A task that already carries `[delegation-hop: 1]` is not delegated again.
