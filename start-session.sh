#!/bin/sh
# Spawns a detached claude remote-control daemon and prints its PID.
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
    cd "$WORKSPACE" || exit 1
fi

nohup env CLAUDE_REMOTE_SESSION=1 \
    "$CLAUDE" remote-control --name "$NAME" \
    >/dev/null 2>&1 &
echo $!
