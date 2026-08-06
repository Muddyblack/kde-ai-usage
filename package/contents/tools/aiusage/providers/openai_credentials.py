import base64
import os

from ..http import as_json


def _read_key_file(path):
    if not os.path.isfile(path):
        return ""
    try:
        with open(path) as f:
            return f.read().translate(str.maketrans("", "", "\n\r ")).strip()
    except OSError:
        return ""


def _decode_jwt_payload(token):
    parts = token.split(".")
    if len(parts) < 2:
        return {}
    segment = parts[1].replace("-", "+").replace("_", "/")
    segment += "=" * (-len(segment) % 4)
    try:
        return as_json(base64.b64decode(segment).decode("utf-8", "replace")) or {}
    except Exception:
        return {}


def get_openai_credentials():
    api_key = os.environ.get("WIDGET_OPENAI_API_KEY", "") or os.environ.get("OPENAI_API_KEY", "")
    if not api_key:
        api_key = _read_key_file(os.path.expanduser("~/.config/openai-api-key"))
    if not api_key:
        api_key = _read_key_file(os.path.expanduser("~/.openai/api-key"))

    access_token = email = plan_type = org_id = account_id = auth_mode = ""

    auth_path = os.path.expanduser("~/.codex/auth.json")
    if os.path.isfile(auth_path):
        try:
            with open(auth_path) as f:
                codex_auth = as_json(f.read())
        except OSError:
            codex_auth = None
        if isinstance(codex_auth, dict):
            tokens = codex_auth.get("tokens") or {}
            access_token = tokens.get("access_token") or codex_auth.get("access_token") or ""
            account_id = tokens.get("account_id") or codex_auth.get("account_id") or ""
            auth_mode = codex_auth.get("auth_mode") or ""

            if not api_key:
                codex_api_key = codex_auth.get("OPENAI_API_KEY") or ""
                if codex_api_key:
                    api_key = codex_api_key

            if access_token:
                payload = _decode_jwt_payload(access_token)
                email = (payload.get("https://api.openai.com/profile") or {}).get("email") or ""
                auth = payload.get("https://api.openai.com/auth") or {}
                plan_type = auth.get("chatgpt_plan_type") or ""
                orgs = auth.get("organizations") or []
                org_id = (orgs[0].get("id") if orgs else "") or ""

    if not api_key and not access_token:
        return {}

    return {
        "openaiApiKey": api_key,
        "codexAccessToken": access_token,
        "email": email,
        "planType": plan_type,
        "orgId": org_id,
        "accountId": account_id,
        "authMode": auth_mode,
        "codexLoggedIn": access_token != "",
    }
