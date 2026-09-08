from ..contract import (
    compact_tokens,
    epoch_of,
    flat_window,
    jround,
    money,
    monthly_window,
    num,
    provider_base,
    provider_error,
    quota_window,
    rolling_windows,
    unavailable_window,
    window_value,
)
from ..stats import muse_stats

_MUSE_ACCENT = "#0064e0"

# The panel pills want the shortest thing that still reads as a count ("30k",
# not "30.00K"), and no Muse session reaches a billion tokens.
_MUSE_UNITS = (("M", 1000000), ("k", 1000))


def _compact(v):
    return compact_tokens(v, units=_MUSE_UNITS)


def _error(now, message, details):
    return provider_error("muse", "Muse", _MUSE_ACCENT, now, message, details)


def _quota_sections(quota):
    """(current, weekly) in the shared window shape, both unavailable until the
    user switches the billed call on and the account actually has a plan.

    Availability gates on resetAt rather than on pct, which is why this cannot
    call window_value() alone: a snapshot without a reset time is not a window,
    while a window at 0% used is simply a fresh one."""
    if not isinstance(quota, dict):
        return unavailable_window(), unavailable_window()
    out = []
    for key in ("current", "weekly"):
        w = quota.get(key)
        has_reset = isinstance(w, dict) and epoch_of(w.get("resetAt")) > 0
        out.append(window_value(num(w.get("pct")), w.get("resetAt"), True) if has_reset else unavailable_window())
    return out[0], out[1]


def normalize_muse(raw):
    now = raw["now"]
    res = raw["inputs"].get("usage")
    # Guard before any res.get(): the raw envelope is replayed from disk in
    # --normalize, so a non-dict here has to be a rendered error, not a
    # traceback.
    if not isinstance(res, dict) or len(res) == 0:
        return _error(now, "Muse: not installed", {"hasLogin": False, "stats": {"available": False}})

    stats = muse_stats(res.get("stats"), now)
    has_login = res.get("hasLogin") is True
    current, weekly = _quota_sections(res.get("quota"))
    quota_error = res.get("quotaError") or ""

    # A paid-for quota must render on its own: someone with a live plan but no
    # local sessions yet would otherwise pay for the call and be told there is
    # nothing to show.
    if not stats.get("available") and not (current["available"] or weekly["available"]):
        return _error(
            now,
            "Muse: no sessions yet" if has_login else "Muse: not logged in",
            {"hasLogin": has_login, "current": current, "weekly": weekly, "quotaError": quota_error, "stats": stats},
        )

    total = num(stats.get("totalTokens"))
    output = num(stats.get("totalOutputTokens"))
    cost = num(stats.get("totalCostUSD"))
    currency = stats.get("currency") or "USD"
    model = stats.get("model") or ""
    calls = num(stats.get("totalModelCalls"))
    sessions = num(stats.get("totalSessions"))

    # Plan windows only exist here when the user opted into the billed call
    # (providers/muse_quota.py); everything else on this tab is free and local.
    windows = []
    if current["available"]:
        windows.append(quota_window("muse_current", "Current", current, f"{jround(current['pct'])}% used"))
    if weekly["available"]:
        windows.append(quota_window("muse_weekly", "Weekly", weekly, f"{jround(weekly['pct'])}% used"))

    if stats.get("available"):
        windows.append(
            flat_window(
                "muse_tokens",
                "Tokens",
                0,
                0,
                _compact(total),
                False,
                note=f"{_compact(output)} out · {int(calls)} calls" if calls else _compact(output) + " out",
            )
        )
    if cost > 0:
        windows.append(flat_window("muse_spend", "Spend (est.)", 0, 0, money(cost, currency), False, note=model))

    headline = current if current["available"] else weekly
    r = provider_base("muse", "Muse", _MUSE_ACCENT, now)
    r["summary"] = {
        "pct": headline["pct"] if headline["available"] else 0,
        "text": f"{jround(headline['pct'])}%" if headline["available"] else _compact(total),
        "detail": model if model else f"{int(sessions)} sessions",
        "hasChart": True,
    }

    tooltip = f"Muse tokens: {_compact(total)}"
    if cost > 0:
        tooltip += f"\nSpend (est.): {money(cost, currency)}"
    if current["available"]:
        tooltip = f"Muse Current: {jround(current['pct'])}% used\n" + tooltip

    r["quotaWindows"] = windows
    r["slots"] = [
        {
            "pct": headline["pct"] if headline["available"] else 0,
            "color": _MUSE_ACCENT,
            "text": None if headline["available"] else _compact(total),
            "tooltip": tooltip,
        }
    ]
    r["chartWindows"] = monthly_window("muse", "mu", True)
    r["historyValues"] = {"mu": total}
    if current["available"] or weekly["available"]:
        r["chartWindows"] = rolling_windows("muse_session", "muse_day", "muse_weekly", "mc", "mw", current, weekly)
        if current["available"]:
            r["historyValues"]["mc"] = current["pct"]
        if weekly["available"]:
            r["historyValues"]["mw"] = weekly["pct"]
    r["details"] = {
        "hasLogin": has_login,
        "email": res.get("email") or "",
        "fullName": res.get("fullName") or "",
        "model": model,
        "currency": currency,
        "totalTokens": total,
        "totalInputTokens": num(stats.get("totalInputTokens")),
        "totalOutputTokens": output,
        "totalCachedTokens": num(stats.get("totalCachedTokens")),
        "totalReasoningTokens": num(stats.get("totalReasoningTokens")),
        "totalCostUSD": cost,
        "totalModelCalls": calls,
        "contextWindow": num(stats.get("contextWindow")),
        "current": current,
        "weekly": weekly,
        "quotaError": quota_error,
        "stats": stats,
    }
    return r
