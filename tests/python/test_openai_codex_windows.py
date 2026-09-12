"""A Codex plan that reports only some of its windows gets rows and pill slots
for exactly those — no empty "Codex 5-hour 0%" for a plan without one."""

import time
import unittest

import _support  # noqa: F401  (sys.path)
from aiusage.normalize import normalize


def envelope(*limits):
    now = int(time.time())
    windows = {name: {"usedPercent": pct, "windowDurationMins": mins, "resetsAt": now + 3600} for name, pct, mins in limits}
    return {
        "id": "openai",
        "now": now,
        "inputs": {"credentials": {"codexLoggedIn": True, "email": "a@b.c"}, "codex": {"rateLimits": windows}},
    }


class CodexWindowsTest(unittest.TestCase):
    def test_weekly_only_plan(self):
        p = normalize(envelope(("primary", 92, 10080)))
        self.assertEqual([w["key"] for w in p["quotaWindows"] if w["key"].startswith("codex")], ["codex_weekly"])
        self.assertEqual([s["pct"] for s in p["slots"]], [92])
        self.assertEqual(p["summary"]["text"], "92%")

    def test_both_windows(self):
        p = normalize(envelope(("primary", 10, 300), ("secondary", 40, 10080)))
        self.assertEqual([w["key"] for w in p["quotaWindows"] if w["key"].startswith("codex")], ["codex_session", "codex_weekly"])
        self.assertEqual([s["pct"] for s in p["slots"]], [10, 40])
        self.assertEqual(p["summary"]["text"], "10%")


if __name__ == "__main__":
    unittest.main()
