from ..contract import (
    compact_tokens,
    epoch_of,
    flat_window,
    monthly_window,
    num,
    pct_clamp,
    provider_base,
    provider_error,
    quota_window,
    reset_text,
    rolling_windows,
)
from ..stats import muse_stats

_MUSE_ACCENT = "#0064E0"


def _pct_text(pct):
    return f"{pct_clamp(num(pct)):g}%"


# The panel pills want the shortest thing that still reads as a count ("30k",
# not "30.00K"), and Muse reports output tokens only — no billions in sight.
_MUSE_UNITS = (("M", 1000000), ("k", 1000))


def _compact(v):
    return compact_tokens(v, units=_MUSE_UNITS)


def _quota_section(quota):
    """Quota windows in the provider shape:

    {"plan": "Muse Code High Usage",
     "current": {"pct": 13, "resetAt": <epoch>},
     "weekly": {"pct": 4, "resetAt": <epoch>}}

    Empty (see providers/muse.py:get_muse_quota): returns no windows so the
    provider renders local session statistics only. Availability gates on
    resetAt, not pct — a fresh window legitimately reports 0% used.
    """
    if not isinstance(quota, dict) or len(quota) == 0:
        return [], [], {}
    session = {"available": False, "pct": 0, "resetAt": 0}
    weekly = {"available": False, "pct": 0, "resetAt": 0}
    cur = quota.get("current") or {}
    wk = quota.get("weekly") or {}
    if isinstance(cur, dict) and epoch_of(cur.get("resetAt")) > 0:
        session = {"available": True, "pct": pct_clamp(num(cur.get("pct"))), "resetAt": epoch_of(cur.get("resetAt"))}
    if isinstance(wk, dict) and epoch_of(wk.get("resetAt")) > 0:
        weekly = {"available": True, "pct": pct_clamp(num(wk.get("pct"))), "resetAt": epoch_of(wk.get("resetAt"))}
    if not session["available"] and not weekly["available"]:
        return [], [], {}
    windows = []
    if session["available"]:
        windows.append(
            quota_window(
                "muse_current",
                "Current",
                session,
                f"{_pct_text(session['pct'])} used · resets {reset_text(session['resetAt'])}",
            )
        )
    if weekly["available"]:
        windows.append(quota_window("muse_weekly", "Weekly", weekly, f"{_pct_text(weekly['pct'])} used · resets {reset_text(weekly['resetAt'])}"))
    charts = rolling_windows("muse_session", "muse_day", "muse_weekly", "mc", "mw", session, weekly)
    history = {}
    if session["available"]:
        history["mc"] = session["pct"]
    if weekly["available"]:
        history["mw"] = weekly["pct"]
    return windows, charts, history


def _blank_details():
    """The details shape with nothing known — what an unusable `usage` yields."""
    return {
        "hasOAuth": False,
        "hasApiKey": False,
        "keyValid": False,
        "quotaError": "",
        "planType": "",
        "email": "",
        "fullName": "",
        "current": {},
        "weekly": {},
    }


def normalize_muse(raw):
    now = raw["now"]
    res = raw["inputs"].get("usage") or {}

    # First statement on purpose: every res.get() below assumes a dict, so a
    # list or a string reaching here would raise AttributeError rather than
    # degrade to "no data".
    if not isinstance(res, dict) or len(res) == 0:
        return provider_error("muse", "Muse", _MUSE_ACCENT, now, "Muse: no data", _blank_details())

    details_base = {
        "hasOAuth": res.get("hasOAuth") is True,
        "hasApiKey": res.get("hasApiKey") is True,
        "keyValid": res.get("keyValid") is True,
        "quotaError": str(res.get("quotaError") or ""),
        "planType": "",
        "email": str(res.get("email") or ""),
        "fullName": str(res.get("fullName") or ""),
        "current": {},
        "weekly": {},
    }
    if res.get("error") is not None:
        details = dict(details_base)
        details["stats"] = {"available": False}
        return provider_error("muse", "Muse", _MUSE_ACCENT, now, f"Muse: {res['error']}", details)

    quota = res.get("quota") or {}
    plan = str(quota.get("plan") or "")
    stats = muse_stats(res.get("stats") or {}, now)
    quota_windows, quota_charts, quota_history = _quota_section(quota)
    if not stats.get("available") and not quota_windows:
        details = dict(details_base)
        details["stats"] = stats
        return provider_error("muse", "Muse", _MUSE_ACCENT, now, "Muse: no sessions found", details)

    has_stats = stats.get("available") is True
    sessions = stats.get("totalSessions", 0)
    model = stats.get("model") or stats.get("favoriteModel") or ""
    out = stats.get("totalOutputTokens", 0)

    if quota_windows:
        headline_pct = quota_windows[0]["pct"]
        label = f"{quota_windows[0]['label']} {_pct_text(headline_pct)}"
        detail = f"{label} · {plan}" if plan else label
    else:
        headline_pct = 0
        detail = f"{sessions} sessions · {model}" if model else f"{sessions} sessions"

    r = provider_base("muse", "Muse", _MUSE_ACCENT, now)
    summary_text = _compact(out) + " out" if has_stats else _pct_text(headline_pct)
    r["summary"] = {"pct": headline_pct, "text": summary_text, "detail": detail, "hasChart": True}
    if quota_windows:
        r["quotaWindows"] = quota_windows
    else:
        r["quotaWindows"] = [
            flat_window("muse_sessions", "Sessions", 0, 0, str(sessions), False),
            flat_window("muse_output", "Output tokens", 0, 0, _compact(out), False),
            flat_window("muse_tools", "Tool calls", 0, 0, _compact(stats["totalToolCalls"]), False),
        ]
    slot_text = _compact(out) if has_stats else _pct_text(headline_pct)
    slot_tip = f"Muse output tokens: {_compact(out)} in {sessions} sessions" if has_stats else f"Muse quota · {plan}" if plan else "Muse quota"
    r["slots"] = [
        {
            "pct": headline_pct,
            "color": _MUSE_ACCENT,
            "text": slot_text,
            "tooltip": slot_tip + (f"\n{plan}" if plan and has_stats else "") + (f"\nCurrent: {quota_windows[0]['detail']}" if quota_windows else ""),
        }
    ]
    r["chartWindows"] = quota_charts if quota_charts else monthly_window("muse", "mu", True)
    history = {"mu": out}
    history.update(quota_history)
    r["historyValues"] = history
    details = dict(details_base)
    details["planType"] = plan
    by_key = {w["key"]: w for w in quota_windows}
    if "muse_current" in by_key:
        w = by_key["muse_current"]
        details["current"] = {"available": True, "pct": w["pct"], "resetAt": w["resetAt"]}
    if "muse_weekly" in by_key:
        w = by_key["muse_weekly"]
        details["weekly"] = {"available": True, "pct": w["pct"], "resetAt": w["resetAt"]}
    details["stats"] = stats
    r["details"] = details
    return r
