"""Drives `codex app-server --stdio` over JSON-RPC to read plan rate limits.

Popen with line-buffered stdin/stdout; a 5s read timeout per phase, and the child is always reaped.
"""

import json
import selectors
import shutil
import subprocess


def _read_until_id(stream, want_id, timeout):
    sel = selectors.DefaultSelector()
    sel.register(stream, selectors.EVENT_READ)
    try:
        while True:
            if not sel.select(timeout):
                return None
            line = stream.readline()
            if line == "":
                return None
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            if obj.get("id") == want_id:
                return obj
    finally:
        sel.close()


def get_codex_rate_limits():
    if shutil.which("codex") is None:
        return {}

    try:
        proc = subprocess.Popen(
            ["codex", "app-server", "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
    except OSError:
        return {}

    # Popen fills both pipes because stdin/stdout are PIPE above, but they are
    # Optional on the type level — bind them once so the child is still reaped
    # if that ever fails rather than raising past the cleanup below.
    stdin, stdout = proc.stdin, proc.stdout

    result = {}
    try:
        if stdin is None or stdout is None:
            return {}

        initialize = json.dumps(
            {
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {"name": "kde-ai-usage", "version": "1"},
                    "capabilities": {"experimentalApi": True},
                },
            }
        )
        try:
            stdin.write(initialize + "\n")
            stdin.flush()
        except (BrokenPipeError, OSError):
            return {}

        if _read_until_id(stdout, 1, 5) is not None:
            read_limits = json.dumps({"id": 2, "method": "account/rateLimits/read", "params": None})
            try:
                stdin.write(read_limits + "\n")
                stdin.flush()
            except (BrokenPipeError, OSError):
                read_limits_reply = None
            else:
                read_limits_reply = _read_until_id(stdout, 2, 5)
            if read_limits_reply is not None:
                result = read_limits_reply.get("result") or {}
    finally:
        for stream in (stdin, stdout):
            try:
                if stream is not None:
                    stream.close()
            except Exception:
                pass
        try:
            proc.terminate()
            proc.wait(timeout=2)
        except Exception:
            try:
                proc.kill()
                proc.wait(timeout=2)
            except Exception:
                pass

    return result
