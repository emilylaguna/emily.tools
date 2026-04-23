---
name: remind
description: Set a one-shot or recurring time-based reminder. Trigger when the user says "remind me at/in/every ...", "in 10 minutes tell me ...", "every weekday at 9am remind me to ...". Uses the `CronCreate` tool (NOT the Monitor tool — reminders are cron events, not polling watches).
argument-hint: '<when> <what>'
---

# /remind

Schedule a reminder using the `CronCreate` tool. This skill does NOT use `watch` or `Monitor` — reminders are time-based events, not polling watches.

## Picking the mode

Look at the phrasing:

- **One-shot** ("remind me at 3pm", "in 20 minutes", "tomorrow morning") → `CronCreate` with `recurring: false`. Pin the exact minute/hour/DoM/month based on the target time in the user's local timezone.
- **Recurring** ("every weekday at 9am", "hourly", "every Monday") → `CronCreate` with `recurring: true`. Tell the user about the 7-day auto-expiry on recurring jobs, and set `durable: true` only if they ask for it to survive restarts.

## Cron expression rules

5 fields: `minute hour day-of-month month day-of-week`, all in the user's local timezone. No timezone conversion.

**Avoid :00 and :30 minute marks** unless the user names that exact time. Every "remind me at 9am" request landing on `0 9` puts load spikes on the same instant across the fleet. Nudge the minute:

- "at 9am" → `3 9 * * *` or `57 8 * * *`
- "hourly" → `7 * * * *`
- "every morning" → `57 8 * * *`

Only use minute 0 or 30 when the user names that exact time ("at 9:00 sharp", "at half past the hour").

## Notification shape

The `prompt` you schedule should tell the next Charlie-turn what to do. Two patterns:

- **Passive reminder** (user wants to see the text): `prompt` tells Charlie to send a `PushNotification` with the reminder text.
- **Active task** ("at 5pm deploy the release"): `prompt` describes the action — but unless the user said so explicitly, default to passive reminders. Do not schedule destructive actions unattended without confirmation.

## Examples

User says "remind me at 3pm to leave work":

```
cron:       3 15 <today_dom> <today_month> *
recurring:  false
prompt:     "Send a PushNotification: 'Time to leave work.'"
```

User says "every weekday at 9am remind me to stretch":

```
cron:       57 8 * * 1-5
recurring:  true
prompt:     "Send a PushNotification: 'Stretch break.'"
```

Tell them: "I'll nudge you weekdays around 9am. These jobs auto-expire after 7 days — ping me to renew."

User says "in 10 minutes tell me to check the deploy":

```
cron:       <current_minute+10> <current_hour> <today_dom> <today_month> *
recurring:  false
prompt:     "Send a PushNotification: 'Check the deploy.'"
```

(If 10 minutes crosses an hour boundary, bump the hour field accordingly.)

## What NOT to use

- **Don't use `Monitor`** for reminders. Monitor is for polling "has X changed?" — reminders fire at a pinned time, there's nothing to poll.
- **Don't use `watch:cmd date +%H%M`** or similar hacks. `CronCreate` is the right primitive.
- **Don't use `ScheduleWakeup`** — that's `/loop dynamic` mode, not scheduled reminders.
