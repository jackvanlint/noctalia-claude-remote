# noctalia-claude-remote

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
| `Settings.qml` | Settings UI — session name and claude binary path |
| `start-session.sh` | Spawns a detached daemon and returns its PID |
| `auto-title.py` | Claude Stop hook — titles new sessions via Haiku API |

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `sessionName` | `"Remote Session"` | Name shown in claude.ai/code and the mobile app |
| `claudeBin` | `"claude"` | Path to the claude CLI binary |
| `favouriteSkills` | `[]` | Skills pinned to the top of the browser |

---

## Requirements

- [Noctalia](https://github.com/noctalia-dev/noctalia) ≥ 3.6.0
- [Claude Code CLI](https://claude.ai/code)
- Python 3 (for `auto-title.py`)
- `kitty` terminal (for Run button — or change `skillRunner` command in `Main.qml`)

---

## Author

Jack Vanlint <277274540+jackvanlint@users.noreply.github.com>
