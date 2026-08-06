"""Shared settings (provider toggles + API keys).

The Hyprland shell writes the settings file; the Plasma widget passes the same
values through WIDGET_* environment variables. Environment always wins.
"""

import json
import os

ALL_PROVIDERS = ["claude", "antigravity", "openai", "kiro", "mistral", "openrouter", "grok", "zai", "copilot", "deepseek", "kimi"]

# Providers that stay off until explicitly enabled (they need a token the user
# has to paste, so defaulting them on would only produce error rows).
OPT_IN_PROVIDERS = {"zai", "copilot", "deepseek", "kimi"}

_KEY_EXPORTS = [
    ("WIDGET_CLAUDE_ADMIN_KEY", "claudeAdmin"),
    ("WIDGET_OPENAI_API_KEY", "openai"),
    ("WIDGET_MISTRAL_API_KEY", "mistral"),
    ("WIDGET_OPENROUTER_API_KEY", "openrouter"),
    ("WIDGET_GROK_API_KEY", "grok"),
    ("WIDGET_ZAI_TOKEN", "zai"),
    ("WIDGET_GITHUB_TOKEN", "github"),
    ("WIDGET_DEEPSEEK_API_KEY", "deepseek"),
    ("WIDGET_MOONSHOT_API_KEY", "moonshot"),
]


def config_path():
    return os.environ.get(
        "AI_USAGE_CONFIG",
        os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "ai-usage-widget", "hyprland-settings.json"),
    )


def cache_dir():
    return os.environ.get(
        "AI_USAGE_CACHE_DIR",
        os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "ai-usage-widget"),
    )


def status_ttl():
    try:
        return int(os.environ.get("AI_USAGE_STATUS_TTL", "300"))
    except ValueError:
        return 300


def load_settings():
    path = config_path()
    if not os.path.isfile(path):
        return {}
    try:
        with open(path) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def cfg_key(cfg, key):
    return (cfg.get("keys") or {}).get(key) or ""


def apply_widget_env(cfg):
    """Export WIDGET_* variables from the settings file, but only when the
    caller (environment) has not already provided one."""
    for var, key in _KEY_EXPORTS:
        if os.environ.get(var):
            continue
        value = cfg_key(cfg, key)
        if value:
            os.environ[var] = value

    if not os.environ.get("WIDGET_COPILOT_QUOTA"):
        quota = cfg.get("copilotQuota", (cfg.get("keys") or {}).get("copilotQuota", 300))
        try:
            quota = int(quota)
        except (TypeError, ValueError):
            quota = 300
        os.environ["WIDGET_COPILOT_QUOTA"] = str(quota)


def provider_enabled(cfg, provider_id):
    providers = cfg.get("providers") or {}
    value = providers.get(provider_id)
    if provider_id in OPT_IN_PROVIDERS:
        return value is True
    return value is not False
