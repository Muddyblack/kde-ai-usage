# Muse Code provider — analysis and discovery notes

How the `muse` provider works, what was verified by probing the real CLI
(1.0.2), and which questions are still open. Companion to the
[Muse section in the README](../README.md#muse) and the provider contract.

## Data sources

All local, under `${XDG_DATA_HOME:-~/.local/share}/muse/`:

| Path | Content | Access |
|---|---|---|
| `sessions/YYYY/MM/DD/<id>/session.jsonl` | One JSON envelope per line: runs, tasks, model calls, tool calls | world-readable |
| `sessions/.../<id>/subagent/<child>/session.jsonl` | Same envelope format for delegated subagents | world-readable |
| `~/.config/muse/auth.json` (`$MUSE_AUTH_PATH`) | `providers.meta`: `mechanism`, `obtained_via`, `api_base_url`, `api_key`, `access_token`, `user_email`, `user_full_name` | owner-only; best-effort read, presence/identity only |
| `model-catalog/`, `feature-config/` | Model context limits, feature gates | world-readable |
| `session-index.db` | SQLite session index | unreadable from sandboxed helpers; not used |

## Session-log events used

- `run/model_completed` → `{model, usage: {input_tokens, output_tokens, cached_tokens, reasoning_tokens}}`
- `run/goal_usage_attribution` (reported, deduped by `usage_id`) — same numbers
- `run/assistant_tool_calls_committed` → `tool_calls[]` length
- `run/user_prompt_display`, `run/assistant_message_committed` → message counts
- `run/terminal` → turn count
- `run.model.configured` → `{model_id, provider_id}`
- `runtime.session.metadata` → `workspace_root` (counted only, never stored)

### Cumulative-input caveat (verified)

Per-call `input_tokens` are cumulative context: summing them overstates
(~3.7M counted vs ~266K real on the reference log, matching
`muse trace inspect` semantics). Headline and chart series therefore use
**output tokens**, which are incremental. `trace inspect` itself projects a
single run stream; the provider aggregates every run and subagent, so its
totals legitimately exceed a one-run export.

## Subscription quota protocol (verified live)

- Base URL: `https://api.meta.ai/v1` (from the login store's `api_base_url`).
- Credential: the login's `api_key` (48 chars) as bearer. The OIDC
  `access_token` (device-code flow) returns **401** on the Model API; an
  explicit `META_API_KEY` takes priority, matching the CLI.
- Quota arrives only as a `response.subscription_usage` SSE event on a
  streaming `POST /v1/responses`. Observed shape:

```json
{
  "type": "response.subscription_usage",
  "subscription": {
    "tier": "<opaque numeric id>",
    "window": {"used_percent": 26, "resets_at": 1788528365, "window_duration_mins": 300},
    "weekly": {"used_percent": 9, "resets_at": 1788739200}
  }
}
```

- Minimal call: `{model, input: "ping", stream: true, max_output_tokens: 16, store: false}`.
  `max_output_tokens` below 16 is rejected; `store: false` is accepted and
  keeps the probe out of server-side history. Cost per refresh: ~12 input +
  ~120 output tokens (mostly reasoning).
- The non-streaming response `usage` object carries token counts only —
  no subscription data.

### Event ordering — the stream cannot be aborted early (probed live)

A single live probe recorded the full event sequence of the minimal call:

| # | Event | Elapsed |
|---|---|---|
| 1 | `response.created` | +2.20s |
| 2 | `response.in_progress` | +2.20s |
| 3 | `response.output_item.added` | +2.20s |
| 4 | `response.incomplete` | +2.35s |
| 5 | `response.subscription_usage` | +2.35s |

The snapshot is the **last** event, emitted only after generation has ended
(`response.incomplete` = the `max_output_tokens: 16` cap was hit). Reading
the stream incrementally and closing the connection as soon as the quota
arrives would therefore save nothing: the output tokens are already spent.
`resp.read()` draining the whole body is not the reason the call costs
tokens — the API design is.

## No free endpoint (verified)

These all return 404 with a valid credential, so every quota read is a
model call by API design (the TUI's own `/usage` pays it too):

`/v1/usage`, `/v1/me`, `/v1/account`, `/v1/subscription`,
`/dashboard/billing/subscription`, `/dashboard/billing/usage`,
`/v1/dashboard/billing/subscription`, `/v1/organization/usage/completions`.

There is no local copy either. A structural scan (JSON parsing, not grep) of
918 `session.jsonl` files found **zero** `subscription_usage` / `used_percent`
objects: the CLI receives the event on every one of its own calls but never
persists it. Nothing in `runtime/muse/sessions/*.json`, `tui-history.jsonl`,
`feature-config/`, `model-catalog/` or the auth store holds it either. So the
widget cannot piggyback on the user's own muse runs.

Consequences, all implemented:

- **Live quota is off by default.** The provider contract says reading a
  statistic must not cost the user, and every avenue to a free read is
  closed, so opt-in is the only honest default: an untouched install makes
  no network call at all and renders the local session statistics.
- Turning it on (settings → `Live quota`, the Hyprland toggle,
  `WIDGET_MUSE_QUOTA=1` / `museQuota: true`) caches the quota for 30 min
  (`MUSE_QUOTA_TTL_SECONDS`, default 1800, ≈48 refreshes/day ≈ ~600 input +
  ~6K output tokens/day).
- A failed refresh reports *why* (`rejected` for 401/403, `unreachable` for
  timeout/DNS/5xx) instead of letting a flaky connection look like a bad
  credential.
- Any quota failure degrades to local stats; quota renders even with zero
  local sessions (fresh login).

## Model selection for the quota call

The snapshot is account-level, so any chat model returns the same windows.
Order: model from local logs (what the user actually runs) → free account
`GET /models` list (first `spark`, non-voice/image) → last-known default.
Nothing is hardcoded that the account itself can tell us.

## Plan display name (open)

The `/usage` view shows e.g. "Muse Code High Usage", but that string exists
in **none** of: stream events, response objects, MSP schema, binary strings,
model catalog, feature config, CLI logs, session logs, runtime state, or the
channel manifest; `muse-code/config/v1` 404s on `api.meta.ai`, and there is
no debug-log switch to observe the TUI's own call. The API exposes only the
opaque `tier` id, which is not mapped anywhere verifiable — so no name is
shown rather than a guessed one. A user-set label was tried and reverted:
displayed text must be detected, not typed.

## Privacy guarantees (covered by tests)

- Tokens and keys never enter the envelope (presence flags only).
- Email/full name are display identity, same as the other providers.
- Workspace paths are counted, never stored.
- The no-leak contract test replays synthetic credentials and asserts none
  appear in the output.
