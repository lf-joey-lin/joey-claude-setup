# Teams notifications for herdr agents

Pings Microsoft Teams when a Claude agent finishes a turn or blocks waiting for an
answer, so a run left going in another worktree reaches a phone instead of sitting
there until someone goes and looks.

The herdr sidebar already answers this at the desk. This is the same signal for when
you are not at the desk.

## Why Teams and not a VPN

Tailscale, Dev Tunnels and VS Code Remote Tunnels are all blocked on the corporate
network. Zscaler returns `403 Not allowed to browse Anonymizer category` for every
`*.tailscale.com` host, `global.devtunnels.ms` and
`global.rel.tunnels.api.visualstudio.com`. `controlplane.tailscale.com` is the fatal
one: without it a tailnet cannot form, so sideloading the binaries changes nothing.

Microsoft 365 is not merely allowed, it is not even TLS-intercepted. `graph.microsoft.com`,
`outlook.office.com` and `*.logic.azure.com` all present real Microsoft certificates.

The deeper reason it works is that nothing has to be reachable. Every blocked option
needs an inbound path to a WSL box behind NAT behind Zscaler. Posting to a webhook is
outbound HTTPS, so the question never comes up.

## Setup

Create the flow in Teams first. Power Automate, "When a Teams webhook request is
received", posting an Adaptive Card to the channel you want. Copy the flow URL, then:

```bash
printf '%s' '<the flow URL>' > ~/.config/herdr/teams-webhook
chmod 600 ~/.config/herdr/teams-webhook
bash herdr-teams/setup.sh
```

Needs `herdr` and `jq`. Safe to re-run, and re-running is how the running watcher
picks up an edit, since it restarts the service. It links five files:

| local path                                          | this repo                                |
| --------------------------------------------------- | ---------------------------------------- |
| `~/.local/bin/herdr-teams-notify`                   | `herdr-teams/herdr-teams-notify`         |
| `~/.local/bin/herdr-teams-watch`                    | `herdr-teams/herdr-teams-watch`          |
| `~/.local/bin/herdr-teams-summary`                  | `herdr-teams/herdr-teams-summary`        |
| `~/.local/bin/herdr-teams-toggle`                   | `herdr-teams/herdr-teams-toggle`         |
| `~/.config/systemd/user/herdr-teams-watch.service`  | `herdr-teams/herdr-teams-watch.service`  |

The URL itself stays local. It is a bearer credential with no expiry: anyone holding
it can post to the channel, so it never goes in the repo.

## Daily use

Nothing to start. The service comes up with the WSL login session, independent of
herdr, and polls whether herdr is running or not.

`ctrl+alt+y` opens the panel: on/off, autostart, restart, logs, and the startup line
that says whether the watcher is really working. `ctrl+alt+shift+y` flips it without
the panel, for walking out of the room, and toasts what it did.

```bash
herdr-teams-toggle                            # the same panel in a shell
herdr-teams-toggle toggle                     # or on / off / status
systemctl --user status herdr-teams-watch     # is it alive
systemctl --user stop herdr-teams-watch       # quiet, at the desk
systemctl --user start herdr-teams-watch      # heading out
journalctl --user -u herdr-teams-watch -f     # what it is deciding, live
herdr-teams-notify "title" "body" "K=v"       # send one by hand
herdr-teams-notify --thread ag:<session> --action reply "title" "body"
herdr-teams-notify --thread ag:<session> --action update "title" "body"
herdr-teams-notify --dry-run "title" "body"        # print the payload, post nothing
herdr-teams-summary <session-id>              # what did that agent last say
herdr-teams-summary --now <session-id>        # what is it doing this second
herdr-teams-summary --loom <id> <cwd>         # how far through its loom run
```

`status` reporting `active` is weaker than it looks, see the traps below. The startup
line in the journal is the real check:

```
watching every 5s; finished=done idle, plus blocked; heartbeat 900s; threads off
```

It ends `one thread per session` once the flow is taught threads and the service stops
pinning them off. If the clause is missing altogether the running watcher predates the
threads code, which is what a `systemctl --user restart` fixes: the scripts are
symlinks into this repo, so editing one does not touch the process already running.

## What sends a card

Every 5 seconds the watcher runs `herdr agent list` over herdr's socket and compares
each agent's state to the last time it looked.

| when                                   | card                        | how                    |
| -------------------------------------- | --------------------------- | ---------------------- |
| anything to `blocked`                  | `<worktree>: needs input`   | reply in the thread    |
| `working` to `done` or `idle`          | `<worktree>: finished`      | reply in the thread    |
| every 15 min while still `working`     | `<worktree>: still working` | reply in the thread    |
| a turn starts, and with each row above | `<worktree>: <state>`       | rewrites the root card |

The first three notify you. The last one does not: it rewrites the thread's root card
in place so the thread opens on what the agent is doing now, and Teams does not count
an edit as new activity.

## What is on the card

The title is the worktree and what happened. Under it, a `Task` fact carrying the pane
title, and `Took`, the length of the turn.

The body is what Claude actually said, read out of its own transcript rather than
scraped off the terminal. `herdr agent list` hands over the session id, and the
transcript sits at `~/.claude/projects/<cwd-with-dashes>/<session-id>.jsonl`.
`herdr-teams-summary` reads that file backwards and takes the first useful thing:

- the turn recap Claude writes at the end of a turn (`away_summary`), which is already
  a two-line "here is what I did, here is the decision waiting on you"
- failing that, the text of its last message, for when recaps are off in `/config`
- and when the turn ended on a tool call rather than a message, which is what `blocked`
  usually is, the pending tool instead: `Waiting on Bash: git push ...`

Reading backwards is what keeps it cheap on a megabyte of transcript, and it is also
what gets the recap in preference to the message, since the recap is written after it.

No transcript means no body, and the card falls back to the `Task` fact alone. That
happens for an agent that is not Claude, or a session id that has moved.

An agent the watcher has never seen is recorded silently and never announced.
Without that, every herdr session restore fires a burst of stale "finished" cards for
work that ended yesterday.

`done` fires at the end of every Claude turn, not once per task. Away from the desk
that is the point. At the desk it is noise, hence `systemctl --user stop`.

## Threads

One thread per agent instead of a card per event. The watcher sends a `threadKey` with
every card and the flow keeps one root card per key: `--action update` rewrites that
card, `--action reply` posts underneath it. So an agent's whole run is one collapsible
thread whose top line is always current, rather than a dozen top-level cards.

The key is the Claude session id, which survives a watcher restart and a herdr session
restore, so an agent keeps the same thread from first sighting to the end.
`HERDR_WATCH_THREAD_KEY=worktree` keys on the directory instead, which gives a worktree
one thread across separate Claude runs and has two panes in the same worktree share it.

**The flow has to be taught this, and until it is, threads stay off.** A flow that
ignores `threadKey` posts everything top-level, so the root-card updates arrive as
extra cards instead of edits. Nothing breaks, it just gets noisy. The service pins
`HERDR_WATCH_THREADS=0` for that reason, so turning threads on is deleting that one
line from `herdr-teams-watch.service` and re-running `setup.sh`.

As of 2026-09-02 the flow is the untaught one. Three probe cards sent to a single
`threadKey`, two as `update` and one as `reply`, arrived as three separate top-level
cards. That is the check to repeat after editing the flow:

```bash
K=probe:$(date +%s)
herdr-teams-notify --thread "$K" --action update "probe 1" "should be replaced"
herdr-teams-notify --thread "$K" --action update "probe 2" "should replace probe 1"
herdr-teams-notify --thread "$K" --action reply  "probe 3" "should sit under probe 2"
```

One card reading "probe 2" with "probe 3" nested under it means it works.

### What the flow needs

Replies exist only in channels. If the flow posts to a chat there are no threads at
all, and `update` is the only consolidation available.

Three actions, all in the Microsoft Teams connector:

- **Post card in a chat or channel**, which returns the new message's id
- **Reply with an adaptive card in a channel**, which takes that id
- **Update an adaptive card in a chat or channel**, which takes that id and replaces
  the whole card, subject included

That id is the whole problem. The webhook trigger answers 202 and nothing else, and
returning a value needs the `Response` action, which needs the HTTP-request trigger,
which is Power Automate Premium. So the key-to-id map has to live in the flow rather
than out here. Everything below is standard connectors only, no premium.

Matching on the message instead of storing the id does not work, so do not go looking
for it. **Get messages** returns an adaptive-card post with a body of
`<attachment id="..."></attachment>` and no card text at all, and the Post action sets
no subject, so there is nothing in a returned message to recognise a thread by.

#### The list

A two-column SharePoint list on the channel's own team site, called `herdr threads`:
`Title` (the built-in column) holds the thread key, `MessageId` (single line of text)
holds the id.

#### The flow

Trigger: **When a Teams webhook request is received**, "anyone" can trigger.

Paste a real payload into the trigger's **Request Body JSON Schema** box, or
`threadKey` and `threadAction` never appear in the designer's dynamic-content list and
you end up hand-writing every reference to them. `herdr-teams-notify --dry-run` prints
one:

```bash
herdr-teams-notify --dry-run --thread ag:demo --action update "title" "body" "Task=demo"
```

Then, in order:

1. Condition `empty(triggerBody()?['threadKey'])`. True goes to **Post card** and
   stops. That is the hand-sent `herdr-teams-notify` case, and today's whole flow.
2. False: **Get items** on `herdr threads`, Filter Query
   `Title eq '@{triggerBody()?['threadKey']}'`, Top Count 1.
3. Condition `empty(body('Get_items')?['value'])`.
   - True: **Post card**, then **Create item** with `Title` = the thread key and
     `MessageId` = the id the post returned. This is also what makes a first
     `--action reply` or `--action update` work, so the watcher never has to know
     whether a thread exists yet.
   - False: the id is `first(body('Get_items')?['value'])?['MessageId']`. Condition
     `equals(triggerBody()?['threadAction'], 'update')`. True goes to **Update an
     adaptive card**, false to **Reply with an adaptive card**.

All three card actions take the same card input, so paste the expression the existing
Post card action already uses into the other two rather than deriving it again.

Two things to get right, both of which fail quietly:

- **Check which output field actually carries the message id**, by opening one run's
  history. The map is worthless if it stores the wrong thing, and a wrong id fails on
  the *next* card rather than this one.
- **Set the flow's concurrency to 1** (Settings, Concurrency Control, degree of
  parallelism 1). Step 2 reads the list and step 3 writes it, and the pair is not
  atomic: two runs for a new key that overlap both find no row and both post a root
  card, so that agent ends up with two threads. The watcher sends serially, but Power
  Automate runs do not, and a handful of parallel worktrees is enough to overlap.

Worth hardening once it works. Point the Update branch's failure path at Post card plus
an overwrite of the row, so a root card someone deleted by hand heals itself instead of
failing every card after it.

## Long runs

A loom run is one Claude turn that lasts an hour. Its subagents are Task calls inside
that turn, so herdr sees a single agent sitting in `working` the whole time: without a
heartbeat the first card arrives when the run is already over.

So every 15 minutes an agent that is still working gets a card, as a reply in its own
thread. The body is its newest tool call, and there are two facts: `Running`, how long
the turn has been going, and for a loom run `Loom`, read from the flight ledger. The
root card is refreshed at the same moment, so the thread's top line never lags the
replies under it.

```
momentum-virtualizeTable: still working
  Task:     Item 702690
  Running:  38m
  Loom:     R1.S2 The virtualize switch on DataTable (4/9 done)

  Agent: Probe slice 2
```

`herdr-teams-summary --loom` finds `artifacts/loom/<slug>-ledger.md` by walking up
from the agent's cwd, since the ledger sits at the worktree root while the agent
usually runs a few directories inside it. It counts the `- [x]` stage headings against
all of them and names the furthest one reached. No ledger means no `Loom` fact, which
is every non-loom session.

`Running` comes from the transcript, not from when the watcher started looking, so
restarting the service mid-run still reports the true elapsed time.

The two `AskUserQuestion` moments in an attended run are a separate thing and already
worked: they put the agent in `blocked`, so they card immediately rather than waiting
for the next heartbeat.

`HERDR_WATCH_HEARTBEAT=0` turns it off; the number is seconds.

## Traps

Three things here look like success and are not. All three were hit while building it.

**A wrong payload shape returns HTTP 202.** The flow accepts any JSON and queues, so
a shape it cannot render answers exactly like one it can. Only the Adaptive Card
shape actually posts. `{"text": ...}`, `{"body": ...}`, `{"message": ...}` and
`{"title":..., "text":...}` all returned 202 and rendered nothing. That is why the
notifier builds one shape only, rather than carrying a switch that can silently do
nothing.

**A systemd user service has no `~/.local/bin` on its PATH.** Its PATH is
`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`, so `herdr` and
`herdr-teams-notify` do not resolve, every poll finds nothing, and the unit sits there
reporting `active` while doing absolutely nothing. The watcher now resolves both by
absolute path, the unit sets an explicit PATH, and failures are logged to journald
instead of being swallowed. Testing a script in an interactive shell proves nothing
about how it behaves under systemd.

**`done` decays to `idle`.** The agent-detection manifest never emits `done` at all
(`grep -c 'state = "done"'` returns 0); herdr derives it server-side and it settles to
`idle` afterwards. Keying only on `done` misses any completion the 5-second poll
happens to straddle. The rule is "left the `working` state", which is why `idle`
counts as finished, and why a finish only counts coming out of `working`. Focusing a
finished pane moves it `done` to `idle` and must not page you a second time.

## Limits

The service dies with the last WSL session (`Linger=no`) and WSL does not run while
Windows sleeps, so cards flow while the desktop is awake. `loginctl enable-linger`
fixes the first half and not the second.

Worst case a blocked agent is 5 seconds late. `herdr-teams-watch 2` if that ever
matters, though it will not.

Output only. Replying from the phone is a different job: it needs Graph API polling
and an Entra app registration, and the consent for `Chat.ReadWrite` is the thing to
check before writing any of it.

## Notes

`/mnt/c` is mounted without the `metadata` option, so everything there reads as
`0777` and `chmod +x` is a no-op. The scripts run from the repo anyway, but do not
read the mode as meaningful.

Tunables, all read from the environment, all fine as they are:
`HERDR_WATCH_FINISHED` (default `done idle`), `HERDR_WATCH_HEARTBEAT` (default 900
seconds), `HERDR_WATCH_THREADS` (script default `1`, pinned to `0` by the service until the
flow reads `threadKey`), `HERDR_WATCH_THREAD_KEY` (default
`session`, or `worktree`), `HERDR_SUMMARY_MAX` (default 1200 characters of body), and
the poll interval as `$1`.
