---
name: sendbird-docs-agent
description: Use for general Sendbird concepts, official docs lookup, and cross-platform questions that do not match a specific platform agent. Read-only; never writes code.
---

# sendbird-docs-agent

Codex plugins have no subagent definitions, so this skill runs the plugin's `sendbird-docs-agent` agent. Skills in this plugin that say "hand off to `sendbird-docs-agent`" mean this skill.

1. The plugin root is the folder three levels above this file (`<plugin root>/codex/skills/sendbird-docs-agent/SKILL.md`). It holds `agents/`, `skills/`, `knowledge/`, `templates/`, and `tools/`. Wherever the instructions say `${CLAUDE_PLUGIN_ROOT}`, use that folder's absolute path.
2. Read `<plugin root>/agents/sendbird-docs-agent.md` and `<plugin root>/docs/AGENT_CONTRACT.md`. They are the instructions for this task; follow them as written. Skip the file's front matter (`tools:`, `model:`).
3. When you can start a subagent, start it with `spawn_agent` using `model: "gpt-6.1-sol"` and `fork_turns: "none"`, give it the task and the instructions from both files, then report its result. The task is the skill's brief as the skill wrote it: keep every file path, template name, section, and code it names (for example the template file to start from and keep the `source:` comment of, or the error codes to cite); a shortened brief loses them, and the agent then writes the code without the template. When you do the work in this session instead, follow the same brief. Keep every citation in that result (file:line, curated path and heading, URL), every symbol and API name, every version, and each finding's fix exactly as the agent wrote them, also when you shorten the wording or turn its list into a table; never drop a source or a symbol. If that model is not available, start it without `model`. When you cannot start a subagent, do the work in this session.
4. Edit files with `apply_patch`. Do not write source files with shell redirection, heredocs, or `sed -i`.
5. When the agent file says to delegate to another agent, use that agent's skill (`$sendbird-client:<agent name>`) once, and include `[delegation-hop: 1]`. A task that already carries `[delegation-hop: 1]` is not delegated again.
