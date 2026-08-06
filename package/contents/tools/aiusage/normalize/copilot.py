import datetime

from ..contract import epoch_of, flat_window, jround, monthly_window, num, pct_clamp, provider_base, provider_error


def next_month_utc(now):
    """Premium requests reset on the first of the following month, UTC."""
    dt = datetime.datetime.fromtimestamp(now, datetime.timezone.utc)
    y, m = dt.year, dt.month
    y, m = (y + 1, 1) if m == 12 else (y, m + 1)
    return epoch_of(f"{y:04d}-{m:02d}-01T00:00:00Z")


def normalize_copilot(raw):
    now = raw["now"]
    res = raw["inputs"].get("usage") or {}

    if not isinstance(res, dict) or len(res) == 0:
        return provider_error("copilot", "Copilot", "#8b5cf6", now, "Copilot: no token configured", {"hasKey": False, "keyValid": False})
    if res.get("error") is not None:
        return provider_error(
            "copilot",
            "Copilot",
            "#8b5cf6",
            now,
            f"Copilot: {res['error']}",
            {"hasKey": res.get("hasKey") is True, "keyValid": res.get("keyValid") is True},
        )

    pct = pct_clamp(num(res.get("pct")))
    used = num(res.get("used"))
    quota = num(res.get("quota")) if res.get("quota") is not None else 300
    username = res.get("username") or ""
    reset_at = next_month_utc(now)
    detail = f"{used} / {quota} requests"

    r = provider_base("copilot", "Copilot", "#8b5cf6", now)
    r["summary"] = {
        "pct": pct,
        "text": f"{jround(pct)}%",
        "detail": f"@{username}" if username != "" else "Personal billing",
        "hasChart": True,
    }
    r["quotaWindows"] = [flat_window("copilot", "Premium requests", pct, reset_at, detail, True)]
    r["slots"] = [{"pct": pct, "color": "#8b5cf6", "text": None, "tooltip": f"Copilot premium requests: {detail}"}]
    r["chartWindows"] = monthly_window("copilot", "gh", False)
    r["historyValues"] = {"gh": pct}
    r["details"] = {
        "hasKey": res.get("hasKey") is True,
        "keyValid": res.get("keyValid") is True,
        "username": username,
        "used": used,
        "quota": quota,
        "pct": pct,
        "resetAt": reset_at,
    }
    return r
