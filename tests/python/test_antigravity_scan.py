"""Finding the Antigravity language server: its CSRF token from the command
line and its port from the listening sockets — through /proc on Linux and
psutil everywhere else. A stand-in process plays the server."""

import os
import subprocess
import sys
import unittest
from unittest import mock

import _support  # noqa: F401  (sys.path)
from aiusage.providers import antigravity

try:
    import psutil
except ImportError:
    psutil = None

STAND_IN = (
    "import socket, sys, time\ns = socket.socket()\ns.bind(('127.0.0.1', 0))\ns.listen()\nprint(s.getsockname()[1], flush=True)\ntime.sleep(60)\n"
)


class AntigravityScanTest(unittest.TestCase):
    def setUp(self):
        self.proc = subprocess.Popen(
            [sys.executable, "-c", STAND_IN, "antigravity-language-server", "--csrf_token", "tok123"],
            stdout=subprocess.PIPE,
            text=True,
        )
        self.addCleanup(self.stop)
        self.port = int(self.proc.stdout.readline())

    def stop(self):
        self.proc.kill()
        self.proc.wait()
        self.proc.stdout.close()

    def check(self):
        found = {str(pid): token for pid, token, _port in antigravity._scan_processes()}
        self.assertEqual(found.get(str(self.proc.pid)), "tok123")
        self.assertIn(self.port, antigravity._pid_listening_ports(self.proc.pid))

    @unittest.skipUnless(psutil, "psutil not installed")
    def test_through_psutil(self):
        with mock.patch.object(antigravity, "_HAS_PROC", False):
            self.check()

    @unittest.skipUnless(os.path.isdir("/proc/self"), "no /proc on this platform")
    def test_through_proc(self):
        with mock.patch.object(antigravity, "_HAS_PROC", True):
            self.check()

    def test_says_what_is_missing_without_either(self):
        no_proc = mock.patch.object(antigravity, "_HAS_PROC", False)
        no_psutil = mock.patch.object(antigravity, "_psutil", lambda: None)
        no_cli = mock.patch.object(antigravity.shutil, "which", lambda _name: None)
        with no_proc, no_psutil, no_cli:
            self.assertIn("psutil", antigravity.get_antigravity_usage()["error"])


if __name__ == "__main__":
    unittest.main()
