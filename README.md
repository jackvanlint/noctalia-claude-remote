# noctalia-claude-remote

[![Latest Release](https://img.shields.io/github/v/release/jackvanlint/noctalia-claude-remote?cacheSeconds=0)](https://github.com/jackvanlint/noctalia-claude-remote/releases/latest)
[⬇ Download v1.4.0](https://github.com/jackvanlint/noctalia-claude-remote/archive/refs/tags/v1.4.0.zip)

A [Noctalia](https://github.com/noctalia-dev/noctalia) bar plugin that runs `claude remote-control` as a persistent background daemon and exposes a live status widget and panel for managing Claude Code sessions and skills.

---

## Features

- **Bar widget** — brain icon with colour-coded status dot (green = connected, amber = connecting, red = stopped)
- **Named sessions** — spawn extra detached remote sessions with per-session Stop buttons and a prune timer
- **Skills browser** — auto-discovers all `~/.claude/commands/*.md` skills; click a skill name for an inline overview, star to favourite (persisted), Run to launch in Kitty
- **Favourites** — pinned to the top of the skills list, saved in plugin settings
- **Auto-title hook** — renames new sessions from their first user message via Claude Haiku
- **Max-sessions warning** — shown only when the 32-session limit is hit

---

## Files

| File | Role |
|------|------|
| `manifest.json` | Plugin metadata, version, entry points, default settings |
| `Main.qml` | Core logic — daemon, session management, skill discovery, favourites |
| `BarWidget.qml` | Status bar widget |
| `Panel.qml` | Drop-down panel |
| `Settings.qml` | Settings UI — session name, claude binary, and terminal emulator |
| `start-session.sh` | Spawns a detached daemon and returns its PID |
| `auto-title.py` | Claude Stop hook — titles new sessions via Haiku API |
| `usage.py` | Fetches rate-limit usage from the Anthropic OAuth API |
| `install.sh` | One-step installer — copies files, detects terminal, creates settings |

---

## Installation

```bash
git clone https://github.com/jackvanlint/noctalia-claude-remote.git
cd noctalia-claude-remote
bash install.sh
```

The script auto-detects your terminal emulator, creates a default `settings.json`, and makes the helper scripts executable. Reload Noctalia afterwards.

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `sessionName` | `"Remote Session"` | Name shown in claude.ai/code and the mobile app |
| `claudeBin` | `"claude"` | Path to the claude CLI binary |
| `terminalBin` | `"kitty"` | Terminal emulator used to run skills (kitty, foot, ghostty, wezterm, alacritty, gnome-terminal, …) |
| `favouriteSkills` | `[]` | Skills pinned to the top of the browser |

---

## Requirements

- [Noctalia](https://github.com/noctalia-dev/noctalia) ≥ 3.6.0
- [Claude Code CLI](https://claude.ai/code)
- Python 3 (for `auto-title.py` and `usage.py`)
- A terminal emulator (configurable in Settings — defaults to `kitty`)

---

## Author

Jack Vanlint <277274540+jackvanlint@users.noreply.github.com>
