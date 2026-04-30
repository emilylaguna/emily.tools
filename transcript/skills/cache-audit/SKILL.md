---
name: cache-audit
description: Cache-only audit of a Claude Code transcript or folder. Surfaces session cache-hit rate, invalidation events, top cache-creation turns, and 20-block lookback misses, then names the suspected invalidator and proposes fixes. Faster and narrower than /analyze-logs — use when you already suspect a session is cache-bleeding and want the cache story without the full proposal flow.
argument-hint: <path-to-jsonl-or-folder>
allowed-tools: Bash, Read, Agent
---

The user wants a cache-only audit of the Claude Code transcripts at: `$ARGUMENTS`

## Scope: only propose fixes the user can actually make

The user is a **Claude Code user**, not someone building against the Anthropic API directly. They control their own files, hooks, plugins, agents, skills, and prompts — they do **not** control the harness internals or API call shape. When you propose fixes, stay inside what they can change.

**In scope (propose fixes for these):**
- CLAUDE.md content — including dynamic content placed before the cache breakpoint
- Hooks they author (pre-tool, stop, etc.) — especially anything emitting non-byte-stable text
- When/whether to run `/plugin` toggles, `/model` switches, or `/reload-plugins` mid-session
- Sub-agent and skill system prompts they author — byte-stability across invocations
- Whether long tool chains should be routed to a sub-agent (they author that decision)
- Session hygiene — e.g. starting a fresh session before a long break instead of mid-session

**Out of scope (don't propose fixes for these — name the cause, then move on):**
- Cache TTL choice (5m vs 1h) — the harness picks; users can't toggle
- API retry behavior — if a retry duplicated a message in the prefix, that's harness behavior. Note it as "harness retry duplicated the user message" and stop.
- Parallel sub-agent dispatch internals — Claude Code doesn't expose a "stagger Task calls" knob. If parallel fan-out paid full write cost N times, name the cost and move on.
- The 20-block lookback window itself — that's Anthropic API. The *user-controllable* fix (split a long chain into a sub-agent or a shorter tool sequence) is still in scope; don't propose API-level changes.
- `tool_choice`, image attach/detach, thinking-mode toggles — harness-driven, not user-set per-turn.
- Anything that requires editing Anthropic SDK internals or Claude Code source.

If a finding's only fix is out-of-scope, **report the diagnosis without a fix** — "this is inherent harness behavior; document and move on." Don't pad the report with non-actionable suggestions.

`txstats` reports cache analysis by default. The cache sections are:

<stats>
```
!`txstats "$ARGUMENTS"`
```
</stats>

Your job:

1. Read the **cache health**, **cache invalidation events**, **top cache-creation turns**, and **20-block lookback risk turns** sections from the stats output above. Ignore everything else for this skill — that's what `/analyze-logs` is for.

2. Compose a tight cache-only report in this shape:

   ```
   # Cache audit: <transcript-or-folder name>

   ## Health
   - cache_hit_rate: <X.XXX> (<healthy | ok | BLEEDING>)
   - billed total: <N> · new tokens: <M>
   - cost-impact estimate: roughly <savings-if-fully-cached> tokens of base-input-equivalent waste vs. ideal

   ## Invalidation events (N)
   For each: turn idx · prev_read → curr_read (drop %) · curr_create · suspected invalidator (drilled from user/system content between the turns).

   ## Top cache-creation turns
   The 3-5 turns where the 1.25× write premium was paid. Note any patterns (same input shape every time → systemic; one-off spike → isolated event).

   ## Lookback risk turns (N)
   For each: turn idx · n_tool_blocks · next_cache_read · whether the lookback actually missed.

   ## Suspected invalidators
   Concrete list of changes the user can make, ordered by token impact. Stay inside the "in scope" list above. Examples:
   - "Move dynamic date out of CLAUDE.md system block; inject as a user message"
   - "Stabilize sub-agent X's system prompt — currently rebuilds file list each call"
   - "Break the 27-block tool chain at turn 113 by routing it to a sub-agent"
   - "Stop-hook emits a timestamp into stdout — make it byte-stable or omit"
   - "Don't toggle plugins mid-session; start a fresh session if the tool set needs to change"

   If a flagged event has no in-scope fix (e.g. it's pure TTL expiry on a multi-hour idle, or harness retry behavior), report the diagnosis under this heading and explicitly mark it **"harness behavior — no user-side fix."** Don't invent a workaround.
   ```

3. For each invalidation event flagged in stats, **drill the diff**: use the recipes in `jq-recipes` ("Inspect a specific cache invalidation event" and "What system-reminders are being injected") to identify the byte-level change between the two turns. If you can't pin it down from a quick drill, delegate to the `assistant` sub-agent with the focus question "identify the invalidator at turn N in <file>".

4. **Do not** produce the full phase-1 proposal directory — that's the analyst's job. This skill is a single readable report. If the audit reveals fixes worth implementing, end the report with one line pointing the user at `/analyze-logs $ARGUMENTS` for the full proposal flow.

Reminders:
- Cache write costs ~1.25× base input (5m TTL) or ~2× (1h TTL); cache read costs ~0.1×. Use these multipliers when estimating savings — but do **not** propose switching TTL as a fix; the harness picks it.
- An invalidation event's lost value is roughly `prev_cache_read × 0.9` (the read you didn't get) plus `curr_cache_creation × 1.25` (the write you paid for).
- Hit rate ≤ 0.6 is the single most actionable signal — surface it in the first line of every report.
- When a bust is caused by something the user can't control (TTL expiry on a long idle, harness retry duplicating a message, etc.), name the cause and stop. Don't manufacture a fix.
