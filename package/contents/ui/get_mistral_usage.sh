#!/usr/bin/env bash
# get_mistral_usage.sh — Resolve Mistral API key and verify it.
# Mistral has no public billing API, so we:
#   1. Resolve the key (widget config > env var > known config files)
#   2. Call GET /v1/models to verify validity and get the model list

API_KEY="${WIDGET_MISTRAL_API_KEY:-}"
[ -z "$API_KEY" ] && [ -n "$MISTRAL_API_KEY" ]                       && API_KEY="$MISTRAL_API_KEY"
[ -z "$API_KEY" ] && [ -f "$HOME/.config/mistral/api-key" ]          && API_KEY=$(cat "$HOME/.config/mistral/api-key"  2>/dev/null | tr -d '\n\r ')
[ -z "$API_KEY" ] && [ -f "$HOME/.mistral/api-key" ]                 && API_KEY=$(cat "$HOME/.mistral/api-key"         2>/dev/null | tr -d '\n\r ')
[ -z "$API_KEY" ] && [ -f "$HOME/.config/mistral.key" ]              && API_KEY=$(cat "$HOME/.config/mistral.key"      2>/dev/null | tr -d '\n\r ')

if [ -z "$API_KEY" ]; then
    echo "{}"; exit 0
fi

RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    --max-time 8 \
    "https://api.mistral.ai/v1/models" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

case "$HTTP_CODE" in
    200)
        # One jq pass: extract models and build output JSON together
        echo "$BODY" | jq --arg key "$API_KEY" \
            '{mistralApiKey: $key, keyValid: true, availableModels: [.data[]?.id // empty]}'
        ;;
    401)
        jq -n '{mistralApiKey: "", keyValid: false, error: "Invalid API key (401)"}'
        ;;
    429)
        jq -n --arg key "$API_KEY" '{mistralApiKey: $key, keyValid: true, error: "Rate limited (429)"}'
        ;;
    *)
        jq -n --arg code "$HTTP_CODE" '{mistralApiKey: "", keyValid: false, error: ("HTTP " + $code)}'
        ;;
esac
