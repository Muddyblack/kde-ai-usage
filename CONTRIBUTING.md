# Contributing

## Development install

```bash
./test_install.sh
```

Installs as `AI Usage (Test)` alongside the real widget so you can iterate
without touching your live install.

To remove the test copy:

```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.aiUsageWidgetTest
```

Preview the widget without installing it at all:

```bash
make view      # planar
make view-h    # horizontal
```

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

Linting the Python backend and tray app needs `ruff`:

```bash
make lint-py
```

## Adding or changing a provider

The backend owns all provider logic and hands the frontends a versioned JSON
model. Read [`docs/provider-contract.md`](docs/provider-contract.md) first — it
documents the schema, the invariants the contract tests enforce, and the rule
that a statistic must not cost the user money to read.

Per-provider specifics (credential resolution, endpoints, API quirks) are
described in [`docs/providers.md`](docs/providers.md).

## Packaging

```bash
./pack.sh
# produces ai-usage-widget-<version>.plasmoid
```

## Releasing

```bash
./tag.sh
```

Prompts for a version bump (patch / minor / major), updates
`package/metadata.json`, commits, tags, and pushes. CI then builds the
`.plasmoid` and creates a GitHub release automatically.
