#!/bin/sh
# Spawns a detached claude remote-control daemon and prints its PID.
# Usage: start-session.sh ["Session name"]
# Sets CLAUDE_REMOTE_SESSION=1 so the auto-title Stop hook activates in sessions.
NAME="${1:-Remote Session: $(date +'%H:%M')}"
nohup env CLAUDE_REMOTE_SESSION=1 \
    /home/jack/.local/bin/claude remote-control --name "$NAME" \
    >/dev/null 2>&1 &
echo $!
