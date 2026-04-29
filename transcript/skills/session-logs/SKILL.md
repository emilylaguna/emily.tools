---
name: session-logs
description: Locates the transcript logs for this session.
disable-model-invocation: true
allowed-tools: Bash
---

Display the `project-folder` and `transcript-files` output to the user:

<project-folder>
!`dirname $(find ~/.claude/projects/ -name '${CLAUDE_SESSION_ID}.jsonl')`
</project-folder>

<transcript-files>
!`rg --files '${CLAUDE_SESSION_ID}' ~/.claude/projects/ --files-with-matches | sort`
</transcript-files>