# herdr on WSL

[herdr](https://herdr.dev) is a terminal workspace manager that knows what a coding
agent is doing. It keeps panes alive in a background server, and its sidebar rolls
each agent's state (idle, working, blocked, done) up to the tab and the space, so a
row of parallel loom runs turns into one queue: whoever is blocked sorts to the top.

That is the whole reason it is in this setup. Momentum work happens in several
worktrees at once, each with its own Claude, and the old way of noticing that one of
them was waiting on an answer was to go and look.

## Usage

```bash
bash herdr/setup.sh
```

Installs herdr's Claude integration and links two files:

| local path                     | this repo            |
| ------------------------------ | -------------------- |
| `~/.config/herdr/config.toml`  | `herdr/config.toml`  |
| `~/.local/bin/cc`              | `herdr/cc`           |

It also adds the `shell/herdr-momentum.sh` source line to `~/.bashrc`, which is a
local file and stays out of the repo. Safe to re-run. Needs herdr installed first.

## The one-stack rule

`make dev` can only run once: sso-auth, the BFFs, postgres and valkey sit on ports
hardcoded in `AppHost.cs`, so two stacks collide. `m-dev` already owns that
constraint, and it shapes the herdr layout: **many agent spaces, one stack**.

`m-dev` launches the stack under `setsid` with no controlling terminal, so the stack
outlives the pane it was started from, and even a herdr restart. That is why it does
not get a pane of its own. `ctrl+alt+d` opens it in a popup instead, now behind
`m-panel`'s one-letter menu.

Every worktree lands on the same URLs (ui-app on :3000, the Aspire dashboard on
:18888), so switching the stack between worktrees is the serialization point in the
whole workflow. It is worth batching: get two or three runs to their verification
gate, then walk the stack through them.

## Layout

| Space                    | Holds                              |
| ------------------------ | ---------------------------------- |
| one per active worktree  | reviewr on tab 1, its Claude on tab 2 |
| `momentum`               | ux-review, spec-ui, makeagoal, TFS |
| `manta`                  | precedent lookups                  |
| none for the dev server  | `ctrl+alt+d` popup                 |

Worktree spaces carry Git provenance, so their sidebar rows show the branch and the
git status, and herdr groups them under the parent repo space.

The `momentum` default worktree is a read-only reference checkout that stays on main,
which makes it the right home for the work that is not about one branch: a ux-review
session, a spec, the weekly goals. Those used to die with whichever worktree they
happened to be sitting in.

## Daily flow

```bash
m-work fix inbox scroll jump   # branch + worktree + its own space + claude in it
```

Then leave it running and start another. When any of them needs you, the sidebar says
so and a toast fires; `ctrl+alt+a` walks to it.

Away from the desk the same two states go to Teams instead. See
[`herdr-teams/README.md`](../herdr-teams/README.md).

Attended loom has exactly two ask moments. Both render as `blocked`, which is the
state this layout is built around. Permission prompts do too.

When a run reaches human verification: `ctrl+alt+d`, switch the stack to that
worktree, check :3000, come back.

At the end, `m-teardown` sweeps the merged worktrees as before. Close the matching
space with `herdr worktree remove --workspace <id>`, which runs `git worktree remove`
and drops the space together; a plain `workspace close` leaves the checkout on disk.

## Commands

`shell/herdr-momentum.sh`, sourced from `~/.bashrc`:

| Command             | Does                                                            |
| ------------------- | --------------------------------------------------------------- |
| `m-work <desc>`     | `/new-work` headless, then the worktree gets its own space with claude running in it |
| `m-space [dir]`     | same, for a worktree that already exists. Idempotent            |
| `m-agents`          | one line per live agent, from any pane                           |

`m-work` is the herdr replacement for `m-newwork`. The difference is where the agent
ends up: `m-newwork` does `cd` plus `claude` in whichever pane you were standing in,
so herdr files that agent under that pane's space, and the panel cannot tell you
which worktree is asking. `m-work` gives the worktree a space and names the agent
after it.

Both call `_m_skill` and `_m_root` from `shell/momentum.sh`, so that file has to be
sourced too. `m-dev`, `m-cd`, `m-newwork` and `m-teardown` are unchanged and still
live there.

Note that `herdr worktree create` is deliberately not used. Without `--path` it puts
the checkout under `<worktrees.directory>/<repo>/<branch-slug>`, and `m-dev` and
`teardown` both expect `~/m-code/momentum-<desc>`. `m-space` passes `--path`.

## Keys

No prefix. Every binding is a single chord on `ctrl+alt`, which is the one layer
nothing inside a pane wants: Claude Code binds no `ctrl+alt` letter, readline binds
none, and Windows Terminal only takes `ctrl+alt+1..9`. Plain `ctrl+letter` was never
an option, because Claude Code uses nearly all of them, `ctrl+w` and `ctrl+n`
included, and a global `ctrl+w` costs you delete-word in every pane.

| Key                     | Does                              |
| ----------------------- | --------------------------------- |
| `ctrl+alt+a`            | next agent                        |
| `ctrl+alt+shift+a`      | previous agent                    |
| `ctrl+alt+enter`        | jump to whatever just toasted     |
| `ctrl+alt+b`            | sidebar                           |
| `ctrl+alt+g`            | goto                              |
| `alt+1..9`              | switch space                      |
| `ctrl+alt+shift+n`      | new space                         |
| `ctrl+alt+o`            | open an existing worktree         |
| `ctrl+alt+shift+g`      | new worktree                      |
| `ctrl+alt+n`            | new tab                           |
| `ctrl+alt+x`            | close tab                         |
| `ctrl+alt+,` / `.`      | previous / next tab               |
| `ctrl+alt+right`        | split right                       |
| `ctrl+alt+down`         | split down                        |
| `ctrl+alt+w`            | close pane                        |
| `ctrl+alt+z`            | zoom                              |
| `ctrl+alt+hjkl`         | focus pane                        |
| `ctrl+alt+shift+arrows` | resize pane                       |
| `ctrl+alt+e`            | scrollback in `$EDITOR`           |
| `ctrl+alt+d`            | panels menu: m-dev, teams-sync    |
| `ctrl+alt+y`            | Teams cards panel, in a popup     |
| `ctrl+alt+shift+y`      | Teams cards on/off, no popup      |
| `f1`                    | help, lists everything            |
| `ctrl+alt+q`            | detach (panes keep running)       |
| `ctrl+alt+r`            | reload config                     |
| `ctrl+alt+s`            | settings                          |

Digits go to spaces rather than agents. A space is a worktree and stays put, while
the agent panel reorders itself by priority, so "agent 3" is not a stable target.
`focus_agent` is left unbound for that reason; `ctrl+alt+1..9` would be the natural
home for it, but Windows Terminal owns those for its own tabs.

The prefix is parked on `f12`. It is not a key to type any more, it is the escape
hatch for the actions still on their defaults: `f12` then `shift+t` renames a tab,
`f12+r` is resize mode, `f12+1..9` switches tabs. Moving it off `ctrl+b` also hands
`ctrl+b` back to Claude Code and to bash.

Chords to check by pressing them, because none is guaranteed here:

- `ctrl+alt+shift+arrows` needs the kitty keyboard protocol end to end. Windows
  Terminal 1.24 and herdr's client both do it, so it should hold. Resize mode on
  `f12+r` is the fallback.
- `ctrl+alt+arrow` is taken by the Intel graphics driver for screen rotation on some
  machines.
- `ctrl+alt+m` does not arrive, and now the reason for this whole family is known:
  `ctrl+m` is carriage return in ASCII, so the chord reaches herdr as ESC+CR, which
  is `ctrl+alt+enter` - already bound to jump-to-toast. Same for `ctrl+alt+i`, since
  `ctrl+i` is tab. Avoid `ctrl+alt+m`, `i`, `[` and probably `j`. The board sits on
  `ctrl+alt+p`, which has no such collision. herdr's own docs separately rule out
  `ctrl+alt+t`, `u`, `s`, `a`, `l`, the arrows and the f-keys, which the OS steals.

`herdr config check` validates key names and catches two actions on the same chord,
so run it after any edit here.

## The rest of config.toml

- `agent_panel_sort = "priority"` makes the panel an attention queue rather than a
  tree. Blocked first.
- The claude sidebar row includes `terminal_title_stripped`. Claude writes its current
  task into the terminal title, and it is the only thing that tells four loom runs
  apart in a narrow sidebar.
- `[ui.toast] delivery = "herdr"`. Toasts ship off. `"terminal"` hands them to Windows
  Terminal and `"system"` to the OS notifier; both are worth a try, in-app is the one
  that definitely works over SSH.
- `[ui.sound]` is left alone. It needs WSLg audio, so try it before relying on it.
- `resume_agents_on_restore` is on by default and works here because the Claude
  integration reports session ids: after a server restart, panes come back into their
  conversations rather than to a bare shell.

## Why cc is a script and not a symlink

This is the trap worth knowing about, because nothing reports it as an error.

herdr works out which agent a pane hosts from the foreground process's `argv[0]`, and
then applies a screen manifest to classify the state. `cc` used to be a symlink to
`claude`, which puts `cc` in `argv[0]`. herdr therefore never picked an agent for the
pane: `herdr agent list` came back empty, `herdr agent explain` said
`agent_not_found`, and the sidebar showed spaces and tabs with an empty agent panel,
while Claude sat there working perfectly.

The screen rules were never the problem. Detection is.

`herdr/cc` execs the real path so `argv[0]` reads as `claude`, and also sets
`HERDR_AGENT=claude`, which is herdr's documented hint for wrapper commands. Either
one is enough on its own.

The same thing happens to anything else that fronts an agent: a sandbox wrapper, a
`nono`/`fence` style launcher, or a shell that auto-enters tmux inside a pane. Set
`HERDR_AGENT` on the wrapper command, not globally.

Diagnosing it:

```bash
herdr pane process-info --current   # what herdr thinks is running
herdr agent explain <pane|name>     # which rule matched, and why
herdr agent explain --file screen.txt --agent claude   # test the rules off a capture
```

Note that the Claude integration is a *session* integration, not a state authority:
its hook reports the session id for restore, and the state you see in the sidebar
always comes from reading the screen. So installing the integration does not fix a
detection failure, which is what makes this one confusing.

## Automation

The socket API is the interesting end of herdr. From any pane:

```bash
herdr agent prompt <name> "..." --wait --until blocked
herdr agent read <name> --source recent-unwrapped --lines 120
herdr agent attach <name>          # one agent full screen, ctrl+alt+q to leave
```

That is enough to kick `/loom` in three worktrees from one loop and wait on each.
It sends real keystrokes to a live Claude with auto mode on, so keep it to prompts
worth typing by hand.

`herdr --skill` prints a skill file that teaches Claude to drive panes, spaces and
other agents. Dropping it in `~/.claude/skills/herdr/` turns the `momentum` space
into a conductor. The CLI works fine from inside a pane; only launching the herdr TUI
inside a pane is blocked.

`ssh` in from a phone and run `herdr`: same session, adapted to a narrow screen.

## Not tracked, and re-runs

Everything else under `~/.config/herdr` is runtime state and stays local:
`session.json`, the sockets, the logs, and the downloaded agent-detection manifests in
`~/.local/state/herdr`.

`herdr integration install claude` writes `~/.claude/hooks/herdr-agent-state.sh` and a
`SessionStart` hook into `~/.claude/settings.json`. On WSL that settings file is a
local file by design, so the hook is not in the repo and `setup.sh` re-installs it.
Re-run setup after a herdr update if `herdr integration status` reports the claude
integration as outdated.

`config.toml` is a symlink and herdr writes to it (`herdr config reset-keys`, and the
`ctrl+alt+s` settings screen). If a write ever replaces the file instead of editing it,
the symlink turns into a plain local file and edits stop showing up in `git status`.
Fix by re-running `setup.sh`. `herdr config check` validates the file, and
`herdr server reload-config` applies it without a restart.
