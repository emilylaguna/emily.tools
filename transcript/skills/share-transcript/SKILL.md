---
name: share-transcript
description: Creates a zip of the logs for this session.
disable-model-invocation: true
allowed-tools: Bash
---

The command will find, zip, and then show the resulting .zip in Finder. Nothing for you to do unless the command fails, then help them out.

!`rg --files '${CLAUDE_SESSION_ID}' ~/.claude/projects/ --files-with-matches | sort | xargs zip "/tmp/session-${CLAUDE_SESSION_ID}.zip" && open -R "/tmp/session-${CLAUDE_SESSION_ID}.zip"`