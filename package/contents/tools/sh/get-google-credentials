#!/usr/bin/env bash

# WIDGET_GOOGLE_API_KEY (set by plasmoid config) takes priority
API_KEY="${WIDGET_GOOGLE_API_KEY:-}"

if [ -z "$API_KEY" ] && [ -n "$GOOGLE_AI_API_KEY" ]; then
    API_KEY="$GOOGLE_AI_API_KEY"
fi

if [ -z "$API_KEY" ] && [ -n "$GEMINI_API_KEY" ]; then
    API_KEY="$GEMINI_API_KEY"
fi

if [ -z "$API_KEY" ] && [ -f "$HOME/.config/google-ai-api-key" ]; then
    API_KEY=$(cat "$HOME/.config/google-ai-api-key" 2>/dev/null | tr -d '\n\r ')
fi

if [ -z "$API_KEY" ] && [ -f "$HOME/.config/gemini-api-key" ]; then
    API_KEY=$(cat "$HOME/.config/gemini-api-key" 2>/dev/null | tr -d '\n\r ')
fi

if [ -z "$API_KEY" ]; then
    echo "{}"
else
    echo "{\"googleApiKey\": \"$API_KEY\"}"
fi
