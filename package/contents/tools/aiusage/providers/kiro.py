"""Reads Kiro's local usage snapshot from state.vscdb.

Ported from tools/sh/get-kiro-usage (a Perl byte-level brace matcher over the
raw SQLite file). state.vscdb is a real SQLite database — an ItemTable(key,
value) key/value store, same shape VS Code forks use — so query it properly
first. Fall back to the marker/brace scan only if the schema is unexpected;
that keeps this working even if a future Kiro version changes the table shape.
"""

import json
import os
import sqlite3

_MARKER_KEY = "kiro.resourceNotifications.usageState"


def _query_sqlite(db_path):
    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=2)
    except sqlite3.Error:
        return None
    try:
        row = conn.execute("SELECT value FROM ItemTable WHERE key = ?", (_MARKER_KEY,)).fetchone()
    except sqlite3.Error:
        return None
    finally:
        conn.close()
    if not row or row[0] is None:
        return None
    value = row[0]
    if isinstance(value, bytes):
        value = value.decode("utf-8", "replace")
    try:
        return json.loads(value)
    except ValueError:
        return None


def _brace_match_scan(db_path):
    try:
        with open(db_path, "rb") as f:
            blob = f.read()
    except OSError:
        return None
    marker = b'"' + _MARKER_KEY.encode() + b'":'
    start = blob.find(marker)
    if start < 0:
        return None
    start += len(marker)
    json_start = blob.find(b"{", start)
    if json_start < 0:
        return None

    depth = 0
    in_string = False
    escaped = False
    json_end = -1
    for i in range(json_start, len(blob)):
        ch = blob[i]
        if in_string:
            if escaped:
                escaped = False
            elif ch == 0x5C:  # backslash
                escaped = True
            elif ch == 0x22:  # "
                in_string = False
            continue
        if ch == 0x22:
            in_string = True
        elif ch == 0x7B:  # {
            depth += 1
        elif ch == 0x7D:  # }
            depth -= 1
            if depth == 0:
                json_end = i
                break
    if json_end < 0:
        return None
    try:
        return json.loads(blob[json_start : json_end + 1].decode("utf-8", "replace"))
    except ValueError:
        return None


def _n(v, default=0):
    try:
        return float(v) if v is not None else default
    except (TypeError, ValueError):
        return default


def get_kiro_usage():
    db_path = os.path.expanduser("~/.config/Kiro/User/globalStorage/state.vscdb")
    if not os.path.isfile(db_path):
        return {"error": "No Kiro state found — open Kiro and sign in once"}

    usage_state = _query_sqlite(db_path)
    if usage_state is None:
        usage_state = _brace_match_scan(db_path)
    if usage_state is None:
        return {"error": "No Kiro usage snapshot — open Kiro and let it refresh"}
    if not isinstance(usage_state, dict):
        return {"error": "Kiro usage payload could not be parsed"}

    breakdowns = usage_state.get("usageBreakdowns")
    breakdown = breakdowns[0] if isinstance(breakdowns, list) and breakdowns else {}
    if not isinstance(breakdown, dict):
        breakdown = {}

    limit = _n(breakdown.get("usageLimit"))
    if limit == 50:
        plan = "free"
    elif limit == 1000:
        plan = "pro"
    elif limit == 2000:
        plan = "pro+"
    elif limit == 10000:
        plan = "power"
    else:
        plan = "custom"

    current = _n(breakdown.get("currentUsage"))
    percentage = _n(breakdown.get("percentageUsed"))
    if percentage == 0 and limit > 0 and current > 0:
        percentage = (current / limit) * 100.0
    remaining = (limit - current) if limit > 0 else 0
    if remaining < 0:
        remaining = 0

    currency = breakdown.get("currency") or {}
    if not isinstance(currency, dict):
        currency = {}

    return {
        "planType": plan,
        "usageType": breakdown.get("type") or "",
        "usageUnit": breakdown.get("unit") or "",
        "displayName": breakdown.get("displayName") or "Credit",
        "displayNamePlural": breakdown.get("displayNamePlural") or "Credits",
        "currentUsage": current,
        "usageLimit": limit,
        "percentageUsed": percentage,
        "remaining": remaining,
        "currentOverages": _n(breakdown.get("currentOverages")),
        "overageCap": _n(breakdown.get("overageCap")),
        "overageCharges": _n(breakdown.get("overageCharges")),
        "overageRate": _n(breakdown.get("overageRate")),
        "resetDate": breakdown.get("resetDate") or "",
        "currencyCode": currency.get("code") or "USD",
        "currencySymbol": currency.get("symbol") or "$",
        "timestamp": _n(usage_state.get("timestamp")),
        "source": db_path,
    }
