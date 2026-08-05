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

# ── End-to-end: settings toggles, key plumbing and the outer envelope ───────

TEST_TMP="$(mktemp -d)"
trap 'case "$TEST_TMP" in /tmp/*) rm -rf -- "$TEST_TMP" ;; esac' EXIT

cat >"$TEST_TMP/config.json" <<'JSON'
{
  "providers": {
    "claude": false, "antigravity": false, "openai": false, "kiro": false,
    "mistral": false, "openrouter": false, "grok": false,
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

checks=$((checks + 1))
if run_backend --provider nonsense >/dev/null 2>&1; then
    printf 'FAIL: an unknown provider id should be rejected\n' >&2
    failures=$((failures + 1))
fi

cat >"$TEST_TMP/defaults.json" <<'JSON'
{"providers": {"claude": false, "antigravity": false, "openai": false, "kiro": false,
               "mistral": false, "openrouter": false, "grok": false}}
JSON
checks=$((checks + 1))
defaults="$(HOME="$TEST_TMP/home" AI_USAGE_CONFIG="$TEST_TMP/defaults.json" \
    AI_USAGE_CACHE_DIR="$TEST_TMP/cache" "$BACKEND" --all)"
if ! printf '%s' "$defaults" | jq -e '(.providers | length) == 0 and .active == ""' >/dev/null 2>&1; then
    printf 'FAIL: opt-in providers should stay off by default\n  got: %s\n' "$defaults" >&2
    failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
    printf '%d of %d checks failed\n' "$failures" "$checks" >&2
    exit 1
fi
printf 'get-ai-usage: %d checks passed\n' "$checks"
