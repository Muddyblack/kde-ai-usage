#!/usr/bin/env bash
# get_openrouter_usage.sh — Resolve OpenRouter API key and fetch usage/credits.
#   GET https://openrouter.ai/api/v1/key → usage, limit, rate_limit info

API_KEY="${WIDGET_OPENROUTER_API_KEY:-}"
[ -z "$API_KEY" ] && [ -n "$OPENROUTER_API_KEY" ]                        && API_KEY="$OPENROUTER_API_KEY"
[ -z "$API_KEY" ] && [ -f "$HOME/.config/openrouter/api-key" ]           && API_KEY=$(cat "$HOME/.config/openrouter/api-key" 2>/dev/null | tr -d '\n\r ')
[ -z "$API_KEY" ] && [ -f "$HOME/.openrouter/api-key" ]                  && API_KEY=$(cat "$HOME/.openrouter/api-key"          2>/dev/null | tr -d '\n\r ')
[ -z "$API_KEY" ] && [ -f "$HOME/.config/openrouter.key" ]               && API_KEY=$(cat "$HOME/.config/openrouter.key"        2>/dev/null | tr -d '\n\r ')

if [ -z "$API_KEY" ]; then
    echo "{}"; exit 0
fi

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    --max-time 8 \
    "https://openrouter.ai/api/v1/key" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

case "$HTTP_CODE" in
    200)
        # Single jq pass — extract all fields and build output JSON
        echo "$BODY" | jq --arg key "$API_KEY" '
            (.data // .) as $d |
            {
                openrouterApiKey:    $key,
                keyValid:            true,
                label:               ($d.label            // ""),
                usageUSD:            ($d.usage            // 0),
                limitUSD:            ($d.limit            // null),
                limitRemainingUSD:   ($d.limit_remaining  // null),
                isFreeTier:          ($d.is_free_tier     // false),
                rateLimit:           ($d.rate_limit       // {})
            }'
        ;;
    401)
        jq -n '{openrouterApiKey: "", keyValid: false, error: "Invalid API key (401)"}'
        ;;
    *)
        jq -n --arg code "$HTTP_CODE" '{openrouterApiKey: "", keyValid: false, error: ("HTTP " + $code)}'
        ;;
esac
