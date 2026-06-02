<p align="center">
  <img src="./readme/icon.svg?v=7" width="120" alt="AI Usage Widget Logo">
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
  <img src="./readme/panel.svg?v=7" alt="Pill Panel view" width="160" valign="middle"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="./readme/panel_2.svg?v=8" alt="Compact Panel view" width="90" valign="middle"/>
</p>

<p align="center">
  <img src="./readme/demo.svg?v=7" alt="Claude view" width="340" valign="top"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="./readme/demo_3.svg?v=8" alt="OpenAI view" width="340" valign="top"/>
</p>
<p align="center">
  <img src="./readme/demo_2.svg?v=7" alt="Antigravity view" width="340" valign="top"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="./readme/settings.svg?v=7" alt="Settings view" width="340" valign="top"/>
</p>

A KDE Plasma 6 panel widget for tracking AI API quota usage across multiple services. Monitor your **Claude** (5-hour session & 7-day weekly), **Antigravity/Google AI Studio**, **OpenAI API**, **Mistral AI**, and **OpenRouter** usage at a glance with animated segmented bars, live countdown timers, account status, and per-model breakdowns.

---

## Features

- **Multi-service support** — Switch between Claude, Antigravity, OpenAI, Mistral, and OpenRouter tabs in the popup
- **Panel view** — Compact percentage readouts in the taskbar, color-coded by usage level, with an inline spark-line trend
- **Popup view** — Segmented bars showing exact fill level with reset times and countdowns
- **Usage chart** — Smooth, glowing area chart of historical usage with a 5H / 7D window toggle and hover-scrub (point + timestamp on hover)
- **Burn-rate ETA** — Estimates time to 100% from your recent trend (e.g. "↗ ~3h to 100%") on both the 5-hour and 7-day windows
- **Period comparison** — Shows how today/this week compares to the same point last period (e.g. "+12% vs last week")
- **Cost aggregation** — Combined API spend across Claude, OpenAI, and OpenRouter in the footer
- **Animated readouts** — Percentages roll up/down smoothly; the chart's latest point pulses when usage is climbing fast
- **Theme-aware accent** — Follows your Plasma accent color by default, or use per-service brand colors (toggle in settings)
- **Glassmorphism popup** — Translucent, blurred popup styling
- **Model breakdown** — See usage per model for providers that expose it
- **Live countdowns** — Ticks down in real time, shows "resetting..." when the window flips
- **Color thresholds** — Amber at 70%, red at 90%
- **Configurable refresh** — Poll interval from 1 to 30 minutes (default 5), reads credentials from local config files
- **Pin a service** — Pin any tab so the widget opens to it; otherwise it stays on the last-viewed tab
- **History export / import** — Save and restore usage history as JSON; history is also mirrored to disk so it survives reinstalls
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

### OpenAI
- **API usage** — Shows 30-day organization token and estimated cost data from the OpenAI Usage API when an API key is configured
- **Codex account status** — Detects Codex/ChatGPT login from `~/.codex/auth.json`
- **Separate surfaces** — Codex/ChatGPT plan limits are not the same as OpenAI API organization billing usage
- **Credential lookup** — Reads the widget setting first, then `$OPENAI_API_KEY`, `~/.config/openai-api-key`, `~/.openai/api-key`, and Codex auth metadata when available

### Mistral AI *(untested)*
- **Key validation** — Confirms the API key is accepted by Mistral
- **Model list** — Shows how many models are available under the account
- **Requires** — A Mistral API key set in widget settings

### OpenRouter *(untested)*
- **Spend tracking** — Shows USD spent against your credit limit (if one is set)
- **Usage bar** — Fills proportionally to spend vs limit; empty if no limit is set
- **Account label** — Displays the account name / identifier from the API
- **Requires** — An OpenRouter API key set in widget settings

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

### For OpenAI Support
| Dependency | Notes |
|---|---|
| OpenAI API key | Required for API token and cost usage via the organization Usage API |
| Codex CLI | Optional; logged-in Codex sessions are shown as account status only |

### For Mistral Support *(untested)*
| Dependency | Notes |
|---|---|
| Mistral API key | Set in widget settings — no local config file is read |

### For OpenRouter Support *(untested)*
| Dependency | Notes |
|---|---|
| OpenRouter API key | Set in widget settings — no local config file is read |

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

### OpenAI
The OpenAI tab has two independent sections. API usage is fetched from the official OpenAI organization usage endpoint with an API key and summarized over the last 30 days. Codex account status is read locally from `~/.codex/auth.json`; it confirms the Codex/ChatGPT login and plan metadata when present, but it does not provide API billing usage.

### Mistral AI *(untested)*
The widget validates the configured API key against the Mistral API and lists available models. No quota or usage data is currently shown — the tab confirms the key is valid and shows how many models the account can access.

### OpenRouter *(untested)*
The widget fetches credit usage and limit from the OpenRouter API using the configured key. The popup shows USD spent, the credit limit (if any), and the account label. The usage bar reflects spend as a percentage of the limit; if no limit is set the bar stays empty.

### Usage history
Each refresh appends the current 5-hour and 7-day percentages to a rolling history (the last 500 samples) used by the chart, spark-lines, burn-rate ETA, and period comparison. History is stored in the widget's Plasma config **and** mirrored to `~/.local/share/ai-usage-widget/usage-history-latest.json`, so it survives a full uninstall/reinstall — on first launch with no config history, the widget restores from that file automatically. You can also manually **Export** (writes a timestamped JSON copy) and **Import** from the settings panel. If a saved file is unreadable or in an unrecognized format, it's discarded and history starts fresh rather than erroring out.

**Privacy:** No credentials are stored or transmitted anywhere other than the official provider endpoints used by each tab. Usage history (percentages and timestamps only) is written locally to `~/.local/share/ai-usage-widget/`.

---

## Releasing

```bash
./tag.sh
```

Prompts for a version bump (patch / minor / major), updates `package/metadata.json`, commits, tags, and pushes. CI then builds the `.plasmoid` and creates a GitHub release automatically.
