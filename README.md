# noctalia-claude-remote

[![Latest Release](https://img.shields.io/github/v/release/jackvanlint/noctalia-claude-remote?cacheSeconds=0)](https://github.com/jackvanlint/noctalia-claude-remote/releases/latest)

```bash
git clone https://github.com/jackvanlint/noctalia-claude-remote.git && bash noctalia-claude-remote/install.sh
```

A [Noctalia](https://github.com/noctalia-dev/noctalia) bar plugin that runs `claude remote-control` as a persistent background daemon and exposes a live status widget and panel for managing Claude Code sessions and skills.

---

## Features

- **Bar widget** — brain icon with colour-coded status dot (green = connected, amber = connecting, red = stopped)
- **Named sessions** — spawn extra detached remote sessions with per-session Stop buttons and a prune timer
- **Skills browser** — auto-discovers all `~/.claude/commands/*.md` slash commands; click a name for an inline overview, star to favourite (persisted), Run to launch in your terminal
- **Favourites** — pinned to the top of the skills list, saved in plugin settings
- **Auto-title hook** — renames new remote sessions from their first user message via Claude Haiku
- **Rate-limit usage** — 5-hour + 7-day bars, weekly chart, tokens-today chip
- **Max-sessions warning** — shown only when the 32-session limit is hit

---

## Files

| File | Role |
|------|------|
| `manifest.json` | Plugin metadata, version, entry points, default settings |
| `Main.qml` | Core logic — daemon, session management, skill discovery, favourites |
| `BarWidget.qml` | Status bar widget |
| `Panel.qml` | Drop-down panel |
| `Settings.qml` | Settings UI — session name, claude binary, terminal emulator |
| `start-session.sh` | Spawns a detached daemon and returns its PID |
| `auto-title.py` | Claude Stop hook — titles new sessions via Haiku |
| `usage.py` | Fetches rate-limit usage from the Anthropic OAuth API |
| `install.sh` | Installer — copies files, detects terminal, registers Stop hook, creates settings |
| `uninstall.sh` | Uninstaller — deregisters hook, removes plugin dir, preserves user hooks |

---

## Installation

```bash
git clone https://github.com/jackvanlint/noctalia-claude-remote.git && bash noctalia-claude-remote/install.sh
```

The installer:

1. Copies plugin files to `~/.config/noctalia/plugins/claude-remote/`
2. Auto-detects your terminal emulator
3. Registers `auto-title.py` as a `Stop` hook in `~/.claude/settings.json` (idempotent — existing hooks are preserved)
4. Creates a default `settings.json` if none exists

Reload Noctalia afterwards.

## Uninstallation

```bash
bash ~/.config/noctalia/plugins/claude-remote/uninstall.sh
```

Removes the plugin directory, deregisters the Stop hook, and backs up your plugin `settings.json` next to the (now-deleted) plugin dir. Running daemons are left alone — stop them from the panel first if desired, or `pkill -f 'claude remote-control'`.

Add `--yes` to skip the confirmation prompt.

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `sessionName` | `"Remote Session"` | Name shown in claude.ai/code and the mobile app |
| `claudeBin` | `"claude"` | Path to the claude CLI binary |
| `terminalBin` | (auto-detected) | Terminal emulator used to run skills |
| `workspaceDir` | `""` | Directory the daemon `cd`s into before launching. Required by `claude remote-control` if Noctalia's cwd isn't a trusted workspace. Supports `~` expansion. |
| `favouriteSkills` | `[]` | Skills pinned to the top of the browser |

### Supported terminals

| Terminal | Launch flag used |
|----------|------------------|
| `kitty`, `foot`, `gnome-terminal` | `--` |
| `alacritty`, `ghostty`, `konsole`, `xterm` | `-e` |
| `wezterm` | `start --` |

You can set `terminalBin` to a full path (e.g. `/usr/bin/konsole`) — the basename is used to pick the right flag.

---

## Auto-title hook auth

`auto-title.py` calls Claude Haiku to summarise each new session's first message. It resolves credentials in this order:

1. **OAuth token from `~/.claude/.credentials.json`** — the same login Claude Code itself uses. Counts against your Claude subscription's 5-hour / 7-day quota (visible in the panel). No configuration required.
2. **`ANTHROPIC_API_KEY` env var** — billed separately as API usage.

If neither is available the hook exits silently and sessions keep their default name.

---

## Requirements

- [Noctalia](https://github.com/noctalia-dev/noctalia) ≥ 3.6.0
- [Claude Code CLI](https://claude.ai/code)
- Python 3 (for `auto-title.py` and `usage.py`)
- A supported terminal emulator (auto-detected during install)

---

## Troubleshooting

**"Start" appears to work but no session shows up on phone / claude.ai, and `pgrep -af "claude remote-control"` returns nothing.** The daemon is failing silently — most commonly because `claude remote-control` requires a *trusted workspace*. Run `claude` in a real project directory (not `~`), accept the trust dialog, then set that path as **Workspace Directory** in plugin Settings. Also confirm your `claude` login is full-scope (`claude auth login`) — inference-only tokens from `claude setup-token` or `CLAUDE_CODE_OAUTH_TOKEN` are rejected by Remote Control.

**Sessions don't get auto-titled.** Check that the hook is registered: `grep -A3 auto-title ~/.claude/settings.json`. Re-run `install.sh` to (idempotently) add it. Confirm you either have `~/.claude/.credentials.json` from a `claude` login, or `ANTHROPIC_API_KEY` set.

**"Run" on a skill does nothing.** Your `terminalBin` setting may not match the binary's actual name. Set it explicitly in Settings — the basename must be one of the values in the Supported terminals table above.

**Rate-limit bars show "—".** `usage.py` needs `~/.claude/.credentials.json`. The first time you log in to `claude`, the file is created and the next 5-minute poll will populate the bars.

**Panel still shows old plugin after install.** Reload Noctalia: `pkill -USR1 noctalia` or restart the bar.

---

## Author

Jack Vanlint <277274540+jackvanlint@users.noreply.github.com>
