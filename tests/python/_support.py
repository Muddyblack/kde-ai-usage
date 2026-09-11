"""Shared by the unittest suites here: puts the backend package on sys.path.

These suites are the portable half of the tests — plain unittest, no shell —
so CI can run them on Windows as well as Linux (.github/workflows/windows.yml).
The shell suites in tests/*.sh stay the contract tests for the Linux frontends.
"""

import os
import sys

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TOOLS = os.path.join(REPO, "package", "contents", "tools")

if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)


def env_without_xdg(**extra):
    """A copy of the environment with every XDG_* variable dropped, plus `extra`."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("XDG_")}
    env.update(extra)
    return env
