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
  <img src="./readme/demo.svg?v=10" alt="Claude tab" width="340" valign="top"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="./readme/demo_2.svg?v=10" alt="Antigravity tab" width="340" valign="top"/>
</p>
<p align="center">
  <img src="./readme/demo_3.svg?v=10" alt="OpenAI tab" width="340" valign="top"/>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <img src="./readme/demo_chart.svg?v=10" alt="Usage Chart" width="340" valign="top"/>
</p>

<p align="center">
  <b>Settings</b><br/><br/>
  <img src="./readme/settings.svg?v=10" alt="Settings panel" width="340" valign="top"/>
</p>

A KDE Plasma 6 panel widget for tracking AI API quota usage across multiple services. Monitor your **Claude** subscription windows and local activity stats, **Antigravity/Google AI Studio**, **OpenAI API and Codex plan limits**, **Grok CLI**, **Kiro**, **Mistral AI**, **OpenRouter**, **Z.AI**, **GitHub Copilot**, and **DeepSeek** usage or balance at a glance with animated segmented bars, live countdown timers, account status, and per-model breakdowns.

---

## Features

- **Multi-service support** — Switch between Claude, Antigravity, OpenAI, Grok, Kiro, Mistral, OpenRouter, Z.AI, GitHub Copilot, and DeepSeek tabs in the popup
- **Balance tracking** — DeepSeek current balance with granted / topped-up breakdown
- **Panel view** — Compact percentage readouts in the taskbar, color-coded by usage level, with an inline spark-line trend
- **Popup view** — Segmented bars showing exact fill level with reset times and countdowns
- **Usage chart** — Smooth, glowing area chart of historical usage with availability-aware 5H / 24H / 7D choices and hover-scrub (point + timestamp on hover). Session choices disappear when a provider does not report a session window.
- **Burn-rate ETA** — Estimates time to 100% from your recent trend (e.g. "↗ ~3h to 100%") for each available window
- **Period comparison** — Shows how today/this week compares to the same point last period (e.g. "+12% vs last week")
- **Cost aggregation** — Combined API spend across Claude, OpenAI, and OpenRouter in the footer
- **Animated readouts** — Percentages roll up/down smoothly; the chart's latest point pulses when usage is climbing fast
- **Theme-aware accent** — Follows your Plasma accent color by default, or use per-service brand colors (toggle in settings)
- **Glassmorphism popup** — Translucent, blurred popup styling
- **Model breakdown** — See usage per model for providers that expose it
- **Live countdowns** — Ticks down in real time, shows "resetting..." when the window flips
- **Color thresholds** — Amber at 70%, red at 90%
- **Configurable refresh** — Poll interval from 1 to 30 minutes (default 5), reads credentials from local config files
- **Pin services** — Pin one or more tabs so they stay visible on the Plasma panel; with no pins, the panel mirrors the active tab
- **History export / import** — Save and restore usage history as JSON; history is also mirrored to disk so it survives reinstalls
- **Stale indicator** — Dims if the last fetch failed, shows error inline
- **Rate-limit backoff** — Respects `retry-after` headers, won't hammer the API

---

## Supported Services

| Service | What the widget shows | Support status |
|---|---|---|
| Claude (Anthropic) | Subscription windows reported by Anthropic, reset times, and local activity stats | Supported |
| Antigravity / Google AI Studio | Overall quota, per-model Gemini usage, and reset times | Supported |
| OpenAI | 30-day API token/cost usage plus Codex/ChatGPT plan limits and account status | Supported |
| Grok (xAI) | CLI billing credits when exposed, free-tier exhaustion, and local session totals | Free tier tested; paid plans unverified |
| Kiro | Monthly credits, remaining balance, reset date, overage, and inferred plan | Supported |
| Mistral AI | Key status, available models, and local vibe CLI cost/token statistics | Supported |
| OpenRouter | Spend, credit limit, usage percentage, and account label | Untested |
| Z.AI | 5-hour token quota, monthly tools quota, reset countdowns, and model details | Untested |
| GitHub Copilot | Monthly premium request usage against a configurable quota | Personal billing supported; organization/enterprise billing not yet supported |
| DeepSeek | Available balance with granted and topped-up breakdown | Untested |

Provider APIs do not all expose the same information. In particular, Codex/ChatGPT
plan limits are separate from OpenAI API organization usage, DeepSeek reports a
balance rather than a usage window, and Grok's free tier does not expose progressive
usage before its limit is exhausted. See
[How it works](#how-it-works) for provider-specific details.

---

## Requirements

| Dependency | Notes |
|---|---|
| KDE Plasma 6.0+ | `X-Plasma-API-Minimum-Version: 6.0` |
| `plasma5support` | Provides the `executable` DataEngine for running the backend |
| `jq` and `curl` | Required by the shared provider backend and every fetch helper |

Enable only the services you use. Each one has its own setup requirement:

| Service | What you need |
|---|---|
| Claude | Claude Code, signed in locally |
| Antigravity | Node.js 18+, the `antigravity-usage` CLI, and a Google account with access |
| OpenAI | An OpenAI API key for organization API usage; a Codex CLI login provides Codex/ChatGPT plan limits and account status |
| Grok | Grok CLI authenticated with `grok --oauth`; an xAI API key is optional |
| Kiro | Kiro IDE, signed in at least once |
| Mistral AI | A Mistral API key; vibe CLI is optional and adds local session statistics |
| OpenRouter | An OpenRouter API key entered in widget settings |
| Z.AI | A Z.AI token from widget settings, `$ZAI_TOKEN`, or `~/.config/zai/token` |
| GitHub Copilot | A GitHub token from widget settings, `$GITHUB_TOKEN`, or `~/.config/github-copilot/token`, with fine-grained **Plan: read** permission; personal billing only. The quota defaults to 300 and is configurable |
| DeepSeek | A DeepSeek API key from widget settings, `$DEEPSEEK_API_KEY`, or `~/.config/deepseek/api-key` |

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

### Hyprland / Caelestia

Run the Quickshell widget together with its standard StatusNotifier tray icon:

```bash
# From a cloned checkout
nix run .#hyprland

# Or run the current GitHub version directly
nix run github:Muddyblack/kde-ai-usage#hyprland
```

During development, use `nix run path:.#hyprland` if newly created files have
not been added to Git yet; regular users do not need the `path:` form.

The tray icon works with any panel that hosts freedesktop StatusNotifier items,
including Caelestia and Waybar. The **Pill** setting offers **Always**, **Edge
hover**, and **Tray only** modes. Edge-hover mode keeps only a small screen-edge
hotspot and reveals the usage pill without polling. Six top/bottom position
presets place both the pill and popup consistently. Clicking the tray icon
toggles the popup; clicking outside the popup closes it.

The Hyprland frontend supports the same provider set as the Plasma widget,
including Z.AI, GitHub Copilot, and DeepSeek. Enable these newer providers and
enter their credentials in the popup settings page; they default to off. The
settings are stored locally in
`~/.config/ai-usage-widget/hyprland-settings.json` (or under
`$XDG_CONFIG_HOME`).

### Package as `.plasmoid`

```bash
./pack.sh
# produces ai-usage-widget-<version>.plasmoid
```

---

## How it works

### Shared provider backend

Both frontends — the Plasma widget and the Hyprland/Quickshell shell — get every
provider value from one executable, `package/contents/tools/sh/get-ai-usage`.
It owns credential discovery, provider API requests, response parsing, quota
maths, reset timestamps and error/stale state, and returns a versioned,
frontend-neutral JSON model:

```bash
get-ai-usage --provider claude        # one provider (Plasma: active tab + pins)
get-ai-usage --all                    # every enabled provider (Hyprland panel)
```

Normalization lives in `package/contents/tools/jq/providers.jq` and is pure, so
`get-ai-usage --normalize` can replay a recorded provider response offline.
Credential lookup, HTTP calls and status-code handling are shared by every
helper via `package/contents/tools/sh/lib/http.sh`.

The QML on both sides is presentation only: no provider URLs, no response
parsing, no percentage or window arithmetic, and not even the table of which
chart ranges a provider has — that arrives with the data. What genuinely is
shared between the two UIs (countdown formatting, usage-history merging) lives
in `package/contents/code/`. The schema is documented in
[`docs/provider-contract.md`](docs/provider-contract.md).

### Claude
On each refresh cycle the widget reads `~/.claude/.credentials.json` to get the OAuth access token, then calls Anthropic's subscription usage endpoint. It prefers the current semantic `limits[]` entries and falls back to the legacy `five_hour` and `seven_day` objects. Only windows with usable data are displayed; legacy five-hour support remains available if Anthropic returns it.

### Antigravity
The widget reads credentials from the `antigravity-usage` CLI configuration (stored in `~/.config/antigravity-usage/` or `~/Library/Application Support/antigravity-usage/`), then calls the Google Cloud Code API to fetch quota information for all available models.

### OpenAI
The OpenAI tab has two independent sections. API usage is fetched from the official OpenAI organization usage endpoint with an API key and summarized over the last 30 days. Codex subscription limits are read through the local Codex app-server, with the authenticated web usage endpoint retained as a compatibility fallback. Windows are classified by their actual duration instead of assuming that `primary` means five hours. Codex plan limits are separate from API billing usage.

### Grok *(free tier tested; paid plans untested)*
The Grok tab reads the Grok CLI login from `~/.grok/auth.json`, fetches the same credit/billing data used by the CLI, and summarizes local CLI sessions from `~/.grok/sessions`. For the tested free tier, the CLI only records the exact token allowance after it returns `free-usage-exhausted`, so the widget can show the confirmed exhausted amount and rolling 24-hour window but cannot infer progressive usage before that event. Paid-plan billing parsing is implemented but remains unverified. An xAI API key is optional; CLI OAuth is the primary source for quota data.

### Kiro
The Kiro tab reads Kiro's locally cached usage state from `~/.config/Kiro/User/globalStorage/state.vscdb`. No API key is needed. The widget extracts the stored credit breakdown, usage percentage, reset date, overage information, and inferred plan tier from that local snapshot, then feeds the percentage into the 30-day chart history.

### Mistral AI
The widget validates the configured API key against the Mistral API and lists available models, highlighting the one currently active in vibe CLI. Since Mistral exposes no public billing REST API, cost data is sourced locally from vibe CLI session logs (`~/.vibe/logs/session/*/meta.json`): cumulative spend, session count, total tokens, and the last session title are shown in a stats card. The spend bar is scaled against a $50 soft cap and feeds into a 30-day chart. The key is resolved from widget settings → `$MISTRAL_API_KEY` → `~/.vibe/.env` → `~/.config/mistral/api-key`.

### OpenRouter *(untested)*
The widget fetches credit usage and limit from the OpenRouter API using the configured key. The popup shows USD spent, the credit limit (if any), and the account label. The usage bar reflects spend as a percentage of the limit; if no limit is set the bar stays empty.

### Z.AI *(untested)*
The Z.AI tab calls the Z.AI usage quota endpoint with the configured token. It shows the 5-hour token quota, monthly tools quota, reset countdowns, and model details when the API response includes them. The token is resolved from widget settings → `$ZAI_TOKEN` → `~/.config/zai/token`.

### GitHub Copilot
The GitHub Copilot tab reads monthly premium request usage from GitHub's user billing API. It validates the token against the GitHub user endpoint, then fetches premium request usage and scales it against the configured quota, which defaults to 300. The token is resolved from widget settings → `$GITHUB_TOKEN` → `~/.config/github-copilot/token`, and a fine-grained token needs **Plan: read** permission. This user endpoint covers Copilot plans billed personally; usage billed through an organization or enterprise is not shown yet. A VS Code Copilot login is not imported automatically because VS Code keeps its session token in encrypted secret storage rather than a reusable plaintext config file.

### DeepSeek *(untested)*
The DeepSeek tab calls `GET https://api.deepseek.com/user/balance` with the configured API key. It shows whether the account has sufficient balance for API calls, the primary total balance, and the granted / topped-up split. The key is resolved from widget settings → `$DEEPSEEK_API_KEY` → `~/.config/deepseek/api-key`.

### Usage history
Each refresh appends the usage values that a provider actually reports to a rolling history (the last 500 samples) used by the chart, spark-lines, burn-rate ETA, and period comparison. Rolling plan windows (Claude, Codex) empty at a known instant, so when the machine was asleep across one the chart replays the drop where it actually happened instead of sloping from the last pre-sleep sample to the first one after wake-up. Most series are percentages; Mistral stores its raw vibe CLI spend and DeepSeek stores its raw balance so their charts retain meaningful units. Existing session and weekly history fields are retained even while a window is unavailable, so five-hour charts can return without migration if providers restore that limit. History is stored in the widget's Plasma config **and** mirrored to `~/.local/share/ai-usage-widget/usage-history-latest.json`, so it survives a full uninstall/reinstall — on first launch with no config history, the widget restores from that file automatically. You can also manually **Export** (writes a timestamped JSON copy) and **Import** from the settings panel. If a saved file is unreadable or in an unrecognized format, it's discarded and history starts fresh rather than erroring out.

**Privacy:** Credentials entered in widget settings are stored locally in the desktop's widget/config file and are sent only to the corresponding provider endpoints. Automatically discovered credentials remain in their original local files. Tokens never leave the backend: the JSON model handed to either frontend carries presence flags (`hasApiKey`, `keyValid`, …) but no credential, and a contract test enforces that. Usage history (timestamps plus the values described above) is written locally to `~/.local/share/ai-usage-widget/`.

---

## Tests

```bash
make test
```

`tests/get-ai-usage.test.sh` replays the fixtures in `tests/fixtures/` through
the backend's `--normalize` mode — success, missing credentials, malformed
responses, offline and rate-limited states for every provider — and then runs
the real backend end to end against the fetch tools' fixture hooks. No network
access is needed. `tests/shared-code.test.js` covers the JavaScript both
frontends share.

---

## Releasing

```bash
./tag.sh
```

Prompts for a version bump (patch / minor / major), updates `package/metadata.json`, commits, tags, and pushes. CI then builds the `.plasmoid` and creates a GitHub release automatically.
