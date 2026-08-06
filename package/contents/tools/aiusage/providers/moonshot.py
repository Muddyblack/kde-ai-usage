"""Resolve a Moonshot/Kimi API key and retrieve its available balance."""

import os

from ..http import as_json, error_json, fetch_json, http_error_json, resolve_key


def _number(value):
    if isinstance(value, bool) or value is None:
        return 0
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0


def get_moonshot_balance():
    api_key = os.environ.get("WIDGET_MOONSHOT_API_KEY") or os.environ.get("MOONSHOT_API_KEY") or os.environ.get("KIMI_API_KEY") or ""
    if not api_key:
        api_key = resolve_key(
            "",
            "",
            os.path.expanduser("~/.config/moonshot/api-key"),
            os.path.expanduser("~/.moonshot/api-key"),
            os.path.expanduser("~/.config/kimi/api-key"),
        )
    if not api_key:
        return {}

    result = fetch_json(
        "https://api.moonshot.ai/v1/users/me/balance",
        headers={"Authorization": f"Bearer {api_key}", "Accept": "application/json", "User-Agent": "kde-ai-usage/kimi"},
        timeout=10,
        fixture_path=os.environ.get("MOONSHOT_BALANCE_RESPONSE_FILE"),
    )
    if result.status != 200:
        return http_error_json("Kimi", result.status, "Invalid Moonshot API key")

    body = as_json(result.body)
    if not isinstance(body, dict):
        return error_json("Kimi invalid JSON")
    data = body.get("data")
    if body.get("status") is False or not isinstance(data, dict):
        return {"hasKey": True, "keyValid": False, "error": body.get("message") or body.get("msg") or "Kimi unexpected response"}

    return {
        "hasKey": True,
        "keyValid": True,
        "availableBalance": _number(data.get("available_balance")),
        "voucherBalance": _number(data.get("voucher_balance")),
        "cashBalance": _number(data.get("cash_balance")),
    }
