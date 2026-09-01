# shell

Bash helpers for the momentum worktree workflow. Two files, both sourced from
`~/.bashrc`:

- `momentum.sh` - `m-newwork`, `m-teardown`, `m-dev`, `m-cd`. No herdr needed.
- `herdr-momentum.sh` - `m-work`, `m-space`, `m-agents`. Needs herdr on the box;
  every function no-ops with a message when it is missing. Calls `_m_root` and
  `_m_skill` out of `momentum.sh`, so that file has to be sourced too.

Bash only. The Windows side has no equivalent yet.

```bash
# momentum workspace shortcuts (source of truth: C:\code2\joey-claude-setup/shell/momentum.sh)
[ -f /mnt/c/code2/joey-claude-setup/shell/momentum.sh ] && . /mnt/c/code2/joey-claude-setup/shell/momentum.sh

# herdr-aware momentum helpers (source of truth: C:\code2\joey-claude-setup/shell/herdr-momentum.sh)
[ -f /mnt/c/code2/joey-claude-setup/shell/herdr-momentum.sh ] && . /mnt/c/code2/joey-claude-setup/shell/herdr-momentum.sh
```

`herdr/setup.sh` adds the second line. The first is added by hand.

## The commands

| Command                  | Does                                                        |
| ------------------------ | ----------------------------------------------------------- |
| `m-work <desc>`          | new branch + worktree, in its own herdr space with claude up |
| `m-newwork <desc>`       | same, but `cd` + claude in the current pane (no herdr)       |
| `m-space [dir]`          | give an existing worktree a herdr space with claude up       |
| `m-agents`               | one line per live herdr agent                                |
| `m-dev [name\|N]`        | run the local stack, one worktree at a time                  |
| `m-cd [name]`            | jump a shell to a worktree                                   |
| `m-teardown [desc]`      | the worktree table: what is safe to tear down, and d does it |

## Starting work

### `m-work <short description>`

The one to use day to day. Runs `/new-work` headless in `~/m-code/momentum`,
which cuts a branch off a fresh `origin/main` and adds a worktree at
`~/m-code/momentum-<desc>`, runs `npm install` in its `src/ui-app`, then opens
that worktree as its own herdr space with claude already running in it.

```bash
m-work fix form submit null check
```

Arguments: everything after the command is the description, passed straight to
`/new-work`. No quoting needed.

The new worktree is found by diffing `git worktree list` around the run, so
nothing is parsed out of Claude's output. If no worktree appears, setup did not
finish and the command fails rather than guessing.

### `m-newwork <short description>`

Same setup, without herdr: it `cd`s you into the new worktree and starts claude
in the pane you were already standing in. Falls back to `~/m-code/momentum`
itself if `/new-work` branched in place instead of adding a worktree.

Under herdr the agent gets filed under whatever space that pane belonged to, so
the panel cannot tell you which worktree is asking. That is the whole reason
`m-work` exists. Use `m-newwork` on a box with no herdr.

### `m-space [dir]`

Adopts a worktree that already exists: opens a herdr space for it and starts
claude in the root pane. Defaults to the worktree you are standing in.

```bash
m-space                              # this worktree
m-space ~/m-code/momentum-betterHeader
```

Idempotent. If the space is already open it says so and leaves it alone. The
space and agent are named after the directory with the `momentum-` prefix
stripped, lowercased and cut to 32 characters.

### `m-agents`

Prints the live agents as a table: status, workspace, name, terminal title.
Works from any pane.

## Running the stack

### `m-dev`

`make dev` can only run once at a time: sso-auth, the BFFs, postgres and valkey
sit on ports hardcoded in `AppHost.cs`, so two stacks collide. `m-dev` drives
exactly one, and switching worktrees means stopping it and bringing it up in the
new one. Every worktree lands on the same URLs, so bookmarks never change:
ui-app on `http://localhost:3000`, the Aspire dashboard on `:18888`.

| Form                | Does                                                  |
| ------------------- | ----------------------------------------------------- |
| `m-dev`             | the live table (interactive)                          |
| `m-dev <name>`      | switch straight to that worktree, then print the table |
| `m-dev <N>`         | same, by row number                                    |
| `m-dev --stop`      | stop the running stack                                 |
| `m-dev --logs`      | `tail -f` the stack log                                |

Keys in the table:

| Key        | Does                                    |
| ---------- | --------------------------------------- |
| up/down, `j`/`k` | move the selection                |
| enter      | switch the stack to the selected worktree |
| `s`        | stop the stack                          |
| `c`        | clear both log panes                    |
| `r`        | refresh the worktree list and stack state |
| `q`        | quit                                    |

The table stays at the top of the screen and the keys always act on the selected
row. Starting or stopping takes minutes, so an action runs detached behind the
frame and its progress goes to a pane underneath, alongside a live tail of the
stack's own output. Pressing enter or `s` while one is running drops it and
starts the new one.

Naming: a worktree is addressed by label (`main` for the default worktree,
otherwise the bit after `momentum-`), by branch name, or by row number. Case and
dashes are ignored, so the kebab-case directory and the camelCase branch it holds
are both fine:

```bash
m-dev main
m-dev better-mobile-header
m-dev betterMobileHeader
m-dev 3
```

A prefix match is enough as long as it is unambiguous; an ambiguous one lists the
candidates and fails.

Two things it handles on its own. A worktree with no `src/ui-app/node_modules`
gets an `npm ci` first, since those are per-worktree and `/new-work` does not
install them. And it stops the stack with `TERM`, not `INT`, because the stack
has no controlling terminal and would ignore a `SIGINT`.

`m-dev` also picks up a `make dev` started by hand in another terminal and will
stop that too.

### `m-cd [name]`

Jumps a shell to a worktree. No argument goes to `~/m-code/momentum`. Takes the
same name, branch or number `m-dev` does.

## Finishing

### `m-teardown [shortdesc|this] [--force]`

Every momentum worktree in a table, each with a verdict on whether it can go, and
`d` removes the selected one after a `y`. Plain shell, no Claude in it.

```bash
m-teardown                # the table
m-teardown betterHeader   # gate that one and remove it after a y/n
m-teardown this           # the worktree the shell is standing in
m-teardown --force        # with a name: skip the gates for it
m-teardown --pull         # just land main and pull manta
```

| Key        | Does                                                |
| ---------- | --------------------------------------------------- |
| up/down, `j`/`k` | select a row                                   |
| `d`        | tear down the selected worktree, after a `y`         |
| `D`        | the same with no gates at all, after a `y`           |
| `r`        | rescan the verdicts                                  |
| `p`        | land the default worktree on main, pull manta        |
| `q`        | quit                                                 |

The verdicts are the same gates `/teardown` applies:

| Verdict | Means                                                                    |
| ------- | ------------------------------------------------------------------------ |
| `SAFE`  | clean tree, nothing unpushed, and a merged PR or none at all              |
| `KEEP`  | one of those stopped it, and the row says which                           |
| `GONE`  | git already calls it prunable - the directory has been deleted from under |
|         | it, so the record goes and the branch only follows if it is safe          |
| `BASE`  | the default worktree, which is landed on main and never removed           |

A verdict costs a `gh pr list`, so the scan runs behind the table and writes to a
cache the redraw reads back - the table is up immediately with the rows filling in
as they resolve. `r` runs it again, and so does a removal, since one changes what
every other verdict was worked out against.

Only `y` answers a confirmation. Every other key cancels it, so a stray keystroke
can only ever call a removal off.

Anything it cannot prove is safe stays. A branch is deleted with `-D` only after
the check proved origin holds the commits, which is what makes a squash merge
(where `-d` cannot see the merge) safe to delete through.

If you are standing in a worktree it is about to remove, it steps out first and
tells you where you ended up.

Under herdr the space outlives the checkout. Close it with
`herdr worktree remove --workspace <id>`; a plain `workspace close` leaves the
checkout on disk.

## Settings

| Variable         | Default        | Does                                        |
| ---------------- | -------------- | ------------------------------------------- |
| `MOMENTUM_ROOT`  | `$HOME/m-code` | where the worktrees live                     |
| `M_DEV_TIMEOUT`  | `420`          | seconds `m-dev` waits for ui-app on :3000    |

The timeout is generous on purpose: a cold worktree also builds .NET and pulls
containers.

State lives in `${XDG_CACHE_HOME:-$HOME/.cache}/m-dev`: `stack.log` (the stack's
own output), `action.log` (m-dev's progress on the current action), `stack.pgid`
and `action.pid`. `m-teardown` keeps its own next door in `m-teardown/`:
`status` (the last scan's verdicts), `action.log` and `action.pid`.

## Headless Claude

`m-newwork` and `m-work` go through `_m_skill`, which runs the skill with
`claude -p --model sonnet` from `~/m-code/momentum` and allows only git, gh, jj
and uname. Everything else in these files is plain git and process handling with
no Claude in it, `m-teardown` included - it used to run `/teardown` headless and
now applies the same gates itself.
