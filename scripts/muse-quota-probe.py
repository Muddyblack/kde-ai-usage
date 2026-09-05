#!/usr/bin/env python3
"""Muse subscription-endpoint discovery probe (phase 2 of the widget provider).

YOU run this in your own terminal: it reads your Muse OAuth store the same
way the `muse` CLI does. The access token stays in this process's memory and
is NEVER printed — output is key shapes, HTTP statuses and quota numbers
only. Inspect the output before pasting it anywhere.

Usage:
    python3 ./tmp/muse-quota-probe.py            # free calls only (models list)
    python3 ./tmp/muse-quota-probe.py --spend    # + one minimal Responses call
                                                 #   (a few tokens, finds the
                                                 #   response.subscription_usage
                                                 #   snapshot shape)

Credential order mirrors the CLI: $META_API_KEY first, then the OAuth login
from $MUSE_AUTH_PATH or ~/.config/muse/auth.json.
"""

import json
import os
import sys
import urllib.error
import urllib.request

BASES = [
    os.environ.get("MUSE_SPARK_BASE_URL") or "https://api.meta.ai/v1",
    "https://api.ai.meta.com/v1",
]

SPEND_BODY = {
    "model": "muse-spark-1.3",
    "input": "Reply with exactly: ok",
    "max_output_tokens": 8,
}


def _clean(s):
    return s.translate(str.maketrans("", "", "\n\r ")).strip()


def load_credential():
    key = _clean(os.environ.get("META_API_KEY", ""))
    if key:
        return ("META_API_KEY", key)
    path = os.environ.get("MUSE_AUTH_PATH")
    if not path:
        config_home = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
        path = os.path.join(config_home, "muse", "auth.json")
    try:
        with open(path, errors="replace") as f:
            doc = json.load(f)
    except (OSError, ValueError) as e:
        return (None, f"cannot read {path}: {type(e).__name__}")
    meta = ((doc.get("providers") or {}).get("meta") or {}) if isinstance(doc, dict) else {}
    # api_key is the Model-API bearer; access_token is the OIDC device-code
    # token (good for auth.meta.com, 401 on the Model API).
    for field in ("api_key", "access_token", "accessToken", "token"):
        token = _clean(meta.get(field) or "")
        if token:
            return (f"auth.json:{field}", token)
    return (None, f"no usable token field in auth store (saw keys: {sorted(meta.keys())})")


def censor(obj, depth=0):
    """Key shapes + numbers/bools only. Strings become their length, except
    a short allowlist of quota-ish scalars worth seeing."""
    if depth > 6:
        return "..."
    if isinstance(obj, dict):
        return {k: censor(v, depth + 1) for k, v in obj.items()}
    if isinstance(obj, list):
        return [censor(v, depth + 1) for v in obj[:5]] + ([f"... +{len(obj) - 5} more"] if len(obj) > 5 else [])
    if isinstance(obj, bool):
        return obj
    if isinstance(obj, (int, float)):
        return obj
    if isinstance(obj, str):
        if len(obj) < 64 and any(t in obj.lower() for t in ("muse", "plan", "usage", "pro", "high")):
            return obj
        return f"<str len={len(obj)}>"
    return f"<{type(obj).__name__}>"


def call(label, method, url, token, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": "Bearer REDACTED",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "kde-ai-usage/probe",
        },
    )
    # Swap in the real credential only at send time; it never touches output.
    req.headers["Authorization"] = "Bearer " + token
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode("utf-8", "replace")
            status = resp.status
    except urllib.error.HTTPError as e:
        try:
            raw = e.read().decode("utf-8", "replace")
        except Exception:
            raw = ""
        status = e.code
    except Exception as e:
        print(f"[{label}] {method} {url}\n  transport error: {type(e).__name__}\n")
        return
    print(f"[{label}] {method} {url}\n  status: {status}")
    try:
        parsed = json.loads(raw)
    except ValueError:
        print(f"  non-JSON body ({len(raw)} chars): {raw[:200]!r}\n")
        return
    print(f"  shape: {json.dumps(censor(parsed), indent=1)[:2500]}\n")


def main():
    origin, credential = load_credential()
    if origin is None:
        print("no credential:", credential)
        return 2
    print(f"credential source: {origin} (value hidden)")
    for base in BASES:
        call("models", "GET", base + "/models", credential)
    if "--spend" in sys.argv[1:]:
        call("responses-minimal", "POST", BASES[0] + "/responses", credential, SPEND_BODY)
    else:
        print("(skipped Responses call: re-run with --spend to allow a few tokens)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
