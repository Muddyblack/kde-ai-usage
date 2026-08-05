# Shared provider normalization for the AI usage widget.
#
# Every function here is pure: a raw envelope goes in, one frontend-neutral
# provider object comes out. All IO (credentials, tool invocations, HTTP) lives
# in tools/sh/get-ai-usage, which is why `get-ai-usage --normalize` can replay
# recorded fixtures offline — that is exactly what tests/get-ai-usage.test.sh
# does.
#
# Envelope:  { id, now, inputs: { ...raw provider payloads... } }
# Result:    see docs/provider-contract.md

def schema_version: 1;

# ── Primitives ──────────────────────────────────────────────────────────────

def num(v):
  (v) as $x
  | if ($x | type) == "number" then $x
    elif ($x | type) == "string" then ($x | tonumber? // 0)
    else 0
    end;

def pct_clamp: if . < 0 then 0 elif . > 100 then 100 else . end;

def round_pct: (. * 100 | round) / 100;

# ISO-8601 (with or without fractional seconds and with Z or ±HH:MM offsets),
# or a plain epoch number, to epoch seconds. 0 means "no reset known".
def epoch_of(v):
  (v) as $s
  | if ($s | type) == "number" then ($s | floor)
    elif ($s | type) != "string" or $s == "" then 0
    else
      ($s | sub("\\.[0-9]+"; "")) as $t
      | ($t | capture("^(?<b>.*?)(?<z>Z|[+-][0-9]{2}:?[0-9]{2})$") // null) as $m
      | if $m == null then (($t + "Z") | fromdateiso8601? // 0)
        elif $m.z == "Z" then (($m.b + "Z") | fromdateiso8601? // 0)
        else
          (($m.b + "Z") | fromdateiso8601? // 0) as $base
          | if $base == 0 then 0
            else
              ($m.z | gsub(":"; "")) as $off
              | ((($off[1:3] | tonumber) * 3600) + (($off[3:5] | tonumber) * 60)) as $secs
              | if ($off[0:1] == "+") then $base - $secs else $base + $secs end
            end
        end
    end;

def reset_text: if . > 0 then (. | strflocaltime("%b %-d, %H:%M")) else "" end;

def unavailable_window: { available: false, pct: 0, resetAt: 0 };

def window_value($pct; $reset; $active):
  if $active == false or (($pct | type) != "number")
  then unavailable_window
  else { available: true, pct: ($pct | pct_clamp), resetAt: epoch_of($reset) }
  end;

def quota_window($key; $label; $w; $detail):
  { key: $key,
    label: $label,
    pct: ($w.pct // 0),
    available: ($w.available // false),
    resetAt: ($w.resetAt // 0),
    resetText: (($w.resetAt // 0) | reset_text),
    detail: $detail,
    showMeter: true };

def flat_window($key; $label; $pct; $resetAt; $detail; $meter):
  { key: $key,
    label: $label,
    pct: ($pct | pct_clamp),
    available: true,
    resetAt: $resetAt,
    resetText: ($resetAt | reset_text),
    detail: $detail,
    showMeter: $meter };

# ── Chart windows ───────────────────────────────────────────────────────────
# Which history series a provider contributes, what each one means and how wide
# its chart range is. This is provider metadata, not styling, so it belongs to
# the contract: both frontends render whatever list they are handed instead of
# each keeping their own copy of the table.

# `size` is how much time the chart shows; `periodMs` is how often the quota
# behind it actually resets, and `resetAt` anchors those resets to the clock.
# The two differ for the 24H range, which plots the five-hour series over a
# wider span. A frontend needs all three to redraw a reset that happened while
# the machine was asleep at the moment it really happened.
def chart_window($id; $key; $label; $size; $gran):
  { id: $id, key: $key, label: $label, size: $size, granularity: $gran,
    raw: false, resets: false, periodMs: 0, resetAt: 0 };

def resetting($period; $window):
  . + { resets: true, periodMs: $period, resetAt: ($window.resetAt // 0) };

# Rolling plan windows (Claude, Codex). The 24H range charts the session series
# over a wider span, so it only exists when the session window does.
def rolling_windows($sessionId; $dayId; $weeklyId; $sessionKey; $weeklyKey; $session; $weekly):
  (if $session.available then
     [ chart_window($sessionId; $sessionKey; "5H"; 18000000; "5h") | resetting(18000000; $session),
       chart_window($dayId; $sessionKey; "24H"; 86400000; "24h") | resetting(18000000; $session) ]
   else [] end)
  + (if $weekly.available then
     [ chart_window($weeklyId; $weeklyKey; "7D"; 604800000; "7d") | resetting(604800000; $weekly) ]
   else [] end);

# Everything else charts one 30-day series. `raw` marks money values that the
# chart auto-scales to their own maximum instead of treating as percentages.
# These are running credit or spend totals rather than rolling windows, so they
# carry no reset instant.
def monthly_window($id; $key; $raw):
  [ chart_window($id; $key; "30D"; 2592000000; "") | .raw = $raw ];

def money($v; $currency):
  ($v | . * 100 | round | . / 100 | tostring) as $amount
  | if $currency == "USD" then "$" + $amount
    elif $currency == "CNY" then "¥" + $amount
    elif $currency == "" or $currency == null then $amount
    else $amount + " " + $currency
    end;

# ── Statuspage (status.*/api/v2/summary.json) ───────────────────────────────

def empty_status:
  { indicator: "", description: "", components: [], incidents: [], latestUpdate: "" };

def status_summary($d):
  if $d == null or ($d | type) != "object" or ($d | has("status") | not)
  then empty_status
  else
    ([ ($d.incidents // [])[]
       | select(.status != "resolved")
       | ((.incident_updates // [])[0].body // "")
       | gsub("^\\s+|\\s+$"; "")
       | select(. != "") ][0] // "") as $body
    | { indicator: (($d.status // {}).indicator // "none"),
        description: (($d.status // {}).description // ""),
        components: [ ($d.components // [])[]
                      | select(((.status // "") != "")
                               and (.status != "operational")
                               and ((.group // false) | not))
                      | ((.name // "") + " (" + ((.status // "") | gsub("_"; " ")) + ")") ],
        incidents: [ ($d.incidents // [])[] | select(.status != "resolved") | (.name // "") ],
        latestUpdate: (if ($body | length) > 200 then ($body[0:197] + "…") else $body end) }
  end;

# ── Result scaffolding ──────────────────────────────────────────────────────

def provider_base($id; $label; $accent; $now):
  { id: $id,
    label: $label,
    accent: $accent,
    ok: true,
    stale: false,
    error: "",
    updatedAt: ($now | floor),
    summary: { pct: 0, text: "", detail: "", hasChart: true },
    quotaWindows: [],
    chartWindows: [],
    slots: [],
    historyValues: {},
    details: {} };

def provider_error($id; $label; $accent; $now; $error; $details):
  provider_base($id; $label; $accent; $now)
  | .ok = false
  | .stale = true
  | .error = $error
  | .summary = { pct: 0, text: "unavailable", detail: $error, hasChart: true }
  | .slots = [ { pct: 0, color: $accent, text: "—", tooltip: $error } ]
  | .details = $details;

# ── Shared local-CLI statistics (Claude Code and Codex agree on the shape) ──

def day_epoch($date):
  if ($date | type) == "string" and $date != ""
  then epoch_of($date[0:10] + "T00:00:00Z")
  else 0
  end;

def activity_streaks($dates; $now):
  ($dates | map(select(. != "")) | unique | sort) as $d
  | (reduce $d[] as $day ({ run: 0, longest: 0, prev: null };
      day_epoch($day) as $cur
      | (if .prev != null and (((($cur - .prev) / 86400) | round) == 1)
         then .run + 1 else 1 end) as $run
      | { run: $run, longest: ([.longest, $run] | max), prev: $cur })) as $acc
  | day_epoch($now | strflocaltime("%Y-%m-%d")) as $today
  | { longest: $acc.longest,
      current: (if ($d | length) == 0 then 0
                elif (((($today - day_epoch($d[-1])) / 86400) | round) <= 1) then $acc.run
                else 0
                end) };

def span_days_since($first; $now):
  day_epoch($first) as $start
  | if $start == 0 then 0
    else ([1, (((($now - $start) / 86400) | round) + 1)] | max)
    end;

# JS iterates integer-like object keys in ascending numeric order and keeps the
# first strictly-greatest bucket; mirror that so the peak hour never drifts
# between the two frontends.
def peak_hour($counts):
  if ($counts | type) != "object" then -1
  else
    [ $counts | to_entries[] | { h: (.key | tonumber? // -1), c: num(.value) } ]
    | map(select(.h >= 0))
    | sort_by(.h)
    | reduce .[] as $e ({ h: -1, c: -1 };
        if $e.c > .c then { h: $e.h, c: $e.c } else . end)
    | .h
  end;

def claude_stats($s; $now):
  if $s == null or ($s | type) != "object" or ($s | length) == 0
  then { available: false }
  else
    ($s.modelUsage // {}) as $usage
    | (reduce ($usage | to_entries[]) as $e
        ({ models: {}, total: 0, cost: 0, searches: 0, favorite: "", favoriteTotal: -1 };
          num($e.value.inputTokens) as $in
          | num($e.value.outputTokens) as $out
          | ($in + $out) as $modelTotal
          | num($e.value.costUSD) as $modelCost
          | num($e.value.webSearchRequests) as $modelSearches
          | .models[$e.key] = { input: $in,
                                output: $out,
                                cacheRead: num($e.value.cacheReadInputTokens),
                                cacheCreation: num($e.value.cacheCreationInputTokens),
                                total: $modelTotal,
                                cost: $modelCost,
                                webSearches: $modelSearches,
                                contextWindow: num($e.value.contextWindow) }
          | .total += $modelTotal
          | .cost += $modelCost
          | .searches += $modelSearches
          | (if $modelTotal > .favoriteTotal
             then .favorite = $e.key | .favoriteTotal = $modelTotal
             else . end))) as $agg
    | [ ($s.dailyActivity // [])[] | select(. != null) | (.date // "") | select(. != "") ] as $dates
    | activity_streaks($dates; $now) as $streaks
    | { available: true,
        version: num($s.version),
        totalMessages: num($s.totalMessages),
        totalSessions: num($s.totalSessions),
        totalTokens: $agg.total,
        totalCostUSD: $agg.cost,
        totalWebSearches: $agg.searches,
        totalToolCalls: ([ ($s.dailyActivity // [])[] | num(.toolCallCount) ] | add // 0),
        favoriteModel: $agg.favorite,
        firstDate: ($s.firstSessionDate // ""),
        computedDate: ($s.lastComputedDate // ""),
        activeDays: ($dates | unique | length),
        spanDays: span_days_since($s.firstSessionDate // ""; $now),
        currentStreak: $streaks.current,
        longestStreak: $streaks.longest,
        longestSessionMs: num(($s.longestSession // {}).duration),
        longestSessionMessages: num(($s.longestSession // {}).messageCount),
        peakHour: peak_hour($s.hourCounts // {}),
        models: $agg.models,
        dailyTokens: ([ ($s.dailyModelTokens // [])[]
                        | { date: (.date // ""),
                            total: ([ (.tokensByModel // {}) | to_entries[] | num(.value) ] | add // 0) } ]
                      | sort_by(.date)) }
  end;

def codex_stats($s; $now):
  if $s == null or ($s | type) != "object" or (num($s.totalSessions)) == 0
  then { available: false }
  else
    ($s.modelUsage // {}) as $usage
    | (reduce ($usage | to_entries[]) as $e
        ({ models: {}, favorite: "", favoriteTotal: -1 };
          num($e.value.totalTokens) as $modelTotal
          | .models[$e.key] = { input: num($e.value.inputTokens),
                                output: num($e.value.outputTokens),
                                cacheRead: num($e.value.cachedInput),
                                reasoning: num($e.value.reasoningTokens),
                                total: $modelTotal,
                                sessions: num($e.value.sessions),
                                contextWindow: num($e.value.contextWindow) }
          | (if $modelTotal > .favoriteTotal
             then .favorite = $e.key | .favoriteTotal = $modelTotal
             else . end))) as $agg
    | [ ($s.dailyActivity // [])[] | select(. != null) | (.date // "") | select(. != "") ] as $dates
    | activity_streaks($dates; $now) as $streaks
    | { available: true,
        totalSessions: num($s.totalSessions),
        totalMessages: num($s.totalMessages),
        totalTokens: num($s.totalTokens),
        totalToolCalls: num($s.totalToolCalls),
        favoriteModel: $agg.favorite,
        firstDate: ($s.firstSessionDate // ""),
        computedDate: ($s.lastComputedDate // ""),
        activeDays: ($dates | unique | length),
        spanDays: span_days_since($s.firstSessionDate // ""; $now),
        currentStreak: $streaks.current,
        longestStreak: $streaks.longest,
        longestSessionMs: num(($s.longestSession // {}).duration),
        longestSessionMessages: num(($s.longestSession // {}).messageCount),
        peakHour: peak_hour($s.hourCounts // {}),
        models: $agg.models,
        dailyTokens: ([ ($s.dailyModelTokens // [])[]
                        | { date: (.date // ""), total: num(.total) } ]
                      | sort_by(.date)),
        model: ($s.model // ""),
        effortLevel: ($s.effortLevel // "") }
  end;

# ── Organization billing (Claude and OpenAI share the aggregation shape) ────

def price_models($entries; $pricing):
  (reduce $entries[] as $entry
    ({ models: {}, totalIn: 0, totalOut: 0 };
      ($entry.model // "unknown") as $name
      | (num($entry.input_tokens) | floor) as $in
      | (num($entry.output_tokens) | floor) as $out
      | ($pricing[$name] // null) as $price
      | .models[$name] = ((.models[$name] // { input_tokens: 0, output_tokens: 0, cost_usd: 0, priced: false })
          | .input_tokens += $in
          | .output_tokens += $out
          | (if $price != null
             then .cost_usd += (($in / 1000000) * num($price.input)) + (($out / 1000000) * num($price.output))
                  | .priced = true
             else . end))
      | .totalIn += $in
      | .totalOut += $out)) as $agg
  | { models: $agg.models,
      totalInputTokens: $agg.totalIn,
      totalOutputTokens: $agg.totalOut,
      totalCostUSD: ([ $agg.models | to_entries[] | .value.cost_usd ] | add // 0) };

def empty_org_usage:
  { models: {}, totalInputTokens: 0, totalOutputTokens: 0, totalCostUSD: 0 };

def claude_pricing:
  { "claude-opus-4":              { input: 15,   output: 75 },
    "claude-sonnet-4":            { input: 3,    output: 15 },
    "claude-sonnet-3-5":          { input: 3,    output: 15 },
    "claude-haiku-4":             { input: 0.8,  output: 4 },
    "claude-haiku-3-5":           { input: 0.8,  output: 4 },
    "claude-3-5-sonnet-20241022": { input: 3,    output: 15 },
    "claude-3-5-sonnet-20240620": { input: 3,    output: 15 },
    "claude-3-5-haiku-20241022":  { input: 0.8,  output: 4 },
    "claude-3-opus-20240229":     { input: 15,   output: 75 } };

def openai_pricing:
  { "gpt-4o":                     { input: 2.5,  output: 10 },
    "gpt-4o-2024-11-20":          { input: 2.5,  output: 10 },
    "gpt-4o-2024-08-06":          { input: 2.5,  output: 10 },
    "gpt-4o-mini":                { input: 0.15, output: 0.6 },
    "gpt-4o-mini-2024-07-18":     { input: 0.15, output: 0.6 },
    "o1":                         { input: 15,   output: 60 },
    "o1-2024-12-17":              { input: 15,   output: 60 },
    "o1-mini":                    { input: 1.1,  output: 4.4 },
    "o1-mini-2024-09-12":         { input: 1.1,  output: 4.4 },
    "o3":                         { input: 10,   output: 40 },
    "o3-mini":                    { input: 1.1,  output: 4.4 },
    "o4-mini":                    { input: 1.1,  output: 4.4 },
    "gpt-4-turbo":                { input: 10,   output: 30 },
    "gpt-4-turbo-2024-04-09":     { input: 10,   output: 30 },
    "gpt-4":                      { input: 30,   output: 60 },
    "gpt-4-32k":                  { input: 60,   output: 120 },
    "gpt-3.5-turbo":              { input: 0.5,  output: 1.5 },
    "gpt-3.5-turbo-0125":         { input: 0.5,  output: 1.5 },
    "text-embedding-3-small":     { input: 0.02, output: 0 },
    "text-embedding-3-large":     { input: 0.13, output: 0 } };

# ── Claude ──────────────────────────────────────────────────────────────────

def claude_windows($u):
  (reduce (($u.limits // [])[]) as $i
    ({ session: unavailable_window, weekly: unavailable_window };
      (if ($i.group == "session" or $i.kind == "session")
       then .session = window_value($i.percent; $i.resets_at; $i.is_active)
       else . end)
      | (if ($i.group == "weekly" or $i.kind == "weekly" or $i.kind == "weekly_scoped")
         then .weekly = window_value($i.percent; $i.resets_at; $i.is_active)
         else . end)))
  | (if ((.session.available | not) and ($u.five_hour != null))
     then .session = window_value($u.five_hour.utilization; $u.five_hour.resets_at; true)
     else . end)
  | (if ((.weekly.available | not) and ($u.seven_day != null))
     then .weekly = window_value($u.seven_day.utilization; $u.seven_day.resets_at; true)
     else . end);

def normalize_claude($raw):
  ($raw.now) as $now
  | ($raw.inputs) as $in
  | ($in.credentials // {}) as $creds
  | (($creds.claudeAiOauth // {}).accessToken // "") as $token
  | (($creds.claudeAdminApiKey // "") != "") as $hasAdmin
  | ($in.usage) as $usage
  | status_summary($in.status) as $status
  | claude_stats($in.stats; $now) as $stats
  | (if $in.orgUsage != null
     then price_models(($in.orgUsage.data // []); claude_pricing)
     else empty_org_usage end) as $org
  | { hasOAuth: ($token != ""),
      hasAdminKey: $hasAdmin,
      subscriptionType: (($creds.claudeAiOauth // {}).subscriptionType // ""),
      rateLimitTier: (($creds.claudeAiOauth // {}).rateLimitTier // ""),
      organizationUuid: ($creds.organizationUuid // ""),
      effortLevel: (($in.settings // {}).effortLevel // ""),
      autoDream: ((($in.settings // {}).autoDreamEnabled) == true),
      organizationUsage: $org,
      stats: $stats,
      status: $status } as $baseDetails
  | if $token == "" then
      provider_error("claude"; "Claude"; "#cc785c"; $now;
        (if $hasAdmin then "OAuth missing — API stats only" else "Claude not logged in" end);
        $baseDetails
        + { session: unavailable_window, weekly: unavailable_window,
            extraTokens: 0,
            extraUsage: { enabled: false, limit: 0, used: 0, pct: 0, currency: "USD" } })
      | .ok = $hasAdmin
    elif $usage == null then
      provider_error("claude"; "Claude"; "#cc785c"; $now;
        (($in.usageError // "") | if . == "" then "Claude usage request failed" else . end);
        $baseDetails
        + { session: unavailable_window, weekly: unavailable_window,
            extraTokens: 0,
            extraUsage: { enabled: false, limit: 0, used: 0, pct: 0, currency: "USD" } })
    else
      claude_windows($usage) as $w
      | ($usage.extra // $usage.extra_budget // {}) as $extra
      | ($usage.extra_usage // {}) as $extraUsage
      | (num(($usage.five_hour // {}).tokens_used)) as $sTokens
      | (num(($usage.five_hour // {}).token_limit)) as $sLimit
      | (num(($usage.seven_day // {}).tokens_used)) as $wTokens
      | (num(($usage.seven_day // {}).token_limit)) as $wLimit
      | (if $sLimit > 0 then (($sTokens | tostring) + " / " + ($sLimit | tostring) + " tokens") else "" end) as $sDetail
      | (if $wLimit > 0 then (($wTokens | tostring) + " / " + ($wLimit | tostring) + " tokens") else "" end) as $wDetail
      | provider_base("claude"; "Claude"; "#cc785c"; $now)
      | .summary = { pct: $w.session.pct,
                     text: (($w.session.pct | round | tostring) + "%"),
                     detail: (($creds.claudeAiOauth // {}).subscriptionType // ""),
                     hasChart: true }
      | .quotaWindows = [ quota_window("session"; "5-hour session"; $w.session; $sDetail),
                          quota_window("weekly"; "7-day window"; $w.weekly; $wDetail) ]
      | .slots = [ { pct: $w.session.pct, color: "#e05252", text: null,
                     tooltip: ("Claude 5-hour: " + ($w.session.pct | round | tostring) + "%"
                               + (if $sDetail != "" then "\n" + $sDetail else "" end)) },
                   { pct: $w.weekly.pct, color: "#f5a623", text: null,
                     tooltip: ("Claude 7-day: " + ($w.weekly.pct | round | tostring) + "%"
                               + (if $wDetail != "" then "\n" + $wDetail else "" end)) } ]
      | .chartWindows = rolling_windows("session"; "day"; "weekly"; "s"; "w";
                                        $w.session; $w.weekly)
      | .historyValues = ((if $w.session.available then { s: $w.session.pct } else {} end)
                          + (if $w.weekly.available then { w: $w.weekly.pct } else {} end))
      | .details = $baseDetails
          + { session: ($w.session + { tokensUsed: $sTokens, tokenLimit: $sLimit }),
              weekly: ($w.weekly + { tokensUsed: $wTokens, tokenLimit: $wLimit }),
              extraTokens: (if ($extra.tokens_remaining != null)
                            then num($extra.tokens_remaining) else num($extra.token_limit) end),
              extraUsage: { enabled: ($extraUsage.is_enabled == true),
                            limit: num($extraUsage.monthly_limit),
                            used: num($extraUsage.used_credits),
                            pct: num($extraUsage.utilization),
                            currency: ($extraUsage.currency // "USD") } }
    end;

# ── OpenAI / Codex ──────────────────────────────────────────────────────────

def codex_window($w):
  if $w == null or ($w | type) != "object" then { kind: "", value: unavailable_window }
  else
    (if (($w.windowDurationMins) | type) == "number" then $w.windowDurationMins else null end) as $mins
    | (if (($w.limit_window_seconds) | type) == "number" then $w.limit_window_seconds else null end) as $secs
    | (if ($mins == 300 or $secs == 18000) then "session"
       elif ($mins == 10080 or $secs == 604800) then "weekly"
       else "" end) as $kind
    | (if ($w.usedPercent != null) then $w.usedPercent else $w.used_percent end) as $pct
    | (if ($w.resetsAt != null) then $w.resetsAt else $w.reset_at end) as $reset
    | { kind: $kind,
        value: (if $kind == "" then unavailable_window else window_value($pct; $reset; true) end) }
  end;

def assign_codex_window($w): codex_window($w) as $c
  | if $c.kind != "" then .[$c.kind] = $c.value else . end;

def codex_normalize($p):
  ($p.rateLimits // $p.rate_limit) as $main
  | ({ session: unavailable_window, weekly: unavailable_window }
     | if $main != null
       then assign_codex_window($main.primary // $main.primary_window)
            | assign_codex_window($main.secondary // $main.secondary_window)
       else . end) as $base
  | ($p.rateLimitsByLimitId) as $byId
  | $base
    + { limitReached: ((($main // {}).limit_reached == true)
                       or ((($main // {}).rateLimitReachedType) != null)),
        planType: ((($main // {}).planType) // $p.plan_type // ""),
        additional:
          (if $byId != null then
            [ $byId | to_entries[] | select(.key != "codex") | .value as $s
              | ({ name: ($s.limitName // $s.limitId // .key),
                   session: unavailable_window,
                   weekly: unavailable_window,
                   limitReached: ($s.rateLimitReachedType != null) })
              | assign_codex_window($s.primary)
              | assign_codex_window($s.secondary) ]
          else
            [ ($p.additional_rate_limits // []) | to_entries[] | .key as $i | .value as $l
              | ($l.rate_limit // {}) as $r
              | ({ name: ($l.limit_name // ("Model " + (($i + 1) | tostring))),
                   session: unavailable_window,
                   weekly: unavailable_window,
                   limitReached: ($r.limit_reached == true) })
              | assign_codex_window($r.primary_window)
              | assign_codex_window($r.secondary_window) ]
          end) };

def normalize_openai($raw):
  ($raw.now) as $now
  | ($raw.inputs) as $in
  | ($in.credentials // {}) as $creds
  | (($creds.openaiApiKey // "") != "") as $hasKey
  | (($creds.codexLoggedIn == true) or (($creds.codexAccessToken // "") != "")) as $loggedIn
  | codex_normalize($in.codex // {}) as $codex
  | ($codex.session.available or $codex.weekly.available) as $codexAvailable
  | status_summary($in.status) as $status
  | codex_stats($in.stats; $now) as $stats
  | (if $in.orgUsage != null
     then price_models([ ($in.orgUsage.data // [])[] | (.results // [])[] ]; openai_pricing)
     else empty_org_usage end) as $org
  | (if ($codex.planType // "") != "" then $codex.planType else ($creds.planType // "") end) as $plan
  | { hasApiKey: $hasKey,
      codexLoggedIn: $loggedIn,
      email: ($creds.email // ""),
      planType: $plan,
      orgId: ($creds.orgId // ""),
      accountId: ($creds.accountId // ""),
      authMode: ($creds.authMode // ""),
      codex: { available: $codexAvailable,
               limitReached: $codex.limitReached,
               session: $codex.session,
               weekly: $codex.weekly,
               additional: $codex.additional },
      organizationUsage: $org,
      stats: $stats,
      status: $status } as $details
  | if (($hasKey | not) and ($loggedIn | not)) then
      provider_error("openai"; "OpenAI"; "#10a37f"; $now;
        "OpenAI: no API key or Codex login"; $details)
    elif $codexAvailable then
      provider_base("openai"; "OpenAI"; "#10a37f"; $now)
      | .summary = { pct: $codex.session.pct,
                     text: (($codex.session.pct | round | tostring) + "%"),
                     detail: ($plan + (if ($creds.email // "") != "" then " · " + $creds.email else "" end)),
                     hasChart: true }
      | .quotaWindows = ([ quota_window("codex_session"; "Codex 5-hour"; $codex.session; "ChatGPT/Codex plan window"),
                           quota_window("codex_weekly"; "Codex weekly"; $codex.weekly; "Secondary plan window") ]
                         + [ $codex.additional[]
                             | . as $a
                             | ( (if $a.session.available
                                  then [ quota_window("additional"; ($a.name + " · 5-hour"); $a.session;
                                          (if $a.limitReached then "Limit reached" else "" end)) ]
                                  else [] end)
                               + (if $a.weekly.available
                                  then [ quota_window("additional"; ($a.name + " · weekly"); $a.weekly; "") ]
                                  else [] end) )[] ])
      | .slots = [ { pct: $codex.session.pct, color: "#10a37f", text: null,
                     tooltip: ("Codex 5h: " + ((100 - $codex.session.pct) | round | tostring) + "% left") },
                   { pct: $codex.weekly.pct, color: "#10a37f", text: null,
                     tooltip: ("Codex weekly: " + ((100 - $codex.weekly.pct) | round | tostring) + "% left") } ]
      | .chartWindows = rolling_windows("codex_primary"; "codex_day"; "codex_weekly"; "cp"; "cw";
                                        $codex.session; $codex.weekly)
      | .historyValues = ((if $codex.session.available then { cp: $codex.session.pct } else {} end)
                          + (if $codex.weekly.available then { cw: $codex.weekly.pct } else {} end))
      | .details = $details
    else
      # Signed in or keyed, but the plan windows are not exposed. Account status
      # and org billing still render, so this is not an error state.
      provider_base("openai"; "OpenAI"; "#10a37f"; $now)
      | .stale = (($in.codexError // "") != "")
      | .summary = { pct: 0,
                     text: (if $org.totalCostUSD > 0 then money($org.totalCostUSD; "USD") else "API" end),
                     detail: (if ($creds.email // "") != "" then $creds.email else "API key configured" end),
                     hasChart: false }
      | .quotaWindows = [ flat_window("account"; "API credentials"; 0; 0;
                            (if $hasKey then "Organization usage available"
                             else "Codex signed in; no organization API key" end); false) ]
      | .slots = [ { pct: 0, color: "#10a37f",
                     text: (if $org.totalCostUSD > 0 then money($org.totalCostUSD; "USD") else "API" end),
                     tooltip: (if ($creds.email // "") != "" then $creds.email else "API key configured" end) } ]
      | .details = $details
    end;

# ── Antigravity ─────────────────────────────────────────────────────────────

def antigravity_family($m):
  (($m.label // $m.modelId // "") | ascii_downcase) as $name
  | if ($name | test("gemini|google")) then "gemini" else "external" end;

def normalize_antigravity($raw):
  ($raw.now) as $now
  | ($raw.inputs.usage // {}) as $res
  | if (($res | type) != "object") or ($res | length) == 0 then
      provider_error("antigravity"; "Antigravity"; "#4285f4"; $now;
        "Antigravity not configured"; {})
    elif ($res.error != null) then
      provider_error("antigravity"; "Antigravity"; "#4285f4"; $now;
        (($res.error | split("\n")[0])
         | if test("Antigravity is not running") then "Antigravity is not running in IDE" else . end);
        {})
    else
      [ ($res.models // [])[]
        | . as $m
        | (if (($m.remainingPercentage) | type) == "number" then $m.remainingPercentage else null end) as $rem
        | { modelId: ($m.modelId // "unknown"),
            displayName: ($m.label // $m.modelId // "unknown"),
            hasQuota: ($rem != null),
            usedPct: (if $rem != null then ((1 - $rem) * 100 | pct_clamp) else 0 end),
            resetTime: ($m.resetTime // ""),
            resetAt: epoch_of($m.resetTime // ""),
            isExhausted: ($m.isExhausted == true),
            family: antigravity_family($m) } ] as $models
      | ([ $models[] | select(.hasQuota) ]) as $quoted
      | (if ($quoted | length) > 0 then ([ $quoted[].usedPct ] | add / ($quoted | length)) else 0 end) as $pct
      | ([ $quoted[] | select(.family == "gemini") ]) as $g
      | ([ $quoted[] | select(.family == "external") ]) as $e
      | (if ($g | length) > 0 then ([ $g[].usedPct ] | add / ($g | length)) else 0 end) as $gpct
      | (if ($e | length) > 0 then ([ $e[].usedPct ] | add / ($e | length)) else 0 end) as $epct
      | ([ $models[] | select(.resetAt > 0) | .resetAt ] | min // 0) as $earliest
      | ([ "gemini", "external" ]
         | map(. as $key
               | ($models | map(select(.family == $key))) as $group
               | ($group | map(select(.hasQuota))) as $groupQuoted
               | select(($group | length) > 0)
               | { key: $key,
                   label: (if $key == "gemini" then "Gemini Models" else "Claude & GPT Models" end),
                   usedPct: (if ($groupQuoted | length) > 0
                             then ([ $groupQuoted[].usedPct ] | add / ($groupQuoted | length))
                             else 0 end),
                   resetAt: ([ $group[] | select(.resetAt > 0) | .resetAt ] | min // 0),
                   isExhausted: ($group | any(.isExhausted)),
                   models: ($group | map(.modelId) | sort) })) as $groups
      | ($res.promptCredits // {}) as $credits
      | ($res.planType // (if $res.method == "local" then "LOCAL" else "CLOUD" end)) as $plan
      | provider_base("antigravity"; "Antigravity"; "#4285f4"; $now)
      | .summary = { pct: $pct, text: (($pct | round | tostring) + "%"), detail: $plan, hasChart: true }
      | .quotaWindows = [ $groups[]
                          | flat_window("group"; .label; .usedPct; .resetAt;
                              (if .key == "gemini" and (num($credits.monthly)) > 0
                               then ((num($credits.available) | tostring) + " / "
                                     + (num($credits.monthly) | tostring) + " credits")
                               else "" end); true) ]
      | .slots = [ { pct: $gpct, color: "#4285f4", text: null,
                     tooltip: ("Gemini (Google) quota: " + ($gpct | round | tostring) + "%"
                               + (if $plan != "" then "\nPlan: " + $plan else "" end)) },
                   { pct: $epct, color: "#34a853", text: null,
                     tooltip: ("External models quota: " + ($epct | round | tostring) + "%"
                               + (if $plan != "" then "\nPlan: " + $plan else "" end)) } ]
      | .chartWindows = monthly_window("antigravity"; "ag"; false)
      | .historyValues = { ag: $pct }
      | .details = { email: ($res.email // ""),
                     planType: $plan,
                     promptCreditsMonthly: num($credits.monthly),
                     promptCreditsAvailable: num($credits.available),
                     pct: $pct,
                     googlePct: $gpct,
                     externalPct: $epct,
                     resetAt: $earliest,
                     models: (reduce $models[] as $m ({};
                       .[$m.modelId] = { displayName: $m.displayName,
                                         usedPct: $m.usedPct,
                                         resetTime: $m.resetTime,
                                         resetAt: $m.resetAt,
                                         isExhausted: $m.isExhausted,
                                         hasQuota: $m.hasQuota })),
                     groups: $groups }
    end;

# ── Kiro ────────────────────────────────────────────────────────────────────

def normalize_kiro($raw):
  ($raw.now) as $now
  | ($raw.inputs.usage // {}) as $res
  | if (($res | type) != "object") or ($res | length) == 0 then
      provider_error("kiro"; "Kiro"; "#8b5cf6"; $now;
        "Kiro: no local usage data found"; { available: false })
    elif ($res.error != null) then
      provider_error("kiro"; "Kiro"; "#8b5cf6"; $now; ("Kiro: " + $res.error); { available: false })
    else
      (num($res.percentageUsed) | pct_clamp) as $pct
      | num($res.currentUsage) as $used
      | num($res.usageLimit) as $limit
      | epoch_of($res.resetDate // "") as $resetAt
      | (($limit > 0) or ($used > 0)) as $available
      | (($used | tostring) + " / " + ($limit | tostring) + " credits") as $detail
      | ($res.planType // "") as $plan
      | provider_base("kiro"; "Kiro"; "#8b5cf6"; $now)
      | .ok = $available
      | .error = (if $available then "" else "Kiro: usage snapshot is empty" end)
      | .summary = { pct: $pct, text: (($pct | round | tostring) + "%"), detail: $plan, hasChart: true }
      | .quotaWindows = [ flat_window("kiro"; "Monthly credits"; $pct; $resetAt; $detail; true) ]
      | .slots = [ { pct: $pct, color: "#8b5cf6", text: null,
                     tooltip: ("Kiro" + (if $plan != "" then "\nPlan: " + ($plan | ascii_upcase) else "" end)
                               + "\nCredits: " + $detail) } ]
      | .chartWindows = (if $available then monthly_window("kiro"; "kr"; false) else [] end)
      | .historyValues = (if $available then { kr: $pct } else {} end)
      | .details = { available: $available,
                     planType: $plan,
                     displayName: ($res.displayName // "Credit"),
                     displayNamePlural: ($res.displayNamePlural // "Credits"),
                     currentUsage: $used,
                     usageLimit: $limit,
                     pct: $pct,
                     remaining: num($res.remaining),
                     currentOverages: num($res.currentOverages),
                     overageCap: num($res.overageCap),
                     overageCharges: num($res.overageCharges),
                     overageRate: num($res.overageRate),
                     currencyCode: ($res.currencyCode // "USD"),
                     currencySymbol: ($res.currencySymbol // "$"),
                     resetAt: $resetAt }
    end;

# ── Mistral ─────────────────────────────────────────────────────────────────

def normalize_mistral($raw):
  ($raw.now) as $now
  | ($raw.inputs.usage // {}) as $res
  | status_summary($raw.inputs.status) as $status
  | if (($res | type) != "object") or ($res | length) == 0 then
      provider_error("mistral"; "Mistral"; "#ff7000"; $now;
        "Mistral: no API key configured"; { hasKey: false, keyValid: false, status: $status })
    else
      num($res.vibeTotalCost) as $cost
      | (($res.keyValid) == true) as $valid
      | ([($cost / 50 * 100), 100] | min) as $pct
      | ($res.availableModels // []) as $models
      | { hasKey: ($res.hasKey == true),
          keyValid: $valid,
          availableModels: $models,
          vibe: { sessionCount: num($res.vibeSessionCount),
                  totalCost: $cost,
                  totalTokens: num($res.vibeTotalTokens),
                  promptTokens: num($res.vibePromptTokens),
                  completionTokens: num($res.vibeCompletionTokens),
                  totalSteps: num($res.vibeTotalSteps),
                  toolOk: num($res.vibeToolOk),
                  toolFail: num($res.vibeToolFail),
                  activeModel: ($res.vibeActiveModel // ""),
                  recent: ($res.vibeRecent // []) },
          status: $status } as $details
      | if ($res.error != null) then
          provider_error("mistral"; "Mistral"; "#ff7000"; $now; $res.error; $details)
        else
          provider_base("mistral"; "Mistral"; "#ff7000"; $now)
          | .ok = $valid
          | .summary = { pct: $pct,
                         text: money($cost; "USD"),
                         detail: (($models | length | tostring) + " models available"),
                         hasChart: true }
          | .quotaWindows = [ flat_window("mistral"; "vibe CLI spend"; $pct; 0;
                                (money($cost; "USD") + " total"); true)
                              + { resetText: "$50 soft cap" } ]
          | .slots = [ { pct: 0, color: "#ff7000",
                         text: (if $cost > 0 then money($cost; "USD")
                                elif $valid then "✓ key" else "—" end),
                         tooltip: ("Mistral AI"
                                   + (if $valid then "\nAPI key configured" else "\nNo key set" end)
                                   + (if $cost > 0 then "\nSpend (vibe): " + money($cost; "USD") else "" end)) } ]
          | .chartWindows = monthly_window("mistral"; "mv"; true)
          | .historyValues = (if $cost > 0 then { mv: $cost } else {} end)
          | .details = $details
        end
    end;

# ── OpenRouter ──────────────────────────────────────────────────────────────

def normalize_openrouter($raw):
  ($raw.now) as $now
  | ($raw.inputs.usage // {}) as $res
  | status_summary($raw.inputs.status) as $status
  | if (($res | type) != "object") or ($res | length) == 0 then
      provider_error("openrouter"; "OpenRouter"; "#9333ea"; $now;
        "OpenRouter: no API key configured"; { hasKey: false, keyValid: false, status: $status })
    elif ($res.error != null) then
      provider_error("openrouter"; "OpenRouter"; "#9333ea"; $now; $res.error;
        { hasKey: ($res.hasKey == true), keyValid: false, status: $status })
    else
      num($res.usageUSD) as $usage
      | (if (($res.limitUSD) | type) == "number" then $res.limitUSD else null end) as $limit
      | (if $limit != null and $limit > 0 then ([($usage / $limit * 100), 100] | min) else 0 end) as $pct
      | ($res.label // "") as $account
      | provider_base("openrouter"; "OpenRouter"; "#9333ea"; $now)
      | .summary = { pct: $pct, text: money($usage; "USD"), detail: $account, hasChart: true }
      | .quotaWindows = [ flat_window("openrouter"; "Credit usage"; $pct; 0;
                            (money($usage; "USD")
                             + (if $limit != null then " / " + money($limit; "USD") else " / unlimited" end));
                            true) ]
      | .slots = [ { pct: $pct, color: "#9333ea",
                     text: (if $usage > 0 then money($usage; "USD") else "✓ key" end),
                     tooltip: ("OpenRouter" + (if $account != "" then "\n" + $account else "" end)
                               + "\nUsed: " + money($usage; "USD")
                               + (if $limit != null then "\nLimit: " + money($limit; "USD") else "" end)) } ]
      | .chartWindows = monthly_window("openrouter"; "or"; false)
      | .historyValues = (if $pct > 0 then { or: $pct } else {} end)
      | .details = { hasKey: ($res.hasKey == true),
                     keyValid: ($res.keyValid == true),
                     label: $account,
                     usageUSD: $usage,
                     limitUSD: $limit,
                     limitRemainingUSD: (if (($res.limitRemainingUSD) | type) == "number"
                                         then $res.limitRemainingUSD else null end),
                     isFreeTier: ($res.isFreeTier == true),
                     rateLimit: ($res.rateLimit // {}),
                     status: $status }
    end;

# ── Grok ────────────────────────────────────────────────────────────────────

def normalize_grok($raw):
  ($raw.now) as $now
  | ($raw.inputs.usage // {}) as $res
  | if (($res | type) != "object") or ($res | length) == 0 then
      provider_error("grok"; "Grok"; "#e6e6e6"; $now;
        "Grok: run grok --oauth or configure an xAI key"; { hasKey: false, loggedIn: false })
    else
      (num($res.creditUsagePercent) | pct_clamp) as $pct
      | (if ($res.used != null) then num($res.used) else num($res.onDemandUsed) end) as $used
      | (if ($res.monthlyLimit != null) then num($res.monthlyLimit) else num($res.onDemandCap) end) as $limit
      | ($res.hasBilling == true) as $hasBilling
      | ($res.quotaKind // "") as $quotaKind
      | ($quotaKind != "free-tier") as $hasChart
      | num($res.sessionCount) as $sessions
      | (if $quotaKind == "free-tier"
         then { text: ($res.quotaWindow // "rolling 24h"), at: 0 }
         else { text: (epoch_of($res.billingPeriodEnd // "") | reset_text),
                at: epoch_of($res.billingPeriodEnd // "") } end) as $reset
      | ($res.teamName // $res.email // $res.tierId // "Grok CLI") as $detail
      | provider_base("grok"; "Grok"; "#e6e6e6"; $now)
      | .error = ($res.billingError // "")
      | .summary = { pct: $pct,
                     text: (if $hasBilling then (($pct | round | tostring) + "%") else "CLI" end),
                     detail: $detail,
                     hasChart: $hasChart }
      | .quotaWindows = ((if $hasBilling
                          then [ flat_window("grok"; "Credit usage"; $pct; $reset.at;
                                   (if $limit > 0 then (($used | tostring) + " / " + ($limit | tostring)) else "" end);
                                   true)
                                 + { resetText: $reset.text } ]
                          else [ flat_window("grok"; "Billing quota"; 0; 0;
                                   "Not exposed for this Grok account"; false) ] end)
                         + [ flat_window("grok_local"; "Local CLI activity"; 0; 0;
                               (($sessions | tostring)
                                + (if $sessions == 1 then " session · " else " sessions · " end)
                                + (num($res.totalTokens) | tostring) + " tokens · "
                                + (num($res.totalToolCalls) | tostring) + " tool calls");
                               false) ])
      | .slots = [ { pct: $pct, color: "#e6e6e6",
                     text: (if $hasBilling then null else "CLI" end),
                     tooltip: (if $hasBilling
                               then ("Grok credits: " + ($pct | round | tostring) + "% used")
                               else "Grok CLI connected; billing quota is not exposed" end) } ]
      | .chartWindows = (if $hasChart then monthly_window("grok"; "gr"; false) else [] end)
      | .historyValues = (if $hasChart then { gr: $pct } else {} end)
      | .details = { hasKey: (($res.xaiApiKey // "") != ""),
                     loggedIn: ($res.loggedIn == true),
                     pct: $pct,
                     used: $used,
                     monthlyLimit: $limit,
                     email: ($res.email // ""),
                     teamName: ($res.teamName // ""),
                     tierId: ($res.tierId // ""),
                     billingPeriodEnd: ($res.billingPeriodEnd // ""),
                     sessionCount: $sessions,
                     totalTokens: num($res.totalTokens),
                     totalToolCalls: num($res.totalToolCalls),
                     hasBilling: $hasBilling,
                     quotaKind: $quotaKind,
                     quotaWindow: ($res.quotaWindow // ""),
                     quotaExhausted: ($res.quotaExhausted == true),
                     billingError: ($res.billingError // "") }
    end;

# ── Z.AI ────────────────────────────────────────────────────────────────────

def normalize_zai($raw):
  ($raw.now) as $now
  | ($raw.inputs.usage // {}) as $res
  | if (($res | type) != "object") or ($res | length) == 0 then
      provider_error("zai"; "Z.AI"; "#126ef4"; $now;
        "Z.AI: no token configured"; { hasKey: false, keyValid: false })
    elif ($res.error != null) then
      provider_error("zai"; "Z.AI"; "#126ef4"; $now; ("Z.AI: " + $res.error);
        { hasKey: ($res.hasKey == true), keyValid: ($res.keyValid == true) })
    else
      (num($res.tokenPct) | pct_clamp) as $tokenPct
      | (num($res.toolsPct) | pct_clamp) as $toolsPct
      | (if (num($res.tokenResetMs)) > 0 then (($now + (num($res.tokenResetMs) / 1000)) | floor) else 0 end) as $tokenReset
      | (if (num($res.toolsResetMs)) > 0 then (($now + (num($res.toolsResetMs) / 1000)) | floor) else 0 end) as $toolsReset
      | (if ($res.tokenUsed != null and $res.tokenLimit != null)
         then ((num($res.tokenUsed) | tostring) + " / " + (num($res.tokenLimit) | tostring) + " tokens")
         else "" end) as $tokenDetail
      | (if ($res.toolsRemaining != null)
         then ((num($res.toolsRemaining) | tostring) + " remaining") else "" end) as $toolsDetail
      | provider_base("zai"; "Z.AI"; "#126ef4"; $now)
      | .summary = { pct: $tokenPct, text: (($tokenPct | round | tostring) + "%"),
                     detail: ($res.level // ""), hasChart: true }
      | .quotaWindows = [ flat_window("zai_tokens"; "5-hour tokens"; $tokenPct; $tokenReset; $tokenDetail; true),
                          flat_window("zai_tools"; "Monthly tools"; $toolsPct; $toolsReset; $toolsDetail; true) ]
      | .slots = [ { pct: $tokenPct, color: "#126ef4", text: null,
                     tooltip: ("Z.AI tokens: " + ($tokenPct | round | tostring) + "%") },
                   { pct: $toolsPct, color: "#60a5fa", text: null,
                     tooltip: ("Z.AI tools: " + ($toolsPct | round | tostring) + "%") } ]
      | .chartWindows = monthly_window("zai"; "za"; false)
      | .historyValues = { za: $tokenPct }
      | .details = { hasKey: ($res.hasKey == true),
                     keyValid: ($res.keyValid == true),
                     level: ($res.level // ""),
                     token: { pct: $tokenPct,
                              used: (if ($res.tokenUsed != null) then num($res.tokenUsed) else null end),
                              limit: (if ($res.tokenLimit != null) then num($res.tokenLimit) else null end),
                              resetAt: $tokenReset },
                     tools: { pct: $toolsPct,
                              remaining: (if ($res.toolsRemaining != null) then num($res.toolsRemaining) else null end),
                              resetAt: $toolsReset },
                     models: ($res.models // []) }
    end;

# ── GitHub Copilot ──────────────────────────────────────────────────────────

# Premium requests reset on the first of the following month, UTC.
def next_month_utc($now):
  ($now | strftime("%Y-%m")) as $ym
  | ($ym[0:4] | tonumber) as $y
  | ($ym[5:7] | tonumber) as $m
  | (if $m == 12 then { y: ($y + 1), m: 1 } else { y: $y, m: ($m + 1) } end)
  | epoch_of(((.y | tostring) + "-" + (if .m < 10 then "0" else "" end) + (.m | tostring) + "-01T00:00:00Z"));

def normalize_copilot($raw):
  ($raw.now) as $now
  | ($raw.inputs.usage // {}) as $res
  | if (($res | type) != "object") or ($res | length) == 0 then
      provider_error("copilot"; "Copilot"; "#8b5cf6"; $now;
        "Copilot: no token configured"; { hasKey: false, keyValid: false })
    elif ($res.error != null) then
      provider_error("copilot"; "Copilot"; "#8b5cf6"; $now; ("Copilot: " + $res.error);
        { hasKey: ($res.hasKey == true), keyValid: ($res.keyValid == true) })
    else
      (num($res.pct) | pct_clamp) as $pct
      | num($res.used) as $used
      | (if ($res.quota != null) then num($res.quota) else 300 end) as $quota
      | ($res.username // "") as $username
      | next_month_utc($now) as $resetAt
      | (($used | tostring) + " / " + ($quota | tostring) + " requests") as $detail
      | provider_base("copilot"; "Copilot"; "#8b5cf6"; $now)
      | .summary = { pct: $pct, text: (($pct | round | tostring) + "%"),
                     detail: (if $username != "" then "@" + $username else "Personal billing" end),
                     hasChart: true }
      | .quotaWindows = [ flat_window("copilot"; "Premium requests"; $pct; $resetAt; $detail; true) ]
      | .slots = [ { pct: $pct, color: "#8b5cf6", text: null,
                     tooltip: ("Copilot premium requests: " + $detail) } ]
      | .chartWindows = monthly_window("copilot"; "gh"; false)
      | .historyValues = { gh: $pct }
      | .details = { hasKey: ($res.hasKey == true),
                     keyValid: ($res.keyValid == true),
                     username: $username,
                     used: $used,
                     quota: $quota,
                     pct: $pct,
                     resetAt: $resetAt }
    end;

# ── DeepSeek ────────────────────────────────────────────────────────────────

def normalize_deepseek($raw):
  ($raw.now) as $now
  | ($raw.inputs.usage // {}) as $res
  | if (($res | type) != "object") or ($res | length) == 0 then
      provider_error("deepseek"; "DeepSeek"; "#4f8cff"; $now;
        "DeepSeek: no API key configured"; { hasKey: false, keyValid: false })
    elif ($res.error != null) then
      provider_error("deepseek"; "DeepSeek"; "#4f8cff"; $now; ("DeepSeek: " + $res.error);
        { hasKey: ($res.hasKey == true), keyValid: ($res.keyValid == true) })
    else
      num($res.primaryTotal) as $total
      | num($res.primaryGranted) as $granted
      | num($res.primaryToppedUp) as $topped
      | ($res.primaryCurrency // "") as $currency
      | (if $currency == "USD" then "$" elif $currency == "CNY" then "¥" else "" end) as $symbol
      | ($res.isAvailable == true) as $available
      | provider_base("deepseek"; "DeepSeek"; "#4f8cff"; $now)
      | .summary = { pct: 0, text: money($total; $currency),
                     detail: (if $available then "Available for API calls" else "Low balance" end),
                     hasChart: true }
      | .quotaWindows = [ flat_window("deepseek_total"; "Total balance"; 0; 0; money($total; $currency); false),
                          flat_window("deepseek_split"; "Granted / topped up"; 0; 0;
                            (money($granted; $currency) + " / " + money($topped; $currency)); false) ]
      | .slots = [ { pct: 0, color: "#4f8cff", text: money($total; $currency),
                     tooltip: ("DeepSeek balance: " + money($total; $currency)) } ]
      | .chartWindows = monthly_window("deepseek"; "ds"; true)
      | .historyValues = { ds: $total }
      | .details = { hasKey: ($res.hasKey == true),
                     keyValid: ($res.keyValid == true),
                     isAvailable: $available,
                     balances: ($res.balances // []),
                     primaryCurrency: $currency,
                     primaryTotal: $total,
                     primaryGranted: $granted,
                     primaryToppedUp: $topped,
                     currency: $currency,
                     symbol: $symbol }
    end;

# ── Dispatch ────────────────────────────────────────────────────────────────

def normalize($raw):
  ($raw.id) as $id
  | if   $id == "claude"      then normalize_claude($raw)
    elif $id == "openai"      then normalize_openai($raw)
    elif $id == "antigravity" then normalize_antigravity($raw)
    elif $id == "kiro"        then normalize_kiro($raw)
    elif $id == "mistral"     then normalize_mistral($raw)
    elif $id == "openrouter"  then normalize_openrouter($raw)
    elif $id == "grok"        then normalize_grok($raw)
    elif $id == "zai"         then normalize_zai($raw)
    elif $id == "copilot"     then normalize_copilot($raw)
    elif $id == "deepseek"    then normalize_deepseek($raw)
    else provider_error($id; $id; "#888888"; ($raw.now // 0); ("unknown provider: " + $id); {})
    end;
