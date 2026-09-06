# PR #20 review log — Muse Code provider

Maintainer review by Muddyblack (CHANGES_REQUESTED) on
[Muddyblack/kde-ai-usage#20](https://github.com/Muddyblack/kde-ai-usage/pull/20),
with per-item status. Verbatim quotes; `OPEN` items have a fix plan,
`DONE` items name the commit.

## General review (CHANGES_REQUESTED body)

### 1. Display cost — "you pay with usage to see your usage?"

> Does it cost tokens/requests ... to just display your ai usage? ...
> As `docs/provider-contract.md` tells a statistic reading should not cost
> the user at any point.

Valid. Verified: no free endpoint exists (eight conventional billing paths
all 404; the snapshot exists only on the Responses stream), no local copy
exists either (structural scan of 918 `session.jsonl` files: zero quota
objects — the CLI never persists the event), and the stream cannot be cut
short to avoid the output tokens: a live probe shows
`response.subscription_usage` is the **last** of five events, after
`response.incomplete`, so generation is already paid for when it arrives.
Each quota refresh is therefore one minimal streaming call (~12 in +
~120 out tokens, `store: false`).

**Resolution: the switch now defaults to OFF.** With no free read possible
anywhere, opt-in is the only default that honours the contract — an
untouched install makes no network call and renders the local session
statistics. Turning it on caches for 30 min. Two tests pin the default (one
end-to-end, one on `muse_quota_enabled()`), both confirmed to fail if it is
flipped back. Response: refreshes cached 30 min
(`MUSE_QUOTA_TTL_SECONDS`), an explicit **Live quota** switch
(settings, Hyprland toggle, `WIDGET_MUSE_QUOTA=0` / `museQuota: false`)
leaves the free offline statistics, and the README documents the exact
cost. Status: **DONE** (`14b62aa`).

### 2. CLI status command alternative

> Does the CLI have a status command with the Current/Weekly windows, or
> only the billing-cycle budget that could be used instead[?]

Checked: no `muse` status/usage subcommand exists (full `--help` surveyed);
`/usage` is TUI-only and not interpretable headless (verified via
`exec --provider echo`). No billing-cycle endpoint found. Status: **DONE**
(answered, no code possible).

### 3. Hardcoded quota model

> `_QUOTA_MODEL = "muse-spark-1.3"` is a hard coded model is there [a]
> better way?

Fixed: the quota model is picked dynamically — model from local logs
first, then the free account `GET /models` list, then the last-known
default. The snapshot is account-level so any chat model returns the same
windows. Status: **DONE** (`14b62aa`).

### 4. Theme reuse — maintainer takes it

> Also not sure if the theme is reused correctly but I might fix that in
> another PR then myself.

No action on our side; overlaps inline items 7–9 below, which we fix
first with theme-aware colors. Status: **ACKNOWLEDGED**.

### 5. README reminder

> If changing shouldnt forget update readme file on that.

Cost paragraph, model selection, toggle, and credential order are
documented in the README Muse section. Status: **DONE**.

## Issue comments

### 6. Screenshots (done by contributor)

Maintainer asked for screenshots; ark3us posted one showing the tab.
Status: **DONE** (no code).

### 7. Model from local files or model list

> Maybe really check if there are no local files like for codex agy
> claude etc which show what model is used [...] or can fetch all models
> of muse instead of hard coding it making it more bulletproof.

Both implemented, in that order (see item 3). Status: **DONE** (`14b62aa`).

## Inline comments

### 8. SSE CRLF handling — `providers/muse.py:388` — DONE

> SSE frames are often \r\n\r\n. If Meta sends CRLF this never matches,
> parsing returns {}. Normalize line endings before splitting.

Fixed: `_parse_subscription_event` normalises `\r\n` → `\n` before
splitting on the blank line.

Writing the test found a second defect. The fixture replay opened the
capture in text mode, and Python's universal-newline translation rewrote
`\r\n` to `\n` on read — so a CRLF fixture could never reproduce a CRLF
stream, and the new test passed with the fix removed. `newline=""` makes
the replay byte-faithful; the fixture path also accepts a raw SSE capture
now, not only the parsed JSON. Both the end-to-end and the unit case were
confirmed to fail without the fix.

### 9. keyValid vs unreachable — `providers/muse.py:505` — DONE

> A network timeout reports the key as invalid. Worth distinguishing
> "no credential" / "rejected" / "couldn't reach".

Fixed. `get_muse_quota` now returns `(quota, error)`, where error is `""`
(a snapshot came back, or the account simply reports no windows),
`"disabled"`, `"no-credential"`, `"rejected"` (401/403) or `"unreachable"`
(timeout, DNS, 5xx, anything else). `keyValid` still means "a real
snapshot arrived" and nothing more. `normalize_muse` passes the code
through as `details.quotaError`, `main.qml` exposes `museQuotaError`, and
`MuseTab` shows one subtle line for `"rejected"` and `"unreachable"` only
— a switch the user turned off or a login they never made are their own
doing and stay silent.

A 200 carrying no subscription object is deliberately not an error: the
key worked, the account just has no windows.

### 10. Quota paid then discarded — `normalize/muse.py:102` — DONE

> The quota has already been fetched and paid for at this point, then
> discarded. Someone with a live subscription but no local session logs
> pays for the call and sees "no sessions found". The quota windows
> should render on their own.

Already the behavior before this comment landed: quota-only mode renders
bars, charts and history with a `"26%"`-style headline
(`muse-quota-only.json` fixture). Status: **DONE** (`14b62aa`).

### 11. Guard order — `normalize/muse.py:92` — DONE

> res.get() runs seven times above this, so a non-dict usage raises
> AttributeError before reaching the guard. Move it to the top of the
> function.

Fixed: the `isinstance` check is the first statement of `normalize_muse`,
and the details shape it returns moved into `_blank_details()` so the
guard needs nothing from `res`. Six `res.get()` calls, not seven, but the
crash was real — the new `muse-malformed` fixture (`"usage": [1, 2]`) took
the backend down with an AttributeError before the fix and returns
`"Muse: no data"` after it.

### 12. Stale probe path — `scripts/muse-quota-probe.py:10` (×2) — DONE

> weird path no? / I doubt that this is where the file lives ;=)

Fixed: both Usage lines now say `./scripts/muse-quota-probe.py`.

### 13. Shared compact formatter — `normalize/muse.py:22` — DONE

> Overlaps with the existing token formatter. Worth reusing rather than
> a third copy.

Done, with the rounding difference kept rather than papered over.
`contract.compact_tokens(v, decimals, units, trim_zeros)` is the single
implementation; both providers are now three-line callers that name their
own policy. zai keeps two decimals and an uppercase `K` because that
figure exists to be checked against the vendor's dashboard; muse keeps
`30k`.

No user-visible string moved. Both formatters were diffed against their
originals over 21 values — boundaries, negatives, floats, 1e12 — before
either was migrated: zero mismatches. A regression test now pins seven of
those strings across both providers, so a future "simplification" that
collapses the two policies fails loudly.

### 14. Hardcoded colors — `MuseTab.qml:55`, `:96` — DONE

> _MUSE_ACCENT, accent: in AiUsageShell, museBlue, these floats. Should
> derive from rootItem.museBlue / main.qml already has themed colors.

Fixed. The badge fill/border now derive from `rootItem.museBlue` via
`Qt.rgba(c.r, c.g, c.b, α)` — the same idiom `PanelSlot.qml` uses for its
fallback chip — and the error heading uses
`Kirigami.Theme.negativeTextColor` instead of `"#ef4444"`.

Context worth stating on the PR: the float form was not muse-specific
sloppiness. `ZaiTab.qml:52-54` writes `zaiBlue` out as
`Qt.rgba(0.07, 0.43, 0.96, …)` in exactly the same way, and `"#ef4444"`
appears in five tabs. MuseTab held one white-alpha overlay against 15 in
`main.qml`, 14 in `MistralTab`, 10 in `OpenAiTab` and 9 in `ClaudeTab`.
The widget-wide cleanup stays with the maintainer (item 4); after this
commit MuseTab has no hardcoded color left at all.

### 15. Tab header icon — `MuseTab.qml:20` — DONE

> a generic icon, while already having muse-color.svg?

Fixed. The header shows `../icons/muse-color.svg` through an `Image`, with
the `code-context` symbolic icon kept only as the `status === Image.Error`
fallback — the same construction as `PanelSlot.qml:50-72`.

### 16. Shared segmented bar — `MuseTab.qml:138` — DONE

> Why rewrite instead using the shared segmented bar?

Fixed. The Current/Weekly rows are two `PopupRow` instances passing
`label`, `value`, `barColor` and `countdownText`, exactly as `ZaiTab` does;
`tokenText`/`etaText` stay unset because Muse reports no token counts or
burn rate. The hand-rolled `Repeater` + `Rectangle` track is gone, which
also removes the file's last `Qt.rgba(1, 1, 1, …)` overlay. 8 of the 13
tabs already used `PopupRow`; muse was an outlier.

Two intentional visual changes come with it, both toward consistency:
the percentage below 70% is now the muse accent rather than
`Kirigami.Theme.textColor` (`PopupRow` colors by `barColor`, as on every
other tab), and the countdown moved from a `· 4h 12m` suffix into the
shared countdown badge.
