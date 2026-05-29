#!/usr/bin/env bash
# get_antigravity_usage.sh - Runs the antigravity-usage CLI or falls back to querying the local server directly

# 1. Try to use CLI if available
CLI=""
if command -v aiu >/dev/null 2>&1; then
    CLI="aiu"
elif command -v antigravity-usage >/dev/null 2>&1; then
    CLI="antigravity-usage"
fi

if [ -n "$CLI" ]; then
    JSON_OUTPUT=$($CLI --json 2>&1)
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        echo "$JSON_OUTPUT"
        exit 0
    fi
fi

# 2. Native bash/curl/jq fallback
get_ports_for_pid() {
    local pid=$1
    local ports=()
    
    # Try ss
    if command -v ss >/dev/null 2>&1; then
        local ss_out
        ss_out=$(ss -tlnp 2>/dev/null | grep "pid=${pid},")
        if [ -n "$ss_out" ]; then
            while read -r line; do
                if [[ "$line" =~ :([0-9]+)[[:space:]] ]]; then
                    ports+=("${BASH_REMATCH[1]}")
                fi
            done <<< "$ss_out"
        fi
    fi
    
    # Try netstat
    if [ ${#ports[@]} -eq 0 ] && command -v netstat >/dev/null 2>&1; then
        local ns_out
        ns_out=$(netstat -tlnp 2>/dev/null | grep "${pid}/")
        if [ -n "$ns_out" ]; then
            while read -r line; do
                if [[ "$line" =~ :([0-9]+)[[:space:]] ]]; then
                    ports+=("${BASH_REMATCH[1]}")
                fi
            done <<< "$ns_out"
        fi
    fi
    
    # Print ports uniquely
    if [ ${#ports[@]} -gt 0 ]; then
        echo "${ports[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '
    fi
}

probe_port() {
    local port=$1
    local token=$2
    
    # Try HTTPS (with -k for self-signed certificates, and max-time 1)
    local http_code
    http_code=$(curl -k -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Connect-Protocol-Version: 1" \
        -H "X-Codeium-Csrf-Token: $token" \
        -d '{"wrapper_data": {}}' \
        --max-time 1 \
        https://127.0.0.1:$port/exa.language_server_pb.LanguageServerService/GetUnleashData 2>/dev/null)
        
    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        echo "https"
        return 0
    fi
    
    # Try HTTP (with max-time 1)
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -H "Connect-Protocol-Version: 1" \
        -H "X-Codeium-Csrf-Token: $token" \
        -d '{"wrapper_data": {}}' \
        --max-time 1 \
        http://127.0.0.1:$port/exa.language_server_pb.LanguageServerService/GetUnleashData 2>/dev/null)
        
    if [ "$http_code" = "200" ] || [ "$http_code" = "401" ]; then
        echo "http"
        return 0
    fi
    
    return 1
}

# Scan for processes
found_any_process=false
for cmdline_file in /proc/[0-9]*/cmdline; do
    [ -f "$cmdline_file" ] || continue
    cmdline=$(tr '\0' ' ' < "$cmdline_file" 2>/dev/null)
    if [[ "$cmdline" == *antigravity* ]] && [[ "$cmdline" == *--csrf_token* ]]; then
        pid=$(basename "$(dirname "$cmdline_file")")
        
        # Extract CSRF token and extension server port
        csrf_token=""
        ext_port=""
        while IFS= read -r -d '' arg; do
            if [[ "$arg" == "--csrf_token" ]]; then
                IFS= read -r -d '' csrf_token
            elif [[ "$arg" == --csrf_token=* ]]; then
                csrf_token="${arg#--csrf_token=}"
            elif [[ "$arg" == "--extension_server_port" ]]; then
                IFS= read -r -d '' ext_port
            elif [[ "$arg" == --extension_server_port=* ]]; then
                ext_port="${arg#--extension_server_port=}"
            fi
        done < "$cmdline_file"
        
        [ -n "$csrf_token" ] || continue
        found_any_process=true
        
        # Get ports for PID
        ports_str=$(get_ports_for_pid "$pid")
        read -r -a ports <<< "$ports_str"
        
        # Fallback to extension server port if no ports found
        if [ ${#ports[@]} -eq 0 ] && [ -n "$ext_port" ]; then
            ports=("$ext_port")
        fi
        
        # Probe each port
        for port in "${ports[@]}"; do
            proto=$(probe_port "$port" "$csrf_token")
            if [ $? -eq 0 ]; then
                # Found a working port! Call GetUserStatus and format with jq
                user_status_json=$(curl -k -s -X POST \
                    -H "Content-Type: application/json" \
                    -H "Connect-Protocol-Version: 1" \
                    -H "X-Codeium-Csrf-Token: $csrf_token" \
                    -d '{"metadata": {"ideName": "antigravity", "extensionName": "antigravity", "locale": "en"}}' \
                    --max-time 2 \
                    "${proto}://127.0.0.1:${port}/exa.language_server_pb.LanguageServerService/GetUserStatus" 2>/dev/null)
                
                if [ -n "$user_status_json" ] && ! echo "$user_status_json" | grep -q "error"; then
                    formatted_json=$(echo "$user_status_json" | jq '.userStatus as $us | ($us.planStatus // {}) as $ps | ($us.cascadeModelConfigData.clientModelConfigs // []) as $configs | { timestamp: (now | strflocaltime("%Y-%m-%dT%H:%M:%S.000Z")), method: "local", email: $us.email, planType: (if $us.userTier.name then $us.userTier.name else null end), promptCredits: (if $ps.availablePromptCredits != null and $ps.planInfo.monthlyPromptCredits != null and $ps.planInfo.monthlyPromptCredits > 0 then { available: $ps.availablePromptCredits, monthly: $ps.planInfo.monthlyPromptCredits, usedPercentage: (($ps.planInfo.monthlyPromptCredits - $ps.availablePromptCredits) / $ps.planInfo.monthlyPromptCredits), remainingPercentage: ($ps.availablePromptCredits / $ps.planInfo.monthlyPromptCredits) } else null end), models: [ $configs[] | { label: (.label // .modelOrAlias.model), modelId: (.modelOrAlias.model // "unknown"), remainingPercentage: .quotaInfo.remainingFraction, isExhausted: (.quotaInfo.remainingFraction == 0), resetTime: .quotaInfo.resetTime, isAutocompleteOnly: (((.modelOrAlias.model // "") | contains("gemini-2.5")) or ((.label // "") | contains("Gemini 2.5"))) } ] }' 2>/dev/null)
                    
                    if [ -n "$formatted_json" ]; then
                        echo "$formatted_json"
                        exit 0
                    fi
                fi
            fi
        done
    fi
done

if [ "$found_any_process" = true ]; then
    echo '{"error":"Antigravity language server found but could not connect to API"}'
else
    echo '{"error":"Antigravity is not running. Please open your IDE."}'
fi
exit 1
