"""Resolve Mistral API key and verify it, plus read vibe CLI session stats.

Ported from tools/sh/get-mistral-usage. Mistral has no public billing API, so:
1. resolve the key (widget config > env var > vibe .env > known config files)
2. call GET /v1/models to verify validity and get the model list
3. read ~/.vibe session logs for local cost / token / session stats
"""

import os
import re

from ..http import as_json, fetch_json, resolve_key


def _vibe_key():
    path = os.path.expanduser("~/.vibe/.env")
    if not os.path.isfile(path):
        return ""
    try:
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("MISTRAL_API_KEY="):
                    return line.split("=", 1)[1].strip().strip("'\"")
    except OSError:
        pass
    return ""


def _vibe_stats():
    session_dir = os.path.expanduser("~/.vibe/logs/session")
    if not os.path.isdir(session_dir):
        return {}
    paths = set()
    for root, _dirs, files in os.walk(session_dir):
        for name in files:
            if name == "meta.json":
                paths.add(os.path.join(root, name))
    docs = []
    for p in sorted(paths):
        try:
            with open(p) as f:
                d = as_json(f.read())
        except OSError:
            continue
        if isinstance(d, dict) and d.get("stats") is not None:
            docs.append(d)
    if not docs:
        return {}

    def s(d, key):
        return (d.get("stats") or {}).get(key) or 0

    by_newest = sorted(docs, key=lambda d: d.get("start_time") or "", reverse=True)
    recent = []
    for d in by_newest[:12]:
        wd = (d.get("environment") or {}).get("working_directory") or ""
        recent.append(
            {
                "title": d.get("title") or "untitled",
                "project": wd.split("/")[-1] if wd else "",
                "branch": d.get("git_branch") or "",
                "cost": s(d, "session_cost"),
                "tokens": s(d, "session_total_llm_tokens"),
                "start": d.get("start_time") or "",
            }
        )
    return {
        "vibeSessionCount": len(docs),
        "vibeTotalCost": sum(s(d, "session_cost") for d in docs),
        "vibeTotalTokens": sum(s(d, "session_total_llm_tokens") for d in docs),
        "vibePromptTokens": sum(s(d, "session_prompt_tokens") for d in docs),
        "vibeCompletionTokens": sum(s(d, "session_completion_tokens") for d in docs),
        "vibeTotalSteps": sum(s(d, "steps") for d in docs),
        "vibeToolOk": sum(s(d, "tool_calls_succeeded") for d in docs),
        "vibeToolFail": sum(s(d, "tool_calls_failed") for d in docs),
        "vibeRecent": recent,
    }


def _vibe_model():
    path = os.path.expanduser("~/.vibe/config.toml")
    if not os.path.isfile(path):
        return ""
    try:
        with open(path, errors="replace") as f:
            for line in f:
                if line.startswith("active_model"):
                    m = re.search(r'=\s*"?([^"]*?)"?\s*$', line.rstrip("\n"))
                    return m.group(1) if m else ""
    except OSError:
        pass
    return ""


def get_mistral_usage():
    api_key = resolve_key(
        "WIDGET_MISTRAL_API_KEY",
        "MISTRAL_API_KEY",
        os.path.expanduser("~/.config/mistral/api-key"),
        os.path.expanduser("~/.mistral/api-key"),
        os.path.expanduser("~/.config/mistral.key"),
    )
    if not api_key:
        api_key = _vibe_key()

    vibe_stats = _vibe_stats()
    vibe_model = _vibe_model()
    base = {**vibe_stats, "vibeActiveModel": vibe_model}

    if not api_key:
        return {**base, "hasKey": False, "keyValid": False}

    result = fetch_json(
        "https://api.mistral.ai/v1/models",
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        timeout=8,
        fixture_path=os.environ.get("MISTRAL_RESPONSE_FILE"),
    )

    if result.status == 200:
        body = as_json(result.body)
        if body is None:
            return {**base, "hasKey": True, "keyValid": False, "error": "Mistral invalid JSON"}
        return {
            **base,
            "hasKey": True,
            "keyValid": True,
            "availableModels": [m.get("id") for m in (body.get("data") or []) if m.get("id")],
        }
    if result.status in (401, 403):
        return {**base, "hasKey": True, "keyValid": False, "error": "Invalid API key (401)"}
    if result.status == 429:
        return {**base, "hasKey": True, "keyValid": True, "error": "Rate limited (429)"}
    if result.status in (0, None, ""):
        return {**base, "hasKey": True, "keyValid": False, "error": "Mistral network error"}
    return {**base, "hasKey": True, "keyValid": False, "error": f"HTTP {result.status}"}
