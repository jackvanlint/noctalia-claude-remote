#!/bin/sh
# Spawns a detached claude remote-control daemon and prints JSON status.
# Usage: start-session.sh ["Session name"] ["claude binary path"] ["workspace dir"]
# Sets CLAUDE_REMOTE_SESSION=1 so the auto-title Stop hook activates.
# If workspace dir is given (and non-empty), cd into it first — this is
# required for `claude remote-control` to start outside an untrusted dir.
NAME="${1:-Remote Session: $(date +'%H:%M')}"
CLAUDE="${2:-claude}"
WORKSPACE="${3:-}"

if [ -n "$WORKSPACE" ]; then
    case "$WORKSPACE" in
        "~") WORKSPACE="$HOME" ;;
        "~/"*) WORKSPACE="$HOME/${WORKSPACE#"~/"}" ;;
    esac
    if ! cd "$WORKSPACE"; then
        printf '{"ok":false,"error":"workspace directory not found"}\n'
        exit 1
    fi
fi

nohup env CLAUDE_REMOTE_SESSION=1 \
    "$CLAUDE" remote-control --name "$NAME" \
    >/dev/null 2>&1 &
pid=$!

sleep 0.5
if ! kill -0 "$pid" 2>/dev/null; then
    printf '{"ok":false,"error":"remote-control exited during startup"}\n'
    exit 1
fi

start_time=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || true)
cmdline=$(tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)

case "$start_time:$cmdline" in
    [0-9]*:*remote-control*)
        printf '{"ok":true,"pid":%s,"start_time":"%s"}\n' "$pid" "$start_time"
        ;;
    *)
        printf '{"ok":false,"error":"remote-control did not stay ready"}\n'
        exit 1
        ;;
esac
