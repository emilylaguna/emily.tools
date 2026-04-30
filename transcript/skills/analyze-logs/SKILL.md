---
name: analyze-logs
description: Get an analysis for a session log or a folder of logs
argument-hint: <path-to-jsonl-or-folder>
allowed-tools: Bash, Read, Write, Agent
---

The user wants to analyze the Claude Code transcripts at: `$ARGUMENTS`

Step 1:
If you are not already the transcript analyst, spawn the analyst as a subagent providing the `stats`

<stats>
```
!`txstats "$ARGUMENTS" --turns --bash-bytes`
```
</stats>

Step 2 — your job:

1. Read the `stats` output above. That covers tool counts, token totals, top files, top bash, redundant reads, **session cache health, cache invalidation events, top cache-creation turns, and 20-block lookback risk turns**, etc. Do **not** re-derive any of those numbers with fresh jq pipelines. Cache-shaped findings (hit rate ≤ 0.6, any invalidation event, any lookback miss) are first-class — surface them in the proposal alongside tool-pattern findings.
2. If anything in the stats raises a flag that needs a focused drill-down (a specific turn, a specific bash command, a specific sub-agent prompt), delegate that drill to the transcript assistant sub-agent rather than running it in this thread. Hand it the path and the focus question.
3. Produce the standard phase-1 proposal in the markdown shape from the transcript analyst system prompt: Summary → Findings → Proposals → Open questions. Do **not** write any files yet — phase 2 only after explicit user confirmation.
4. End by asking which output folder to use for phase 2 if the user has not already named one.

Reminders:
- Skill `transcript-recipes` has the canonical jq idioms when you do need to drill.
- Never `Read` a `.jsonl` file without `offset` + `limit`.
- Quantify findings with `.message.usage` numbers, never estimates.
