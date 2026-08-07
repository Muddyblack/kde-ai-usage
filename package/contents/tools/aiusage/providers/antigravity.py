"""Runs the antigravity-usage CLI if present, else scans /proc for the
Antigravity language server and probes its local API directly.

Ported from tools/sh/get-antigravity-usage. The bash version shelled out to
`ss`/`netstat` to find the language server's listening ports; this reads
/proc/[pid]/fd and /proc/net/tcp[6] directly instead, which is both more
portable (no external tool required) and avoids a process fork per probe.
"""

import datetime
import json
import os
import shutil
import ssl
import subprocess
import urllib.error
import urllib.request

from ..http import as_json


def _scan_processes():
    found = []
    try:
        pids = [e for e in os.listdir("/proc") if e.isdigit()]
    except OSError:
        return found
    for pid in pids:
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                raw = f.read()
        except OSError:
            continue
        parts = raw.split(b"\x00")
        if parts and parts[-1] == b"":
            parts = parts[:-1]
        args = [a.decode("utf-8", "replace") for a in parts]
        text = " ".join(args)
        if "antigravity" not in text or "--csrf_token" not in text:
            continue

        csrf_token, ext_port = "", ""
        i = 0
        while i < len(args):
            a = args[i]
            if a == "--csrf_token" and i + 1 < len(args):
                i += 1
                csrf_token = args[i]
            elif a.startswith("--csrf_token="):
                csrf_token = a.split("=", 1)[1]
            elif a == "--extension_server_port" and i + 1 < len(args):
                i += 1
                ext_port = args[i]
            elif a.startswith("--extension_server_port="):
                ext_port = a.split("=", 1)[1]
            i += 1

        if not csrf_token:
            continue
        found.append((pid, csrf_token, ext_port))
    return found


def _pid_listening_ports(pid):
    inodes = set()
    fd_dir = f"/proc/{pid}/fd"
    try:
        for entry in os.listdir(fd_dir):
            try:
                target = os.readlink(os.path.join(fd_dir, entry))
            except OSError:
                continue
            if target.startswith("socket:["):
                inodes.add(target[8:-1])
    except OSError:
        return []

    ports = set()
    for proc_net in ("/proc/net/tcp", "/proc/net/tcp6"):
        try:
            with open(proc_net) as f:
                lines = f.readlines()[1:]
        except OSError:
            continue
        for line in lines:
            fields = line.split()
            if len(fields) < 10 or fields[3] != "0A" or fields[9] not in inodes:
                continue
            try:
                port = int(fields[1].split(":")[1], 16)
            except (IndexError, ValueError):
                continue
            ports.add(port)
    return sorted(ports)


def _probe(url, token, body, timeout, ctx):
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json", "Connect-Protocol-Version": "1", "X-Codeium-Csrf-Token": token},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            return resp.status, resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        try:
            body_text = e.read().decode("utf-8", "replace")
        except Exception:
            body_text = ""
        return e.code, body_text
    except Exception:
        return None, None


def _probe_port(port, token):
    body = json.dumps({"wrapper_data": {}}).encode()
    for scheme in ("https", "http"):
        url = f"{scheme}://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/GetUnleashData"
        ctx = ssl._create_unverified_context() if scheme == "https" else None
        status, _ = _probe(url, token, body, 1, ctx)
        if status in (200, 401):
            return scheme
    return None


def _fetch_user_status(scheme, port, token):
    body = json.dumps({"metadata": {"ideName": "antigravity", "extensionName": "antigravity", "locale": "en"}}).encode()
    url = f"{scheme}://127.0.0.1:{port}/exa.language_server_pb.LanguageServerService/GetUserStatus"
    ctx = ssl._create_unverified_context() if scheme == "https" else None
    status, text = _probe(url, token, body, 2, ctx)
    if not text or "error" in text:
        return None
    return as_json(text)


def _format_user_status(data):
    us = data.get("userStatus") or {}
    ps = us.get("planStatus") or {}
    plan_info = ps.get("planInfo") or {}
    configs = (us.get("cascadeModelConfigData") or {}).get("clientModelConfigs") or []

    prompt_credits = None
    avail = ps.get("availablePromptCredits")
    monthly = plan_info.get("monthlyPromptCredits")
    if avail is not None and monthly is not None and monthly > 0:
        prompt_credits = {
            "available": avail,
            "monthly": monthly,
            "usedPercentage": (monthly - avail) / monthly,
            "remainingPercentage": avail / monthly,
        }

    models = []
    for c in configs:
        model_or_alias = c.get("modelOrAlias") or {}
        model_id = model_or_alias.get("model") or "unknown"
        label = c.get("label") or model_or_alias.get("model")
        quota = c.get("quotaInfo") or {}
        remaining = quota.get("remainingFraction")
        models.append(
            {
                "label": label,
                "modelId": model_id,
                "remainingPercentage": remaining,
                "isExhausted": remaining == 0,
                "resetTime": quota.get("resetTime"),
                "isAutocompleteOnly": ("gemini-2.5" in (model_or_alias.get("model") or "")) or ("Gemini 2.5" in (c.get("label") or "")),
            }
        )

    user_tier = us.get("userTier") or {}
    plan_type = user_tier.get("name") if user_tier.get("name") else None

    return {
        # Local time with a literal "Z", matching what the jq version emitted
        # via strflocaltime. Nothing in normalize/ reads this field; it exists
        # to mirror the antigravity-usage CLI's output shape.
        "timestamp": datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        "method": "local",
        "email": us.get("email"),
        "planType": plan_type,
        "promptCredits": prompt_credits,
        "models": models,
    }


def get_antigravity_usage():
    cli = shutil.which("aiu") or shutil.which("antigravity-usage")
    if cli:
        try:
            proc = subprocess.run([cli, "--json"], capture_output=True, text=True, timeout=15)
        except (OSError, subprocess.TimeoutExpired):
            proc = None
        if proc is not None and proc.returncode == 0:
            parsed = as_json(proc.stdout)
            return parsed if isinstance(parsed, dict) else {}

    found_any_process = False
    for pid, csrf_token, ext_port in _scan_processes():
        found_any_process = True
        ports = _pid_listening_ports(pid)
        if not ports and ext_port:
            try:
                ports = [int(ext_port)]
            except ValueError:
                ports = []
        for port in ports:
            scheme = _probe_port(port, csrf_token)
            if scheme is None:
                continue
            data = _fetch_user_status(scheme, port, csrf_token)
            if data is not None:
                return _format_user_status(data)

    if found_any_process:
        return {"error": "Antigravity language server found but could not connect to API"}
    return {"error": "Antigravity is not running. Please open your IDE."}
