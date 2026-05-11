#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
err()  { echo -e "${RED}✗${NC} $*"; exit 1; }
info() { echo -e "  $*"; }

PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins/claude-remote"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

PLUGIN_FILES=(
    auto-title.py
    BarWidget.qml
    Main.qml
    manifest.json
    Panel.qml
    README.md
    Settings.qml
    start-session.sh
    uninstall.sh
    usage.py
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${BOLD}Claude Remote — Noctalia Plugin Installer${NC}"
echo "────────────────────────────────────────────"
echo ""

# ── Prerequisites ────────────────────────────────────────────────────────────

if ! command -v python3 &>/dev/null; then
    err "python3 not found — required for auto-title.py and usage.py"
fi
ok "python3 found"

if ! command -v claude &>/dev/null; then
    warn "claude CLI not found on PATH"
    info "Install it from https://claude.ai/code, or set the path in plugin Settings after install."
else
    ok "claude CLI found ($(command -v claude))"
fi

if ! command -v pgrep &>/dev/null; then
    warn "pgrep not found — session counting will not work"
    info "Install procps-ng (Arch: sudo pacman -S procps-ng  |  Debian/Ubuntu: sudo apt install procps)"
else
    ok "pgrep found"
fi

if ! command -v nohup &>/dev/null; then
    warn "nohup not found — daemon background spawning will not work"
    info "Install coreutils (Arch: sudo pacman -S coreutils  |  Debian/Ubuntu: sudo apt install coreutils)"
else
    ok "nohup found"
fi

if ! command -v xdg-open &>/dev/null; then
    warn "xdg-open not found — 'Get Claude Code' button will not open the browser"
    info "Install xdg-utils (Arch: sudo pacman -S xdg-utils  |  Debian/Ubuntu: sudo apt install xdg-utils)"
else
    ok "xdg-open found"
fi

NOCTALIA_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia"
if [[ ! -d "$NOCTALIA_CFG" ]]; then
    warn "Noctalia config directory not found at $NOCTALIA_CFG"
    info "Make sure Noctalia ≥ 3.6.0 is installed before using the plugin."
fi

# ── Auth check (for auto-title hook) ────────────────────────────────────────

if [[ -f "$HOME/.claude/.credentials.json" ]]; then
    ok "Claude OAuth credentials found — auto-title will use your subscription"
elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    ok "ANTHROPIC_API_KEY set — auto-title will use API billing"
else
    warn "No Claude auth found — auto-title will be inactive"
    info "Either log in with 'claude' once, or export ANTHROPIC_API_KEY in your shell."
fi

# ── Terminal auto-detection ──────────────────────────────────────────────────

detect_terminal() {
    for t in kitty foot ghostty wezterm alacritty gnome-terminal konsole xterm; do
        if command -v "$t" &>/dev/null; then
            echo "$t"
            return
        fi
    done
    echo "kitty"
}

DETECTED_TERMINAL="$(detect_terminal)"

if command -v "$DETECTED_TERMINAL" &>/dev/null; then
    ok "Terminal detected: $DETECTED_TERMINAL"
else
    warn "Could not detect a terminal emulator — defaulting to 'kitty'"
    info "Change this in plugin Settings after install."
fi

# ── Install files ────────────────────────────────────────────────────────────

echo ""
info "Installing to: $PLUGIN_DIR"
echo ""

mkdir -p "$PLUGIN_DIR"

for f in "${PLUGIN_FILES[@]}"; do
    src="$SCRIPT_DIR/$f"
    if [[ ! -f "$src" ]]; then
        warn "Missing file: $f (skipped)"
        continue
    fi
    cp "$src" "$PLUGIN_DIR/$f"
    ok "Copied $f"
done

# ── Executable bits ──────────────────────────────────────────────────────────

chmod +x "$PLUGIN_DIR/start-session.sh"
chmod +x "$PLUGIN_DIR/auto-title.py"
chmod +x "$PLUGIN_DIR/usage.py"
chmod +x "$PLUGIN_DIR/uninstall.sh"

# ── Register Stop hook for auto-title ────────────────────────────────────────

HOOK_PATH="$PLUGIN_DIR/auto-title.py"

hook_result="$(python3 - "$HOOK_PATH" "$CLAUDE_SETTINGS" <<'PYEOF'
import json, os, pathlib, sys

hook_path = sys.argv[1]
settings_file = pathlib.Path(sys.argv[2])
settings_file.parent.mkdir(parents=True, exist_ok=True)

if settings_file.exists():
    try:
        with open(settings_file) as f:
            settings = json.load(f)
        if not isinstance(settings, dict):
            print("INVALID")
            sys.exit(0)
    except Exception:
        print("INVALID")
        sys.exit(0)
else:
    settings = {}

hooks = settings.setdefault("hooks", {})
stop_hooks = hooks.setdefault("Stop", [])

# Already registered?
for entry in stop_hooks:
    for h in entry.get("hooks", []):
        cmd = h.get("command", "")
        if cmd == hook_path or cmd.endswith("/auto-title.py"):
            # Update path in case the plugin moved
            if cmd != hook_path:
                h["command"] = hook_path
                tmp = settings_file.with_suffix(".tmp")
                with open(tmp, "w") as f:
                    json.dump(settings, f, indent=2)
                os.replace(tmp, settings_file)
                print("UPDATED")
            else:
                print("ALREADY")
            sys.exit(0)

stop_hooks.append({
    "matcher": "",
    "hooks": [{"type": "command", "command": hook_path}]
})

tmp = settings_file.with_suffix(".tmp")
with open(tmp, "w") as f:
    json.dump(settings, f, indent=2)
os.replace(tmp, settings_file)
print("ADDED")
PYEOF
)"

case "$hook_result" in
    ADDED)    ok "Registered auto-title Stop hook in $CLAUDE_SETTINGS" ;;
    UPDATED)  ok "Updated auto-title hook path in $CLAUDE_SETTINGS" ;;
    ALREADY)  ok "Auto-title hook already registered" ;;
    INVALID)  warn "$CLAUDE_SETTINGS is not valid JSON — skipped hook registration"
              info "Fix or remove the file and re-run install.sh to enable auto-title." ;;
    *)        warn "Could not register Stop hook (unexpected: $hook_result)" ;;
esac

# ── settings.json (create only — preserve existing user settings) ────────────

SETTINGS_FILE="$PLUGIN_DIR/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
    ok "settings.json already exists — preserved"
else
    cat > "$SETTINGS_FILE" <<EOF
{
  "sessionName": "Remote Session",
  "claudeBin": "claude",
  "terminalBin": "$DETECTED_TERMINAL",
  "workspaceDir": "~",
  "favouriteSkills": []
}
EOF
    ok "Created settings.json (terminalBin: $DETECTED_TERMINAL, workspaceDir: ~)"
fi

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}Done.${NC}"
echo ""
info "Next steps:"
info "  1. Reload Noctalia (or restart it) to pick up the new plugin."
info "  2. Open the plugin panel — it will check for Claude Code automatically."
info "  3. Click Start. The panel will guide you if anything needs setting up:"
info "       • Claude not found  → follow the in-panel install steps"
info "       • Workspace untrusted → click 'Set up workspace' in the panel"
info "  4. Adjust the binary path or workspace in Settings if needed."
info ""
info "To uninstall: bash $PLUGIN_DIR/uninstall.sh"
echo ""
