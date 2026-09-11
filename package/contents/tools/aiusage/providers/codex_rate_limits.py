"""Drives `codex app-server --stdio` over JSON-RPC to read plan rate limits.

Popen with line-buffered stdin/stdout; a 5s read deadline per phase, and the
child is always reaped.

Replies are read on a helper thread rather than with `selectors`: Windows can
only select() on sockets, never on a pipe, and a thread works the same on both.
"""

import json
import queue
import shutil
import subprocess
import threading
import time

from .. import paths


def _pump(stream, lines):
    """Reader thread: hand every line on, then None for end of stream."""
    try:
        for line in stream:
            lines.put(line)
    except (OSError, ValueError):
        # ValueError: the stream was closed under us during cleanup.
        pass
    finally:
        lines.put(None)


def _read_until_id(lines, want_id, timeout):
    deadline = time.monotonic() + timeout
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return None
        try:
            line = lines.get(timeout=remaining)
        except queue.Empty:
            return None
        if line is None:
            # Leave the end marker for the next phase, which would otherwise
            # sit out its whole deadline on a stream that has already ended.
            lines.put(None)
            return None
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        if isinstance(obj, dict) and obj.get("id") == want_id:
            return obj


def _stop(proc):
    """Terminate the child and everything it started, then reap it.

    On Windows an npm install is codex.cmd, so the child is cmd.exe with node
    and the native server below it. Terminating cmd.exe alone would orphan the
    server on every poll, so the whole tree goes, by pid, while the parent is
    still there to name it."""
    if paths.IS_WINDOWS:
        try:
            subprocess.run(
                ["taskkill", "/T", "/F", "/PID", str(proc.pid)],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
                **paths.no_window(),
            )
        except (OSError, subprocess.TimeoutExpired):
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


def get_codex_rate_limits():
    # The resolved path, not the bare name: Popen does not apply PATHEXT, so on
    # Windows "codex" would never find codex.cmd or codex.exe.
    codex = shutil.which("codex")
    if codex is None:
        return {}

    try:
        proc = subprocess.Popen(
            [codex, "app-server", "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
            **paths.no_window(),
        )
    except OSError:
        return {}

    # Popen fills both pipes because stdin/stdout are PIPE above, but they are
    # Optional on the type level — bind them once so the child is still reaped
    # if that ever fails rather than raising past the cleanup below.
    stdin, stdout = proc.stdin, proc.stdout

    result = {}
    reader = None
    try:
        if stdin is None or stdout is None:
            return {}

        lines = queue.Queue()
        reader = threading.Thread(target=_pump, args=(stdout, lines), daemon=True)
        reader.start()

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

        if _read_until_id(lines, 1, 5) is not None:
            read_limits = json.dumps({"id": 2, "method": "account/rateLimits/read", "params": None})
            try:
                stdin.write(read_limits + "\n")
                stdin.flush()
            except (BrokenPipeError, OSError):
                read_limits_reply = None
            else:
                read_limits_reply = _read_until_id(lines, 2, 5)
            if read_limits_reply is not None:
                result = read_limits_reply.get("result") or {}
    finally:
        try:
            if stdin is not None:
                stdin.close()
        except Exception:
            pass
        _stop(proc)
        # Closing stdout while the reader is blocked in it can deadlock on the
        # stream's lock, so only close it once the reader has seen the end. A
        # grandchild still holding the pipe open leaves the daemon thread
        # parked there, which costs nothing: this process exits right after.
        if reader is not None:
            reader.join(timeout=1)
        if stdout is not None and (reader is None or not reader.is_alive()):
            try:
                stdout.close()
            except Exception:
                pass

    return result
