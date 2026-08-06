import os

from ..http import as_json


def get_claude_credentials():
    oauth_creds = None
    path = os.path.expanduser("~/.claude/.credentials.json")
    if os.path.isfile(path):
        try:
            with open(path) as f:
                oauth_creds = as_json(f.read())
        except OSError:
            oauth_creds = None

    admin_key = os.environ.get("WIDGET_CLAUDE_ADMIN_KEY", "")
    if not admin_key:
        admin_key = os.environ.get("CLAUDE_ADMIN_API_KEY", "")
    if not admin_key:
        for candidate in (
            os.path.expanduser("~/.config/claude-admin-api-key"),
            os.path.expanduser("~/.claude/admin-api-key"),
        ):
            if os.path.isfile(candidate):
                try:
                    with open(candidate) as f:
                        admin_key = f.read().translate(str.maketrans("", "", "\n\r ")).strip()
                except OSError:
                    admin_key = ""
                if admin_key:
                    break

    if isinstance(oauth_creds, dict):
        if admin_key:
            return {**oauth_creds, "claudeAdminApiKey": admin_key}
        return oauth_creds
    if admin_key:
        return {"claudeAdminApiKey": admin_key}
    return {}
