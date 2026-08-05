#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SNAPSHOT="$ROOT/package/contents/tools/sh/get-usage-snapshot"
TEST_TMP="$(mktemp -d)"
trap 'case "$TEST_TMP" in /tmp/*) rm -rf -- "$TEST_TMP" ;; esac' EXIT

cat >"$TEST_TMP/config.json" <<'JSON'
{
  "providers": {
    "claude": false,
    "antigravity": false,
    "openai": false,
    "kiro": false,
    "mistral": false,
    "openrouter": false,
    "grok": false,
    "zai": true,
    "copilot": true,
    "deepseek": true
  },
  "keys": {
    "zai": "zai-test",
    "github": "github-test",
    "deepseek": "deepseek-test"
  },
  "copilotQuota": 500
}
JSON

cat >"$TEST_TMP/zai.json" <<'JSON'
{
  "success": true,
  "data": {
    "level": "pro",
    "limits": [
      {"type":"TOKENS_LIMIT","percentage":25,"nextResetTime":3600000,"used":250,"limit":1000},
      {"type":"TIME_LIMIT","percentage":40,"nextResetTime":7200000,"remaining":60,"usageDetails":[]}
    ]
  }
}
JSON

cat >"$TEST_TMP/github-user.json" <<'JSON'
{"login":"octocat"}
JSON

cat >"$TEST_TMP/github-usage.json" <<'JSON'
[{"grossQuantity":125}]
JSON

cat >"$TEST_TMP/deepseek.json" <<'JSON'
{
  "is_available": true,
  "balance_infos": [
    {"currency":"USD","total_balance":"12.50","granted_balance":"2.50","topped_up_balance":"10.00"}
  ]
}
JSON

result="$(
  HOME="$TEST_TMP/home" \
  AI_USAGE_CONFIG="$TEST_TMP/config.json" \
  ZAI_RESPONSE_FILE="$TEST_TMP/zai.json" \
  COPILOT_USER_RESPONSE_FILE="$TEST_TMP/github-user.json" \
  COPILOT_USAGE_RESPONSE_FILE="$TEST_TMP/github-usage.json" \
  DEEPSEEK_BALANCE_RESPONSE_FILE="$TEST_TMP/deepseek.json" \
  "$SNAPSHOT"
)"

jq -e '
  (.providers | length) == 3 and
  (.providers | map(.id) | sort) == ["copilot", "deepseek", "zai"] and
  (.providers[] | select(.id == "zai") | .hist.za) == 25 and
  (.providers[] | select(.id == "copilot") | .hist.gh) == 25 and
  (.providers[] | select(.id == "copilot") | .rows[0].detail) == "125 / 500 requests" and
  (.providers[] | select(.id == "deepseek") | .hist.ds) == 12.5 and
  (.providers[] | select(.id == "deepseek") | .currency) == "USD"
' <<<"$result" >/dev/null

cat >"$TEST_TMP/defaults.json" <<'JSON'
{
  "providers": {
    "claude": false,
    "antigravity": false,
    "openai": false,
    "kiro": false,
    "mistral": false,
    "openrouter": false,
    "grok": false
  }
}
JSON

defaults="$(HOME="$TEST_TMP/home" AI_USAGE_CONFIG="$TEST_TMP/defaults.json" "$SNAPSHOT")"
jq -e '(.providers | length) == 0' <<<"$defaults" >/dev/null

printf '%s\n' "get-usage-snapshot tests passed"
