import math

from ..contract import flat_window, jround, monthly_window, num, pct_clamp, provider_base, provider_error

# Anything at or above this, read as a duration, would be more than 31 years —
# so it is an absolute epoch instead. Live z.ai responses put an absolute
# millisecond timestamp in `nextResetTime`, despite the field name; treating it
# as a duration and adding it to `now` produced reset dates in the 2080s, which
# went unnoticed because the formatted string carries no year.
_ABSOLUTE_MS_FLOOR = 1000000000000


def _reset_at(value, now):
    """Reset epoch in seconds from a value that may be absolute or relative."""
    ms = num(value)
    if ms <= 0:
        return 0
    if ms >= _ABSOLUTE_MS_FLOOR:
        return math.floor(ms / 1000)
    return math.floor(now + ms / 1000)


def normalize_zai(raw):
    now = raw["now"]
    res = raw["inputs"].get("usage") or {}

    if not isinstance(res, dict) or len(res) == 0:
        return provider_error("zai", "Z.AI", "#126ef4", now, "Z.AI: no token configured", {"hasKey": False, "keyValid": False})
    if res.get("error") is not None:
        return provider_error(
            "zai",
            "Z.AI",
            "#126ef4",
            now,
            f"Z.AI: {res['error']}",
            {"hasKey": res.get("hasKey") is True, "keyValid": res.get("keyValid") is True},
        )

    token_pct = pct_clamp(num(res.get("tokenPct")))
    token2_pct = pct_clamp(num(res.get("token2Pct")))
    tools_pct = pct_clamp(num(res.get("toolsPct")))
    token_reset = _reset_at(res.get("tokenResetMs"), now)
    token2_reset = _reset_at(res.get("token2ResetMs"), now)
    tools_reset = _reset_at(res.get("toolsResetMs"), now)
    token_detail = (
        f"{num(res.get('tokenUsed'))} / {num(res.get('tokenLimit'))} tokens"
        if res.get("tokenUsed") is not None and res.get("tokenLimit") is not None
        else ""
    )
    tools_detail = f"{num(res.get('toolsRemaining'))} remaining" if res.get("toolsRemaining") is not None else ""

    r = provider_base("zai", "Z.AI", "#126ef4", now)
    r["summary"] = {"pct": token_pct, "text": f"{jround(token_pct)}%", "detail": res.get("level") or "", "hasChart": True}
    r["quotaWindows"] = [
        flat_window("zai_tokens", "5-hour tokens", token_pct, token_reset, token_detail, True),
        flat_window("zai_tokens_long", "7-day tokens", token2_pct, token2_reset, "", True),
        flat_window("zai_tools", "Monthly tools", tools_pct, tools_reset, tools_detail, True),
    ]
    r["slots"] = [
        {"pct": token_pct, "color": "#126ef4", "text": None, "tooltip": f"Z.AI tokens (5h): {jround(token_pct)}%"},
        {"pct": token2_pct, "color": "#3b82f6", "text": None, "tooltip": f"Z.AI tokens (7d): {jround(token2_pct)}%"},
        {"pct": tools_pct, "color": "#60a5fa", "text": None, "tooltip": f"Z.AI tools: {jround(tools_pct)}%"},
    ]
    r["chartWindows"] = monthly_window("zai", "za", False)
    r["historyValues"] = {"za": token_pct}
    r["details"] = {
        "hasKey": res.get("hasKey") is True,
        "keyValid": res.get("keyValid") is True,
        "level": res.get("level") or "",
        "token": {
            "pct": token_pct,
            "used": num(res.get("tokenUsed")) if res.get("tokenUsed") is not None else None,
            "limit": num(res.get("tokenLimit")) if res.get("tokenLimit") is not None else None,
            "resetAt": token_reset,
        },
        "tokenLong": {
            "pct": token2_pct,
            "resetAt": token2_reset,
        },
        "tools": {
            "pct": tools_pct,
            "remaining": num(res.get("toolsRemaining")) if res.get("toolsRemaining") is not None else None,
            "resetAt": tools_reset,
        },
        "models": res.get("models") or [],
    }
    return r
