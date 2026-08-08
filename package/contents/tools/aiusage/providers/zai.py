"""Resolve a Z.AI token and fetch quota/limit data.

Ported from tools/sh/get-zai-usage.
"""

import os

from ..http import as_json, error_json, fetch_json, http_error_json, resolve_key


def get_zai_usage():
    api_key = resolve_key("WIDGET_ZAI_TOKEN", "ZAI_TOKEN", os.path.expanduser("~/.config/zai/token"))
    if not api_key:
        return {}

    result = fetch_json(
        "https://api.z.ai/api/monitor/usage/quota/limit",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json",
            "User-Agent": "kde-ai-usage/zai",
        },
        timeout=10,
        fixture_path=os.environ.get("ZAI_RESPONSE_FILE"),
    )
    if result.status != 200:
        return http_error_json("Z.AI", result.status, "Invalid Z.AI token")

    body = as_json(result.body)
    if body is None:
        return error_json("Z.AI invalid JSON")

    if body.get("success") is False:
        return {"hasKey": True, "keyValid": False, "error": body.get("msg") or "Z.AI API error"}

    data = body.get("data") if isinstance(body.get("data"), dict) else None
    limits = data.get("limits") if data and isinstance(data.get("limits"), list) else None
    has_expected = limits is not None and any(lim.get("type") in ("TOKENS_LIMIT", "TIME_LIMIT") for lim in limits)

    if body.get("success") is True and has_expected:
        # Z.AI exposes multiple TOKENS_LIMIT windows (a short ~5-hour AND a
        # longer ~weekly one). Upstream took only the first via next() and
        # silently dropped the second; collect all in API order instead.
        tok_windows = [lim for lim in limits if lim.get("type") == "TOKENS_LIMIT"]
        tok = tok_windows[0] if tok_windows else {}
        tok2 = tok_windows[1] if len(tok_windows) > 1 else {}
        tools = next((lim for lim in limits if lim.get("type") == "TIME_LIMIT"), {})
        return {
            "hasKey": True,
            "keyValid": True,
            "level": data.get("level") or "",
            "tokenPct": tok.get("percentage") or 0,
            "tokenResetMs": tok.get("nextResetTime"),
            "tokenUsed": tok.get("used") if tok.get("used") is not None else tok.get("usage"),
            "tokenLimit": tok.get("limit") if tok.get("limit") is not None else tok.get("total"),
            "token2Pct": tok2.get("percentage") or 0,
            "token2ResetMs": tok2.get("nextResetTime"),
            "toolsPct": tools.get("percentage") or 0,
            "toolsRemaining": tools.get("remaining"),
            "toolsResetMs": tools.get("nextResetTime"),
            "models": tools.get("usageDetails") or [],
        }
    return {"hasKey": True, "keyValid": False, "error": "Z.AI unexpected response"}
