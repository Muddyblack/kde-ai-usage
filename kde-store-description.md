# AI Usage Monitor

I got tired of opening a different website or CLI tool every time I wanted to check how much quota I had left. So I built this: a little panel widget that puts every AI service I use right where I can see it — no tabs, no terminal, just a glance.

**One glance at your panel tells you exactly how much you've got left.**

---

### What it tracks

Switch between tabs in the popup for each service:

- **Claude** — 5-hour session + 7-day weekly windows
- **Antigravity / Google AI Studio**
- **OpenAI API**
- **Mistral AI**
- **OpenRouter**

### Why I like using it

- 📊 **Burn-rate ETA** — tells you *"↗ ~3h to 100%"* so you can pace yourself instead of getting surprised
- ⏱️ **Countdown timers** — ticks down to your next quota reset (refreshes every ~5 min to stay friendly to the APIs)
- 📈 **Usage chart** — a smooth, glowing trend graph with 5H / 24H / 7D toggle and hover-scrub (24H shows the whole day's session burn as a sawtooth)
- 📉 **Period comparison** — *"+12% vs last week"* at the same point in the cycle
- 🎨 **Theme-aware** — follows your Plasma accent by default, or flip on per-service brand colors
- 🫧 **Glassmorphism popup** — translucent, blurred, and honestly just nice to look at
- 📌 **Pin a service** — open straight to your most-used tab

### Panel modes

Compact percentage readouts right in the taskbar — color-coded (amber at 70%, red at 90%) with an inline spark-line trend. Pill or compact mode, your call.

---

### Setup

Reads your credentials from local config files — nothing leaves your machine except the calls to each provider's own usage API. Refresh interval is configurable (1–30 min, default 5).

**Requires Plasma 6.0+.**

---

🐙 Source, setup details & issues → [github.com/Muddyblack/kde-ai-usage](https://github.com/Muddyblack/kde-ai-usage)

Built by **muddyblack** • MIT licensed

*(Yeah, I know yet another AI usage widget, but I wanted one for my own NixOS setup that just worked the way I needed it to. If you're in the same boat, here it is.)* 💙
