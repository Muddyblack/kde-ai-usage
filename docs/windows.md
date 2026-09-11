# The Windows tray app

`windows/` is a PySide6 host for the same popup the Hyprland panel draws. It
adds no provider logic of its own:

| Part | Lives in | Shared with |
|---|---|---|
| Provider data, credentials, maths | `package/contents/tools/aiusage` | every frontend |
| Usage history file and its lock | `aiusage/historyio.py` | Plasma + Hyprland, via `tools/sh/history-io` |
| Platform directories | `aiusage/paths.py` | every frontend |
| Popup layout | `hyprland/PopupContent.qml` | Hyprland |
| Settings page, rows, chart, stats | `hyprland/*.qml` | Hyprland |
| Provider list, opt-in rule | `hyprland/ProviderRegistry.js` | Hyprland |
| Countdown / history JS | `package/contents/code/*.js` | Plasma + Hyprland |
| Window, tray icon, autostart | `windows/app.py`, `windows/qml/Main.qml` | — |

`Main.qml` and `hyprland/AiUsageShell.qml` are the two implementations of the
`shell` interface that `PopupContent.qml` and `SettingsPage.qml` read. A
property added to one belongs in the other.

## Running it

On Linux, which is how it is developed:

```bash
make run-windows              # PySide6 + psutil from `nix develop .#windows`
python windows/app.py         # the same, from inside `nix develop .#windows`
python3 windows/app.py        # or any Python with windows/requirements.txt installed
```

On Windows, from a checkout:

```powershell
pip install -r windows/requirements.txt
python windows\app.py
```

Starting it a second time toggles the running instance's popup instead of
opening another tray icon.

## Checking it without a desktop

```bash
python3 windows/app.py --selftest                      # exit 1 on any QML warning
python3 windows/app.py --screenshot popup.png          # after the first refresh
python3 windows/app.py --screenshot settings.png --settings
```

`--selftest` opens every settings section once, so a binding that only breaks on
a hidden page still fails it. `tests/python/test_windows_app.py` runs it with
every provider switched off, so it needs no network.

## Building the .exe

On Windows (PyInstaller does not cross-compile):

```powershell
pip install -r windows/requirements.txt pyinstaller pillow
pyinstaller --noconfirm windows/ai-usage.spec
"dist\AI Usage\AI Usage.exe" --selftest
```

The result is a folder, `dist\AI Usage\`, rather than a single file: a one-file
build unpacks itself to a temp directory on every start. Zip the folder to ship
it.

The installer wraps that folder (Inno Setup, `windows/installer.iss`):

```powershell
windows\build-installer.ps1 -Version 2.4.0     # → AI-Usage-Setup-2.4.0.exe
```

It installs per user (no admin rights) to `%LOCALAPPDATA%\Programs\AI Usage`,
adds a Start menu entry, optionally a desktop shortcut and *Start when I sign
in* (the same registry value as the tray menu's switch), stops a running copy
before replacing it, and registers an uninstaller. Keep its `AppId` as it is:
that is how a newer installer finds and updates the installed app.

CI does all of this on every push (`.github/workflows/windows.yml`, as a
workflow artifact), and tagged releases attach both the installer and the zip
(`release.yml`).

## Testing on real Windows

Docker and distrobox cannot run this: Windows containers need a Windows host,
and distrobox runs Linux only. Wine runs the backend but is not worth trusting
for the tray or window behaviour. What works:

- **A KVM virtual machine** — the main loop for anything visual.
  - `quickemu` (in nixpkgs): `quickget windows 11`, then `quickemu --vm windows-11.conf`.
  - [`dockur/windows`](https://github.com/dockur/windows) — the "docker" way: a
    KVM Windows VM inside a container, with a web viewer and RDP. Easy to throw
    away and recreate from a compose file.
  - virt-manager with libvirt, if it is already set up.

  Share the checkout into the VM (virtiofs, or an SMB share) so you edit on
  Linux and only run on Windows.
- **CI** — every push runs `tests/python` and `--selftest` on `windows-latest`,
  and builds the `.exe`, which then has to pass `--selftest` itself. That
  catches most regressions without starting a VM.

Worth checking by hand in a VM, since no test covers it:

- the popup opens against the taskbar next to the icon, with the taskbar on each
  edge;
- each tray style (Logo and percent, Numbers, Ring) reads at 100 %, 125 % and
  150 % display scaling, on a light and a dark taskbar, and the icons keep their
  places (and "show in taskbar" choice) across a restart;
- each logo sits to the left of its number: the icons are created newest-last
  on the assumption that Windows, like Plasma, lays them out newest-first
  (`TrayApp._show_entries`) — flip that if Windows turns out not to;
- a number below 70 % is white on a dark taskbar and near-black on a light one
  (read from the "system" light/dark setting);
- the floating pill: its slot logos show (they are tinted by a GPU effect, so
  check a machine without GPU acceleration too — a VM, a remote desktop), a
  drag moves it and a click opens the popup beside it, and it comes back where
  it was left after a restart, or above the taskbar when that screen is gone;
- a click on the icon while the popup is open closes it rather than reopening it;
- **Start with Windows** survives a sign-out;
- no console window flashes up on a refresh (Codex and `gh` are console programs);
- each provider you use finds its login — the paths below are the ones not yet
  confirmed on a real machine.

## Where things are on Windows

Confirmed by construction (the CLIs use `%USERPROFILE%\.<name>` on Windows too,
which is what `~/.<name>` resolves to): Claude, Codex, Gemini/Antigravity
accounts, Grok, Cline, Kimi, the Copilot CLI.

Still to confirm on a real install:

| Provider | Looked for at |
|---|---|
| Cursor IDE | `%APPDATA%\Cursor\User\globalStorage\state.vscdb` |
| Kiro IDE | `%APPDATA%\Kiro\User\globalStorage\state.vscdb` |
| cursor-agent | `%APPDATA%\cursor\auth.json` |
| kiro-cli | `%LOCALAPPDATA%\kiro-cli\data.sqlite3` |
| Muse | `%LOCALAPPDATA%\muse\…`, `%APPDATA%\muse\…` |
| Copilot editor plugins | `%LOCALAPPDATA%\github-copilot\apps.json` |
| Z.AI via glm-acp-agent | `%USERPROFILE%\.config\glm-acp-agent\credentials.json` (the Linux path under the profile; the tool may use `%APPDATA%` instead) |

Everything else is either one of those dotfile folders or a key file of the
widget's own (`~/.config/deepseek/api-key` and the like), which no vendor tool
writes: on Windows it is simply looked for under `%USERPROFILE%\.config\`, and
the Settings page or an environment variable is the usual way in anyway.

Every one of them can be pointed elsewhere with the provider's environment
variable (`CURSOR_IDE_DB`, `KIRO_IDE_DB`, `KIRO_CLI_DB`, `MUSE_SESSIONS_DIR`, …)
while a path is being confirmed.
