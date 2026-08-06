"""get-ai-usage — the shared provider backend for every frontend of this widget.

This tool owns credential discovery, provider API requests, response parsing,
quota/percentage maths, reset timestamps and error/stale state. The KDE Plasma
widget and the Hyprland/Quickshell shell both consume its output and do
presentation only; see docs/provider-contract.md for the schema.

  get-ai-usage --provider claude          one provider (KDE's active tab)
  get-ai-usage --provider claude,openai   several providers (active + pinned)
  get-ai-usage --all                      every enabled provider (Hyprland)
  get-ai-usage --normalize < envelope     replay a raw envelope offline (tests)
"""

import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor

from . import config
from .collect import collect
from .contract import SCHEMA_VERSION, finalize
from .normalize import normalize

USAGE = """usage: get-ai-usage [--all | --provider <id>[,<id>...] | --normalize]

  --all                 fetch every provider enabled in the shared settings file
  --provider <ids>      fetch the named providers regardless of the toggles
  --normalize           read one raw envelope on stdin, print the provider object
  --list                print the known provider ids, one per line
  -h, --help            show this help

providers: """ + " ".join(config.ALL_PROVIDERS)


def _emit(obj):
    sys.stdout.write(json.dumps(finalize(obj), separators=(",", ":"), ensure_ascii=False) + "\n")


def main(argv):
    mode = ""
    requested = ""

    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--all":
            mode = "all"
        elif arg == "--provider":
            mode = "provider"
            i += 1
            requested = argv[i] if i < len(argv) else ""
        elif arg.startswith("--provider="):
            mode = "provider"
            requested = arg[len("--provider=") :]
        elif arg == "--normalize":
            mode = "normalize"
        elif arg == "--list":
            for p in config.ALL_PROVIDERS:
                print(p)
            return 0
        elif arg in ("-h", "--help"):
            print(USAGE)
            return 0
        else:
            sys.stderr.write(f"get-ai-usage: unknown argument: {arg}\n")
            sys.stderr.write(USAGE + "\n")
            return 2
        i += 1

    cfg = config.load_settings()
    config.apply_widget_env(cfg)

    if mode == "normalize":
        try:
            envelope = json.load(sys.stdin)
        except ValueError as e:
            sys.stderr.write(f"get-ai-usage: invalid envelope on stdin: {e}\n")
            return 2
        _emit(normalize(envelope))
        return 0

    if not mode:
        mode = "all"

    if mode == "provider":
        if not requested:
            sys.stderr.write("get-ai-usage: --provider needs at least one id\n")
            return 2
        selected = []
        for id_ in requested.split(","):
            if id_ not in config.ALL_PROVIDERS:
                sys.stderr.write(f"get-ai-usage: unknown provider: {id_}\n")
                return 2
            selected.append(id_)
    else:
        selected = [id_ for id_ in config.ALL_PROVIDERS if config.provider_enabled(cfg, id_)]

    now = time.time()

    def fetch_one(id_):
        return normalize(collect(id_, now))

    if selected:
        with ThreadPoolExecutor(max_workers=len(selected)) as pool:
            providers = list(pool.map(fetch_one, selected))
    else:
        providers = []

    active = ""
    for p in providers:
        if p.get("ok") is True:
            active = p.get("id") or ""
            break
    else:
        if providers:
            active = providers[0].get("id") or ""

    _emit({"schemaVersion": SCHEMA_VERSION, "updatedAt": int(now), "active": active, "providers": providers})
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
