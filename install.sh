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

PLUGIN_FILES=(
    auto-title.py
    BarWidget.qml
    Main.qml
    manifest.json
    Panel.qml
    README.md
    Settings.qml
    start-session.sh
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

NOCTALIA_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia"
if [[ ! -d "$NOCTALIA_CFG" ]]; then
    warn "Noctalia config directory not found at $NOCTALIA_CFG"
    info "Make sure Noctalia ≥ 3.6.0 is installed before using the plugin."
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
  "favouriteSkills": []
}
EOF
    ok "Created settings.json (terminalBin: $DETECTED_TERMINAL)"
fi

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}Done.${NC}"
echo ""
info "Next steps:"
info "  1. Reload Noctalia (or restart it) to pick up the new plugin."
info "  2. Open the plugin panel and click Start to launch the daemon."
info "  3. If the terminal or claude path are wrong, adjust them in Settings."
echo ""
