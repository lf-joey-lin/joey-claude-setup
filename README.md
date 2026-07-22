# joey-claude-setup

Source of truth for my Claude Code configuration: skills, the global `CLAUDE.md`, custom statusline, settings, and writing corpus.

## How it works

The files live here, in this repo. In `~/.claude` the same names are symlinks pointing back into this repo, so editing a skill (or anything else) edits the repo file directly. Commit whenever; there is no copy or export step and nothing can drift out of sync.

Linked paths:

| `~/.claude`            | this repo               |
| ---------------------- | ----------------------- |
| `CLAUDE.md`            | `CLAUDE.md`             |
| `settings.json`        | `settings.json`         |
| `statusline.js`        | `statusline.js`         |
| `joey-writing-style.md`| `joey-writing-style.md` |
| `skills/`              | `skills/`               |
| `writing-corpus/`      | `writing-corpus/`       |

## Setting up a new machine

Clone the repo, then run the bootstrap script. It recreates the symlinks above and moves any existing local file aside as `*.pre-bootstrap` instead of overwriting it.

```powershell
git clone https://github.com/lf-joey-lin/joey-claude-setup.git
cd joey-claude-setup
pwsh -File bootstrap.ps1
```

Symlink creation needs Windows Developer Mode on, or an elevated shell.

## Not tracked here

Everything else under `~/.claude` is local runtime state or secrets and stays out of the repo: `.credentials.json`, session/history/cache/daemon files, `plugins/`, `agent-memory/`, and so on.

## Caveat to watch

`settings.json` is a symlink, and Claude Code writes to it. If a write ever replaces the file instead of editing it in place, the symlink turns into a plain local file and stops syncing. Symptom: settings changes stop showing up in `git status`. Fix: re-run `bootstrap.ps1`.
