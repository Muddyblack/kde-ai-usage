"""Codex session stats take each rollout's date from its directory names —
which on Windows arrive from os.walk with backslashes."""

import json
import os
import shutil
import tempfile
import unittest
from unittest import mock

import _support  # noqa: F401  (sys.path)
from aiusage.providers.codex_stats import get_codex_stats


def _line(**fields):
    return json.dumps(fields, separators=(",", ":")) + "\n"


class CodexStatsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)
        day = os.path.join(self.tmp, "sessions", "2026", "09", "10")
        os.makedirs(day)
        with open(os.path.join(day, "rollout-a.jsonl"), "w") as fh:
            fh.write(_line(timestamp="2026-09-10T10:00:00.000Z", type="session_meta"))
            fh.write(_line(timestamp="2026-09-10T10:05:00.000Z", type="event_msg", payload={"type": "user_message"}))

    def test_dates_come_from_the_directory_names(self):
        env = {
            "CODEX_SESSIONS_DIR": os.path.join(self.tmp, "sessions"),
            "CODEX_CONFIG_FILE": os.path.join(self.tmp, "missing.toml"),
            "XDG_CACHE_HOME": os.path.join(self.tmp, "cache"),
        }
        with mock.patch.dict(os.environ, env):
            stats = get_codex_stats()
        self.assertEqual([d["date"] for d in stats["dailyActivity"]], ["2026-09-10"])
        self.assertEqual(stats["totalSessions"], 1)
        self.assertEqual(stats["totalMessages"], 1)


if __name__ == "__main__":
    unittest.main()
