from ..contract import flat_window, money, monthly_window, num, provider_base, provider_error


def normalize_moonshot(raw):
    now = raw["now"]
    res = raw["inputs"].get("usage") or {}
    if not isinstance(res, dict) or not res:
        return provider_error("kimi", "Kimi", "#1e3a8a", now, "Kimi: no Moonshot API key configured", {"hasKey": False, "keyValid": False})
    if res.get("error") is not None:
        return provider_error("kimi", "Kimi", "#1e3a8a", now, f"Kimi: {res['error']}", {"hasKey": res.get("hasKey") is True, "keyValid": False})

    available = num(res.get("availableBalance"))
    voucher = num(res.get("voucherBalance"))
    cash = num(res.get("cashBalance"))
    r = provider_base("kimi", "Kimi", "#1e3a8a", now)
    r["summary"] = {"pct": 0, "text": money(available, "USD"), "detail": "Moonshot API", "hasChart": True}
    r["quotaWindows"] = [
        flat_window("kimi_balance", "Available balance", 0, 0, money(available, "USD"), False),
        flat_window("kimi_split", "Voucher / cash", 0, 0, f"{money(voucher, 'USD')} / {money(cash, 'USD')}", False),
    ]
    r["slots"] = [{"pct": 0, "color": "#1e3a8a", "text": money(available, "USD"), "tooltip": f"Kimi balance: {money(available, 'USD')}"}]
    r["chartWindows"] = monthly_window("kimi", "km", True)
    r["historyValues"] = {"km": available}
    r["details"] = {
        "hasKey": res.get("hasKey") is True,
        "keyValid": res.get("keyValid") is True,
        "availableBalance": available,
        "voucherBalance": voucher,
        "cashBalance": cash,
        "currency": "USD",
    }
    return r
