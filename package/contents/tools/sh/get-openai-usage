#!/usr/bin/env bash

# WIDGET_OPENAI_API_KEY (set by plasmoid config) takes priority over everything
API_KEY="${WIDGET_OPENAI_API_KEY:-}"

if [ -z "$API_KEY" ] && [ -n "$OPENAI_API_KEY" ]; then
    API_KEY="$OPENAI_API_KEY"
fi

if [ -z "$API_KEY" ] && [ -f "$HOME/.config/openai-api-key" ]; then
    API_KEY=$(cat "$HOME/.config/openai-api-key" 2>/dev/null | tr -d '\n\r ')
fi

if [ -z "$API_KEY" ] && [ -f "$HOME/.openai/api-key" ]; then
    API_KEY=$(cat "$HOME/.openai/api-key" 2>/dev/null | tr -d '\n\r ')
fi

# Read Codex OAuth credentials from ~/.codex/auth.json.
# Codex/ChatGPT auth is separate from OpenAI API organization usage, but it is
# useful account status to show alongside API billing data when available.
CODEX_AUTH=""
ACCESS_TOKEN=""
EMAIL=""
PLAN_TYPE=""
ORG_ID=""
ACCOUNT_ID=""
AUTH_MODE=""

if [ -f "$HOME/.codex/auth.json" ]; then
    CODEX_AUTH=$(cat "$HOME/.codex/auth.json" 2>/dev/null)
    if [ -n "$CODEX_AUTH" ]; then
        ACCESS_TOKEN=$(echo "$CODEX_AUTH" | jq -r '.tokens.access_token // .access_token // ""' 2>/dev/null)
        ACCOUNT_ID=$(echo  "$CODEX_AUTH" | jq -r '.tokens.account_id // .account_id // ""' 2>/dev/null)
        AUTH_MODE=$(echo   "$CODEX_AUTH" | jq -r '.auth_mode // ""' 2>/dev/null)

        if [ -z "$API_KEY" ]; then
            CODEX_API_KEY=$(echo "$CODEX_AUTH" | jq -r '.OPENAI_API_KEY // ""' 2>/dev/null)
            if [ -n "$CODEX_API_KEY" ]; then
                API_KEY="$CODEX_API_KEY"
            fi
        fi

        # Decode plan/email from JWT payload (no external deps needed, just base64)
        if [ -n "$ACCESS_TOKEN" ]; then
            PAYLOAD=$(echo "$ACCESS_TOKEN" | cut -d'.' -f2 | tr '_-' '/+' | awk '{while(length($0)%4!=0)$0=$0"="; print}' | base64 -d 2>/dev/null)
            EMAIL=$(echo     "$PAYLOAD" | jq -r '.["https://api.openai.com/profile"].email // ""' 2>/dev/null)
            PLAN_TYPE=$(echo "$PAYLOAD" | jq -r '.["https://api.openai.com/auth"].chatgpt_plan_type // ""' 2>/dev/null)
            ORG_ID=$(echo    "$PAYLOAD" | jq -r '.["https://api.openai.com/auth"].organizations[0].id // ""' 2>/dev/null)
        fi
    fi
fi

# Build output JSON
if [ -n "$API_KEY" ] || [ -n "$ACCESS_TOKEN" ]; then
    jq -n \
        --arg key       "$API_KEY" \
        --arg token     "$ACCESS_TOKEN" \
        --arg email     "$EMAIL" \
        --arg plan      "$PLAN_TYPE" \
        --arg orgId     "$ORG_ID" \
        --arg accountId "$ACCOUNT_ID" \
        --arg authMode  "$AUTH_MODE" \
        '{
            openaiApiKey: $key,
            codexAccessToken: $token,
            email: $email,
            planType: $plan,
            orgId: $orgId,
            accountId: $accountId,
            authMode: $authMode,
            codexLoggedIn: ($token != "")
        }'
else
    echo "{}"
fi
