#!/usr/bin/env bash
#
# Contract tests for the shared provider backend.
#
# Every case replays a recorded raw envelope through `get-ai-usage --normalize`,
# so the whole provider matrix — success, missing credentials, malformed
# responses, offline and rate-limited — is covered without touching the network.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/package/contents/tools/sh/get-ai-usage"
FIXTURES="$ROOT/tests/fixtures"

failures=0
checks=0

# check <fixture> <description> <jq boolean expression over the provider object>
check() {
    local fixture="$1" description="$2" filter="$3" result
    checks=$((checks + 1))
    if ! result="$("$BACKEND" --normalize <"$FIXTURES/$fixture.json" 2>&1)"; then
        printf 'FAIL %s: backend errored\n%s\n' "$fixture" "$result" >&2
        failures=$((failures + 1))
        return
    fi
    if ! printf '%s' "$result" | jq -e "$filter" >/dev/null 2>&1; then
        printf 'FAIL %s: %s\n  got: %s\n' "$fixture" "$description" "$result" >&2
        failures=$((failures + 1))
    fi
}

# ── Envelope invariants every provider must satisfy ─────────────────────────

for fixture in "$FIXTURES"/*.json; do
    name="$(basename "$fixture" .json)"
    check "$name" "carries the full contract shape" '
        (has("id") and has("label") and has("accent") and has("ok") and has("stale")
         and has("error") and has("updatedAt") and has("summary") and has("quotaWindows")
         and has("chartWindows") and has("slots") and has("historyValues") and has("details"))
        and (.summary | has("pct") and has("text") and has("detail") and has("hasChart"))
        and (.quotaWindows | type) == "array"
        and (.historyValues | type) == "object"
        and (.error | type) == "string"'
    # No credential may ever reach a frontend.
    check "$name" "never leaks a credential" '
        (tojson | test("secret|sk-ant-|sk-oauth|gh-secret|zai-secret|xai-secret|ds-secret|or-secret|codex-secret") | not)'
    check "$name" "reset timestamps are epoch seconds or 0" '
        [.quotaWindows[].resetAt] | all((type == "number") and (. == 0 or . > 1000000000))'
    check "$name" "chart windows are fully described" '
        .chartWindows | all(
            (.id | type) == "string" and (.key | type) == "string"
            and (.label | type) == "string" and (.size | type) == "number" and .size > 0
            and (.granularity | type) == "string"
            and (.raw | type) == "boolean" and (.resets | type) == "boolean"
            and (.periodMs | type) == "number" and (.resetAt | type) == "number"
            and (if .resets then .periodMs > 0 else .periodMs == 0 end))'
    check "$name" "charts only series the provider reports" '
        (.historyValues | keys) as $series
        | (.chartWindows | length) == 0 or ($series | length) == 0
          or ([.chartWindows[].key] | inside($series))'
done

# ── Claude ──────────────────────────────────────────────────────────────────

check claude-success "prefers semantic limits over legacy windows" '
    .ok and (.error == "")
    and .details.session.pct == 23 and .details.weekly.pct == 61
    and .details.session.tokensUsed == 120000 and .details.session.tokenLimit == 500000
    and .historyValues == {s: 23, w: 61}'
check claude-success "formats the session window for the panel" '
    (.quotaWindows[0] | .key == "session" and .available and .detail == "120000 / 500000 tokens")'
check claude-success "keeps a scoped week out of the account week" '
    .details.weekly.pct == 61
    and (.details.scopedWeekly | length) == 1
    and (.details.scopedWeekly[0] | .pct == 44 and .model == "" and .label == "7-day scoped")'
check claude-scoped-week "reads the account week and the per-model week apart" '
    .ok and .details.session.pct == 9 and .details.weekly.pct == 17
    and (.details.scopedWeekly | length) == 1
    and (.details.scopedWeekly[0] | .pct == 13 and .model == "Fable"
         and .key == "weekly_fable" and .label == "7-day Fable"
         and .resetAt == 1786949999)'
check claude-scoped-week "shows a scoped week that is not the binding limit" '
    (.quotaWindows | map(.key)) == ["session", "weekly", "weekly_fable"]
    and (.quotaWindows[2] | .available and .pct == 13 and .label == "7-day Fable")'
check claude-success "reports credential presence, not values" '
    .details.hasOAuth == true and .details.hasAdminKey == true
    and .details.subscriptionType == "max" and .details.organizationUuid == "org-1234"'
check claude-success "prices organization usage in one place" '
    .details.organizationUsage.totalInputTokens == 2005000
    and .details.organizationUsage.totalOutputTokens == 400500
    and (.details.organizationUsage.models["claude-sonnet-4"].priced == true)
    and (.details.organizationUsage.models["mystery-model"].priced == false)
    and ((.details.organizationUsage.totalCostUSD - 12) | fabs) < 0.001'
check claude-success "derives local activity statistics" '
    .details.stats.available
    and .details.stats.activeDays == 3
    and .details.stats.longestStreak == 3
    and .details.stats.totalToolCalls == 13
    and .details.stats.totalTokens == 165
    and .details.stats.favoriteModel == "claude-opus-4"
    and .details.stats.peakHour == 14
    and (.details.stats.dailyTokens | map(.date)) == ["2026-07-22", "2026-07-23"]
    and (.details.stats.dailyTokens[1].total) == 120'
check claude-success "offers 5H/24H/7D when both windows exist" '
    (.chartWindows | map(.id)) == ["session", "day", "weekly"]
    and (.chartWindows | map(.key)) == ["s", "s", "w"]
    and (.chartWindows[0].granularity) == "5h"
    and (.chartWindows[2].size) == 604800000'
check claude-success "anchors resets so a sleep gap can be redrawn" '
    (.chartWindows[0] | .periodMs == 18000000 and .resetAt == 1784473200)
    and (.chartWindows[1] | .size == 86400000 and .periodMs == 18000000)
    and (.chartWindows[2] | .periodMs == 604800000 and .resetAt == 1784991600)'
check claude-malformed "offers no chart ranges without windows" '
    (.chartWindows | length) == 0'
check claude-success "summarises the status page" '
    .details.status.indicator == "minor"
    and .details.status.components == ["API (degraded performance)"]
    and .details.status.incidents == ["Elevated errors"]
    and .details.status.latestUpdate == "We are looking into it."'
check claude-missing-credentials "reports a logged-out account" '
    (.ok | not) and .error == "Claude not logged in" and .stale
    and .historyValues == {} and (.details.hasOAuth | not)'
check claude-admin-key-only "keeps API stats usable without OAuth" '
    .ok and .error == "OAuth missing — API stats only" and .details.hasAdminKey'
check claude-offline "surfaces the offline state" '
    (.ok | not) and .error == "offline" and .stale'
check claude-rate-limited "surfaces the rate-limited state" '
    (.ok | not) and .error == "rate limited" and .stale'
check claude-malformed "treats an unknown body as no windows" '
    .ok and (.details.session.available | not) and (.details.weekly.available | not)
    and .historyValues == {}'

# ── OpenAI / Codex ──────────────────────────────────────────────────────────

check openai-codex-success "classifies app-server windows by duration" '
    .details.codex.available
    and .details.codex.session.pct == 58 and .details.codex.session.resetAt == 1785010000
    and .details.codex.weekly.pct == 30
    and .historyValues == {cp: 58, cw: 30}'
check openai-codex-success "keeps named per-model limits, minus the codex entry" '
    (.details.codex.additional | length) == 1
    and .details.codex.additional[0].name == "Spark"
    and .details.codex.additional[0].limitReached
    and .details.codex.additional[0].session.pct == 90
    and .details.codex.additional[0].weekly.pct == 9'
check openai-codex-success "prices organization completions" '
    .details.organizationUsage.totalInputTokens == 3001000
    and (.details.organizationUsage.models["gpt-4o"].priced == true)'
check openai-codex-success "carries Codex CLI statistics" '
    .details.stats.available and .details.stats.model == "gpt-5-codex"
    and .details.stats.effortLevel == "medium" and .details.stats.activeDays == 2
    and (.details.stats.dailyTokens | map(.date)) == ["2026-07-23", "2026-07-24"]'
check openai-codex-success "maps chart ranges onto the Codex series" '
    (.chartWindows | map(.id)) == ["codex_primary", "codex_day", "codex_weekly"]
    and (.chartWindows | map(.key)) == ["cp", "cp", "cw"]'
check openai-api-key-only "offers no chart ranges without plan windows" '
    (.chartWindows | length) == 0'
check openai-legacy-windows "classifies legacy windows even when reversed" '
    .details.codex.session.pct == 20 and .details.codex.weekly.pct == 70
    and (.details.codex.additional | length) == 1
    and .details.codex.additional[0].name == "GPT-5"
    and .details.codex.additional[0].session.pct == 100'
check openai-missing-credentials "reports a missing key and login" '
    (.ok | not) and .error == "OpenAI: no API key or Codex login"'
check openai-api-key-only "stays healthy with billing only" '
    .ok and .error == "" and (.details.codex.available | not)
    and .summary.hasChart == false
    and .details.organizationUsage.totalCostUSD > 0'
check openai-offline "marks a failed plan lookup stale, not fatal" '
    .ok and .stale and (.details.codex.available | not)'

# ── Antigravity ─────────────────────────────────────────────────────────────

check antigravity-success "averages quota per family" '
    .details.googlePct == 40 and .details.externalPct == 100
    and .details.pct == 60
    and (.details.groups | length) == 2
    and (.details.groups[0].key == "gemini")
    and (.details.groups[1].models == ["autocomplete-1", "claude-sonnet-4-5"])
    and .details.groups[1].isExhausted
    and .historyValues == {ag: 60}'
check antigravity-success "keeps models without a quota out of the average" '
    (.details.models["autocomplete-1"].hasQuota | not)
    and .details.models["gemini-3-pro"].usedPct == 60'
check antigravity-not-running "shortens the not-running message" '
    (.ok | not) and .error == "Antigravity is not running in IDE"'
check antigravity-missing "reports an unconfigured provider" '
    (.ok | not) and .error == "Antigravity not configured"'

# ── Kiro ────────────────────────────────────────────────────────────────────

check kiro-success "exposes credits, overage and reset" '
    .ok and .details.pct == 25 and .details.currentUsage == 250
    and .details.overageCharges == 0.8 and .details.resetAt == 1785542400
    and .historyValues == {kr: 25}'
check kiro-missing "reports no local snapshot" '
    (.ok | not) and .error == "Kiro: no local usage data found"'
check kiro-error "passes the tool error through" '
    (.ok | not) and (.error | startswith("Kiro: No Kiro state found"))'

# ── Mistral ─────────────────────────────────────────────────────────────────

check mistral-success "marks the spend series as a raw money value" '
    (.chartWindows | length) == 1 and .chartWindows[0].raw and (.chartWindows[0].resets | not)'
check deepseek-success "marks the balance series as a raw money value" '
    (.chartWindows | length) == 1 and .chartWindows[0].raw'
check kiro-success "charts one 30-day range" '
    (.chartWindows | map(.id)) == ["kiro"] and .chartWindows[0].label == "30D"
    and (.chartWindows[0].raw | not) and (.chartWindows[0].resets | not)'
check mistral-success "aggregates vibe CLI spend" '
    .ok and .details.vibe.totalCost == 12.5 and .details.vibe.sessionCount == 4
    and .details.keyValid and .details.hasKey
    and (.details.availableModels | length) == 2
    and .historyValues == {mv: 12.5}'
check mistral-invalid-key "keeps local stats on an invalid key" '
    (.ok | not) and .error == "Invalid API key (401)"
    and .details.vibe.totalCost == 12.5'
check mistral-missing "reports an unconfigured key" '
    (.ok | not) and .error == "Mistral: no API key configured"'

# ── OpenRouter ──────────────────────────────────────────────────────────────

check openrouter-success "derives the credit percentage" '
    .ok and .details.usageUSD == 3.25 and .details.limitUSD == 10
    and .historyValues == {or: 32.5}
    and .quotaWindows[0].detail == "$3.25 / $10"'
check openrouter-unlimited "treats a null limit as unlimited" '
    .ok and .details.limitUSD == null and .summary.pct == 0
    and .historyValues == {}
    and (.quotaWindows[0].detail | endswith("unlimited"))'
check openrouter-missing "reports an unconfigured key" '
    (.ok | not) and .error == "OpenRouter: no API key configured"'

# ── Grok ────────────────────────────────────────────────────────────────────

check grok-billing "reports billing quota and local activity" '
    .ok and .details.hasBilling and .details.pct == 42
    and .summary.hasChart and .historyValues == {gr: 42}
    and (.quotaWindows | length) == 2
    and .quotaWindows[0].detail == "21 / 50"
    and .quotaWindows[1].detail == "1 session · 900 tokens · 4 tool calls"'
check grok-free-tier "hides the chart when there is no billing quota" '
    .ok and (.details.hasBilling | not) and .summary.text == "CLI"
    and (.summary.hasChart | not) and .historyValues == {} and (.chartWindows | length) == 0
    and .quotaWindows[1].detail == "3 sessions · 12000 tokens · 9 tool calls"'
check grok-missing "asks for a login" '
    (.ok | not) and (.error | test("grok --oauth"))'

# ── Z.AI ────────────────────────────────────────────────────────────────────

check zai-success "turns relative resets into absolute timestamps" '
    .ok and .details.hasKey and .details.token.pct == 25 and .details.token.resetAt == 1785003600
    and .details.tools.resetAt == 1785007200 and .details.tools.remaining == 60
    and .historyValues == {za: 25}
    and .quotaWindows[0].detail == "250 / 1000 tokens"'
# Live responses put an absolute millisecond epoch in nextResetTime, not a
# duration. Adding that to `now` once produced reset dates decades out, which
# the year-less formatting hid. Both shapes have to survive.
check zai-absolute-reset "keeps an absolute reset epoch instead of adding it to now" '
    .ok and .details.token.resetAt == 1785007200
    and .details.tools.resetAt == 1786000000
    and ([.quotaWindows[] | select(.key == "zai_tokens_long")] | first | .resetAt) == 1785086400'
check zai-absolute-reset "resets stay within a plausible horizon of now" '
    [.quotaWindows[].resetAt] | all(. == 0 or (. > 1785000000 and . < 1785000000 + 60 * 86400))'
# The monitor endpoints report consumption, not a share of a quota, so the
# row carries a value instead of a meter and is ruled off from the windows.
check zai-today "reports the service day total beside the quota windows" '
    .ok and .details.today.available
    and .details.today.tokens == 41175632 and .details.today.calls == 370
    and .details.today.date == "2026-08-11"
    and (.details.today.models | map(.name)) == ["GLM-5.2", "GLM-5-Turbo", "GLM-4.7"]'
check zai-today "renders the day total as a value, not a meter" '
    (.quotaWindows | map(.key)) == ["zai_tokens", "zai_tokens_long", "zai_tools", "zai_today"]
    and (.quotaWindows[3] | .detail == "41.18M tokens" and .note == "370 calls"
         and (.showMeter | not) and .resetAt == 1786485600)'
# The reset column shows the date this rolls over TO, so the label has to name
# the day being summed — otherwise the row reads as being about tomorrow.
check zai-today "names the day it is summing" '
    (.quotaWindows[3].label) == "Today (Aug 11)"'
# A day total that has stopped growing would read as a stuck counter, so the
# date change is carried rather than left to the reader to work out.
check zai-success "stays silent about a day total that was not fetched" '
    (.details.today.available | not)
    and ([.quotaWindows[] | select(.key == "zai_today")] | length) == 0'
check zai-invalid-token "passes the token error through" '
    (.ok | not) and .error == "Z.AI: Invalid Z.AI token"'
check zai-missing "reports an unconfigured token" '
    (.ok | not) and .error == "Z.AI: no token configured"'

# ── Copilot ─────────────────────────────────────────────────────────────────

check copilot-success "reports premium requests against the quota" '
    .ok and .details.hasKey and .details.used == 125 and .details.quota == 500 and .details.pct == 25
    and .details.resetAt == 1785542400
    and .historyValues == {gh: 25}
    and .quotaWindows[0].detail == "125 / 500 requests"'
check copilot-error "passes the token error through" '
    (.ok | not) and (.error | startswith("Copilot: GitHub token cannot"))'
check copilot-missing "reports an unconfigured token" '
    (.ok | not) and .error == "Copilot: no token configured"'

# ── DeepSeek ────────────────────────────────────────────────────────────────

check deepseek-success "reports the balance split" '
    .ok and .details.primaryTotal == 12.5 and .details.symbol == "$"
    and .summary.text == "$12.5" and .historyValues == {ds: 12.5}
    and .quotaWindows[1].detail == "$2.5 / $10"'
check deepseek-error "passes the key error through" '
    (.ok | not) and .error == "DeepSeek: Invalid DeepSeek API key"'
check deepseek-missing "reports an unconfigured key" '
    (.ok | not) and .error == "DeepSeek: no API key configured"'

# ── Kimi / Moonshot ─────────────────────────────────────────────────────────

check kimi-success "reports the Moonshot balance split" '
    .ok and .details.keyValid
    and ((.details.availableBalance - 49.58894) | fabs) < 0.00001
    and ((.details.voucherBalance - 46.58893) | fabs) < 0.00001
    and ((.details.cashBalance - 3.00001) | fabs) < 0.00001
    and .historyValues == {km: 49.58894}'
check kimi-missing "reports a missing Moonshot API key" '
    (.ok | not) and .error == "Kimi: no Moonshot API key configured"'

# ── Muse ────────────────────────────────────────────────────────────────────

check muse-success "reports local session statistics" '
    .ok and .details.hasOAuth and (.details.hasApiKey | not)
    and .details.stats.totalSessions == 3 and .details.stats.totalOutputTokens == 30000
    and .details.stats.model == "muse-spark-1.3-contributor"
    and .summary.text == "30k out" and .historyValues == {mu: 30000}
    and (.quotaWindows | length) == 3'
check muse-error "passes the missing-sessions error through" '
    (.ok | not) and .error == "Muse: No Muse sessions found — run muse once"'
check muse-missing "reports empty input as no data" '
    (.ok | not) and .error == "Muse: no data"'
check muse-quota-only "renders quota bars with no local sessions" '
    .ok and (.quotaWindows | length) == 2
    and .summary.text == "26%" and .historyValues == {mu: 0, mc: 26, mw: 9}'
check muse-quota-success "renders live quota windows with rolling charts" '
    .ok and .details.keyValid
    and .details.email == "user@example.com" and .details.fullName == "Test User"
    and (.quotaWindows | length) == 2
    and (.quotaWindows[0] | .key == "muse_current" and .pct == 26 and .resetAt == 1788528365)
    and (.quotaWindows[1] | .key == "muse_weekly" and .pct == 9 and .resetAt == 1788739200)
    and .quotaWindows[0].detail == "26% used · resets Sep 4, 15:26"
    and .summary.pct == 26 and .summary.text == "30k out"
    and .historyValues == {mu: 30000, mc: 26, mw: 9}
    and ([.chartWindows[].key] | sort) == ["mc", "mc", "mw"]'
check muse-malformed "degrades to no data when usage is not an object" '
    (.ok | not) and .error == "Muse: no data"
    and (.details.keyValid | not) and .details.quotaError == ""'

# ── End-to-end: settings toggles, key plumbing and the outer envelope ───────

TEST_TMP="$(mktemp -d)"
trap 'case "$TEST_TMP" in /tmp/*) rm -rf -- "$TEST_TMP" ;; esac' EXIT

cat >"$TEST_TMP/config.json" <<'JSON'
{
  "providers": {
    "claude": false, "antigravity": false, "openai": false, "kiro": false,
    "mistral": false, "openrouter": false, "grok": false, "muse": false,
    "zai": true, "copilot": true, "deepseek": true
  },
  "keys": { "zai": "zai-test", "github": "github-test", "deepseek": "deepseek-test" },
  "copilotQuota": 500
}
JSON

cat >"$TEST_TMP/zai.json" <<'JSON'
{"success":true,"data":{"level":"pro","limits":[
  {"type":"TOKENS_LIMIT","percentage":25,"nextResetTime":3600000,"used":250,"limit":1000},
  {"type":"TIME_LIMIT","percentage":40,"nextResetTime":7200000,"remaining":60,"usageDetails":[]}]}}
JSON
printf '{"login":"octocat"}\n' >"$TEST_TMP/github-user.json"
printf '[{"grossQuantity":125}]\n' >"$TEST_TMP/github-usage.json"
cat >"$TEST_TMP/deepseek.json" <<'JSON'
{"is_available":true,"balance_infos":[
  {"currency":"USD","total_balance":"12.50","granted_balance":"2.50","topped_up_balance":"10.00"}]}
JSON

run_backend() {
    HOME="$TEST_TMP/home" \
        AI_USAGE_CONFIG="$TEST_TMP/config.json" \
        AI_USAGE_CACHE_DIR="$TEST_TMP/cache" \
        ZAI_RESPONSE_FILE="$TEST_TMP/zai.json" \
        COPILOT_USER_RESPONSE_FILE="$TEST_TMP/github-user.json" \
        COPILOT_USAGE_RESPONSE_FILE="$TEST_TMP/github-usage.json" \
        DEEPSEEK_BALANCE_RESPONSE_FILE="$TEST_TMP/deepseek.json" \
        MUSE_SESSIONS_DIR="$TEST_TMP/muse-sessions" \
        MUSE_AUTH_PATH="$TEST_TMP/muse-auth.json" \
        MUSE_QUOTA_RESPONSE_FILE="${MUSE_QUOTA_RESPONSE_FILE:-$TEST_TMP/muse-quota.json}" \
        "$BACKEND" "$@"
}

assert_backend() {
    local description="$1" filter="$2" output
    shift 2
    checks=$((checks + 1))
    output="$(run_backend "$@")"
    if ! printf '%s' "$output" | jq -e "$filter" >/dev/null 2>&1; then
        printf 'FAIL %s\n  got: %s\n' "$description" "$output" >&2
        failures=$((failures + 1))
    fi
}

# check_prog <label> <expected stdout> <python program, aiusage importable>
check_prog() {
    local label="$1" expected="$2" prog="$3" got
    checks=$((checks + 1))
    if ! got="$(python3 -c "import sys; sys.path.insert(0, '$ROOT/package/contents/tools')
$prog" 2>&1)"; then
        got="raised: $got"
    fi
    if [ "$got" = "$expected" ]; then
        return 0
    fi
    failures=$((failures + 1))
    printf 'FAIL %s\n  expected: %s\n  got: %s\n' "$label" "$expected" "$got"
}

assert_backend "--all honours the provider toggles and API keys" '
    .schemaVersion == 1
    and (.providers | length) == 3
    and (.providers | map(.id) | sort) == ["copilot", "deepseek", "zai"]
    and .active == "zai"
    and (.providers[] | select(.id == "zai") | .historyValues.za) == 25
    and (.providers[] | select(.id == "copilot") | .historyValues.gh) == 25
    and (.providers[] | select(.id == "copilot") | .quotaWindows[0].detail) == "125 / 500 requests"
    and (.providers[] | select(.id == "deepseek") | .details.currency) == "USD"
    and (tojson | test("zai-test|github-test|deepseek-test") | not)' --all

assert_backend "--provider fetches exactly what was asked for" '
    (.providers | map(.id)) == ["deepseek", "zai"]' --provider deepseek,zai

assert_backend "--provider ignores the enabled toggles" '
    (.providers | length) == 1 and .providers[0].id == "kiro"' --provider kiro

mkdir -p "$TEST_TMP/muse-sessions/2026/09/04/aaa" "$TEST_TMP/muse-sessions/2026/09/04/aaa/subagent/bbb"
cat >"$TEST_TMP/muse-auth.json" <<'JSON'
{"providers": {"meta": {"mechanism": "oauth", "access_token": "muse-secret-token", "user_email": "test@example.com", "user_full_name": "Test User"}}}
JSON
cp "$FIXTURES/muse-quota.json" "$TEST_TMP/muse-quota.json"
cat >"$TEST_TMP/muse-sessions/2026/09/04/aaa/session.jsonl" <<'JSON'
{"schema_version":1,"id":"1","stream":{"kind":"session","id":"aaa"},"sequence":1,"recorded_at":1785000000000000,"record_type":"event","durability":"durable","causation_id":null,"payload_type":"runtime.session.metadata","payload_schema_version":1,"payload":{"kind":"metadata","record":{"workspace_root":"/tmp/secret-project"}}}
{"schema_version":1,"id":"2","stream":{"kind":"session","id":"aaa"},"sequence":2,"recorded_at":1785000001000000,"record_type":"event","durability":"durable","causation_id":null,"payload_type":"run.model.configured","payload_schema_version":1,"payload":{"kind":"run_model","record":{"model_id":"test-model","provider_id":"meta"}}}
{"schema_version":1,"id":"3","stream":{"kind":"session","id":"aaa"},"sequence":3,"recorded_at":1785000002000000,"record_type":"event","durability":"durable","causation_id":null,"payload_type":"runtime.session","payload_schema_version":1,"payload":{"kind":"run","run_id":"r1","event":{"kind":"user_prompt_display"}}}
{"schema_version":1,"id":"4","stream":{"kind":"session","id":"aaa"},"sequence":4,"recorded_at":1785000003000000,"record_type":"event","durability":"durable","causation_id":null,"payload_type":"runtime.session","payload_schema_version":1,"payload":{"kind":"run","run_id":"r1","event":{"kind":"model_completed","model":"test-model","usage":{"input_tokens":1000,"output_tokens":200,"cached_tokens":50,"reasoning_tokens":10}}}}
{"schema_version":1,"id":"5","stream":{"kind":"session","id":"aaa"},"sequence":5,"recorded_at":1785000004000000,"record_type":"event","durability":"durable","causation_id":null,"payload_type":"runtime.session","payload_schema_version":1,"payload":{"kind":"run","run_id":"r1","event":{"kind":"assistant_tool_calls_committed","tool_calls":[{"name":"bash"},{"name":"read"}]}}}
{"schema_version":1,"id":"6","stream":{"kind":"session","id":"aaa"},"sequence":6,"recorded_at":1785000005000000,"record_type":"event","durability":"durable","causation_id":null,"payload_type":"runtime.session","payload_schema_version":1,"payload":{"kind":"run","run_id":"r1","event":{"kind":"assistant_message_committed"}}}
{"schema_version":1,"id":"7","stream":{"kind":"session","id":"aaa"},"sequence":7,"recorded_at":1785000006000000,"record_type":"event","durability":"durable","causation_id":null,"payload_type":"runtime.session","payload_schema_version":1,"payload":{"kind":"run","run_id":"r1","event":{"kind":"terminal"}}}
JSON
printf '{"schema_version":1,"id":"8","stream":{"kind":"session","id":"bbb"},"sequence":1,"recorded_at":1785000007000000,"record_type":"event","durability":"durable","causation_id":null,"payload_type":"runtime.session","payload_schema_version":1,"payload":{"kind":"run","run_id":"r2","event":{"kind":"model_completed","model":"test-model","usage":{"input_tokens":500,"output_tokens":100,"cached_tokens":0,"reasoning_tokens":5}}}}\n' >"$TEST_TMP/muse-sessions/2026/09/04/aaa/subagent/bbb/session.jsonl"

WIDGET_MUSE_QUOTA=1 assert_backend "reads local Muse sessions with OAuth presence and no secret leaks" '
    (.providers | length) == 1 and .providers[0].id == "muse"
    and .providers[0].ok
    and .providers[0].details.hasOAuth
    and (.providers[0].details.hasApiKey | not)
    and .providers[0].details.stats.totalSessions == 1
    and .providers[0].details.stats.subagentSessions == 1
    and .providers[0].details.stats.totalOutputTokens == 300
    and .providers[0].details.stats.totalToolCalls == 2
    and .providers[0].details.stats.totalMessages == 2
    and .providers[0].details.stats.model == "test-model"
    and .providers[0].details.stats.workspaceCount == 1
    and .providers[0].details.email == "test@example.com"
    and .providers[0].details.fullName == "Test User"
    and .providers[0].historyValues.mu == 300
    and (.providers[0].quotaWindows | length) == 2
    and .providers[0].quotaWindows[0].pct == 26
    and .providers[0].details.keyValid
    and .providers[0].historyValues.mc == 26
    and (tojson | test("muse-secret-token|secret-project") | not)' --provider muse

assert_backend "live quota is off until asked for, so a default install spends nothing" '
    (.providers | length) == 1 and .providers[0].id == "muse"
    and .providers[0].ok
    and .providers[0].details.quotaError == "disabled"
    and (.providers[0].details.keyValid | not)
    and (.providers[0].historyValues | has("mc") | not)' --provider muse

check_prog "an unset switch reads as off" "False" '
import os
os.environ.pop("WIDGET_MUSE_QUOTA", None)
from aiusage.config import muse_quota_enabled
print(muse_quota_enabled())'
check_prog "an explicit opt-in turns it on" "True" '
import os
os.environ["WIDGET_MUSE_QUOTA"] = "1"
from aiusage.config import muse_quota_enabled
print(muse_quota_enabled())'

WIDGET_MUSE_QUOTA=0 assert_backend "a disabled quota switch renders free stats only" '
    (.providers | length) == 1 and .providers[0].id == "muse"
    and .providers[0].ok
    and (.providers[0].details.keyValid | not)
    and .providers[0].details.quotaError == "disabled"
    and (.providers[0].quotaWindows | length) == 3
    and (.providers[0].historyValues | has("mc") | not)' --provider muse

# SSE frames arrive CRLF-terminated often enough that splitting on "\n\n"
# alone would silently yield no quota at all. Replay a real-shaped CRLF stream.
printf 'event: response.created\r\ndata: {"type":"response.created"}\r\n\r\nevent: response.subscription_usage\r\ndata: {"type":"response.subscription_usage","subscription":{"tier":"1","window":{"used_percent":26,"resets_at":1788528365,"window_duration_mins":300},"weekly":{"used_percent":9,"resets_at":1788739200}}}\r\n\r\n' >"$TEST_TMP/muse-quota-crlf.sse"

MUSE_QUOTA_RESPONSE_FILE="$TEST_TMP/muse-quota-crlf.sse" WIDGET_MUSE_QUOTA=1 \
    assert_backend "parses a CRLF-terminated SSE quota stream" '
    (.providers | length) == 1 and .providers[0].id == "muse"
    and .providers[0].details.keyValid
    and .providers[0].details.quotaError == ""
    and (.providers[0].quotaWindows | length) == 2
    and .providers[0].quotaWindows[0].pct == 26
    and .providers[0].quotaWindows[1].pct == 9' --provider muse

muse_py() {
    MUSE_MODELS_RESPONSE_FILE="${MUSE_MODELS_RESPONSE_FILE:-}" \
        python3 -c "import sys; sys.path.insert(0, '$ROOT/package/contents/tools'); $1"
}

check_py() {
    name="$1"
    label="$2"
    expected="$3"
    got="$(muse_py "from aiusage.providers.muse import $4; print($4$5)")"
    checks=$((checks + 1))
    if [ "$got" = "$expected" ]; then
        return 0
    fi
    failures=$((failures + 1))
    printf 'FAIL %s %s\n  expected: %s\n  got: %s\n' "$name" "$label" "$expected" "$got"
}

cat >"$TEST_TMP/muse-models.json" <<'JSON'
{"data": [{"id": "muse-voice-transcribe-1.0"}, {"id": "fixture-spark-2"}]}
JSON

check_py muse "prefers the model from local logs" \
    "muse-spark-9.9" "_quota_model" "('muse-spark-9.9', '')"
check_py muse "falls back to the last-known default offline" \
    "muse-spark-1.3" "_quota_model" "('test-model', '')"
MUSE_MODELS_RESPONSE_FILE="$TEST_TMP/muse-models.json" check_py muse "picks chat models from the account list" \
    "fixture-spark-2" "_quota_model" "('test-model', '')"


# A timeout must not be reported as a rejected credential.
check_prog "an HTTP 401 is a rejected credential" "rejected" '
from urllib.error import HTTPError
from aiusage.providers.muse import _quota_error_code
print(_quota_error_code(HTTPError("u", 401, "x", {}, None)))'
check_prog "an HTTP 403 is a rejected credential" "rejected" '
from urllib.error import HTTPError
from aiusage.providers.muse import _quota_error_code
print(_quota_error_code(HTTPError("u", 403, "x", {}, None)))'
check_prog "a timeout is unreachable, not invalid" "unreachable" '
from aiusage.providers.muse import _quota_error_code
print(_quota_error_code(TimeoutError()))'
check_prog "a DNS failure is unreachable" "unreachable" '
from urllib.error import URLError
from aiusage.providers.muse import _quota_error_code
print(_quota_error_code(URLError("name resolution failed")))'
check_prog "a 500 is unreachable, not a bad key" "unreachable" '
from urllib.error import HTTPError
from aiusage.providers.muse import _quota_error_code
print(_quota_error_code(HTTPError("u", 500, "x", {}, None)))'
check_prog "no credential is reported as such" "{} no-credential" '
import os
os.environ["WIDGET_MUSE_QUOTA"] = "1"
os.environ.pop("MUSE_QUOTA_RESPONSE_FILE", None)
os.environ["MUSE_AUTH_PATH"] = "/nonexistent/auth.json"
os.environ["META_API_KEY"] = ""
from aiusage.providers.muse import get_muse_quota
q, e = get_muse_quota("")
print(q, e)'

# CRLF frames must parse exactly like LF ones (see _parse_subscription_event).
check_prog "CRLF and LF frames parse identically" "True" '
from aiusage.providers.muse import _parse_subscription_event
body = ("event: response.subscription_usage\r\n"
        "data: {\"type\": \"response.subscription_usage\", \"subscription\": {\"window\": {\"used_percent\": 7}}}\r\n\r\n")
print(_parse_subscription_event(body) == _parse_subscription_event(body.replace("\r\n", "\n")))'

# The shared formatter must not have drifted either vendor'"'"'s printed strings.
check_prog "the shared formatter keeps both vendors byte-identical" "41.18M 1.00K 500 30k 1.5k 2M 500" '
from aiusage.normalize.zai import _compact as z
from aiusage.normalize.muse import _compact as m
print(z(41180000), z(1000), z(500), m(30000), m(1500), m(2000000), m(500))'

checks=$((checks + 1))
if run_backend --provider nonsense >/dev/null 2>&1; then
    printf 'FAIL: an unknown provider id should be rejected\n' >&2
    failures=$((failures + 1))
fi

cat >"$TEST_TMP/defaults.json" <<'JSON'
{"providers": {"claude": false, "antigravity": false, "openai": false, "kiro": false,
               "mistral": false, "openrouter": false, "grok": false, "muse": false}}
JSON
checks=$((checks + 1))
defaults="$(HOME="$TEST_TMP/home" AI_USAGE_CONFIG="$TEST_TMP/defaults.json" \
    AI_USAGE_CACHE_DIR="$TEST_TMP/cache" "$BACKEND" --all)"
if ! printf '%s' "$defaults" | jq -e '(.providers | length) == 0 and .active == ""' >/dev/null 2>&1; then
    printf 'FAIL: opt-in providers should stay off by default\n  got: %s\n' "$defaults" >&2
    failures=$((failures + 1))
fi

# ── Credentials from the environment are stripped ───────────────────────────
# A token pasted into the widget's settings field with a trailing newline is
# passed straight through as WIDGET_*. urllib rejects such a header value with
# a ValueError whose message contains the credential, so an unstripped value
# both breaks the provider and prints the secret in the traceback. Tested here
# rather than through a provider call: a fixture returns before the header is
# built, so only resolve_key itself can show the difference.
# shellcheck source=../package/contents/tools/sh/python-interp.sh
. "$ROOT/package/contents/tools/sh/python-interp.sh"
if py_resolve; then
    checks=$((checks + 1))
    # $'…' keeps the newline: command substitution would strip it and the case
    # under test would silently disappear.
    stripped="$(WIDGET_TEST_KEY=$'secret-value\n' \
        PYTHONPATH="$ROOT/package/contents/tools" "$PY" -c '
from aiusage.http import resolve_key
print(repr(resolve_key("WIDGET_TEST_KEY", "", )))
')"
    if [ "$stripped" != "'secret-value'" ]; then
        printf 'FAIL: a trailing newline must not survive into a credential\n  got: %s\n' "$stripped" >&2
        failures=$((failures + 1))
    fi
fi

if [ "$failures" -ne 0 ]; then
    printf '%d of %d checks failed\n' "$failures" "$checks" >&2
    exit 1
fi
printf 'get-ai-usage: %d checks passed\n' "$checks"
