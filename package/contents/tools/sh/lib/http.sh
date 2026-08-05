# Shared credential + HTTP plumbing for the get-* provider helpers.
#
# Every helper needs the same four things: locate a credential, call one JSON
# endpoint, turn a status code into an error document, and stay replayable from
# a fixture file so the tests never touch the network. Keeping them here means a
# fix lands once instead of once per provider.
#
# Source it from a helper:
#   . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/http.sh"

# Result of the last http_json call. These are globals rather than stdout
# because a status code and a body cannot both come back through a command
# substitution — the substitution runs in a subshell, so anything the function
# assigns there is thrown away.
HTTP_STATUS=""
HTTP_BODY=""

# Bail out with a well-formed document when jq is missing, so callers never have
# to guard every jq invocation. jq is a hard requirement of every helper.
require_jq() {
    command -v jq >/dev/null 2>&1 && return 0
    printf '%s\n' '{"hasKey":false,"keyValid":false,"error":"jq is required"}'
    exit 0
}

# resolve_key WIDGET_VAR ENV_VAR [FILE...]
#
# Credential precedence, identical for every provider: the value the widget
# passed in, then a conventional environment variable, then the first readable
# config file. Prints the empty string when nothing is configured.
resolve_key() {
    local widget_var="$1" env_var="$2" value file
    shift 2
    value="${!widget_var:-}"
    [ -z "$value" ] && [ -n "$env_var" ] && value="${!env_var:-}"
    if [ -z "$value" ] && [ -n "${HOME:-}" ]; then
        for file in "$@"; do
            [ -f "$file" ] || continue
            value="$(tr -d '\n\r ' <"$file" 2>/dev/null)"
            [ -n "$value" ] && break
        done
    fi
    printf '%s' "$value"
}

# http_json FIXTURE_VAR URL [curl args...]
#
# Sets HTTP_BODY and HTTP_STATUS. Call it directly, never inside $( ) — see the
# note on the globals above. Pass "" as FIXTURE_VAR when there is no fixture
# hook; otherwise, when that variable names an existing file, the file is
# replayed as a 200, which is how the tests exercise the real helpers offline.
http_json() {
    local fixture_var="$1" url="$2" response
    shift 2
    if [ -n "$fixture_var" ] && [ -n "${!fixture_var:-}" ] && [ -f "${!fixture_var}" ]; then
        HTTP_STATUS=200
        HTTP_BODY="$(cat "${!fixture_var}")"
        return 0
    fi
    response="$(curl -s -w $'\n%{http_code}' --max-time "${HTTP_TIMEOUT:-10}" "$@" "$url" 2>/dev/null)"
    HTTP_STATUS="${response##*$'\n'}"
    HTTP_BODY="${response%$'\n'*}"
}

# error_json MESSAGE — the shape every helper returns on failure.
error_json() {
    jq -n --arg error "$1" '{hasKey: false, keyValid: false, error: $error}'
}

# http_error_json LABEL STATUS [AUTH_MESSAGE]
#
# Maps a status code onto the usual wording. Providers with a more specific
# authentication message than "Invalid <label> credential" pass it as the third
# argument.
http_error_json() {
    case "$2" in
        401 | 403) error_json "${3:-Invalid $1 credential}" ;;
        000 | '') error_json "$1 network error" ;;
        *) error_json "$1 HTTP $2" ;;
    esac
}
