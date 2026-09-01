# joey-claude-setup

Source of truth for my Claude Code configuration: skills, the global `CLAUDE.md`, custom statusline, and settings.

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

Two more links live outside `~/.claude` and are made by `herdr/setup.sh` rather than
the bootstrap script: `~/.config/herdr/config.toml` and `~/.local/bin/cc`.

## Setting up a new machine

Clone the repo, then run the bootstrap script. It recreates the symlinks above and moves any existing local file aside as `*.pre-bootstrap` instead of overwriting it.

```powershell
git clone https://github.com/lf-joey-lin/joey-claude-setup.git
cd joey-claude-setup
pwsh -File bootstrap.ps1
```

Symlink creation needs Windows Developer Mode on, or an elevated shell.

Bootstrap only does the symlinks. The language servers behind the `LSP` tool are a
separate install and are easy to forget, because nothing complains when they are
missing: the tool just reports "No LSP server available" and never gets used. See
[`language-servers/README.md`](language-servers/README.md), or on WSL just run:

```bash
bash language-servers/setup.sh
```

The `chrome-devtools` MCP plugin is a similar case on WSL: it installs clean, then
fails every tool call with "Target closed" because it tries to launch a Chrome stable
that is not there. See
[`chrome-devtools-mcp/README.md`](chrome-devtools-mcp/README.md), or just run:

```bash
bash chrome-devtools-mcp/setup.sh
```

Both need a Claude Code restart, and both have to be re-run after a plugin or nvm
change rather than being set once.

`herdr` is the terminal workspace manager the momentum worktree workflow runs in: one
space per worktree, one attention queue across the parallel loom runs. It is a
separate install, and it needs its config linked, the `cc` launcher fixed and the
Claude integration installed before it can see an agent at all. See
[`herdr/README.md`](herdr/README.md), or run:

```bash
bash herdr/setup.sh
```

`loom-board/` is a small read-only board that goes with it: `m-board` prints every
momentum worktree, its live agent and what each loom run's slices are doing, read
from the flight ledgers. No install step, it comes with the shell helpers. See
[`loom-board/README.md`](loom-board/README.md).

## Not tracked here

Everything else under `~/.claude` is local runtime state or secrets and stays out of the repo: `.credentials.json`, session/history/cache/daemon files, `plugins/`, `agent-memory/`, and so on.

`local-plugins/` is in that group too, but for a different reason: it holds the `vue-lsp` config, which needs an absolute machine-specific path. `language-servers/setup.sh` generates it rather than the repo carrying it.

## Caveat to watch

`settings.json` is a symlink, and Claude Code writes to it. If a write ever replaces the file instead of editing it in place, the symlink turns into a plain local file and stops syncing. Symptom: settings changes stop showing up in `git status`. Fix: re-run `bootstrap.ps1`.
