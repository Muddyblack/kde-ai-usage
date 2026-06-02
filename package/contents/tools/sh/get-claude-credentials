#!/usr/bin/env bash

# Get Claude OAuth credentials
OAUTH_CREDS=""
if [ -f "$HOME/.claude/.credentials.json" ]; then
    OAUTH_CREDS=$(cat "$HOME/.claude/.credentials.json" 2>/dev/null)
fi

# Get Claude Admin API key — WIDGET_CLAUDE_ADMIN_KEY (set by plasmoid config) takes priority
ADMIN_KEY="${WIDGET_CLAUDE_ADMIN_KEY:-}"

# Fall back to environment variable
if [ -z "$ADMIN_KEY" ] && [ -n "$CLAUDE_ADMIN_API_KEY" ]; then
    ADMIN_KEY="$CLAUDE_ADMIN_API_KEY"
fi

# Check config file
if [ -z "$ADMIN_KEY" ] && [ -f "$HOME/.config/claude-admin-api-key" ]; then
    ADMIN_KEY=$(cat "$HOME/.config/claude-admin-api-key" 2>/dev/null | tr -d '\n\r ')
fi

# Check alternative config location
if [ -z "$ADMIN_KEY" ] && [ -f "$HOME/.claude/admin-api-key" ]; then
    ADMIN_KEY=$(cat "$HOME/.claude/admin-api-key" 2>/dev/null | tr -d '\n\r ')
fi

# Build JSON output
if [ -n "$OAUTH_CREDS" ]; then
    # Parse OAuth credentials and add admin key
    if [ -n "$ADMIN_KEY" ]; then
        echo "$OAUTH_CREDS" | jq --arg key "$ADMIN_KEY" '. + {claudeAdminApiKey: $key}'
    else
        echo "$OAUTH_CREDS"
    fi
else
    # No OAuth credentials, just return admin key if available
    if [ -n "$ADMIN_KEY" ]; then
        echo "{\"claudeAdminApiKey\": \"$ADMIN_KEY\"}"
    else
        echo "{}"
    fi
fi
