<p align="center">
  <img src="./readme/icon.svg" width="120" alt="AI Usage Widget Logo">
</p>


<h1 align="center">AI Usage Widget</h1>

<p align="center">
  <a href="https://github.com/Muddyblack/kde-ai-usage">
    <img src="https://img.shields.io/badge/KDE_Store-Coming_Soon-orange?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Store" />
  </a>
  <img src="https://img.shields.io/badge/KDE_Plasma-6.0%2B-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Plasma 6.0+" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License: MIT" />
  </a>
  <img src="https://img.shields.io/github/downloads/Muddyblack/kde-ai-usage/total?style=for-the-badge&logo=kdeplasma&logoColor=white&label=Downloads&color=blue" alt="Downloads" />
</p>

<p align="center">
  <b>Panel Applet Views (Pill / Compact modes)</b><br/>
  <img src="./readme/panel.svg?v=4" alt="Pill Panel view" width="160" valign="middle"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="./readme/panel_2.svg?v=4" alt="Compact Panel view" width="90" valign="middle"/>
</p>

<p align="center">
  <img src="./readme/demo.svg?v=4" alt="Claude view" width="312" valign="top"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="./readme/demo_2.svg?v=4" alt="Antigravity view" width="380" valign="top"/>
</p>

A KDE Plasma 6 panel widget for tracking AI API quota usage across multiple services. Monitor your **Claude** (5-hour session & 7-day weekly) and **Antigravity/Google AI Studio** usage at a glance with animated segmented bars, live countdown timers, and per-model breakdowns.

---

## Features

- **Multi-service support** — Switch between Claude and Antigravity tabs in the popup
- **Panel view** — Compact percentage readouts in the taskbar, color-coded by usage level
- **Popup view** — Segmented bars showing exact fill level with reset times and countdowns
- **Model breakdown** — See usage per model (Sonnet, Opus, Haiku for Claude; Gemini models for Antigravity)
- **Live countdowns** — Ticks down in real time, shows "resetting..." when the window flips
- **Color thresholds** — Amber at 70%, red at 90%
- **Auto-refresh** — Polls every 5 minutes, reads credentials from local config files
- **Stale indicator** — Dims if the last fetch failed, shows error inline
- **Rate-limit backoff** — Respects `retry-after` headers, won't hammer the API

---

## Supported Services

### Claude (Anthropic)
- **5-hour session window** — Rolling 5-hour usage limit
- **7-day weekly window** — Rolling 7-day usage limit
- **Auto-detection** — Reads credentials from `~/.claude/.credentials.json`
- **Model tracking** — Opus, Sonnet, Haiku usage breakdown (coming soon)

### Antigravity (Google AI Studio)
- **Overall quota** — Combined usage across all models
- **Per-model breakdown** — Individual Gemini model usage
- **Multi-account support** — Works with `antigravity-usage` CLI
- **Reset tracking** — Shows when quota resets

---

## Requirements

| Dependency | Notes |
|---|---|
| KDE Plasma 6.0+ | `X-Plasma-API-Minimum-Version: 6.0` |
| `plasma5support` | Provides the `executable` DataEngine for reading credentials |

### For Claude Support
| Dependency | Notes |
|---|---|
| Claude Code | Logged-in session required — credentials read from `~/.claude/.credentials.json` |

### For Antigravity Support
| Dependency | Notes |
|---|---|
| Node.js 18+ | Required to run `antigravity-usage` CLI |
| `antigravity-usage` | Install with `npm install -g antigravity-usage` |
| Google Account | With AI Studio / Antigravity access |

See [SETUP.md](SETUP.md) for detailed configuration instructions.

---

## Install

### Manual (any distro)

```bash
git clone https://github.com/Muddyblack/kde-ai-usage.git
cd kde-ai-usage
kpackagetool6 -t Plasma/Applet -i package
# or to update an existing install:
kpackagetool6 -t Plasma/Applet -u package
```

Then right-click your panel → *Add Widgets* → search **"AI Usage"**.

To remove:

```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.aiUsageWidget
```

### Development / test install

```bash
./test_install.sh
```

Installs as `AI Usage (Test)` alongside the real widget so you can iterate without touching your live install.

To remove the test copy:

```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.aiUsageWidgetTest
```

### NixOS (flake)

```nix
# flake.nix
{
  inputs.ai-usage.url = "github:Muddyblack/kde-ai-usage";

  outputs = { self, nixpkgs, ai-usage, ... }: {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            ai-usage.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
```

### Package as `.plasmoid`

```bash
./pack.sh
# produces ai-usage-widget-<version>.plasmoid
```

---

## How it works

### Claude
On each refresh cycle the widget reads `~/.claude/.credentials.json` to get the OAuth access token, then calls the Anthropic usage API. The response contains two rolling windows — a 5-hour session window and a 7-day weekly window — each with a utilization percentage and a reset timestamp.

### Antigravity
The widget reads credentials from the `antigravity-usage` CLI configuration (stored in `~/.config/antigravity-usage/` or `~/Library/Application Support/antigravity-usage/`), then calls the Google Cloud Code API to fetch quota information for all available models.

**Privacy:** No credentials are stored or transmitted anywhere other than the official API endpoints (Anthropic and Google).

---

## Releasing

```bash
./tag.sh
```

Prompts for a version bump (patch / minor / major), updates `package/metadata.json`, commits, tags, and pushes. CI then builds the `.plasmoid` and creates a GitHub release automatically.
