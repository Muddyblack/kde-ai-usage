#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/codex" <<'EOF'
#!/usr/bin/env bash
IFS= read -r initialize
if IFS= read -r -t 0.05 premature; then
    printf '%s\n' '{"id":1,"result":{"userAgent":"test"}}'
    exit 0
fi
printf '%s\n' '{"id":1,"result":{"userAgent":"test"}}'
IFS= read -r read_limits
printf '%s\n' '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":42,"windowDurationMins":10080,"resetsAt":200}}}}'
EOF
chmod +x "$tmp/codex"

actual="$(PATH="$tmp:$PATH" "$repo/package/contents/tools/sh/get-codex-rate-limits")"
jq -e '.rateLimits.primary.windowDurationMins == 10080 and .rateLimits.primary.usedPercent == 42' <<<"$actual" >/dev/null

cat >"$tmp/codex" <<'EOF'
#!/usr/bin/env bash
IFS= read -r initialize
printf '%s\n' '{"id":1,"result":{}}'
IFS= read -r read_limits
EOF
chmod +x "$tmp/codex"

test "$(PATH="$tmp:$PATH" "$repo/package/contents/tools/sh/get-codex-rate-limits")" = '{}'
