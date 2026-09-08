"""Aggregate lifetime Muse Code usage from local session logs.

Muse Code persists every session under
${XDG_DATA_HOME:-~/.local/share}/muse/sessions/YYYY/MM/DD/<id>/session.jsonl
(one JSON envelope per line), with one sub-log per delegated subagent under
<subagent>/<child-id>/session.jsonl. Each model call leaves a
run/model_completed record carrying {model, usage:{input_tokens,
output_tokens, cached_tokens, reasoning_tokens}}, so lifetime totals are
computable fully offline with only the standard library.

Two honesty notes, both verified against a live log plus `muse trace inspect`:

- input_tokens are cumulative context per call (every request resends the
  context), so their sum overstates; output/reasoning are incremental.
  Totals follow the `trace inspect` convention (plain sums) and the raw
  chart series uses output tokens only.
- `trace inspect` projects a single run stream; this aggregates every run
  and every subagent log, so totals legitimately exceed a one-run export.

Results are cached and only recomputed when a session file is newer than
the cache, mirroring providers/codex_stats.py.

Subscription quota (the Current/Weekly windows of the in-TUI /usage view)
comes from one minimal streaming Responses call per cache TTL: the server
emits a response.subscription_usage event carrying
{window: {used_percent, resets_at, window_duration_mins},
 weekly: {used_percent, resets_at}}. The call uses store:false,
max_output_tokens:16 and costs a handful of tokens; quota is cached for
MUSE_QUOTA_TTL_SECONDS (default 1800) so a 5-minute poll interval does not
turn into a per-poll model call. Any quota failure degrades to local
session statistics — it never fails the provider.
"""

import datetime
import json
import os
import re

from .. import config as _config
from ..http import resolve_key

_DATE_RE = re.compile(r"/(\d{4})/(\d{2})/(\d{2})/[^/]+/")
_MAX_FILE_BYTES = 64 * 1024 * 1024


def _n(v):
    if isinstance(v, bool) or v is None:
        return 0
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0


def sessions_root():
    override = os.environ.get("MUSE_SESSIONS_DIR")
    if override:
        return override
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(data_home, "muse", "sessions")


def _auth_path():
    override = os.environ.get("MUSE_AUTH_PATH")
    if override:
        return override
    config_home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return os.path.join(config_home, "muse", "auth.json")


def _auth_meta():
    """The CLI login slot (providers.meta) or None when the store is
    missing, unreadable or has no meta login. Tokens stay in memory here;
    callers expose presence and the display identity only, never secrets."""
    try:
        with open(_auth_path(), errors="replace") as f:
            doc = json.load(f)
    except (OSError, ValueError):
        return None
    if not isinstance(doc, dict):
        return None
    providers = doc.get("providers")
    if not isinstance(providers, dict):
        return None
    meta = providers.get("meta")
    return meta if isinstance(meta, dict) else None


def auth_presence():
    """Credential *presence* only — the OAuth token is never read out.

    Best-effort: an unreadable or locked-down store means "unknown",
    never an error. This function never changes any permission itself.
    """
    return _auth_meta() is not None


def _iter_session_files(root):
    for dirpath, _dirs, files in os.walk(root):
        for name in files:
            if name != "session.jsonl":
                continue
            path = os.path.join(dirpath, name)
            m = _DATE_RE.search(path.replace(os.sep, "/"))
            if not m:
                continue
            yield path, f"{m.group(1)}-{m.group(2)}-{m.group(3)}", "/subagent/" in path.replace(os.sep, "/")


def _scan_file(path):
    """Aggregate one session.jsonl into a record. Pure counters only: no
    prompt text, tool arguments, file paths or any other payload content
    is retained — only event kinds, model names and token numbers."""
    calls = []
    configured = {}
    tool_calls = 0
    user_msgs = 0
    asst_msgs = 0
    turns = 0
    first_ts = 0
    last_ts = 0
    workspace = ""
    try:
        if os.path.getsize(path) > _MAX_FILE_BYTES:
            return None
    except OSError:
        return None
    try:
        f = open(path, errors="replace")
    except OSError:
        return None
    with f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if not isinstance(rec, dict):
                continue
            ts = _n(rec.get("recorded_at"))
            if ts > 0:
                ts = ts / 1000000
                if first_ts == 0 or ts < first_ts:
                    first_ts = ts
                if ts > last_ts:
                    last_ts = ts
            payload = rec.get("payload")
            if not isinstance(payload, dict):
                continue
            if rec.get("payload_type") == "run.model.configured":
                record = payload.get("record") or {}
                model_id = record.get("model_id") if isinstance(record, dict) else ""
                if model_id:
                    configured[str(model_id)] = True
                continue
            if rec.get("payload_type") == "runtime.session.metadata":
                record = payload.get("record") or {}
                root = record.get("workspace_root") if isinstance(record, dict) else ""
                if root:
                    # Counted only (workspaceCount) — the path itself never
                    # leaves this module, so project locations stay private.
                    workspace = str(root)
                continue
            event = payload.get("event")
            if not isinstance(event, dict):
                continue
            kind = event.get("kind")
            if kind == "model_completed":
                usage = event.get("usage") or {}
                if not isinstance(usage, dict):
                    usage = {}
                calls.append(
                    {
                        "model": str(event.get("model") or "unknown"),
                        "run": str(payload.get("run_id") or ""),
                        "in": _n(usage.get("input_tokens")),
                        "out": _n(usage.get("output_tokens")),
                        "cached": _n(usage.get("cached_tokens")),
                        "reasoning": _n(usage.get("reasoning_tokens")),
                    }
                )
            elif kind == "assistant_tool_calls_committed":
                tool_calls += len(event.get("tool_calls") or [])
            elif kind == "user_prompt_display":
                user_msgs += 1
            elif kind == "assistant_message_committed":
                asst_msgs += 1
            elif kind == "terminal":
                turns += 1
    return {
        "calls": calls,
        "configured": configured,
        "toolCalls": tool_calls,
        "userMsgs": user_msgs,
        "asstMsgs": asst_msgs,
        "turns": turns,
        "firstTs": first_ts,
        "lastTs": last_ts,
        "workspace": workspace,
    }


def _aggregate(records):
    s = sorted((r for r in records if r.get("date")), key=lambda r: r["start"])

    model_usage = {}
    for r in s:
        for call in r["calls"]:
            e = model_usage.setdefault(
                call["model"],
                {"in": 0, "out": 0, "cached": 0, "reasoning": 0, "sessions": set(), "maxCtx": 0},
            )
            e["in"] += call["in"]
            e["out"] += call["out"]
            e["cached"] += call["cached"]
            e["reasoning"] += call["reasoning"]
            e["sessions"].add(r["key"])
    for _run, calls in _runs(s).items():
        peak = max([c["in"] for c in calls] or [0])
        for c in calls:
            model_usage[c["model"]]["maxCtx"] = max(model_usage[c["model"]]["maxCtx"], peak)

    daily = {}
    for r in s:
        d = daily.setdefault(r["date"], {"sessions": 0, "msgs": 0, "tools": 0, "out": 0})
        if not r["subagent"]:
            d["sessions"] += 1
        d["msgs"] += r["userMsgs"] + r["asstMsgs"]
        d["tools"] += r["toolCalls"]
        d["out"] += sum(c["out"] for c in r["calls"])

    longest = {"ms": 0, "messageCount": 0}
    for r in s:
        ms = (r["end"] - r["start"]) * 1000 if r["end"] > r["start"] > 0 else 0
        if ms > longest["ms"]:
            longest = {"ms": ms, "messageCount": r["userMsgs"] + r["asstMsgs"]}

    hours = {}
    for r in s:
        if r["start"] > 0:
            h = datetime.datetime.fromtimestamp(r["start"]).strftime("%H")
            hours[h.lstrip("0") or "0"] = hours.get(h.lstrip("0") or "0", 0) + 1

    model = ""
    for r in reversed(s):
        names = [m for m in r["configured"] if m != "unknown"]
        if names:
            model = names[-1]
            break
    if not model:
        for r in reversed(s):
            names = [c["model"] for c in r["calls"] if c["model"] != "unknown"]
            if names:
                model = names[-1]
                break

    workspaces = set()
    for r in s:
        if r["workspace"]:
            workspaces.add(r["workspace"])

    return {
        "version": 1,
        "source": "muse-sessions",
        "lastComputedDate": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "totalSessions": sum(1 for r in s if not r["subagent"]),
        "subagentSessions": sum(1 for r in s if r["subagent"]),
        "totalMessages": sum(r["userMsgs"] + r["asstMsgs"] for r in s),
        "totalTokens": sum(c["in"] + c["out"] for r in s for c in r["calls"]),
        "totalInputTokens": sum(c["in"] for r in s for c in r["calls"]),
        "totalOutputTokens": sum(c["out"] for r in s for c in r["calls"]),
        "totalCachedTokens": sum(c["cached"] for r in s for c in r["calls"]),
        "totalReasoningTokens": sum(c["reasoning"] for r in s for c in r["calls"]),
        "totalToolCalls": sum(r["toolCalls"] for r in s),
        "totalTurns": sum(r["turns"] for r in s),
        "totalModelCalls": sum(len(r["calls"]) for r in s),
        "maxContextTokens": max([e["maxCtx"] for e in model_usage.values()] or [0]),
        "workspaceCount": len(workspaces),
        "firstSessionDate": min((r["date"] for r in s), default=""),
        "model": model,
        "modelUsage": {
            name: {
                "inputTokens": e["in"],
                "outputTokens": e["out"],
                "cachedTokens": e["cached"],
                "reasoningTokens": e["reasoning"],
                "totalTokens": e["in"] + e["out"],
                "sessions": len(e["sessions"]),
                "contextWindow": e["maxCtx"],
            }
            for name, e in model_usage.items()
        },
        "dailyActivity": [
            {"date": date, "sessionCount": d["sessions"], "messageCount": d["msgs"], "toolCallCount": d["tools"]} for date, d in sorted(daily.items())
        ],
        "dailyModelTokens": [{"date": date, "total": d["out"]} for date, d in sorted(daily.items())],
        "longestSession": {"duration": longest["ms"], "messageCount": longest["messageCount"]},
        "hourCounts": hours,
    }


def _runs(records):
    grouped = {}
    for r in records:
        for call in r["calls"]:
            grouped.setdefault(call["run"] or r["key"], []).append(call)
    return grouped


def _muse_key():
    """Widget field, then the vendor variable. No conventional file: the
    OAuth login lives in a JSON store, not a raw-key file, and is handled
    by auth_presence(). Kept as a named function so the credential tests
    exercise the same order production does instead of restating it."""
    return resolve_key("WIDGET_MUSE_API_KEY", "META_API_KEY")


_QUOTA_BASE_URL = "https://api.meta.ai/v1"
_QUOTA_URL = _QUOTA_BASE_URL + "/responses"
_QUOTA_MODEL = "muse-spark-1.3"
_QUOTA_TIMEOUT = 15


def _quota_ttl():
    try:
        return max(0, int(os.environ.get("MUSE_QUOTA_TTL_SECONDS", "1800")))
    except ValueError:
        return 1800


def _fetch_models(api_key):
    """Account chat-model ids via a free GET (no tokens spent).

    Lets the quota call track the newest model instead of a hardcoded id.
    Runs at most once per quota refresh, and only when the local logs name
    no usable model.
    """
    fixture_path = os.environ.get("MUSE_MODELS_RESPONSE_FILE")
    if fixture_path and os.path.isfile(fixture_path):
        try:
            with open(fixture_path, errors="replace") as f:
                doc = json.load(f)
        except (OSError, ValueError):
            return []
        rows = doc.get("data") if isinstance(doc, dict) else doc
        if not isinstance(rows, list):
            return []
        return [str(r.get("id") or "") for r in rows if isinstance(r, dict) and r.get("id")]
    if not api_key:
        return []

    import urllib.error
    import urllib.request

    req = urllib.request.Request(
        _QUOTA_BASE_URL + "/models",
        headers={"Authorization": f"Bearer {api_key}", "Accept": "application/json", "User-Agent": "kde-ai-usage/muse"},
    )
    try:
        with urllib.request.urlopen(req, timeout=_QUOTA_TIMEOUT) as resp:
            doc = json.loads(resp.read().decode("utf-8", "replace"))
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        return []
    rows = doc.get("data") if isinstance(doc, dict) else []
    if not isinstance(rows, list):
        return []
    return [str(r.get("id") or "") for r in rows if isinstance(r, dict) and r.get("id")]


def _quota_model(stats_model, api_key):
    """Model id for the quota call: what the user actually runs (from local
    logs), else the account list, else the last-known default. The snapshot
    is account-level, so any chat model returns the same windows."""
    if stats_model and stats_model != "unknown" and "spark" in stats_model:
        return stats_model
    for mid in _fetch_models(api_key):
        if "spark" in mid and "voice" not in mid and "image" not in mid:
            return mid
    return _QUOTA_MODEL


def _auth_api_key():
    """The Model-API bearer from the CLI's own login store.

    auth.json holds both the OIDC device-code access_token (401 on the
    Model API) and the api_key the CLI itself sends as bearer — only the
    latter is used here, and only in memory: it is never returned, logged
    or placed in the envelope. Best-effort: an unreadable store just means
    no OAuth credential.
    """
    meta = _auth_meta() or {}
    return _clean(meta.get("api_key") or "")


def _clean(s):
    return s.translate(str.maketrans("", "", "\n\r ")).strip()


def _quota_cache_path():
    return os.path.join(_config.cache_dir(), "muse-quota.json")


def _read_quota_cache(ttl):
    try:
        with open(_quota_cache_path(), errors="replace") as f:
            cached = json.load(f)
    except (OSError, ValueError):
        return None
    if not isinstance(cached, dict) or not isinstance(cached.get("quota"), dict):
        return None
    try:
        age = datetime.datetime.now(datetime.timezone.utc).timestamp() - float(cached.get("fetchedAt") or 0)
    except (TypeError, ValueError):
        return None
    if 0 <= age < ttl:
        return cached["quota"]
    return None


def _write_quota_cache(quota):
    try:
        os.makedirs(_config.cache_dir(), exist_ok=True)
        with open(_quota_cache_path(), "w") as f:
            json.dump(
                {"fetchedAt": datetime.datetime.now(datetime.timezone.utc).timestamp(), "quota": quota},
                f,
            )
    except OSError:
        pass


def _parse_subscription_event(body):
    """First response.subscription_usage object in an SSE stream, or {}.

    Line endings are normalised first: an SSE frame boundary is a blank line,
    which on the wire is frequently CRLF CRLF. Splitting a CRLF stream on
    "\n\n" finds no boundary at all and silently returns {} — the quota would
    just never appear, with no error to explain it.
    """
    buf = body if isinstance(body, str) else ""
    buf = buf.replace("\r\n", "\n")
    start = 0
    while True:
        end = buf.find("\n\n", start)
        if end < 0:
            break
        for line in buf[start:end].splitlines():
            line = line.strip()
            if not line.startswith("data:"):
                continue
            try:
                obj = json.loads(line[5:].strip())
            except ValueError:
                continue
            if isinstance(obj, dict) and obj.get("type") == "response.subscription_usage":
                sub = obj.get("subscription")
                return sub if isinstance(sub, dict) else {}
        start = end + 2
    return {}


def _subscription_to_quota(sub):
    if not isinstance(sub, dict):
        return {}
    window = sub.get("window") or {}
    weekly = sub.get("weekly") or {}
    if not isinstance(window, dict):
        window = {}
    if not isinstance(weekly, dict):
        weekly = {}
    quota = {"plan": "", "current": {}, "weekly": {}}
    cur_reset = int(_n(window.get("resets_at")))
    wk_reset = int(_n(weekly.get("resets_at")))
    if cur_reset > 0:
        quota["current"] = {"pct": _n(window.get("used_percent")), "resetAt": cur_reset}
    if wk_reset > 0:
        quota["weekly"] = {"pct": _n(weekly.get("used_percent")), "resetAt": wk_reset}
    if not quota["current"] and not quota["weekly"]:
        return {}
    return quota


def _quota_error_code(exc):
    """Stable reason code for a failed quota fetch.

    Separates "the server said no" from "we could not ask". Without this a
    network timeout was indistinguishable from a rejected credential, so a
    flaky connection made the tab report the key as invalid.
    """
    status = getattr(exc, "code", None)
    if status in (401, 403):
        return "rejected"
    return "unreachable"


def _fetch_quota_sse(api_key, model, fixture_path=None):
    """(quota, error): error is "" on success, else a _quota_error_code value."""
    if fixture_path and os.path.isfile(fixture_path):
        try:
            # newline="" disables universal-newline translation: a replayed
            # capture has to carry the CRLF the wire actually sent, or it
            # silently tests a stream nobody ever receives.
            with open(fixture_path, errors="replace", newline="") as f:
                raw = f.read()
        except OSError:
            return {}, "unreachable"
        try:
            doc = json.loads(raw)
        except ValueError:
            # Not JSON: replay it as a raw SSE capture, CRLF included.
            return _subscription_to_quota(_parse_subscription_event(raw)), ""
        if isinstance(doc, dict) and isinstance(doc.get("subscription"), dict):
            doc = doc["subscription"]
        return _subscription_to_quota(doc), ""

    import urllib.error
    import urllib.request

    body = json.dumps(
        {
            "model": model,
            "input": "ping",
            "stream": True,
            "max_output_tokens": 16,
            "store": False,
        }
    ).encode()
    req = urllib.request.Request(
        _QUOTA_URL,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Accept": "text/event-stream",
            "User-Agent": "kde-ai-usage/muse",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=_QUOTA_TIMEOUT) as resp:
            raw = resp.read().decode("utf-8", "replace")
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return {}, _quota_error_code(exc)
    # A 200 with no snapshot is not a failure: the account simply reports no
    # subscription windows. Only an unusable answer gets an error code.
    return _subscription_to_quota(_parse_subscription_event(raw)), ""


def get_muse_quota(api_key="", stats_model=""):
    """(quota, error): Current/Weekly subscription windows, cached, never fatal.

    `error` is "" when the snapshot came back (or when the account simply has
    no windows), and otherwise one of "disabled", "no-credential", "rejected"
    or "unreachable" — so the frontend can say "could not reach Meta" instead
    of accusing a working credential of being invalid.

    Credential order mirrors the CLI: an explicit META_API_KEY (widget
    field or environment) wins over the OAuth login's own api_key, exactly
    like the CLI's "META_API_KEY always takes priority". The call needs a
    chat model id but the snapshot is account-level, so the model is picked
    dynamically (local logs, then the free account list) with the
    last-known default as fallback.

    One refresh costs a minimal streaming call (~12 input + ~120 output
    tokens, mostly reasoning, store:false so nothing is kept server-side).
    The stream cannot be cut short to save the output tokens: the server
    emits response.subscription_usage as the LAST event, after
    response.incomplete (probed live — created, in_progress,
    output_item.added, incomplete, subscription_usage), so the generation
    is already paid for by the time the snapshot arrives.
    There is no free endpoint for this data (verified: the usual billing
    paths all 404 and the snapshot exists only on the Responses stream),
    so the switch defaults to OFF: without WIDGET_MUSE_QUOTA=1 (or
    museQuota=true) no call is made at all and the provider renders the free
    offline statistics only.
    """
    if not _config.muse_quota_enabled():
        return {}, "disabled"
    fixture_path = os.environ.get("MUSE_QUOTA_RESPONSE_FILE")
    if fixture_path and os.path.isfile(fixture_path):
        # Test replay, like fetch_json's fixture_path: no credential needed.
        return _fetch_quota_sse("", "", fixture_path=fixture_path)
    key = _clean(api_key) or _auth_api_key()
    if not key:
        return {}, "no-credential"
    model = _quota_model(stats_model, key)
    ttl = _quota_ttl()
    if ttl > 0:
        cached = _read_quota_cache(ttl)
        if cached is not None:
            return cached, ""
    quota, error = _fetch_quota_sse(key, model)
    if quota and ttl > 0:
        _write_quota_cache(quota)
    return quota, error


def get_muse_usage():
    # One store read for identity, key and presence together.
    slot = _auth_meta()
    meta = slot or {}
    has_oauth = slot is not None
    api_key = _muse_key()
    oauth_key = "" if api_key else _clean(meta.get("api_key") or "")
    base = {
        "hasOAuth": has_oauth,
        "hasApiKey": bool(api_key) or bool(oauth_key),
        "keyValid": False,
        "quota": {},
        "quotaError": "",
        "email": str(meta.get("user_email") or ""),
        "fullName": str(meta.get("user_full_name") or ""),
    }

    root = sessions_root()
    if not os.path.isdir(root):
        base["quota"], base["quotaError"] = get_muse_quota(api_key or oauth_key)
        base["keyValid"] = bool(base["quota"])
        if not base["quota"]:
            base["error"] = "No Muse sessions found — run muse once"
        else:
            base["stats"] = {"available": False}
        return base

    try:
        files = [(p, d, sub) for p, d, sub in _iter_session_files(root)]
    except OSError:
        base["error"] = "Muse session store could not be read"
        return base

    cache_path = os.path.join(_config.cache_dir(), "muse-stats.json")
    stats = None
    if os.path.isfile(cache_path):
        try:
            cache_mtime = os.path.getmtime(cache_path)
            stale = any(os.path.getmtime(f) > cache_mtime for f, _d, _s in files)
        except OSError:
            stale = True
        if not stale:
            try:
                with open(cache_path) as fh:
                    stats = json.load(fh)
            except (OSError, ValueError):
                stats = None

    if stats is None:
        records = []
        for path, date, subagent in files:
            scanned = _scan_file(path)
            if scanned is None:
                continue
            key = f"{date}:{os.path.basename(os.path.dirname(path))}"
            records.append(
                {
                    "key": key,
                    "date": date,
                    "subagent": subagent,
                    "start": scanned["firstTs"],
                    "end": scanned["lastTs"],
                    "calls": scanned["calls"],
                    "configured": scanned["configured"],
                    "toolCalls": scanned["toolCalls"],
                    "userMsgs": scanned["userMsgs"],
                    "asstMsgs": scanned["asstMsgs"],
                    "turns": scanned["turns"],
                    "workspace": scanned["workspace"],
                }
            )
        stats = _aggregate(records)
        try:
            os.makedirs(_config.cache_dir(), exist_ok=True)
            with open(cache_path, "w") as fh:
                json.dump(stats, fh)
        except OSError:
            pass

    has_sessions = isinstance(stats, dict) and stats.get("totalSessions", 0) + stats.get("subagentSessions", 0) > 0
    model_hint = stats.get("model", "") if isinstance(stats, dict) else ""
    quota, quota_error = get_muse_quota(api_key or oauth_key, model_hint)
    base["quota"] = quota
    base["quotaError"] = quota_error
    base["keyValid"] = bool(quota)
    if has_sessions:
        base["stats"] = stats
        return base
    if quota:
        base["stats"] = {"available": False}
        return base
    base["error"] = "No Muse sessions found — run muse once"
    return base
