---
name: remind
description: Set a one-shot or recurring time-based reminder. Trigger when the user says "remind me at/in/every ...", "in 10 minutes tell me ...", "every weekday at 9am remind me to ...". Defaults to the Monitor tool via watch-remind (available in every session). Falls back to CronCreate only for recurring reminders where that tool is available.
argument-hint: '<when> <what>'
---

# /remind

Schedule a reminder. Default primitive is **Monitor + watch-remind** because Monitor is available in every Claude Code session (including subagents, where CronCreate is typically NOT available). Only reach for CronCreate for recurring reminders when it's in the session's toolset.

## Picking the primitive

Look at the phrasing:

- **One-shot** ("remind me at 3pm", "in 20 minutes", "tomorrow morning") → **Monitor + watch-remind**. Always works.
- **Recurring** ("every weekday at 9am", "hourly", "every Monday") → try `CronCreate` with `recurring: true` first. If it's not in your tool list, tell the user: "I can't schedule a recurring job in this session — the `CronCreate` tool isn't loaded. I can set up today's reminder as a one-shot, or you'll need a calendar entry." Do NOT try to fake recurring via Monitor (a watch can't outlive the session).

## One-shot via watch-remind (primary path)

### Step 1: Compute the target epoch

Run a bash command to turn the user's phrasing into absolute seconds-since-1970. Handle the three common cases:

**Absolute time today** ("at 3pm", "at 12:50"):
```bash
date -v15H -v0M -v0S +%s      # macOS: 3:00pm today
# or: date -v12H -v50M -v0S +%s  # 12:50 today
```
If that time has already passed today, either tell the user and ask about tomorrow, or add 86400 seconds to push to the next day — don't silently schedule in the past.

**Relative offset** ("in 10 minutes", "in 2 hours"):
```bash
date -v+10M +%s      # macOS
date -d "+10 minutes" +%s   # GNU (Linux)
```

**Named day + time** ("tomorrow at 8am", "Friday at 5pm"):
```bash
date -v+1d -v8H -v0M -v0S +%s   # tomorrow 8am on macOS
date -d "tomorrow 08:00" +%s    # GNU
```

Store the result as `TARGET_EPOCH`.

### Step 2: Pick a polling interval

- Target within **5 minutes** → `interval=5` (second-accurate)
- Target within **1 hour** → `interval=15`
- Target hours or days out → `interval=30` (30 seconds is enough; the script only fires once, overhead is minimal)

### Step 3: Invoke Monitor

```
command:     watch watch-remind <interval> <TARGET_EPOCH> <message>
description: remind:<short-summary>
persistent:  true
```

Example — "remind me at 12:50pm that I have a meeting at 1pm":
```
TARGET_EPOCH=$(date -v12H -v50M -v0S +%s)
# command becomes:
watch watch-remind 5 1745423400 "Meeting at 1pm"
description: remind:12:50 meeting
persistent: true
```

### Step 4: Route the event

When `remind:fire at=<iso> :: <message>` lands in your Monitor events, **always** send a `PushNotification` with the message. That's the whole point.

The harness auto-stops (exit 1 from the script) once the reminder fires — no `TaskStop` needed.

## Recurring via CronCreate (if available)

If `CronCreate` IS in your tool list, use it for recurring reminders:

5 fields: `minute hour day-of-month month day-of-week`, user's local timezone.

**Avoid :00 and :30 minute marks** unless the user named that exact time. Every "remind me at 9am" request landing on `0 9` clusters requests. Nudge off:
- "at 9am" → `3 9 * * *` or `57 8 * * *`
- "hourly" → `7 * * * *`
- "every morning" → `57 8 * * *`

Set `recurring: true`, and `durable: true` only if the user explicitly wants it to survive restarts. Tell them recurring jobs auto-expire after 7 days.

The `prompt` you schedule should tell the next Charlie-turn to send a `PushNotification` with the reminder text.

Example — "every weekday at 9am remind me to stretch":
```
cron:       57 8 * * 1-5
recurring:  true
prompt:     "Send a PushNotification: 'Stretch break.'"
```

## What NOT to do

- **Don't** try `CronCreate` for one-shots when `watch-remind` is sufficient — Monitor is universally available, CronCreate isn't.
- **Don't** silently schedule in the past if the user's target time has already passed today. Ask.
- **Don't** hack recurring reminders via Monitor — the harness dies when the session ends, so "every weekday" won't survive overnight. If CronCreate isn't available, say so and offer one-shots or a calendar entry.
- **Don't** use `ScheduleWakeup` — that's `/loop dynamic` mode only.
