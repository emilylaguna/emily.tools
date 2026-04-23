---
name: url
description: Watch an HTTP or HTTPS URL for status code changes and body content changes. Trigger when the user asks to watch a webpage, know when a site goes down, be alerted when content updates, or monitor an endpoint's availability.
argument-hint: '<url> [--status-only] [every <seconds>]'
---

# /watch:url

Poll a URL and emit events on status-code changes, body content changes, and reachability flips.

## Collecting arguments

- `url` — full URL with scheme.
- `interval` seconds (default 60; respect rate limits — don't go below 30 for third-party services).
- Optional `--status-only` to skip body fetching when only availability matters.

## Invocation

```
command:     watch watch-url <interval> <url>
description: url:<domain-or-path>
persistent:  true
```

## Event format

```
url:status_changed   <url> <FROM>→<TO>
url:content_changed  <url> bytes=<n>        # only in content mode
url:unreachable      <url> :: <reason>
url:recovered        <url> status=<code>
```

## State persistence

Keyed by `(url, mode)`. Cold boot silently seeds the status code + body hash. Warm boot compares and emits deltas.

## Routing decisions

- **Push now**: `url:unreachable` (site is down), `url:status_changed` flipping into a 5xx or 4xx range, `url:recovered` after an outage.
- **Log only**: `url:content_changed` on a frequently-updated page (blog, dashboard). Push only if the user explicitly set up the watch to catch content updates.

## Stop conditions

No auto-stop. Cancel via `TaskStop`.

## Notes

- Follows redirects (`curl -L`).
- 15-second request timeout per poll.
- For sites that need auth/cookies, use `watch:cmd` with a configured `curl` command instead — `watch:url` is for plain public endpoints.
