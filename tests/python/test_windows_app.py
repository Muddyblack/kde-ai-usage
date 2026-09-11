"""The tray app's QML loads without a single warning — the shared popup and
settings page included — and its plain helpers behave. Needs PySide6."""

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

from _support import REPO

APP = os.path.join(REPO, "windows", "app.py")
HAS_PYSIDE = importlib.util.find_spec("PySide6") is not None


@unittest.skipUnless(HAS_PYSIDE, "PySide6 not installed")
class TrayAppTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def env(self, settings):
        config = os.path.join(self.tmp, "settings.json")
        with open(config, "w") as fh:
            json.dump(settings, fh)
        return dict(
            os.environ,
            QT_QPA_PLATFORM="offscreen",
            AI_USAGE_CONFIG=config,
            XDG_DATA_HOME=os.path.join(self.tmp, "data"),
            XDG_CACHE_HOME=os.path.join(self.tmp, "cache"),
        )

    def selftest(self, settings):
        return subprocess.run([sys.executable, APP, "--selftest"], env=self.env(settings), capture_output=True, text=True, timeout=120)

    def test_popup_and_every_settings_section_load_cleanly(self):
        # Every provider off, so nothing here depends on the network. The
        # selftest itself opens each settings section in turn.
        off = {"providers": dict.fromkeys(("claude", "antigravity", "openai", "kiro", "mistral", "openrouter", "grok"), False)}
        result = self.selftest(off)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
