"""Cline CLI: local session statistics.

The Cline CLI writes one JSON record per session to
~/.cline/data/sessions/<id>/<id>.json — provider, model, workspace, start and
end time, and the session's token and cost totals (`metadata.aggregateUsage`,
which includes any sub-agents). Only those fields are kept: the prompt, the
title, the git remote and the transcript beside it are never read into the
result.
"""

import json
import os

from ..contract import epoch_of, num


def _sessions_dir():
    return os.environ.get("CLINE_SESSIONS_DIR") or os.path.expanduser("~/.cline/data/sessions")


def _usage(meta):
    usage = meta.get("aggregateUsage") if isinstance(meta.get("aggregateUsage"), dict) else meta.get("usage")
    usage = usage if isinstance(usage, dict) else {}
    return {
        "input": num(usage.get("inputTokens")),
        "output": num(usage.get("outputTokens")),
        "cacheRead": num(usage.get("cacheReadTokens")),
        "cacheWrite": num(usage.get("cacheWriteTokens")),
        "cost": num(usage.get("totalCost", meta.get("totalCost"))),
    }


def _read_session(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict):
        return None
    started = epoch_of(data.get("started_at") or "")
    if started <= 0:
        return None
    meta = data.get("metadata") if isinstance(data.get("metadata"), dict) else {}
    workspace = data.get("workspace_root") or data.get("cwd") or ""
    return {
        "startedAt": started,
        "endedAt": epoch_of(data.get("ended_at") or ""),
        "provider": data.get("provider") if isinstance(data.get("provider"), str) else "",
        "model": data.get("model") if isinstance(data.get("model"), str) else "",
        "workspace": os.path.basename(workspace.rstrip("/\\")) if isinstance(workspace, str) else "",
        "status": data.get("status") if isinstance(data.get("status"), str) else "",
        **_usage(meta),
    }


def get_cline_sessions():
    """Every readable session record, oldest first. {} when Cline never ran."""
    root = _sessions_dir()
    if not os.path.isdir(root):
        return {}
    sessions = []
    try:
        entries = os.listdir(root)
    except OSError:
        return {}
    for name in entries:
        record = _read_session(os.path.join(root, name, name + ".json"))
        if record is not None:
            sessions.append(record)
    sessions.sort(key=lambda s: s["startedAt"])
    return {"sessions": sessions}
