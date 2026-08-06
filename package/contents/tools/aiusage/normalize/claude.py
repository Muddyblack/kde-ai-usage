from ..billing import CLAUDE_PRICING, empty_org_usage, price_models
from ..contract import (
    jround,
    num,
    provider_base,
    provider_error,
    quota_window,
    rolling_windows,
    status_summary,
    unavailable_window,
    window_value,
)
from ..stats import claude_stats


def claude_windows(u):
    session = unavailable_window()
    weekly = unavailable_window()
    for i in u.get("limits") or []:
        group, kind = i.get("group"), i.get("kind")
        if group == "session" or kind == "session":
            session = window_value(i.get("percent"), i.get("resets_at"), i.get("is_active"))
        if group == "weekly" or kind in ("weekly", "weekly_scoped"):
            weekly = window_value(i.get("percent"), i.get("resets_at"), i.get("is_active"))
    if not session["available"] and u.get("five_hour") is not None:
        fh = u["five_hour"]
        session = window_value(fh.get("utilization"), fh.get("resets_at"), True)
    if not weekly["available"] and u.get("seven_day") is not None:
        sd = u["seven_day"]
        weekly = window_value(sd.get("utilization"), sd.get("resets_at"), True)
    return {"session": session, "weekly": weekly}


def normalize_claude(raw):
    now = raw["now"]
    inp = raw["inputs"]
    creds = inp.get("credentials") or {}
    oauth = creds.get("claudeAiOauth") or {}
    token = oauth.get("accessToken") or ""
    has_admin = (creds.get("claudeAdminApiKey") or "") != ""
    usage = inp.get("usage")
    status = status_summary(inp.get("status"))
    stats = claude_stats(inp.get("stats"), now)
    if inp.get("orgUsage") is not None:
        org = price_models((inp["orgUsage"].get("data") or []), CLAUDE_PRICING)
    else:
        org = empty_org_usage()

    base_details = {
        "hasOAuth": token != "",
        "hasAdminKey": has_admin,
        "subscriptionType": oauth.get("subscriptionType") or "",
        "rateLimitTier": oauth.get("rateLimitTier") or "",
        "organizationUuid": creds.get("organizationUuid") or "",
        "effortLevel": (inp.get("settings") or {}).get("effortLevel") or "",
        "autoDream": (inp.get("settings") or {}).get("autoDreamEnabled") is True,
        "organizationUsage": org,
        "stats": stats,
        "status": status,
    }

    if token == "":
        r = provider_error(
            "claude",
            "Claude",
            "#cc785c",
            now,
            "OAuth missing — API stats only" if has_admin else "Claude not logged in",
            {
                **base_details,
                "session": unavailable_window(),
                "weekly": unavailable_window(),
                "extraTokens": 0,
                "extraUsage": {"enabled": False, "limit": 0, "used": 0, "pct": 0, "currency": "USD"},
            },
        )
        r["ok"] = has_admin
        return r

    if usage is None:
        err = inp.get("usageError") or ""
        return provider_error(
            "claude",
            "Claude",
            "#cc785c",
            now,
            err if err != "" else "Claude usage request failed",
            {
                **base_details,
                "session": unavailable_window(),
                "weekly": unavailable_window(),
                "extraTokens": 0,
                "extraUsage": {"enabled": False, "limit": 0, "used": 0, "pct": 0, "currency": "USD"},
            },
        )

    w = claude_windows(usage)
    extra = usage.get("extra") or usage.get("extra_budget") or {}
    extra_usage = usage.get("extra_usage") or {}
    s_tokens = num((usage.get("five_hour") or {}).get("tokens_used"))
    s_limit = num((usage.get("five_hour") or {}).get("token_limit"))
    w_tokens = num((usage.get("seven_day") or {}).get("tokens_used"))
    w_limit = num((usage.get("seven_day") or {}).get("token_limit"))
    s_detail = f"{s_tokens} / {s_limit} tokens" if s_limit > 0 else ""
    w_detail = f"{w_tokens} / {w_limit} tokens" if w_limit > 0 else ""

    r = provider_base("claude", "Claude", "#cc785c", now)
    r["summary"] = {
        "pct": w["session"]["pct"],
        "text": f"{jround(w['session']['pct'])}%",
        "detail": oauth.get("subscriptionType") or "",
        "hasChart": True,
    }
    r["quotaWindows"] = [
        quota_window("session", "5-hour session", w["session"], s_detail),
        quota_window("weekly", "7-day window", w["weekly"], w_detail),
    ]
    r["slots"] = [
        {
            "pct": w["session"]["pct"],
            "color": "#e05252",
            "text": None,
            "tooltip": f"Claude 5-hour: {jround(w['session']['pct'])}%" + (f"\n{s_detail}" if s_detail else ""),
        },
        {
            "pct": w["weekly"]["pct"],
            "color": "#f5a623",
            "text": None,
            "tooltip": f"Claude 7-day: {jround(w['weekly']['pct'])}%" + (f"\n{w_detail}" if w_detail else ""),
        },
    ]
    r["chartWindows"] = rolling_windows("session", "day", "weekly", "s", "w", w["session"], w["weekly"])
    r["historyValues"] = {
        **({"s": w["session"]["pct"]} if w["session"]["available"] else {}),
        **({"w": w["weekly"]["pct"]} if w["weekly"]["available"] else {}),
    }
    if extra.get("tokens_remaining") is not None:
        extra_tokens = num(extra.get("tokens_remaining"))
    else:
        extra_tokens = num(extra.get("token_limit"))
    r["details"] = {
        **base_details,
        "session": {**w["session"], "tokensUsed": s_tokens, "tokenLimit": s_limit},
        "weekly": {**w["weekly"], "tokensUsed": w_tokens, "tokenLimit": w_limit},
        "extraTokens": extra_tokens,
        "extraUsage": {
            "enabled": extra_usage.get("is_enabled") is True,
            "limit": num(extra_usage.get("monthly_limit")),
            "used": num(extra_usage.get("used_credits")),
            "pct": num(extra_usage.get("utilization")),
            "currency": extra_usage.get("currency") or "USD",
        },
    }
    return r
