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
  <br/>
  <a href="https://www.opendesktop.org/p/2361382/">
    <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.pling.com%2Focs%2Fv1%2Fcontent%2Fdata%2F%3Fformat%3Djson%26user%3DMuddyblack%26pagesize%3D20%26sortmode%3Dalpha&query=%24.data%5B0%5D.downloads&label=KDE%20Downloads&style=for-the-badge&color=1d99f3&logo=kde&logoColor=white" alt="KDE Store Downloads" />
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
  <img src="./readme/settings.svg?v=11" alt="Settings panel" width="340" valign="top"/>
</p>

A KDE Plasma 6 panel widget for tracking AI API quota usage across multiple services. Monitor your **Claude** subscription windows and local activity stats, **Antigravity/Google AI Studio**, **OpenAI API and Codex plan limits**, **Grok CLI**, **Kiro**, **Mistral AI**, **OpenRouter**, **Z.AI**, **GitHub Copilot**, **DeepSeek**, **Kimi / Moonshot AI**, and **Muse** usage or balance at a glance with animated segmented bars, live countdown timers, account status, and per-model breakdowns.

---

## Features

- **Multi-service support** — Switch between Claude, Antigravity, OpenAI, Grok, Kiro, Mistral, OpenRouter, Z.AI, GitHub Copilot, DeepSeek, Kimi, Muse, Cursor, and Cline tabs in the popup
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
- **Terminal frontend** — [`ai-usage-cli`](#terminal) prints the same data as a table, or a single status-bar line with `--compact`, on desktops without Plasma 6 and over SSH

---

## Supported Services

| Service | What the widget shows | Support status |
|---|---|---|
| Claude (Anthropic) | Subscription windows reported by Anthropic, reset times, and local activity stats | Supported |
| Antigravity / Google AI Studio | Overall quota, per-model Gemini usage, and reset times | Supported |
| OpenAI | 30-day API token/cost usage plus Codex/ChatGPT plan limits and account status | Supported |
| Grok (xAI) | CLI billing credits when exposed, free-tier exhaustion, and local session totals | Free tier tested; paid plans unverified |
| Kiro | Monthly credits, remaining balance, reset date, overage, and plan — from kiro-cli's login or the Kiro IDE | Supported |
| Mistral AI | Key status, available models, and local vibe CLI cost/token statistics | Supported |
| OpenRouter | Spend, credit limit, usage percentage, and account label | Untested |
| Z.AI | 5-hour token quota, monthly tools quota, reset countdowns, model details, and today's token consumption | Supported |
| GitHub Copilot | Premium request usage against the plan's own entitlement, the real reset day, and local Copilot CLI activity stats | Personal billing supported; organization/enterprise billing not yet supported |
| DeepSeek | Available balance with granted and topped-up breakdown | Supported |
| Kimi / Moonshot AI | Kimi Code plan windows (5-hour and weekly) and extra-usage wallet; Moonshot API balance with voucher and cash breakdown | Moonshot balance supported; Kimi Code quota tested on a used-up plan only |
| Muse | Local session stats: tokens, offline spend estimate, sessions, tool calls, workspaces, streaks. Plan windows available behind an opt-in switch | Supported (the plan quota costs tokens to read — off by default) |
| Cursor | Included usage for the billing cycle, the Auto/API split, on-demand spend, and plan name | Free plan tested; paid plans unverified |
| Cline | Tokens, sessions and spend for today / 7 / 30 days, plus all-time stats per model and workspace, from the CLI's own session logs | Supported (local stats; account balance not yet shown) |

Provider APIs do not all expose the same information. In particular, Codex/ChatGPT
plan limits are separate from OpenAI API organization usage, DeepSeek reports a
balance rather than a usage window, and Grok's free tier does not expose progressive
usage before its limit is exhausted. See
[How it works](#how-it-works) for provider-specific details.

---

## Requirements

| Dependency | Notes |
|---|---|
| KDE Plasma 6.0+ | `X-Plasma-API-Minimum-Version: 6.0`. Needed for the widget only — the Hyprland shell and the [terminal frontend](#terminal) run without it |
| `plasma5support` | Provides the `executable` DataEngine for running the backend |
| Python 3.8+ | Runs the shared provider backend (standard library only, no `pip install`). Auto-detected from PATH as `python3`, a versioned `python3.x`, or bare `python`. To pin a specific interpreter — a virtualenv, a non-standard prefix — set it under **Settings → Advanced → Python**, or export `$PYTHON3`. NixOS installs need no PATH entry at all: the flake pins the interpreter at build time |

Enable only the services you use. Each one has its own setup requirement:

| Service | What you need |
|---|---|
| Claude | Claude Code, signed in locally |
| Antigravity | Node.js 18+, the `antigravity-usage` CLI, and a Google account with access |
| OpenAI | An OpenAI API key for organization API usage; a Codex CLI login provides Codex/ChatGPT plan limits and account status |
| Grok | Grok CLI authenticated with `grok --oauth`; an xAI API key is optional |
| Kiro | kiro-cli signed in (`kiro-cli login`), or the Kiro IDE signed in at least once |
| Mistral AI | A Mistral API key; vibe CLI is optional and adds local session statistics |
| OpenRouter | An OpenRouter API key entered in widget settings |
| Z.AI | A Z.AI token from widget settings, `$ZAI_TOKEN`, `$Z_AI_API_KEY`, `~/.config/zai/token`, `~/.zai/token`, or the one `glm-acp-agent --setup` already stored |
| GitHub Copilot | Usually nothing to configure: the Copilot editor login (`~/.config/github-copilot/apps.json`), the Copilot CLI login, or `gh auth token` is picked up automatically. Widget settings, `$GITHUB_TOKEN` and `$GH_TOKEN` still win when set; a token with fine-grained **Plan: read** permission additionally unlocks the documented billing endpoint. Personal billing only |
| DeepSeek | A DeepSeek API key from widget settings, `$DEEPSEEK_API_KEY`, or `~/.config/deepseek/api-key` |
| Kimi / Moonshot AI | A Kimi Code login (`kimi`, then `/login`) for the plan quota, and/or a Moonshot API key from widget settings, `$MOONSHOT_API_KEY`, `$KIMI_API_KEY`, or `~/.config/moonshot/api-key` for the API balance |
| Muse | Nothing to configure for the local stats — `muse login` is enough. The optional plan quota additionally uses `$META_API_KEY` or the key `muse login` stored |
| Cursor | cursor-agent signed in (`cursor-agent login`), or the Cursor IDE signed in. No API key |
| Cline | The Cline CLI, run at least once. Nothing to configure |

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

### Windows *(preview)*

A tray app with the same popup as the Hyprland panel — the QML is shared, not
copied — backed by the same provider package. Download
`AI-Usage-Setup-<version>.exe` from a release and run it: no admin rights, a
Start menu entry, an optional *Start when I sign in*, and an uninstaller under
*Installed apps*; running a newer one updates in place. (Or take
`ai-usage-windows-<version>.zip`, unzip it anywhere and run `AI Usage.exe`.)
The app isn't code-signed yet, so SmartScreen asks once: *More info → Run
anyway*. It sits in the notification area: click the icon for the popup,
right-click for **Refresh**, **Settings**, **Tray style**, **Floating pill**,
**Start with Windows** and **Quit**. Three tray styles (also under *Settings →
Display*):

- **Ring** (default) — a single icon, the logo inside a usage ring: one icon to
  keep in view.
- **Logo and percent** — like the panel pill: for each value of the active tab,
  the provider's logo tinted by level, then `NN%`. Windows gives every tray icon
  the same square, so that is two icons per value.
- **Numbers** — the logo once, then each value as plain coloured digits.

**Floating pill** adds the panel's own pill as a small always-on-top window —
drag it anywhere, it stays where it was left; a click opens the popup beside it.

Windows 11 puts new tray icons in the `^` overflow at first — which is why the
very first start opens the popup by itself: drag the icon onto the taskbar
once, or turn it on under *Settings → Personalization → Taskbar → Other system
tray icons*. Starting AI Usage again from the Start menu while it runs opens
the popup too. Nothing to install — Python and Qt ship inside the folder.

It reads the same logins as on Linux, which the CLIs keep under your profile on
Windows too (`%USERPROFILE%\.claude`, `.codex`, `.gemini`, `.copilot`, …). The
VS Code-family IDEs (Cursor, Kiro) are read from `%APPDATA%`. Its own files:

| What | Where |
|---|---|
| Settings (same format as Hyprland's) | `%APPDATA%\ai-usage-widget\hyprland-settings.json` |
| Usage history | `%LOCALAPPDATA%\ai-usage-widget\` |
| Log (Qt warnings and Python errors; the previous one is `tray.log.1`) | `%LOCALAPPDATA%\ai-usage-widget\tray.log` |

Antigravity is found through `psutil`, which the build bundles. Running from a
checkout instead:

```powershell
pip install -r windows/requirements.txt
python windows/app.py
```

The app runs on Linux as well, which is how it is developed —
`make run-windows`, or `python windows/app.py` inside `nix develop .#windows`
(a separate shell, so the everyday one stays free of PySide6). See
[docs/windows.md](docs/windows.md) for building the `.exe` and testing it in a
Windows VM.

### Terminal

`ai-usage-cli` renders the same provider data as a table, with no Plasma,
Quickshell or compositor involved. It is the way to use this on a desktop the
widget cannot be installed on — Plasma 5, GNOME, XFCE — as well as over SSH, in
a shell prompt, or in a status bar.

```bash
# From a cloned checkout: put the tools on PATH …
export PATH="$PWD/package/contents/tools/sh:$PATH"

# … or link just the frontend (it resolves symlinks to find its package)
ln -s "$PWD/package/contents/tools/sh/ai-usage-cli" ~/.local/bin/ai-usage-cli

# … or, on NixOS, run it straight from the flake without installing anything
nix run .#cli
nix run github:Muddyblack/kde-ai-usage#cli
```

If the widget is already installed, its settings page lists the path under
**Terminal** with a copy button, so the plasmoid directory does not have to be
hunted down by hand.

```bash
ai-usage-cli                        # every enabled provider
ai-usage-cli --provider claude,zai  # a subset, ignoring the toggles
ai-usage-cli --compact              # one line, for status bars
watch -n 300 ai-usage-cli           # refresh in place
get-ai-usage --all | ai-usage-cli   # render an envelope you already fetched
```

```
PROVIDER  PLAN          WINDOW             USAGE                NOTE                      RESET
────────────────────────────────────────────────────────────────────────────────────────────────────────
Claude    max           5-hour session     [██░░░░░░░░]  23%    120000 / 500000 tokens    Jul 19, 17:00
Claude    max           7-day window       [██████░░░░]  61%    3000000 / 5000000 tokens  Jul 25, 17:00
────────────────────────────────────────────────────────────────────────────────────────────────────────
Z.AI      pro           5-hour tokens      [██░░░░░░░░]  25%    250 / 1000 tokens         Jul 25, 20:20
Z.AI      pro           Monthly tools      [████░░░░░░]  40%    60 remaining              Jul 25, 21:20
────────────────────────────────────────────────────────────────────────────────────────────────────────
Kimi      Moonshot API  Available balance  $49.59
────────────────────────────────────────────────────────────────────────────────────────────────────────
Copilot   —             —                  Copilot: no token configured
```

Colour follows the same thresholds as the panel indicators (amber from 70%, red
from 90%) and switches off automatically when the output is not a terminal, or
when `NO_COLOR` is set. `--color always|never` overrides that, and `--ascii`
replaces the box drawing for terminals without a UTF-8 locale. Columns that stay
empty — a provider set with no reset times, say — are dropped rather than
printed blank. A provider that cannot report keeps its row and shows the reason,
so a missing key does not look like a service you never enabled.

Without a widget there is no settings page to write the config, so create it
once by hand at `~/.config/ai-usage-widget/hyprland-settings.json` (or under
`$XDG_CONFIG_HOME`; `AI_USAGE_CONFIG` overrides the path). Providers not listed
default to on; credentials go in `keys`, and the `WIDGET_*` environment
variables win over the file if you would rather not store them:

```json
{
  "providers": { "claude": true, "zai": true, "kimi": true, "openai": false },
  "keys": { "zai": "…", "moonshot": "…" }
}
```

Claude needs no key — a local Claude Code login is enough. See
[Supported Services](#supported-services) for what each of the others reads.

### Package as `.plasmoid`

```bash
./pack.sh
# produces ai-usage-widget-<version>.plasmoid
```

---

## How it works

### Shared provider backend

All four frontends — the Plasma widget, the Hyprland/Quickshell shell, the
Windows tray app and the terminal frontend — get every provider value from one
package. The Linux frontends run it through
`package/contents/tools/sh/get-ai-usage`; the Windows app, which has no shell,
calls it in-process.
It owns credential discovery, provider API requests, response parsing, quota
maths, reset timestamps and error/stale state, and returns a versioned,
frontend-neutral JSON model:

```bash
get-ai-usage --provider claude        # one provider (Plasma: active tab + pins)
get-ai-usage --all                    # every enabled provider (Hyprland panel)
```

The backend itself is a standard-library-only Python package,
`package/contents/tools/aiusage`; `get-ai-usage` is a thin bash launcher that
execs into it. Normalization is pure, so `get-ai-usage --normalize` can replay
a recorded provider response offline without touching the network.

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
The Kiro tab needs no API key and works with either Kiro tool:

- **kiro-cli** — kiro-cli stores no usage snapshot, but it keeps its login in `~/.local/share/kiro-cli/data.sqlite3`. The widget opens that store read-only and asks the same `getUsageLimits` endpoint the CLI's own `/usage` screen shows. This live figure wins whenever it answers. The CLI's access token lasts about an hour after kiro-cli last ran and the widget deliberately does not renew it (a second refresher could sign the CLI out), so an expired login reports as such until kiro-cli runs again.
- **Kiro IDE** — the IDE caches its last usage payload in `~/.config/Kiro/User/globalStorage/state.vscdb`, read with no network request. It is the fallback, and the only source on a machine without kiro-cli.

Either way the tab shows the credit breakdown, usage percentage, reset date, overage information and plan tier, and feeds the percentage into the 30-day chart history.

### Mistral AI
The widget validates the configured API key against the Mistral API and lists available models, highlighting the one currently active in vibe CLI. Since Mistral exposes no public billing REST API, cost data is sourced locally from vibe CLI session logs (`~/.vibe/logs/session/*/meta.json`): cumulative spend, session count, total tokens, and the last session title are shown in a stats card. The spend bar is scaled against a $50 soft cap and feeds into a 30-day chart. The key is resolved from widget settings → `$MISTRAL_API_KEY` → `~/.vibe/.env` → `~/.config/mistral/api-key`.

### OpenRouter *(untested)*
The widget fetches credit usage and limit from the OpenRouter API using the configured key. The popup shows USD spent, the credit limit (if any), and the account label. The usage bar reflects spend as a percentage of the limit; if no limit is set the bar stays empty.

### Z.AI
The Z.AI tab calls the Z.AI usage quota endpoint with the configured token. It shows the 5-hour token quota, monthly tools quota, reset countdowns, and model details when the API response includes them. The token is resolved from widget settings → `$ZAI_TOKEN` → `$Z_AI_API_KEY` → `~/.config/zai/token` → `~/.zai/token`.

### GitHub Copilot
The GitHub Copilot tab has a **Usage** and a **Stats** sub-tab.

Usage reads premium request consumption from `GET /copilot_internal/user` — the endpoint the Copilot editor plugins themselves call. It answers any Copilot login, and reports the plan's own entitlement, how much of it is left, the plan name, and the date the allowance actually resets, so neither the quota nor the reset day has to be guessed. If that endpoint does not answer (an account without a Copilot quota), the documented `GET /users/{user}/settings/billing/premium_request/usage` billing endpoint is used instead, scaled against the configured quota (default 300); a fine-grained token needs **Plan: read** permission for it. Personal billing only — usage billed through an organization or enterprise is not shown yet.

The credential is resolved from widget settings → `$GITHUB_TOKEN` / `$GH_TOKEN` → `~/.config/github-copilot/token` → the Copilot plugin login in `apps.json` / `hosts.json` (under `$XDG_CONFIG_HOME/github-copilot`, `~/.config/github-copilot` or `~/.copilot`) → `gh auth token`. So a machine that is already signed in to the Copilot CLI, a JetBrains/Neovim Copilot plugin, or the GitHub CLI needs no token pasted at all. A VS Code Copilot login is still not imported: VS Code keeps its session token in encrypted secret storage rather than a reusable file.

Stats aggregates the Copilot CLI's own history from `~/.copilot/session-store.db` — sessions, messages, tool calls, files touched, repositories, active days, streaks, peak hour, longest session and a messages-per-day sparkline. The CLI records no token counts, models or cost, so those tiles are absent rather than shown as zero.

### DeepSeek
The DeepSeek tab calls `GET https://api.deepseek.com/user/balance` with the configured API key. It shows whether the account has sufficient balance for API calls, the primary total balance, and the granted / topped-up split. The key is resolved from widget settings → `$DEEPSEEK_API_KEY` → `~/.config/deepseek/api-key`.

### Kimi / Moonshot AI
The Kimi tab combines two independent sources; either one is enough.

- **Kimi Code plan** — read with the login the `kimi` CLI stores in `~/.kimi-code/credentials/kimi-code.json` (`$KIMI_CODE_HOME` is honoured), from the same `GET https://api.kimi.com/coding/v1/usages` endpoint its `/usage` panel shows (`$KIMI_CODE_BASE_URL` is honoured). It shows each plan window with its reset countdown — the 5-hour and weekly windows are charted — plus the extra-usage wallet when there is one. A plan that is used up is shown as full rather than as an error. The access token is short-lived and the widget does not refresh it (the CLI rotates the pair itself and a second refresher could sign it out), so run `kimi` once when the tab reports an expired login.
- **Moonshot API balance** — `GET https://api.moonshot.ai/v1/users/me/balance` with the available, voucher and cash balances. The key is resolved from widget settings → `$MOONSHOT_API_KEY` / `$KIMI_API_KEY` → `~/.config/moonshot/api-key`.

### Cursor *(free plan tested; paid plans untested)*
The Cursor tab needs no API key and no Cursor IDE: it uses the login `cursor-agent login` stores in `~/.config/cursor/auth.json`, falling back to the Cursor IDE's own login in its `state.vscdb`. With it, the widget calls the two dashboard RPCs the CLI's `/usage` screen uses (`aiserver.v1.DashboardService/GetCurrentPeriodUsage` and `GetPlanInfo` on `api2.cursor.sh`) and shows the included usage for the billing cycle, how much of it went to Auto/Composer versus hand-picked API models, on-demand spend against its limit, the plan name and the cycle's end. Enterprise seats get no plan block from Cursor — the CLI says the same — and the tab reports that instead of a number. A **Stats** sub-tab mirrors the Usage page of cursor.com/dashboard for the current billing cycle: tokens, the usage value Cursor prices it at, requests, conversations, active days, peak hour, a per-day sparkline and a per-model breakdown, from the same `GetAggregatedUsageEvents` / `GetFilteredUsageEvents` calls the dashboard makes (the request list is capped at 500 per refresh; beyond that the per-day figures cover the newest requests). Cursor is opt-in, so enable it under **Settings → Providers**.

### Cline
The Cline tab is **offline**: it reads the session records the Cline CLI writes to `~/.cline/data/sessions/<id>/<id>.json` and keeps only the provider, model, workspace folder name, start and end time, and the token and cost totals (sub-agents included). Prompts, titles, git remotes and transcripts are never read into the result. **Usage** shows today, the last 7 days and the last 30 days — tokens, sessions, and spend when Cline recorded one; a lifetime token count says little on its own, since a token costs very different amounts from model to model. **Stats** keeps the all-time picture: tokens, spend, sessions, active days, streaks, longest session, peak hour, a per-day sparkline, top workspaces and a per-model breakdown. Cline is opt-in, so enable it under **Settings → Providers**.

### Muse
The Muse tab is **fully offline** — it opens no socket, and a test enforces that against the provider's import graph. It reads what Muse Code writes to disk anyway:

| File | What the tab takes from it |
| --- | --- |
| `~/.local/share/muse/sessions/**/session.jsonl` | sessions, subagents, turns, messages, tool calls, per-call token counters, workspace folder name |
| `~/.local/share/muse/sessions/.msp-view-v1/<id>/snapshot-*.json` | the folded counted-once token totals — the same numbers the TUI's `/usage` prints |
| `~/.local/share/muse/model-catalog/*.json` | every model id, its real context limit, and its price list |
| `~/.config/muse/settings.json` | the model the CLI will use next |
| `~/.config/muse/auth.json` | login presence and display name only; the stored tokens are never read |

Because Meta ships the price list to disk, this is the one tab that can price its own usage offline: tokens × the catalog's rates gives the spend estimate, per model and in total, in the catalog's own currency. Nothing is hardcoded — a new Muse model needs no widget update.

**The plan quota is opt-in, because it is the one number here that costs money.** The Current/Weekly windows in the TUI's `/usage` screen are stored nowhere: they arrive only as a `response.subscription_usage` frame riding a live model call, and are absent from the MSP wire schema, the view fold, `session-index.db` and the feature-config cache. The CLI has no `usage`/`status`/`quota` subcommand either, and the frame is the *last* event on the stream — after generation has been paid for — so the call cannot be cut short. (Running `/usage` in the CLI itself stays free: it re-displays what a call you already made told it.)

So reading it from a widget means one minimal model call per refresh — about 12 input and 120 output tokens, `store: false`, cached 30 minutes. At the contributor tier that is a few cents a year; at standard rates closer to ten dollars. [The provider contract](docs/provider-contract.md) says a statistic must not cost the user, so:

- **Off by default.** Out of the box the tab makes no network call at all — `providers/muse.py` imports no networking module, and a test enforces that against its import graph.
- Turn it on in settings → *Muse Quota* (Hyprland has the same toggle, or `WIDGET_MUSE_QUOTA=1` / `museQuota: true`). Both panels state the cost next to the switch, priced from your own model's catalog rates.
- The billed path lives in a separate module (`providers/muse_quota.py`) so it cannot be reached by accident, and every failure falls back to the free local numbers — saying whether the credential was refused or the endpoint was unreachable, rather than calling a working key invalid.
- `MUSE_QUOTA_TTL_SECONDS` (default 1800) bounds how often it can fire, so a 5-minute poll interval cannot become a per-poll model call.

The tab itself is off by default too: enable *Muse* in settings if you use Muse Code.

### Usage history
Each refresh records the usage values that a provider actually reports into a rolling history of up to 10,000 samples — only when a value moves, plus one sighting an hour, so a flat stretch costs two points rather than one per refresh — used by the chart, spark-lines, burn-rate ETA, and period comparison. Rolling plan windows (Claude, Codex) empty at a known instant, so when the machine was asleep across one the chart replays the drop where it actually happened instead of sloping from the last pre-sleep sample to the first one after wake-up. Most series are percentages; Mistral stores its raw vibe CLI spend and DeepSeek stores its raw balance so their charts retain meaningful units. Existing session and weekly history fields are retained even while a window is unavailable, so five-hour charts can return without migration if providers restore that limit. History lives in `~/.local/share/ai-usage-widget/usage-history-latest.json`, shared by both frontends, so it survives a full uninstall/reinstall; the widget's Plasma config keeps only a recent tail of it as a first-run fallback, because Plasma rewrites every widget's config whole on each change. You can also manually **Export** (copies the shared file to a timestamped snapshot) and **Import** from the settings panel. If a saved file is unreadable or in an unrecognized format, it's discarded and history starts fresh rather than erroring out.

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
access is needed. `tests/ai-usage-cli.test.sh` renders those same fixtures
through the terminal frontend, checking among other things that a provider which
cannot report still gets a row instead of silently vanishing from the table.
`tests/shared-code.test.js` covers the JavaScript both QML frontends share.

`tests/python/` holds the portable suites — plain `unittest`, no shell — that
CI also runs on Windows: platform paths, the shared history file and its lock,
the Codex app-server client against a fake `codex.cmd`, finding Antigravity
through `psutil`, and the tray app loading its QML headless with every settings
section opened once (`make test-py`, or `python windows/app.py --selftest`).

---

## Releasing

```bash
./tag.sh
```

Prompts for a version bump (patch / minor / major), updates `package/metadata.json`, commits, tags, and pushes. CI then builds the `.plasmoid` and creates a GitHub release automatically.
