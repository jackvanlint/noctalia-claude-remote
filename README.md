# noctalia-claude-remote

[![Latest Release](https://img.shields.io/github/v/release/jackvanlint/noctalia-claude-remote?cacheSeconds=0)](https://github.com/jackvanlint/noctalia-claude-remote/releases/latest)

A [Noctalia](https://github.com/noctalia-dev/noctalia) bar plugin that keeps a `claude remote-control` daemon running in the background so your Claude Code sessions stay reachable from your phone and claude.ai — without leaving a terminal window open.

## Quick install

```bash
git clone https://github.com/jackvanlint/noctalia-claude-remote.git && bash noctalia-claude-remote/install.sh
```

Reload Noctalia afterwards. The panel will walk you through any remaining setup steps automatically.

## What it does

- **Remote daemon** — starts and keeps `claude remote-control` running; status visible in the bar at a glance
- **Named sessions** — spawn multiple remote sessions with individual stop buttons; sessions are pruned automatically when they exit
- **Rate-limit bars** — live 5-hour and 7-day usage pulled from the Anthropic API; click for a weekly chart and today's token count
- **Skills browser** — lists every `~/.claude/commands/*.md` slash command with a preview; star to favourite, click Run to launch in your terminal
- **Auto-titling** — renames each new session from its first message using Claude Haiku, so your session list stays readable
- **First-run guidance** — detects a missing `claude` binary or untrusted workspace and walks you through fixing it without leaving the panel

## Uninstall

```bash
bash ~/.config/noctalia/plugins/claude-remote/uninstall.sh
```

Removes plugin files and deregisters the auto-title hook. Add `--yes` to skip confirmation.

---

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `sessionName` | `"Remote Session"` | Name shown in claude.ai and the mobile app |
| `claudeBin` | `"claude"` | Path to the `claude` CLI binary |
| `terminalBin` | (auto-detected) | Terminal emulator used to run skills |
| `workspaceDir` | `"~"` | Directory the daemon `cd`s into before launching — must be a trusted Claude workspace |
| `favouriteSkills` | `[]` | Skills pinned to the top of the browser |

### Supported terminals

| Terminal | Flag |
|----------|------|
| `kitty`, `foot`, `gnome-terminal` | `--` |
| `alacritty`, `ghostty`, `konsole`, `xterm` | `-e` |
| `wezterm` | `start --` |

`terminalBin` can be a full path — only the basename is used to pick the right flag.

---

## Requirements

- [Noctalia](https://github.com/noctalia-dev/noctalia) ≥ 3.6.0
- [Claude Code CLI](https://claude.ai/code)
- Python 3
- `pgrep` (procps-ng), `nohup` (coreutils), `xdg-open` (xdg-utils)
- A supported terminal emulator (auto-detected during install)

---

## Troubleshooting

**Daemon fails to start / no sessions appear on phone.**
The most common cause is an untrusted workspace. Open a terminal, `cd` to the path in **Workspace Directory**, run `claude`, and accept the trust prompt. The panel shows a **Set up workspace** button that does this automatically when it detects the failure.

**Sessions don't get auto-titled.**
Check the hook is registered: `grep -A3 auto-title ~/.claude/settings.json`. Re-run `install.sh` to add it. You need either `~/.claude/.credentials.json` (from `claude` login) or `ANTHROPIC_API_KEY` set in your shell.

**"Run" on a skill does nothing.**
Set `terminalBin` explicitly in Settings — the basename must match one of the terminals in the table above.

**Rate-limit bars show "—".**
`usage.py` needs `~/.claude/.credentials.json`. Log in with `claude` once and the next 5-minute poll will populate the bars.

**Panel still shows old plugin after install.**
Reload Noctalia: `pkill -USR1 noctalia` or restart the bar.

---

## Auto-title credentials

`auto-title.py` resolves auth in this order:

1. `~/.claude/.credentials.json` — your Claude Code login; counts against your subscription quota
2. `ANTHROPIC_API_KEY` env var — billed as API usage

If neither is present, sessions keep their timestamp name.

---

## Author

Jack Vanlint <277274540+jackvanlint@users.noreply.github.com>
