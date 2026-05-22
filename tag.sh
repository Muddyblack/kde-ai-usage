#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
METADATA_FILE="$HERE/package/metadata.json"

if [ ! -f "$METADATA_FILE" ]; then
    echo "Error: metadata.json not found!" >&2
    exit 1
fi

cd "$HERE"

# ── version bump ─────────────────────────────────────────────────────────────
CURRENT_VERSION="$(grep -oE '"Version":[[:space:]]*"[^"]+"' "$METADATA_FILE" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"

NUMERIC="${CURRENT_VERSION%%-*}"
if [[ "$CURRENT_VERSION" == *-* ]]; then
    CURRENT_SUFFIX="-${CURRENT_VERSION#*-}"
else
    CURRENT_SUFFIX=""
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$NUMERIC"

echo "Current version: ${CURRENT_VERSION}"
echo ""
echo "Bump type:"
echo "  [p] patch  → ${MAJOR}.${MINOR}.$((PATCH + 1))${CURRENT_SUFFIX}"
echo "  [m] minor  → ${MAJOR}.$((MINOR + 1)).0${CURRENT_SUFFIX}"
echo "  [M] major  → $((MAJOR + 1)).0.0${CURRENT_SUFFIX}"
echo "  [k] keep   → ${CURRENT_VERSION}"
read -rp "Choice [p/m/M/k]: " bump_choice

case "$bump_choice" in
    m) NEW_NUMERIC="${MAJOR}.$((MINOR + 1)).0" ;;
    M) NEW_NUMERIC="$((MAJOR + 1)).0.0" ;;
    k) NEW_NUMERIC="$NUMERIC" ;;
    *) NEW_NUMERIC="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
esac

if [[ -n "$CURRENT_SUFFIX" ]]; then
    echo ""
    read -rp "Keep beta suffix? [Y/n]: " keep_suffix
    if [[ "$keep_suffix" =~ ^[Nn]$ ]]; then
        NEW_SUFFIX=""
    else
        NEW_SUFFIX="$CURRENT_SUFFIX"
    fi
else
    echo ""
    read -rp "Add beta suffix? [y/N]: " add_suffix
    if [[ "$add_suffix" =~ ^[Yy]$ ]]; then
        NEW_SUFFIX="-beta"
    else
        NEW_SUFFIX=""
    fi
fi

NEW_VERSION="${NEW_NUMERIC}${NEW_SUFFIX}"
TAG_NAME="v${NEW_VERSION}"

echo ""
echo "New version: ${NEW_VERSION}"
read -rp "Confirm? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo "Aborting."
    exit 0
fi

sed -i "s/\"Version\": \"${CURRENT_VERSION}\"/\"Version\": \"${NEW_VERSION}\"/" "$METADATA_FILE"
echo "Updated metadata.json → ${NEW_VERSION}"

# ── commit, tag, push ─────────────────────────────────────────────────────────
if ! git diff-index --quiet HEAD --; then
    echo ""
    read -rp "Commit message (default: 'chore: release ${TAG_NAME}'): " commit_msg
    if [ -z "$commit_msg" ]; then
        commit_msg="chore: release ${TAG_NAME}"
    fi
    git add .
    git commit -m "$commit_msg"
fi

if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "Warning: Tag ${TAG_NAME} already exists."
    read -rp "Overwrite? [y/N]: " recreate_tag
    if [[ "$recreate_tag" =~ ^[Yy]$ ]]; then
        git tag -d "$TAG_NAME"
        git push origin --delete "$TAG_NAME" || true
    else
        echo "Aborting."
        exit 0
    fi
fi

echo "Creating tag ${TAG_NAME}..."
git tag -a "$TAG_NAME" -m "Release ${TAG_NAME}"

CURRENT_BRANCH="$(git branch --show-current)"
echo "Pushing branch '${CURRENT_BRANCH}' and tag '${TAG_NAME}' to remote..."
git push origin "$CURRENT_BRANCH"
git push origin "$TAG_NAME"

echo ""
echo "=== Tagged ${TAG_NAME} and pushed. CI will build the .plasmoid and create the GitHub release. ==="
