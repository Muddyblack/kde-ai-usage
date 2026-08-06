"""Raw input collection — one envelope-builder per provider.

Every provider's raw inputs are gathered here and handed to
aiusage.normalize.normalize(). This is the IO half: credentials, provider API
requests and on-disk stats/caches all live in this module and providers/.
"""

import datetime
import os
import time

from . import config
from .http import as_json, fetch_json, http_error_text
from .providers.antigravity import get_antigravity_usage
from .providers.claude_credentials import get_claude_credentials
from .providers.codex_rate_limits import get_codex_rate_limits
from .providers.codex_stats import get_codex_stats
from .providers.copilot import get_copilot_usage
from .providers.deepseek import get_deepseek_balance
from .providers.grok import get_grok_usage
from .providers.kiro import get_kiro_usage
from .providers.mistral import get_mistral_usage
from .providers.moonshot import get_moonshot_balance
from .providers.openai_credentials import get_openai_credentials
from .providers.openrouter import get_openrouter_usage
from .providers.zai import get_zai_usage


def read_json_file(path):
    if not os.path.isfile(path):
        return None
    try:
        with open(path) as f:
            return as_json(f.read())
    except OSError:
        return None


def status_json(name, url):
    """Fetch a Statuspage summary, memoised on disk so a fast poll interval
    does not hammer the status hosts. Never fatal."""
    cache_path = os.path.join(config.cache_dir(), f"status-{name}.json")
    if os.path.isfile(cache_path):
        try:
            age = time.time() - os.path.getmtime(cache_path)
        except OSError:
            age = None
        if age is not None and 0 <= age < config.status_ttl():
            cached = read_json_file(cache_path)
            if cached is not None:
                return cached

    result = fetch_json(url, timeout=12)
    if result.status == 200:
        body = as_json(result.body)
        if body is not None:
            try:
                os.makedirs(config.cache_dir(), exist_ok=True)
                with open(cache_path, "w") as f:
                    f.write(result.body)
            except OSError:
                pass
            return body
    cached = read_json_file(cache_path)
    return cached


def collect_claude(now):
    creds = get_claude_credentials()
    # ~/.claude/.credentials.json is written by another program and read
    # verbatim, so nothing guarantees these are the shapes we expect.
    oauth = creds.get("claudeAiOauth")
    oauth = oauth if isinstance(oauth, dict) else {}
    token = str(oauth.get("accessToken") or "")
    admin = str(creds.get("claudeAdminApiKey") or "")

    usage = None
    usage_error = ""
    if token:
        result = fetch_json(
            "https://api.anthropic.com/api/oauth/usage",
            headers={
                "Authorization": f"Bearer {token}",
                "anthropic-beta": "oauth-2025-04-20",
                "User-Agent": "claude-code/2.1.0",
            },
            timeout=12,
            fixture_path=os.environ.get("CLAUDE_USAGE_RESPONSE_FILE"),
        )
        if result.status == 200:
            usage = as_json(result.body)
            if usage is None:
                usage_error = "parse error"
        else:
            usage_error = http_error_text(result.status)

    org = None
    if admin:
        today = datetime.datetime.now(datetime.timezone.utc)
        end = today.strftime("%Y-%m-%d")
        start = (today - datetime.timedelta(days=30)).strftime("%Y-%m-%d")
        result = fetch_json(
            f"https://api.anthropic.com/v1/organization/usage?start_date={start}&end_date={end}",
            headers={"x-api-key": admin, "anthropic-version": "2023-06-01", "Content-Type": "application/json"},
            timeout=12,
            fixture_path=os.environ.get("CLAUDE_ORG_USAGE_RESPONSE_FILE"),
        )
        if result.status == 200:
            org = as_json(result.body)

    settings = read_json_file(os.path.expanduser("~/.claude/settings.json"))
    stats = read_json_file(os.path.expanduser("~/.claude/stats-cache.json"))
    status = status_json("claude", "https://status.claude.com/api/v2/summary.json")

    return {
        "id": "claude",
        "now": now,
        "inputs": {
            "credentials": creds or {},
            "usage": usage,
            "usageError": usage_error,
            "orgUsage": org,
            "settings": settings or {},
            "stats": stats or {},
            "status": status,
        },
    }


def collect_openai(now):
    creds = get_openai_credentials()
    # As in collect_claude: ~/.codex/auth.json is not ours, so coerce rather
    # than trust. These all flow into HTTP headers, which must be str.
    token = str(creds.get("codexAccessToken") or "")
    account = str(creds.get("accountId") or "")
    api_key = str(creds.get("openaiApiKey") or "")

    codex = None
    codex_error = ""
    fixture = os.environ.get("CODEX_USAGE_RESPONSE_FILE")
    if fixture:
        codex = read_json_file(fixture)
    else:
        codex = get_codex_rate_limits()
        if not (codex.get("rateLimits") or codex.get("rate_limit")) and token:
            headers = {"Authorization": f"Bearer {token}", "User-Agent": "codex-cli"}
            if account:
                headers["chatgpt-account-id"] = account
            result = fetch_json("https://chatgpt.com/backend-api/codex/usage", headers=headers, timeout=12)
            if result.status == 200:
                codex = as_json(result.body) or {}
            else:
                codex_error = http_error_text(result.status)

    org = None
    if api_key:
        end = int(now)
        start = int(now) - 30 * 86400
        result = fetch_json(
            f"https://api.openai.com/v1/organization/usage/completions?start_time={start}&end_time={end}&group_by=model&limit=100",
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            timeout=12,
            fixture_path=os.environ.get("OPENAI_ORG_USAGE_RESPONSE_FILE"),
        )
        if result.status == 200:
            org = as_json(result.body)

    stats = get_codex_stats()
    status = status_json("openai", "https://status.openai.com/api/v2/summary.json")

    return {
        "id": "openai",
        "now": now,
        "inputs": {
            "credentials": creds or {},
            "codex": codex or {},
            "codexError": codex_error,
            "orgUsage": org,
            "stats": stats or {},
            "status": status,
        },
    }


_SIMPLE = {
    "antigravity": (get_antigravity_usage, None, None),
    "kiro": (get_kiro_usage, None, None),
    "mistral": (get_mistral_usage, "mistral", "https://status.mistral.ai/api/v2/summary.json"),
    "openrouter": (get_openrouter_usage, "openrouter", "https://status.openrouter.ai/api/v2/summary.json"),
    "grok": (get_grok_usage, None, None),
    "zai": (get_zai_usage, None, None),
    "copilot": (get_copilot_usage, None, None),
    "deepseek": (get_deepseek_balance, None, None),
    "kimi": (get_moonshot_balance, None, None),
}


def collect(id_, now):
    if id_ == "claude":
        return collect_claude(now)
    if id_ == "openai":
        return collect_openai(now)
    if id_ in _SIMPLE:
        fn, status_name, status_url = _SIMPLE[id_]
        usage = fn() or {}
        status = status_json(status_name, status_url) if status_url else None
        return {"id": id_, "now": now, "inputs": {"usage": usage, "status": status}}
    return {"id": id_, "now": now, "inputs": {}}
