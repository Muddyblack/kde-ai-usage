#!/usr/bin/env bash

# Get OpenAI API key from environment or config files
API_KEY=""

if [ -n "$OPENAI_API_KEY" ]; then
    API_KEY="$OPENAI_API_KEY"
fi

if [ -z "$API_KEY" ] && [ -f "$HOME/.config/openai-api-key" ]; then
    API_KEY=$(cat "$HOME/.config/openai-api-key" 2>/dev/null | tr -d '\n\r ')
fi

if [ -z "$API_KEY" ] && [ -f "$HOME/.openai/api-key" ]; then
    API_KEY=$(cat "$HOME/.openai/api-key" 2>/dev/null | tr -d '\n\r ')
fi

if [ -z "$API_KEY" ]; then
    echo "{}"
else
    echo "{\"openaiApiKey\": \"$API_KEY\"}"
fi
