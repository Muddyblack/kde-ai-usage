"""Where things live on this platform.

Almost everything a provider reads was written by another program, and that
program follows its platform's conventions: XDG directories on Linux,
%APPDATA% / %LOCALAPPDATA% on Windows, ~/Library on macOS. Every provider asks
here instead of spelling out ``~/.config`` itself.

The XDG variables win whenever they are set, on every platform. That keeps the
tests — which plant each file under a throwaway HOME and point XDG_* at it —
independent of the platform they run on.

Dotfile homes such as ~/.claude, ~/.codex and ~/.gemini need nothing from this
module: those CLIs use ``%USERPROFILE%\\.<name>`` on Windows as well, which is
exactly what ``os.path.expanduser("~/.<name>")`` resolves to there.
"""

import os
import sys

IS_WINDOWS = sys.platform == "win32"
IS_MACOS = sys.platform == "darwin"

# The folder this tool keeps its own settings, cache and history under.
APP_DIR = "ai-usage-widget"


def _windows_known(var, fallback):
    """A Windows known folder from its environment variable, with the default
    location under the profile for the rare session that lacks the variable."""
    return os.environ.get(var) or os.path.join(os.path.expanduser("~"), "AppData", fallback)


def config_home():
    """$XDG_CONFIG_HOME, else ~/.config — %APPDATA% on Windows."""
    xdg = os.environ.get("XDG_CONFIG_HOME")
    if xdg:
        return xdg
    if IS_WINDOWS:
        return _windows_known("APPDATA", "Roaming")
    return os.path.expanduser("~/.config")


def data_home():
    """$XDG_DATA_HOME, else ~/.local/share — %LOCALAPPDATA% on Windows."""
    xdg = os.environ.get("XDG_DATA_HOME")
    if xdg:
        return xdg
    if IS_WINDOWS:
        return _windows_known("LOCALAPPDATA", "Local")
    return os.path.expanduser("~/.local/share")


def cache_home():
    """$XDG_CACHE_HOME, else ~/.cache — %LOCALAPPDATA%\\cache on Windows.

    Windows has no cache folder of its own; the subfolder keeps caches apart
    from data_home(), which is %LOCALAPPDATA% itself there."""
    xdg = os.environ.get("XDG_CACHE_HOME")
    if xdg:
        return xdg
    if IS_WINDOWS:
        return os.path.join(_windows_known("LOCALAPPDATA", "Local"), "cache")
    return os.path.expanduser("~/.cache")


def electron_app_data():
    """Electron's appData: the parent of a VS Code-family IDE's own folder
    (Cursor, Kiro, …), which holds User/globalStorage/state.vscdb.

    Electron follows XDG_CONFIG_HOME on Linux and uses %APPDATA% on Windows,
    which is config_home() on both; macOS is the one that differs."""
    if IS_MACOS and not os.environ.get("XDG_CONFIG_HOME"):
        return os.path.expanduser("~/Library/Application Support")
    return config_home()


def history_dir():
    """Where the shared usage-history file and its snapshots live."""
    return os.path.join(data_home(), APP_DIR)


def no_window():
    """Keyword arguments for subprocess calls that keep Windows from opening a
    console for a console program (codex, gh, …).

    The Windows frontend is a GUI program with no console of its own, so each
    child would otherwise flash a terminal window up on every poll. Empty on
    every other platform."""
    if IS_WINDOWS:
        # Imported here: history saves import this module and are otherwise
        # kept free of heavy imports (see history.save).
        import subprocess

        return {"creationflags": subprocess.CREATE_NO_WINDOW}
    return {}
