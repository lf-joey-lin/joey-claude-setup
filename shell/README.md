# shell

Bash helpers for the momentum worktree workflow. Three files, all sourced from
`~/.bashrc`:

- `momentum.sh` - `m-panel`, `m-newwork`, `m-teardown`, `m-dev`, `m-cd`. No herdr
  needed.
- `mqueue.sh` - `mq`, the `m-board` panel and the `m-run` runner. Filing and
  editing need neither herdr nor momentum; running an item needs both.
- `herdr-momentum.sh` - `m-work`, `m-space`, `m-agents`. Needs herdr on the box;
  every function no-ops with a message when it is missing. Calls `_m_root` and
  `_m_skill` out of `momentum.sh`, so that file has to be sourced too.

Bash only. The Windows side has no equivalent yet.

```bash
# momentum workspace shortcuts (source of truth: C:\code2\joey-claude-setup/shell/momentum.sh)
[ -f /mnt/c/code2/joey-claude-setup/shell/momentum.sh ] && . /mnt/c/code2/joey-claude-setup/shell/momentum.sh

# herdr-aware momentum helpers (source of truth: C:\code2\joey-claude-setup/shell/herdr-momentum.sh)
[ -f /mnt/c/code2/joey-claude-setup/shell/herdr-momentum.sh ] && . /mnt/c/code2/joey-claude-setup/shell/herdr-momentum.sh

# momentum work queues (source of truth: C:\code2\joey-claude-setup/shell/mqueue.sh)
[ -f /mnt/c/code2/joey-claude-setup/shell/mqueue.sh ] && . /mnt/c/code2/joey-claude-setup/shell/mqueue.sh
```

`herdr/setup.sh` adds the herdr line. The other two are added by hand, and
`mqueue.sh` has to come after `momentum.sh`, whose `_m_dev_label`,
`_m_dev_worktrees` and `_m_root` it calls.

## The commands

| Command                  | Does                                                        |
| ------------------------ | ----------------------------------------------------------- |
| `m-work <desc>`          | new branch + worktree, in its own herdr space with claude up |
| `m-newwork <desc>`       | same, but `cd` + claude in the current pane (no herdr)       |
| `m-space [dir]`          | give an existing worktree a herdr space with claude up       |
| `m-agents`               | one line per live herdr agent                                |
| `m-panel`                | the panel menu: a letter opens one, `q` closes               |
| `mq [text]`              | file an item against this worktree, or open the board        |
| `m-board`                | the work queues: one per worktree, and the runner controls   |
| `m-run [start\|stop]`    | the runner: drain the queues N worktrees at a time           |
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

## The panels

### `m-panel`

The one popup. `ctrl+alt+d` opens this menu, a letter runs that panel
full-screen in the same popup, and quitting the panel comes back to the menu
rather than closing the popup.

```
momentum panels

  t   work queues            one queue per worktree, and the runner
  d   the momentum stack     switch which worktree runs on :3000
  y   teams-sync             cards out and replies in, together or one at a time

  a letter opens a panel   q closes this
```

The letters are the chords each panel used to have, so `ctrl+alt+d` then `d` is
still the stack. `ctrl+alt+y` still opens the teams panel directly, for when
that is the only thing you want.

Adding a panel is one line in `_M_PANELS`, near the function:

```bash
#          key|name|what it is for|command
_M_PANELS=(
  't|work queues|one queue per worktree, and the runner that drains them|m-board'
  'd|the momentum stack|switch which worktree runs on :3000|m-dev'
  'y|teams-sync|cards out and replies in, together or one at a time|herdr-teams-toggle panel'
)
```

A panel whose command is not installed on this box drops out of the menu
instead of appearing broken, so a line can land here before the thing it runs
exists. The command is word-split on purpose, which is what lets an entry carry
an argument, and a shell function works as well as an executable.

The menu does not open the alternate screen. A terminal has only one, `m-dev`
switches to it and back on its own, and opening a second would leave the buffer
unbalanced as soon as a panel exited.

Two keys beyond the letters: `q` or escape closes the popup, and an arrow key
is swallowed rather than read as a letter. A panel that exits non-zero pauses
with its exit code, because the next repaint would wipe what it printed.

### `m-board`

The work queues, on `t`. One queue per worktree, so the unit of work is the
worktree you already made rather than a note in a global pile. You cut the
branch and prototype in it as before; the queue owns what happens after.

Two levels. It opens on the worktrees, because picking one is what it is for,
and enter drills into that one's lane.

```
worktrees                                runner: on   N=1

  bpBulk2                 2q  1r  0b  1d  working  bulk delete confirm
  rulesListing            3q  0r  0b  0d  idle     next: column widths
  surveys                 0q  0r  1b  0d  blocked
  taskinfo                0q  0r  0b  2d  idle

  enter lane  s/S runner  +/- lanes  r reload  q close
```

Every worktree shows, an empty one included, because that is where the next
item goes. The counts are queued, running, blocked, done. The word after them
is what herdr says that worktree's agent is doing, and the rest of the line is
the running item, or the next one up if nothing is running.

| Key | Does |
| --- | ---- |
| up/down, `j`/`k` | select |
| enter | open that worktree's lane |
| `s` / `S` | runner on / off |
| `+` / `-` | one more / one fewer lane at a time |
| `r` | reload |
| `q` | close |

A lane is the items in order, with two modes on top of the usual keys, because
an input and single-key commands cannot both own the keyboard: with the input
always live, `e` types an e and `q` types a q. The lane opens in list mode, and
`a` drops into the input.

```
bpBulk2                                  runner: on   N=1

  [x] loom    empty state copy
  [>] loom    bulk delete confirm
  [ ] loom    keyboard select on the row
  [ ] finish  bake in the filter prototype

  enter run  a add  e edit  m mode  x done  D delete  A all  q back
```

| List mode | Does |
| --------- | ---- |
| up/down, `j`/`k` | select |
| enter | run it now, attended, after a `y` |
| `a`, `i`, tab | the input, to file a new one |
| `e` | the item's file in `$EDITOR`, frontmatter and body |
| `m` | cycle its mode: loom, finish, free |
| `x` | done, or back to queued |
| `D` | delete it, after a `y` |
| `A` | show the done ones too |
| `r` | reload |
| `q` | back to the worktrees |

Marks are `[ ]` queued, `[>]` running, `[!]` blocked, `[x]` done. Only `y`
answers a confirmation, so a stray keystroke can only ever call one off.

There is no reorder key. Order is the number the filename starts with, in
steps of ten, so putting something first is `mv 030-foo.md 005-foo.md` and
nothing in the panel needs to know about it.

#### The three modes

`m` cycles them, and the mode decides what gets typed at the agent.

| Mode | Sends | For |
| ---- | ----- | --- |
| `loom` | `/loom --in <worktree> <body>` | the normal case: a request, built by the pipeline in that worktree |
| `finish` | `/loom-finish` | bake in a prototype you left in the tree. The body is your note to yourself; loom-finish reads the diff, not a request |
| `free` | the body, verbatim | anything else, a slash command included. The escape hatch |

The runner adds `--solo` to the first two. Running one by hand from the board
does not, which is the reason to run one by hand: you get loom's two ask
moments and can steer it.

#### Running one by hand

Enter on an item runs it right now, in its worktree, attended, whatever the
runner is doing. It still respects the one-per-worktree rule, so it refuses if
that lane already has something running. Use it for the first item on a branch,
where the ask moments are worth sitting through, and let the runner have the
rest.

### `m-run`

The runner. It walks the worktrees and keeps N of them working at once.

```bash
m-run              # what it is doing
m-run start        # on
m-run stop         # off. items already dispatched keep running
m-run n 2          # two lanes at a time
m-run tick         # one pass by hand, for when something looks stuck
m-run log          # tail the runner log
```

`s`, `S` and `+`/`-` on the board are the same controls, which is where you
will actually use them.

Each tick it reaps anything whose dispatcher died, then fills: walk the
worktrees from one past whoever went last, take the first that has queued work
and nothing running, stop once N lanes are busy. At N=1 that is one item from
each worktree in turn, round robin. Raise N and the same walk just fills more
lanes. Changing N takes effect on the next tick, so `+` on the board while a
run is in flight starts a second lane without restarting anything.

#### One running item per worktree, whatever N is

This is the invariant the whole thing rests on. A worktree is one working tree
and one branch, so two runs in it would fight over both and over the ledger.
So **N caps worktrees, not items**: set it above the number of worktrees with
queued work and the extra capacity simply goes unused.

The other half of that: items in one lane stack commits on one branch, so a
lane is one PR's worth of work. An item that deserves its own PR belongs in a
new worktree, not at the bottom of an existing lane.

#### What counts as finished

The item goes to the worktree's own claude in its herdr space, not to a
headless one. Those panes already run in auto mode, so there is no new
permission surface to open, and the run shows up in the sidebar where blocked
sorts to the top.

**A settled agent is not a finished run.** It means the turn ended, which is a
different claim, and herdr's own help says as much: its wait matches the first
settled state after submission, including the end of a turn already in flight.
Waiting on `idle` and `done` is what the dispatcher used to do, and it ended an
item thirteen minutes into an eight-hour run, freed the slot, and started
another worktree while that pane worked on until morning.

So the dispatcher waits on the run's own word. A loom run's last act is one line
at `artifacts/loom/<slug>-status`: the timestamp, `landed` or `blocked`, the
round, and why (the loom contract, "The end-of-run receipt"). The dispatcher
reads that line at dispatch and waits for it to change, so an earlier round's
receipt in the same file cannot be read as this one's. `landed` makes the item
done. Anything else marks it blocked, and the lane stays stopped, so the runner
cannot stack another item on top of a failure it cannot see. `note:` in the item
carries the receipt line.

herdr still answers the other half: `--until working` confirms the agent picked
the prompt up. It also backs the fallback, for a run that dies without writing a
receipt. That needs the pane settled for `MQUEUE_SETTLE_POLLS` passes *and* the
ledger untouched for `MQUEUE_QUIET`, because either alone lies - herdr has been
seen calling a live run `done`, and a run inside a long stage writes no ledger
for tens of minutes. A Land heading marked `[x]` still makes such an item done,
but only if the ledger moved after the item was dispatched. `MQUEUE_TIMEOUT` is
the last backstop.

An item can also be dispatched into a worktree whose agent is not there or is
busy. The runner skips that lane this tick and moves on rather than queueing
behind it; by hand you get the reason on the status line.

#### The store

```
~/m-code/mqueue/bpBulk2/020-bulk-delete-confirm.md
```

```markdown
---
id: bpBulk2/020-bulk-delete-confirm
title: bulk delete confirm
status: queued
mode: loom
created: 2026-09-04T14:03:11-04:00
---

bulk delete confirm
```

The body starts as the title, so the file is a usable spec from the first
second, and `e` is where it grows into one. The body is what gets typed at the
agent, so there is nothing to translate on the way out, and multiple lines are
fine: herdr pastes with bracketed paste and sends one Enter after the whole
thing.

`status` is `queued`, `running`, `blocked` or `done`. A run in flight also
carries `started`, `pid` and, once it ends, `finished` and `note`.

It is a git repo, committed on every add, edit, dispatch and status change, so
`git log -p bpBulk2/020-bulk-delete-confirm.md` is the record of how a rough
note became a spec and how the run went. `MQUEUE_GIT=0` turns that off and
`MQUEUE_ROOT` moves the store. Runtime state is not in there: N, the round
robin cursor, the runner pid and the logs live under
`${XDG_CACHE_HOME:-$HOME/.cache}/mqueue`, because none of it is worth
committing.

A worktree torn down leaves its lane behind, which is the point of the store
sitting outside the worktree. Nothing dispatches into a lane whose worktree is
gone.

#### It needs `loom-scout --in`

`/loom` used to always cut its own worktree and stop when the name was taken,
so it could not run in one you had already made. `loom-scout` now takes
`--in <dir>`, adopts that worktree, creates and resets nothing, and treats a
second request on the branch as a new `## Round <n>` in the one ledger the
branch already has, the way `loom-finish` already did. That is what makes a
per-worktree queue possible at all.

`finish` items need none of that, since `loom-finish` always ran in place.

### `mq [text]`

File an item against the worktree the shell is standing in, for when a pane is
free and the panel is a detour. It says nothing on success. No argument opens
the board.

```bash
cd ~/m-code/momentum-bpBulk2
mq keyboard select on the row
```

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
| `MQUEUE_ROOT`    | `$HOME/m-code/mqueue` | where the queues live               |
| `MQUEUE_GIT`     | `1`            | commit the store on every change             |
| `MQUEUE_TICK`    | `10`           | seconds between runner passes                |
| `MQUEUE_POLL`    | `20`           | seconds between checks for a run's receipt   |
| `MQUEUE_START_TIMEOUT` | `30000`  | ms to see the agent pick a prompt up         |
| `MQUEUE_SETTLE_POLLS`  | `15`     | settled polls before a receiptless run is given up |
| `MQUEUE_QUIET`   | `600`          | seconds of ledger silence that has to agree with them |
| `MQUEUE_TIMEOUT` | `14400000`     | ms before a dispatched item is called stuck  |

The dev timeout is generous on purpose: a cold worktree also builds .NET and
pulls containers. The queue timeout is four hours because that is a loom run
that has gone wrong rather than one taking its time. The fallback pair is slow
for the same reason: five minutes of a settled pane and ten of an untouched
ledger is a dead run, where either on its own is a normal middle of one.

State lives in `${XDG_CACHE_HOME:-$HOME/.cache}/m-dev`: `stack.log` (the stack's
own output), `action.log` (m-dev's progress on the current action), `stack.pgid`
and `action.pid`. `m-teardown` keeps its own next door in `m-teardown/`:
`status` (the last scan's verdicts), `action.log` and `action.pid`. `mqueue/`
holds the runner's: `n`, `cursor`, `runner.pid`, `runner.log` and one
`items/<id>.log` per dispatch.

## Headless Claude

`m-newwork` and `m-work` go through `_m_skill`, which runs the skill with
`claude -p --model sonnet` from `~/m-code/momentum` and allows only git, gh, jj
and uname. Everything else in these files is plain git and process handling with
no Claude in it, `m-teardown` included - it used to run `/teardown` headless and
now applies the same gates itself.

`mqueue.sh` runs no Claude of its own either. It types at the ones already
sitting in the herdr spaces, through `herdr agent prompt`, so a queued run
inherits whatever permissions that pane already had rather than needing a
headless session with its own grant.
