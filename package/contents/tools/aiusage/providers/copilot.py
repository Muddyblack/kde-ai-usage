"""Resolve a GitHub token and fetch Copilot premium-request usage.

Ported from tools/sh/get-copilot-usage.
"""

import os

from ..http import as_json, error_json, fetch_json, http_error_json, resolve_key


def _github_get(url, api_key, fixture_path):
    return fetch_json(
        url,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "kde-ai-usage/copilot",
        },
        timeout=10,
        fixture_path=fixture_path,
    )


def get_copilot_usage():
    api_key = resolve_key("WIDGET_GITHUB_TOKEN", "GITHUB_TOKEN", os.path.expanduser("~/.config/github-copilot/token"))
    if not api_key:
        return {}

    quota_raw = os.environ.get("WIDGET_COPILOT_QUOTA") or os.environ.get("COPILOT_QUOTA") or ""
    try:
        quota = int(quota_raw)
    except ValueError:
        quota = 300

    user_result = _github_get("https://api.github.com/user", api_key, os.environ.get("COPILOT_USER_RESPONSE_FILE"))
    if user_result.status != 200:
        return http_error_json("GitHub", user_result.status, "Invalid GitHub token")

    user_body = as_json(user_result.body) or {}
    username = user_body.get("login")
    if not isinstance(username, str) or username == "":
        return error_json("GitHub username missing")

    usage_result = _github_get(
        f"https://api.github.com/users/{username}/settings/billing/premium_request/usage",
        api_key,
        os.environ.get("COPILOT_USAGE_RESPONSE_FILE"),
    )
    if usage_result.status != 200:
        return http_error_json("GitHub Copilot", usage_result.status, "GitHub token cannot read Copilot premium request usage")

    usage_body = as_json(usage_result.body)
    if usage_body is None:
        return error_json("GitHub Copilot invalid JSON")

    items = usage_body if isinstance(usage_body, list) else (usage_body.get("usageItems") or [])
    used = 0
    for item in items:
        q = item.get("grossQuantity") or 0
        if not isinstance(q, (int, float)) or isinstance(q, bool):
            try:
                q = float(q)
            except (TypeError, ValueError):
                q = 0
        used += q

    return {
        "hasKey": True,
        "keyValid": True,
        "username": username,
        "used": used,
        "quota": quota,
        "pct": min(100, (used / quota) * 100) if quota > 0 else 0,
    }
