import os

from ..http import as_json, resolve_key


def get_claude_credentials():
    oauth_creds = None
    path = os.path.expanduser("~/.claude/.credentials.json")
    if os.path.isfile(path):
        try:
            with open(path) as f:
                oauth_creds = as_json(f.read())
        except OSError:
            oauth_creds = None

    admin_key = resolve_key(
        "WIDGET_CLAUDE_ADMIN_KEY",
        "CLAUDE_ADMIN_API_KEY",
        os.path.expanduser("~/.config/claude-admin-api-key"),
        os.path.expanduser("~/.claude/admin-api-key"),
    )

    if isinstance(oauth_creds, dict):
        if admin_key:
            return {**oauth_creds, "claudeAdminApiKey": admin_key}
        return oauth_creds
    if admin_key:
        return {"claudeAdminApiKey": admin_key}
    return {}
