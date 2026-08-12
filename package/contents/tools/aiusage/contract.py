"""Shared provider normalization primitives.

Every function here is pure: raw provider inputs go in, contract-shaped
pieces come out.
docs/provider-contract.md for the schema these build up.
"""

import calendar
import datetime
import math
import re

SCHEMA_VERSION = 1

# Brand artwork per provider, as a bare filename under contents/icons/. The
# frontends live at different depths, so each resolves the directory itself.
# Every provider funnels through provider_base(), which is why this table can
# stay here instead of being repeated in each normalize module — or, worse, in
# both frontends, where the two copies would drift apart.
# A provider with no artwork yet is simply absent; callers fall back to the
# plain accent dot.
PROVIDER_ICONS = {
    "antigravity": "antigravity-color.svg",
    "claude": "claude-color.svg",
    "copilot": "copilot-color.svg",
    "deepseek": "deepseek-color.svg",
    "grok": "grok.svg",
    "kimi": "kimi.svg",
    "kiro": "kiro.svg",
    "mistral": "mistral-color.svg",
    "openai": "openai.svg",
    "openrouter": "openrouter.svg",
    "zai": "zai.svg",
}


def num(v):
    if isinstance(v, bool):
        return 0
    if isinstance(v, (int, float)):
        return v
    if isinstance(v, str):
        try:
            return float(v) if ("." in v or "e" in v.lower()) else int(v)
        except ValueError:
            return 0
    return 0


def pct_clamp(x):
    if x < 0:
        return 0
    if x > 100:
        return 100
    return x


def jround(x):
    """Round halves away from zero, unlike Python's banker's rounding."""
    if x >= 0:
        return math.floor(x + 0.5)
    return math.ceil(x - 0.5)


def round_pct(x):
    return jround(x * 100) / 100


_TZ_SUFFIX_RE = re.compile(r"(Z|[+-]\d{2}:?\d{2})$")
_FRACTIONAL_SECONDS_RE = re.compile(r"\.\d+")


def _parse_utc(s):
    """Parse strict "%Y-%m-%dT%H:%M:%SZ" input; return None when invalid."""
    try:
        dt = datetime.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        return None
    return calendar.timegm(dt.timetuple())


def epoch_of(v):
    """ISO-8601 (Z / ±HH:MM / ±HHMM, optional fractional seconds) or an epoch
    number, to epoch seconds. 0 means "no reset known"."""
    if isinstance(v, bool):
        return 0
    if isinstance(v, (int, float)):
        return math.floor(v)
    if not isinstance(v, str) or v == "":
        return 0
    t = _FRACTIONAL_SECONDS_RE.sub("", v)
    m = _TZ_SUFFIX_RE.search(t)
    if not m:
        base = _parse_utc(t + "Z")
        return base if base is not None else 0
    b, z = t[: m.start()], m.group(1)
    if z == "Z":
        base = _parse_utc(b + "Z")
        return base if base is not None else 0
    base = _parse_utc(b + "Z")
    if base is None or base == 0:
        return 0
    off = z.replace(":", "")
    sign = off[0]
    hh, mm = int(off[1:3]), int(off[3:5])
    secs = hh * 3600 + mm * 60
    return base - secs if sign == "+" else base + secs


def reset_text(ts):
    if ts is None or ts <= 0:
        return ""
    dt = datetime.datetime.fromtimestamp(ts)
    return dt.strftime("%b ") + str(dt.day) + dt.strftime(", %H:%M")


def unavailable_window():
    return {"available": False, "pct": 0, "resetAt": 0}


def window_value(pct, reset, active):
    if active is False or not isinstance(pct, (int, float)) or isinstance(pct, bool):
        return unavailable_window()
    return {"available": True, "pct": pct_clamp(pct), "resetAt": epoch_of(reset)}


def quota_window(key, label, w, detail):
    reset_at = w.get("resetAt", 0) or 0
    return {
        "key": key,
        "label": label,
        "pct": w.get("pct", 0) or 0,
        "available": w.get("available", False) or False,
        "resetAt": reset_at,
        "resetText": reset_text(reset_at),
        "detail": detail,
        "showMeter": True,
    }


def flat_window(key, label, pct, reset_at, detail, meter, note=""):
    w = {
        "key": key,
        "label": label,
        "pct": pct_clamp(pct),
        "available": True,
        "resetAt": reset_at,
        "resetText": reset_text(reset_at),
        "detail": detail,
        "showMeter": meter,
    }
    if note:
        # A meterless row spends `detail` on the value itself, leaving nothing
        # beside it. `note` is the aside such a row would otherwise have to
        # cram into the value.
        w["note"] = note
    return w


def chart_window(id_, key, label, size, gran):
    return {
        "id": id_,
        "key": key,
        "label": label,
        "size": size,
        "granularity": gran,
        "raw": False,
        "resets": False,
        "periodMs": 0,
        "resetAt": 0,
    }


def resetting(cw, period, window):
    cw = dict(cw)
    cw["resets"] = True
    cw["periodMs"] = period
    cw["resetAt"] = window.get("resetAt", 0) or 0
    return cw


def rolling_windows(session_id, day_id, weekly_id, session_key, weekly_key, session, weekly):
    out = []
    if session.get("available"):
        out.append(resetting(chart_window(session_id, session_key, "5H", 18000000, "5h"), 18000000, session))
        out.append(resetting(chart_window(day_id, session_key, "24H", 86400000, "24h"), 18000000, session))
    if weekly.get("available"):
        out.append(resetting(chart_window(weekly_id, weekly_key, "7D", 604800000, "7d"), 604800000, weekly))
    return out


def monthly_window(id_, key, raw):
    cw = chart_window(id_, key, "30D", 2592000000, "")
    cw["raw"] = raw
    return [cw]


def money(v, currency):
    cents = jround(v * 100)
    sign = "-" if cents < 0 else ""
    c = abs(cents)
    whole, frac = divmod(c, 100)
    if frac == 0:
        amount = f"{sign}{whole}"
    elif frac % 10 == 0:
        amount = f"{sign}{whole}.{frac // 10}"
    else:
        amount = f"{sign}{whole}.{frac:02d}"
    if currency == "USD":
        return "$" + amount
    if currency == "CNY":
        return "¥" + amount
    if currency in ("", None):
        return amount
    return amount + " " + currency


def empty_status():
    return {"indicator": "", "description": "", "components": [], "incidents": [], "latestUpdate": ""}


def status_summary(d):
    if d is None or not isinstance(d, dict) or "status" not in d:
        return empty_status()
    incidents = d.get("incidents") or []
    body = ""
    for inc in incidents:
        if inc.get("status") == "resolved":
            continue
        updates = inc.get("incident_updates") or []
        b = (updates[0].get("body") if updates else "") or ""
        b = b.strip()
        if b != "":
            body = b
            break
    status_obj = d.get("status") or {}
    components = []
    for c in d.get("components") or []:
        status_val = c.get("status") or ""
        if status_val != "" and status_val != "operational" and not (c.get("group") or False):
            components.append((c.get("name") or "") + " (" + status_val.replace("_", " ") + ")")
    incident_names = [inc.get("name") or "" for inc in incidents if inc.get("status") != "resolved"]
    latest = body[0:197] + "…" if len(body) > 200 else body
    return {
        "indicator": status_obj.get("indicator") or "none",
        "description": status_obj.get("description") or "",
        "components": components,
        "incidents": incident_names,
        "latestUpdate": latest,
    }


def provider_base(id_, label, accent, now):
    return {
        "id": id_,
        "label": label,
        "accent": accent,
        "icon": PROVIDER_ICONS.get(id_, ""),
        "ok": True,
        "stale": False,
        "error": "",
        "updatedAt": math.floor(now),
        "summary": {"pct": 0, "text": "", "detail": "", "hasChart": True},
        "quotaWindows": [],
        "chartWindows": [],
        "slots": [],
        "historyValues": {},
        "details": {},
    }


def provider_error(id_, label, accent, now, error, details):
    r = provider_base(id_, label, accent, now)
    r["ok"] = False
    r["stale"] = True
    r["error"] = error
    r["summary"] = {"pct": 0, "text": "unavailable", "detail": error, "hasChart": True}
    r["slots"] = [{"pct": 0, "color": accent, "text": "—", "tooltip": error}]
    r["details"] = details
    return r


def finalize(obj):
    """Recursively collapse integral floats to int ahead of json.dumps."""
    if isinstance(obj, float):
        if math.isfinite(obj) and obj == int(obj):
            return int(obj)
        return obj
    if isinstance(obj, dict):
        return {k: finalize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [finalize(v) for v in obj]
    return obj
