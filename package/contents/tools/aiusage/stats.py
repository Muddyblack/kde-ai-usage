"""Shared local-CLI statistics normalization (Claude Code and Codex CLI agree
on the shape)."""

import datetime

from .contract import epoch_of, num


def day_epoch(date):
    if isinstance(date, str) and date != "":
        return epoch_of(date[0:10] + "T00:00:00Z")
    return 0


def activity_streaks(dates, now):
    d = sorted({x for x in dates if x != ""})
    run = 0
    longest = 0
    prev = None
    for day in d:
        cur = day_epoch(day)
        if prev is not None and round((cur - prev) / 86400) == 1:
            run = run + 1
        else:
            run = 1
        longest = max(longest, run)
        prev = cur
    today = day_epoch(datetime.datetime.fromtimestamp(now).strftime("%Y-%m-%d"))
    if len(d) == 0:
        current = 0
    elif round((today - day_epoch(d[-1])) / 86400) <= 1:
        current = run
    else:
        current = 0
    return {"longest": longest, "current": current}


def span_days_since(first, now):
    start = day_epoch(first)
    if start == 0:
        return 0
    return max(1, round((now - start) / 86400) + 1)


def peak_hour(counts):
    """JS iterates integer-like object keys in ascending numeric order and
    keeps the first strictly-greatest bucket; mirror that so the peak hour
    never drifts between the two frontends."""
    if not isinstance(counts, dict):
        return -1
    entries = []
    for k, v in counts.items():
        try:
            h = int(k)
        except (ValueError, TypeError):
            h = -1
        if h >= 0:
            entries.append((h, num(v)))
    entries.sort(key=lambda e: e[0])
    best_h, best_c = -1, -1
    for h, c in entries:
        if c > best_c:
            best_h, best_c = h, c
    return best_h


def claude_stats(s, now):
    if s is None or not isinstance(s, dict) or len(s) == 0:
        return {"available": False}

    usage = s.get("modelUsage") or {}
    models = {}
    total = 0
    cost = 0
    searches = 0
    favorite = ""
    favorite_total = -1
    for key, e in usage.items():
        e = e or {}
        in_ = num(e.get("inputTokens"))
        out_ = num(e.get("outputTokens"))
        model_total = in_ + out_
        model_cost = num(e.get("costUSD"))
        model_searches = num(e.get("webSearchRequests"))
        models[key] = {
            "input": in_,
            "output": out_,
            "cacheRead": num(e.get("cacheReadInputTokens")),
            "cacheCreation": num(e.get("cacheCreationInputTokens")),
            "total": model_total,
            "cost": model_cost,
            "webSearches": model_searches,
            "contextWindow": num(e.get("contextWindow")),
        }
        total += model_total
        cost += model_cost
        searches += model_searches
        if model_total > favorite_total:
            favorite, favorite_total = key, model_total

    dates = [(a.get("date") or "") for a in (s.get("dailyActivity") or []) if a is not None and (a.get("date") or "") != ""]
    streaks = activity_streaks(dates, now)

    daily_tokens = [
        {
            "date": a.get("date") or "",
            "total": sum(num(v) for v in (a.get("tokensByModel") or {}).values()),
        }
        for a in (s.get("dailyModelTokens") or [])
    ]
    daily_tokens.sort(key=lambda a: a["date"])

    total_tool_calls = sum(num(a.get("toolCallCount")) for a in (s.get("dailyActivity") or []))
    longest = s.get("longestSession") or {}

    return {
        "available": True,
        "version": num(s.get("version")),
        "totalMessages": num(s.get("totalMessages")),
        "totalSessions": num(s.get("totalSessions")),
        "totalTokens": total,
        "totalCostUSD": cost,
        "totalWebSearches": searches,
        "totalToolCalls": total_tool_calls,
        "favoriteModel": favorite,
        "firstDate": s.get("firstSessionDate") or "",
        "computedDate": s.get("lastComputedDate") or "",
        "activeDays": len(set(dates)),
        "spanDays": span_days_since(s.get("firstSessionDate") or "", now),
        "currentStreak": streaks["current"],
        "longestStreak": streaks["longest"],
        "longestSessionMs": num(longest.get("duration")),
        "longestSessionMessages": num(longest.get("messageCount")),
        "peakHour": peak_hour(s.get("hourCounts") or {}),
        "models": models,
        "dailyTokens": daily_tokens,
    }


def codex_stats(s, now):
    if s is None or not isinstance(s, dict) or num(s.get("totalSessions")) == 0:
        return {"available": False}

    usage = s.get("modelUsage") or {}
    models = {}
    favorite = ""
    favorite_total = -1
    for key, e in usage.items():
        e = e or {}
        model_total = num(e.get("totalTokens"))
        models[key] = {
            "input": num(e.get("inputTokens")),
            "output": num(e.get("outputTokens")),
            "cacheRead": num(e.get("cachedInput")),
            "reasoning": num(e.get("reasoningTokens")),
            "total": model_total,
            "sessions": num(e.get("sessions")),
            "contextWindow": num(e.get("contextWindow")),
        }
        if model_total > favorite_total:
            favorite, favorite_total = key, model_total

    dates = [(a.get("date") or "") for a in (s.get("dailyActivity") or []) if a is not None and (a.get("date") or "") != ""]
    streaks = activity_streaks(dates, now)

    daily_tokens = [{"date": a.get("date") or "", "total": num(a.get("total"))} for a in (s.get("dailyModelTokens") or [])]
    daily_tokens.sort(key=lambda a: a["date"])

    longest = s.get("longestSession") or {}

    return {
        "available": True,
        "totalSessions": num(s.get("totalSessions")),
        "totalMessages": num(s.get("totalMessages")),
        "totalTokens": num(s.get("totalTokens")),
        "totalToolCalls": num(s.get("totalToolCalls")),
        "favoriteModel": favorite,
        "firstDate": s.get("firstSessionDate") or "",
        "computedDate": s.get("lastComputedDate") or "",
        "activeDays": len(set(dates)),
        "spanDays": span_days_since(s.get("firstSessionDate") or "", now),
        "currentStreak": streaks["current"],
        "longestStreak": streaks["longest"],
        "longestSessionMs": num(longest.get("duration")),
        "longestSessionMessages": num(longest.get("messageCount")),
        "peakHour": peak_hour(s.get("hourCounts") or {}),
        "models": models,
        "dailyTokens": daily_tokens,
        "model": s.get("model") or "",
        "effortLevel": s.get("effortLevel") or "",
    }
