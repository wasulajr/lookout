---
name: headsup-diagnose
description: Actively exercise the headsup hook stack end-to-end. Flashes the three tab colors (idle → processing → waiting) on the current tab and verifies each round-trips through the daemon. Use when the user asks "is the headsup thing actually working", "test the headsup hooks", "/headsup-diagnose", or wants confirmation after a change. Different from /headsup-status (passive snapshot) — this skill performs writes and briefly changes the visible tab color. Add the `--restart` arg to also kill the daemon and verify the launchd watchdog respawns it (~30s extra).
---

# iTerm hook stack diagnose

Active end-to-end test. Flashes colors on the current tab, verifies each pushes through to iTerm2 via the daemon, and reports pass/fail per step.

## When to use

- "Test the headsup tab hooks"
- "Is the headsup stack actually working"
- "Run headsup diagnose"
- "/headsup-diagnose"
- After installing/upgrading anything in the headsup stack — confirm the install actually works before declaring done

## Heads-up to the user before invoking

Brief warning is enough: "Going to flash white → blue → orange on this tab over ~3s, then restore. OK?" Only ask if the user invoked you in a context where unexpected color changes might be confusing. For an explicit `/headsup-diagnose` invocation, just run it.

## What to do when invoked

Run the diagnose script. Default mode (no `--restart`) is fast (~3s) and only flashes colors. Pass `--restart` ONLY if the user explicitly asked for "deep" / "full" / "include daemon respawn" — that one adds ~30s while the watchdog re-spawns the daemon.

```bash
~/.claude/hooks/headsup-diagnose.sh             # color flash test only
~/.claude/hooks/headsup-diagnose.sh --restart   # also test daemon respawn
```

Let the script's output speak for itself. It prints per-step pass/fail with the same green-check/red-cross convention as `/headsup-status`. Don't restate or interpret unless asked.

## What gets tested

1. **Prereqs** — venv python, daemon script, resync script exist; UUID resolved
2. **Daemon health** — PID alive, heartbeat status=OK
3. **Watchdog** — LaunchAgent loaded
4. **Cost helper** — headsup-session-cost.py runs cleanly
5–7. **Color round-trip** — push idle / processing / waiting, verify state file is written AND daemon's "applied" log line lands within 2s
8. **(--restart only)** — kill the daemon, verify the watchdog respawns it within 35s

Original tab state is restored on exit (whatever color/attention it was before the test).

## Exit code

`0` on all-pass, `1` on any fail. Useful for scripting.

## If something fails

- Step 1 failures → run `setup.sh` to reinstall scripts
- Step 2 failures → daemon should respawn on next event; check `~/.claude/hooks/.state/daemon.stderr`
- Step 3 → `launchctl load ~/Library/LaunchAgents/claude-code.headsup-watchdog.plist`
- Step 5–7 → the daemon's API connection might be dead; check `~/.claude/hooks/.state/daemon.stderr` for websocket errors
- Step 8 → the watchdog didn't fire or the daemon respawn path is broken; check `~/.claude/hooks/.state/watchdog.stderr`

## Where the supporting files live

- `~/.claude/hooks/headsup-diagnose.sh` — this script
- `~/.claude/hooks/headsup-resync.sh` — how each color push lands
- `~/.claude/hooks/headsup-session-cost.py` — the cost helper that gets smoke-tested

All under version control at `github.com/wasulajr/headsup`.
