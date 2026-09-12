#!/usr/bin/env bash
#
# Compile translate/<lang>.po into the binary catalogs the plasmoid loads at
# runtime: package/contents/locale/<lang>/LC_MESSAGES/plasma_applet_<Id>.mo.
#
# The .mo files are committed because the widget is distributed as a plain
# KPackage archive — there is no build step on the user's machine to run
# msgfmt for them.
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$dir")"
pkg="$root/package"

id="$(grep -oE '"Id"[[:space:]]*:[[:space:]]*"[^"]+"' "$pkg/metadata.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
domain="plasma_applet_$id"

shopt -s nullglob
for po in "$dir"/*.po; do
    lang="$(basename "$po" .po)"
    outdir="$pkg/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$outdir"
    msgfmt --check-format --output-file="$outdir/$domain.mo" "$po"
    echo "[i18n] $lang -> ${outdir#"$root"/}/$domain.mo"
done
shopt -u nullglob
