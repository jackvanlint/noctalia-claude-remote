#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
info() { echo -e "  $*"; }

PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins/claude-remote"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

echo ""
echo -e "${BOLD}Claude Remote — Noctalia Plugin Uninstaller${NC}"
echo "──────────────────────────────────────────────"
echo ""

# ── Confirm ─────────────────────────────────────────────────────────────────

info "This will:"
info "  • Remove $PLUGIN_DIR"
info "  • Deregister the auto-title Stop hook from $CLAUDE_SETTINGS"
info "  • Leave any running 'claude remote-control' daemons alone (stop them from the panel first if desired)"
echo ""

if [[ "${1:-}" != "--yes" && "${1:-}" != "-y" ]]; then
    read -r -p "Continue? [y/N] " reply
    case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) info "Aborted."; exit 0 ;;
    esac
fi

# ── Warn about running daemons ──────────────────────────────────────────────

if command -v pgrep &>/dev/null; then
    daemon_count=$(pgrep -fc "claude remote-control" 2>/dev/null || echo 0)
    if [[ "$daemon_count" -gt 0 ]]; then
        warn "$daemon_count 'claude remote-control' process(es) still running"
        info "These were not killed automatically. To stop them: pkill -f 'claude remote-control'"
    fi
fi

# ── Deregister Stop hook ────────────────────────────────────────────────────

if [[ -f "$CLAUDE_SETTINGS" ]]; then
    hook_result="$(python3 - "$PLUGIN_DIR" "$CLAUDE_SETTINGS" <<'PYEOF'
import json, os, pathlib, sys

plugin_dir = sys.argv[1]
settings_file = pathlib.Path(sys.argv[2])

try:
    with open(settings_file) as f:
        settings = json.load(f)
    if not isinstance(settings, dict):
        print("INVALID")
        sys.exit(0)
except Exception:
    print("INVALID")
    sys.exit(0)

hooks = settings.get("hooks", {})
stop_hooks = hooks.get("Stop", [])
removed = 0
new_stop = []

for entry in stop_hooks:
    inner = entry.get("hooks", [])
    kept = []
    for h in inner:
        cmd = h.get("command", "")
        # Only remove this plugin's hook. Other tools may also use auto-title.py.
        if cmd == os.path.join(plugin_dir, "auto-title.py"):
            removed += 1
            continue
        kept.append(h)
    if kept:
        entry["hooks"] = kept
        new_stop.append(entry)

if removed == 0:
    print("NONE")
    sys.exit(0)

if new_stop:
    hooks["Stop"] = new_stop
else:
    hooks.pop("Stop", None)

if not hooks:
    settings.pop("hooks", None)
else:
    settings["hooks"] = hooks

tmp = settings_file.with_suffix(".tmp")
with open(tmp, "w") as f:
    json.dump(settings, f, indent=2)
os.replace(tmp, settings_file)
print(f"REMOVED:{removed}")
PYEOF
)"

    case "$hook_result" in
        NONE)       ok "No auto-title hook found in $CLAUDE_SETTINGS" ;;
        REMOVED:*)  ok "Removed ${hook_result#REMOVED:} auto-title hook entry/entries from $CLAUDE_SETTINGS" ;;
        INVALID)    warn "$CLAUDE_SETTINGS is not valid JSON — left untouched" ;;
        *)          warn "Unexpected deregister result: $hook_result" ;;
    esac
else
    info "No $CLAUDE_SETTINGS — nothing to deregister"
fi

# ── Remove plugin dir ───────────────────────────────────────────────────────

if [[ -d "$PLUGIN_DIR" ]]; then
    # Preserve favouriteSkills + custom paths the user may want back
    if [[ -f "$PLUGIN_DIR/settings.json" ]]; then
        backup="$PLUGIN_DIR.settings.bak.$(date +%s)"
        cp "$PLUGIN_DIR/settings.json" "$backup"
        info "Backed up plugin settings to $backup"
    fi
    rm -rf "$PLUGIN_DIR"
    ok "Removed $PLUGIN_DIR"
else
    info "Plugin directory $PLUGIN_DIR not found — nothing to remove"
fi

echo ""
echo -e "${GREEN}${BOLD}Done.${NC} Reload Noctalia for the plugin to disappear from the bar."
echo ""
