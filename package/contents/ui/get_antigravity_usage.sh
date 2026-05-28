#!/usr/bin/env bash
# get_antigravity_usage.sh - Runs the antigravity-usage CLI and returns JSON

# Try to find aiu or antigravity-usage in path, or run locally from temp_repos
CLI=""
if command -v aiu >/dev/null 2>&1; then
    CLI="aiu"
elif command -v antigravity-usage >/dev/null 2>&1; then
    CLI="antigravity-usage"
elif [ -f "/mnt/projects/KDE-PLASMA/ai-usage-widget/temp_repos/antigravity-usage/dist/index.js" ]; then
    # Fallback to Node running the local repo build
    if command -v node >/dev/null 2>&1; then
        CLI="node /mnt/projects/KDE-PLASMA/ai-usage-widget/temp_repos/antigravity-usage/dist/index.js"
    elif [ -x "/run/current-system/sw/bin/nix-shell" ]; then
        CLI="/run/current-system/sw/bin/nix-shell -p nodejs --run \"node /mnt/projects/KDE-PLASMA/ai-usage-widget/temp_repos/antigravity-usage/dist/index.js\""
    fi
fi

if [ -z "$CLI" ]; then
    echo '{"error":"antigravity-usage CLI not found"}'
    exit 1
fi

# Run the CLI with --json and output the result.
# Set a timeout so we don't hang if local connection or port probing hangs.
if [[ "$CLI" == *"nix-shell"* ]]; then
    # For nix-shell, we need to pass `--json` inside the --run command
    JSON_OUTPUT=$(/run/current-system/sw/bin/nix-shell -p nodejs --run "node /mnt/projects/KDE-PLASMA/ai-usage-widget/temp_repos/antigravity-usage/dist/index.js --json" 2>&1)
    EXIT_CODE=$?
else
    JSON_OUTPUT=$($CLI --json 2>&1)
    EXIT_CODE=$?
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "$JSON_OUTPUT"
else
    # Extract the error message and put it into JSON format
    # Strip ANSI escape codes
    CLEAN_ERR=$(echo "$JSON_OUTPUT" | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | tr '\n' ' ' | sed 's/"/\\"/g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "{\"error\":\"$CLEAN_ERR\"}"
fi
