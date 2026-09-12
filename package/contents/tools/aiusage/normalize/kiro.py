from .. import N_
from ..contract import epoch_of, flat_window, jround, monthly_window, num, pct_clamp, provider_base, provider_error


def normalize_kiro(raw):
    now = raw["now"]
    res = raw["inputs"].get("usage") or {}

    if not isinstance(res, dict) or not res:
        return provider_error("kiro", "Kiro", "#8b5cf6", now, N_("Kiro: no local usage data found"), {"available": False})
    if res.get("error") is not None:
        return provider_error("kiro", "Kiro", "#8b5cf6", now, N_("Kiro: %s") % res["error"], {"available": False})

    pct = pct_clamp(num(res.get("percentageUsed")))
    used = num(res.get("currentUsage"))
    limit = num(res.get("usageLimit"))
    reset_at = epoch_of(res.get("resetDate") or "")
    available = limit > 0 or used > 0
    detail = N_("%s / %s credits") % (used, limit)
    plan = res.get("planType") or ""

    r = provider_base("kiro", "Kiro", "#8b5cf6", now)
    r["ok"] = available
    r["error"] = "" if available else N_("Kiro: usage snapshot is empty")
    r["summary"] = {"pct": pct, "text": f"{jround(pct)}%", "detail": plan, "hasChart": True}
    r["quotaWindows"] = [flat_window("kiro", N_("Monthly credits"), pct, reset_at, detail, True)]
    r["slots"] = [
        {
            "pct": pct,
            "color": "#8b5cf6",
            "text": None,
            "tooltip": "Kiro" + (N_("\nPlan: %s") % plan.upper() if plan != "" else "") + N_("\nCredits: %s") % detail,
        }
    ]
    r["chartWindows"] = monthly_window("kiro", "kr", False) if available else []
    r["historyValues"] = {"kr": pct} if available else {}
    r["details"] = {
        "available": available,
        "planType": plan,
        "displayName": res.get("displayName") or N_("Credit"),
        "displayNamePlural": res.get("displayNamePlural") or N_("Credits"),
        "currentUsage": used,
        "usageLimit": limit,
        "pct": pct,
        "remaining": num(res.get("remaining")),
        "currentOverages": num(res.get("currentOverages")),
        "overageCap": num(res.get("overageCap")),
        "overageCharges": num(res.get("overageCharges")),
        "overageRate": num(res.get("overageRate")),
        "currencyCode": res.get("currencyCode") or "USD",
        "currencySymbol": res.get("currencySymbol") or "$",
        "resetAt": reset_at,
        # "cli" = live from kiro-cli's login, "ide" = the Kiro IDE's snapshot.
        "source": res.get("source") if res.get("source") in ("cli", "ide") else "ide",
    }
    return r
