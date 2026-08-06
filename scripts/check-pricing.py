#!/usr/bin/env python3
"""Dev-only: report drift between the shipped pricing tables and the providers'
live pricing pages.

This is NOT part of the widget. The backend never fetches pricing at runtime —
there is no pricing API, only human-facing documentation pages, and a silent
mis-parse would show users a confident wrong dollar figure. An unpriced model
(`priced: false`) is the honest failure mode, so the tables stay static and a
maintainer runs this before a release to see what changed.

    make check-pricing                     # fetch both pages and diff
    scripts/check-pricing.py --from-file anthropic=/tmp/a.html openai=/tmp/o.html

Exit status: 0 = no drift, 1 = drift found, 2 = extraction looks broken
(page redesigned, parser needs updating) or fetch failed.

Extraction is deliberately tolerant: strip markup, then find rows that pair a
model label with two dollar amounts. Both pages list standard pricing first and
discounted variants (batch, flex, fast mode) after, so the FIRST price seen for
a model wins.
"""

import argparse
import html
import re
import sys
import urllib.error
import urllib.request

sys.path.insert(0, __file__.rsplit("/", 2)[0] + "/package/contents/tools")

from aiusage.billing import CLAUDE_PRICING, OPENAI_PRICING  # noqa: E402

SOURCES = {
    "anthropic": ("https://platform.claude.com/docs/en/about-claude/pricing", CLAUDE_PRICING),
    "openai": ("https://developers.openai.com/api/docs/pricing", OPENAI_PRICING),
}

# Below this many extracted models, assume the page changed shape rather than
# reporting a page full of "removed" models.
MIN_PLAUSIBLE_MODELS = 5

_TAG_RE = re.compile(r"<[^>]+>")
_MONEY_RE = re.compile(r"\$\s*(\d+(?:\.\d+)?)")
_ANTHROPIC_LABEL_RE = re.compile(r"\bClaude\s+([A-Za-z]+(?:\s+[\d.]+|\s+\d)?)", re.I)
_OPENAI_ID_RE = re.compile(r"\b((?:gpt|o|chat|text-embedding|davinci|babbage)[a-z0-9.\-]*)\b", re.I)


def strip_markup(text):
    return html.unescape(_TAG_RE.sub(" ", text))


def anthropic_slug(label):
    """ "Claude Opus 4.5" -> "claude-opus-4-5", matching the API model IDs."""
    return "claude-" + re.sub(r"[\s.]+", "-", label.strip().lower())


def extract(provider, text):
    """-> {model_id: (input_price, output_price)}, first occurrence wins."""
    found = {}
    for line in strip_markup(text).splitlines():
        prices = _MONEY_RE.findall(line)
        if len(prices) < 2:
            continue
        if provider == "anthropic":
            m = _ANTHROPIC_LABEL_RE.search(line)
            if not m:
                continue
            key = anthropic_slug(m.group(1))
            # Row shape: base input | 5m write | 1h write | cache hit | output.
            # First and last money values are the two we bill on.
            in_p, out_p = float(prices[0]), float(prices[-1])
        else:
            m = _OPENAI_ID_RE.search(line)
            if not m or len(m.group(1)) < 2:
                continue
            key = m.group(1).lower()
            in_p, out_p = float(prices[0]), float(prices[1])
        found.setdefault(key, (in_p, out_p))
    return found


def compare(found, table):
    """-> (changed, missing, unlisted) against the shipped table."""
    changed, missing = [], []
    for key, (in_p, out_p) in sorted(found.items()):
        have = table.get(key)
        if have is None:
            missing.append((key, in_p, out_p))
        elif (float(have["input"]), float(have["output"])) != (in_p, out_p):
            changed.append((key, (have["input"], have["output"]), (in_p, out_p)))
    unlisted = sorted(k for k in table if k not in found)
    return changed, missing, unlisted


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (ai-usage-widget pricing check)"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8", "replace")


def report(provider, found, table):
    changed, missing, unlisted = compare(found, table)
    print(f"\n=== {provider}: {len(found)} models parsed from page, {len(table)} in table")

    if changed:
        print("  PRICE CHANGED (table is wrong):")
        for key, (old_in, old_out), (new_in, new_out) in changed:
            print(f"    {key}: ${old_in}/${old_out} -> ${new_in}/${new_out}")
    if missing:
        print("  ON PAGE, NOT IN TABLE (usage of these bills as unpriced):")
        for key, in_p, out_p in missing:
            print(f'    "{key}": {{"input": {in_p:g}, "output": {out_p:g}}},')
    if unlisted:
        print("  IN TABLE, NOT ON PAGE (retired, or the label/ID changed — keep for old usage data):")
        print("    " + ", ".join(unlisted))
    if not (changed or missing):
        print("  no drift")
    return bool(changed or missing)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument(
        "--from-file",
        nargs="*",
        default=[],
        metavar="PROVIDER=PATH",
        help="parse a saved page dump instead of fetching (offline testing)",
    )
    args = ap.parse_args(argv)

    overrides = dict(pair.split("=", 1) for pair in args.from_file)
    drift = False

    for provider, (url, table) in SOURCES.items():
        if provider in overrides:
            with open(overrides[provider], errors="replace") as f:
                text = f.read()
        else:
            try:
                text = fetch(url)
            except (urllib.error.URLError, OSError, TimeoutError) as e:
                print(f"=== {provider}: FETCH FAILED ({type(e).__name__}: {e})", file=sys.stderr)
                print(f"    {url}", file=sys.stderr)
                return 2

        found = extract(provider, text)
        if len(found) < MIN_PLAUSIBLE_MODELS:
            print(
                f"=== {provider}: only {len(found)} models extracted — the page layout probably\n"
                f"    changed. Update the parser in {__file__}; do NOT trust this run.\n"
                f"    {url}",
                file=sys.stderr,
            )
            return 2
        drift |= report(provider, found, table)

    if drift:
        print("\nPricing drift found. Update package/contents/tools/aiusage/billing.py by hand,")
        print("then re-run. Prices are only ever changed by a human reading the page.")
        return 1
    print("\nAll pricing tables match the live pages.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
