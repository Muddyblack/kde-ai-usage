"""Shared credential + HTTP plumbing for the provider helpers.

`urllib.request` is imported lazily inside fetch_json, never at module scope:
it pulls in ssl/http.client/email and costs ~60ms of interpreter startup that
--normalize, cache-hit status lookups, and unconfigured providers should never
pay. See plan.md constraint #3.
"""

import os


class HttpResult:
    __slots__ = ("status", "body")

    def __init__(self, status, body):
        self.status = status
        self.body = body


def resolve_key(widget_var, env_var, *files):
    """Credential precedence, identical for every provider: the value the
    widget passed in, then a conventional environment variable, then the
    first readable config file.

    Every source is cleaned the same way: strip the surrounding whitespace,
    then drop any \n, \r or space left embedded in the middle. A credential
    pasted with a trailing newline would otherwise reach urllib, which
    rejects the header with a ValueError — and that exception carries the
    credential into the traceback, defeating the guarantee that no secret
    leaves this package. This only covers whitespace/CR/LF; a credential
    containing other control characters would still reach urllib as-is.

    `env_var` accepts either a single name or a sequence of them, tried in
    order. Several vendors ship two spellings of the same variable — Moonshot
    is read as both MOONSHOT_API_KEY and KIMI_API_KEY, Z.AI documents
    Z_AI_API_KEY while this package reads ZAI_TOKEN — and a provider that
    knows only one of them reports "no token configured" at a user who did
    set the key, which is the least debuggable failure we can produce.
    """

    def _clean(s):
        return s.translate(str.maketrans("", "", "\n\r ")).strip()

    value = _clean(os.environ.get(widget_var, "")) if widget_var else ""
    if not value and env_var:
        names = (env_var,) if isinstance(env_var, str) else env_var
        for name in names:
            if not name:
                continue
            value = _clean(os.environ.get(name, ""))
            if value:
                break
    if not value:
        for path in files:
            if not path or not os.path.isfile(path):
                continue
            try:
                with open(path) as f:
                    value = _clean(f.read())
            except OSError:
                value = ""
            if value:
                break
    return value


def http_error_text(status):
    """The frontend-facing error vocabulary — deliberately shorter than the
    per-provider wording (see docs/provider-contract.md)."""
    if status in (0, None, ""):
        return "offline"
    if status == 401:
        return "token expired"
    if status == 403:
        return "access denied"
    if status == 429:
        return "rate limited"
    return f"err {status}"


def error_json(message):
    return {"hasKey": False, "keyValid": False, "error": message}


def http_error_json(label, status, auth_message=None):
    """Maps a status code onto the usual wording. Providers with a more
    specific authentication message than "Invalid <label> credential" pass it
    as auth_message."""
    if status in (401, 403):
        return error_json(auth_message or f"Invalid {label} credential")
    if status in (0, None, ""):
        return error_json(f"{label} network error")
    return error_json(f"{label} HTTP {status}")


def fetch_json(url, headers=None, timeout=10, fixture_path=None):
    """Returns an HttpResult. `fixture_path` replays a recorded response as a
    200 so tests never touch the network — the *_RESPONSE_FILE hooks."""
    if fixture_path and os.path.isfile(fixture_path):
        try:
            with open(fixture_path) as f:
                return HttpResult(200, f.read())
        except OSError:
            return HttpResult(0, "")

    import urllib.error
    import urllib.request

    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return HttpResult(resp.status, resp.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        try:
            body = e.read().decode("utf-8", "replace")
        except Exception:
            body = ""
        return HttpResult(e.code, body)
    except (urllib.error.URLError, TimeoutError, OSError):
        return HttpResult(0, "")


def as_json(text):
    """Parse JSON, returning None on any failure — mirrors the bash
    as_json/null-on-invalid convention."""
    import json

    if not text:
        return None
    try:
        return json.loads(text)
    except ValueError:
        return None
