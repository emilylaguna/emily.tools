---
name: analyze-project-logs
description: Get an analysis for a session log or a folder of logs
allowed-tools: Bash, Read, Write, Agent, Skill
---

Run the analyze-logs skill with the `path`.

<path>
!`dirname $(find ~/.claude/projects/ -name '${CLAUDE_SESSION_ID}.jsonl')`
</path>