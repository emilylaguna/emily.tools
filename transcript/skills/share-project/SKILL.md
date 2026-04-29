---
name: share-project-logs
description: Creates a zip of all the Claude project folder and shows it in finder.
disable-model-invocation: true
allowed-tools: Bash
---

The command will find the folder for the session transcripts, zip, and then show the resulting .zip in Finder. Nothing for you to do unless the command fails, then help them out.

!`find $(dirname $(find ~/.claude/projects/ -name '${CLAUDE_SESSION_ID}.jsonl')) | xargs zip "/tmp/project-${CLAUDE_SESSION_ID}.zip" && open -R "/tmp/project-${CLAUDE_SESSION_ID}.zip"`