<p align="center">
  <img src="./readme/icon.svg?v=7" width="120" alt="AI Usage Widget Logo">
</p>


<h1 align="center">AI Usage Widget</h1>

<p align="center">
  <a href="https://www.opendesktop.org/p/2361382/">
    <img src="https://img.shields.io/badge/KDE_Store-Download-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Store" />
  </a>
  <img src="https://img.shields.io/badge/KDE_Plasma-6.0%2B-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Plasma 6.0+" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License: MIT" />
  </a>
  <a href="https://www.opendesktop.org/p/2361382/">
    <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.pling.com%2Focs%2Fv1%2Fcontent%2Fdata%3Fsearch%3DAI%2Busage%2Bwidget%26format%3Djson&query=%24.data%5B0%5D.downloads&label=KDE%20Downloads&style=for-the-badge&color=1d99f3&logo=kde&logoColor=white" alt="KDE Store Downloads" />
  </a>
  <img src="https://img.shields.io/github/downloads/Muddyblack/kde-ai-usage/total?style=for-the-badge&logo=github&logoColor=white&label=GitHub%20Downloads&color=blue" alt="GitHub Downloads" />
</p>

<p align="center">
  <b>Panel — Pill &amp; Compact modes</b><br/><br/>
  <img src="./readme/panel.svg?v=7" alt="Pill Panel view" width="160" valign="middle"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="./readme/panel_2.svg?v=8" alt="Compact Panel view" width="90" valign="middle"/>
</p>

<p align="center">
  <b>Popup — Provider tabs</b><br/><br/>
  <img src="./readme/demo.svg?v=7" alt="Claude tab" width="340" valign="top"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="./readme/demo_2.svg?v=7" alt="Antigravity tab" width="340" valign="top"/>
</p>
<p align="center">
  <img src="./readme/demo_3.svg?v=8" alt="OpenAI tab" width="340" valign="top"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="./readme/demo_chart.svg?v=1" alt="Usage Chart" width="340" valign="top"/>
</p>

<p align="center">
  <b>Settings</b><br/><br/>
  <img src="./readme/settings.svg?v=7" alt="Settings panel" width="340" valign="top"/>
</p>

A KDE Plasma 6 panel widget for tracking AI API quota usage across multiple services. Monitor your **Claude** (5-hour session & 7-day weekly), **Antigravity/Google AI Studio**, **OpenAI API**, **Mistral AI**, and **OpenRouter** usage at a glance with animated segmented bars, live countdown timers, account status, and per-model breakdowns.

---

## Features

- **Multi-service support** — Switch between Claude, Antigravity, OpenAI, Mistral, and OpenRouter tabs in the popup
- **Panel view** — Compact percentage readouts in the taskbar, color-coded by usage level, with an inline spark-line trend
- **Popup view** — Segmented bars showing exact fill level with reset times and countdowns
- **Usage chart** — Smooth, glowing area chart of historical usage with a 5H / 24H / 7D window toggle and hover-scrub (point + timestamp on hover). The 24H window plots the session percentage across the whole day, so each 5-hour limit climbing toward 100% and resetting shows up as a sawtooth burn pattern.
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

### Mistral AI
- **Key validation** — Confirms the API key is accepted by Mistral
- **Model list** — Shows available models, with the active vibe CLI model highlighted
- **vibe CLI stats** — Reads `~/.vibe/logs/session/*/meta.json` to show cumulative cost, session count, total tokens, and last session title
- **Cost bar** — Spend bar scaled against a $50 soft cap, backed by 30-day chart history
- **Credential lookup** — Reads the widget setting first, then `$MISTRAL_API_KEY`, `~/.vibe/.env`, `~/.config/mistral/api-key`, `~/.mistral/api-key`
- **Requires** — A Mistral API key (or vibe CLI installed with a key in `~/.vibe/.env`)

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

### For Mistral Support
| Dependency | Notes |
|---|---|
| Mistral API key | Widget settings, `$MISTRAL_API_KEY`, `~/.vibe/.env`, or `~/.config/mistral/api-key` |
| vibe CLI | Optional; session logs in `~/.vibe/logs/session/` provide cost and token stats without an API key |

### For OpenRouter Support *(untested)*
| Dependency | Notes |
|---|---|
| OpenRouter API key | Set in widget settings — no local config file is read |

All configuration is done in the widget's settings panel (right-click the widget → *Configure*). See [How it works](#how-it-works) below for what each tab reads and where credentials are resolved from.

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

### Mistral AI
The widget validates the configured API key against the Mistral API and lists available models, highlighting the one currently active in vibe CLI. Since Mistral exposes no public billing REST API, cost data is sourced locally from vibe CLI session logs (`~/.vibe/logs/session/*/meta.json`): cumulative spend, session count, total tokens, and the last session title are shown in a stats card. The spend bar is scaled against a $50 soft cap and feeds into a 30-day chart. The key is resolved from widget settings → `$MISTRAL_API_KEY` → `~/.vibe/.env` → `~/.config/mistral/api-key`.

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
