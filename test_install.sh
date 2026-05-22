#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
METADATA="$HERE/package/metadata.json"
TOOL=/run/current-system/sw/bin/kpackagetool6

if [ ! -x "$TOOL" ]; then
    echo "kpackagetool6 not found at $TOOL" >&2
    exit 1
fi

ID="$(grep -oE '"Id":[[:space:]]*"[^"]+"' "$METADATA" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
NAME="$(grep -oE '"Name":[[:space:]]*"[^"]+"' "$METADATA" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
TEST_ID="${ID}Test"
TEMP_DIR="/tmp/$(basename "$HERE")-test"

rm -rf "$TEMP_DIR"
cp -r "$HERE/package" "$TEMP_DIR"

sed -i "s/$ID/$TEST_ID/g" "$TEMP_DIR/metadata.json"
sed -i "s/\"Name\": \"$NAME\"/\"Name\": \"$NAME (Test)\"/g" "$TEMP_DIR/metadata.json"

ICON_SRC="$(find "$TEMP_DIR/contents/icons" -name "${ID}.svg" | head -1)"
ICON_DST="$(dirname "$ICON_SRC")/${TEST_ID}.svg"
mv "$ICON_SRC" "$ICON_DST"
sed -i "s/${ID}/${TEST_ID}/g" "$TEMP_DIR/contents/ui/main.qml"

ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$ICON_DIR"
cp "$ICON_DST" "$ICON_DIR/$TEST_ID.svg"

echo "Installing test version of the widget..."
if "$TOOL" -t Plasma/Applet -l 2>/dev/null | grep -q "$TEST_ID"; then
    "$TOOL" -t Plasma/Applet -u "$TEMP_DIR" 2>/dev/null
    echo "Updated existing test install."
else
    "$TOOL" -t Plasma/Applet -i "$TEMP_DIR" 2>/dev/null
    echo "Installed fresh test widget."
fi

echo ""
echo "=== Test Widget Installed! ==="
echo "Add '$NAME (Test)' to your desktop/panel, or restart plasmashell if already added:"
echo "  plasmashell --replace &"
echo ""
echo "To remove the test version:"
echo "  $TOOL -t Plasma/Applet -r $TEST_ID"
echo "  rm -f $ICON_DIR/$TEST_ID.svg"
