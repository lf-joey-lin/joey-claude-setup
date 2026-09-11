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
picks up an edit, since it restarts the service. It links seven files:

| local path                                          | this repo                                |
| --------------------------------------------------- | ---------------------------------------- |
| `~/.local/bin/herdr-teams-notify`                   | `herdr-teams/herdr-teams-notify`         |
| `~/.local/bin/herdr-teams-watch`                    | `herdr-teams/herdr-teams-watch`          |
| `~/.local/bin/herdr-teams-summary`                  | `herdr-teams/herdr-teams-summary`        |
| `~/.local/bin/herdr-teams-toggle`                   | `herdr-teams/herdr-teams-toggle`         |
| `~/.local/bin/herdr-teams-listen`                   | `herdr-teams/herdr-teams-listen`         |
| `~/.config/systemd/user/herdr-teams-watch.service`  | `herdr-teams/herdr-teams-watch.service`  |
| `~/.config/systemd/user/herdr-teams-listen.service` | `herdr-teams/herdr-teams-listen.service` |

The URL itself stays local. It is a bearer credential with no expiry: anyone holding
it can post to the channel, so it never goes in the repo.

For the way back in, make the second flow too and drop its URL beside the first:

```bash
printf '%s' '<the replies flow URL>' > ~/.config/herdr/teams-replies-webhook
chmod 600 ~/.config/herdr/teams-replies-webhook
bash herdr-teams/setup.sh
```

Without that file the listener stays stopped and setup says so, rather than enabling a
unit that would restart-loop. See [Replies](#replies) for what the flow contains.

## Daily use

Nothing to start. The service comes up with the WSL login session, independent of
herdr, and polls whether herdr is running or not.

`ctrl+alt+y` opens the panel. `[space]` is **teams-sync**, both halves at once, which is
the normal way to use it; `[c]` and `[i]` still flip one on its own. Under that:
autostart, restart, logs, the startup lines that say whether either half is really
working, and [the agent poll table](#the-agent-poll-table). `ctrl+alt+shift+y` flips
teams-sync without the panel, for walking out of the room, and toasts what it did.

Both halves are on by default and start with WSL. Cards without replies is the setting
worth knowing about: Teams can page you while nothing in Teams can type into a live
agent. That is what `[c]` and `[i]` are for, and the panel says `PARTIAL` when the two
disagree rather than picking one of them to report.

```bash
herdr-teams-toggle                            # the same panel in a shell
herdr-teams-toggle toggle                     # teams-sync, both halves; or on / off / status
herdr-teams-toggle cards                      # cards only, or cards-on / cards-off
herdr-teams-toggle replies                    # replies only, or replies-on / replies-off
herdr-teams-toggle next                       # one line: is it on, next pass, and this thread's tier
systemctl --user status herdr-teams-watch     # is it alive
systemctl --user stop herdr-teams-watch       # quiet, at the desk
systemctl --user start herdr-teams-watch      # heading out
journalctl --user -u herdr-teams-watch -f     # what it is deciding, live
herdr-teams-notify "title" "body" "K=v"       # send one by hand
herdr-teams-notify --thread ag:<session> "title" "body"   # starts or replies in a thread
herdr-teams-notify --dry-run "title" "body"        # print the payload, post nothing
herdr-teams-summary <session-id>              # what did that agent last say
herdr-teams-summary --now <session-id>        # what is it doing this second
herdr-teams-summary --loom <id> <cwd>         # how far through its loom run
```

`status` reporting `active` is weaker than it looks, see the traps below. The startup
line in the journal is the real check:

```
watching every 5s; finished=done idle, plus blocked; heartbeat 15m; one thread per session
```

If the clause is missing altogether the running watcher predates the threads code,
which is what a `systemctl --user restart` fixes: the scripts are symlinks into this
repo, so editing one does not touch the process already running.

## What sends a card

Every 5 seconds the watcher runs `herdr agent list` over herdr's socket and compares
each agent's state to the last time it looked.

| when                               | card                        | how                        |
| ---------------------------------- | --------------------------- | -------------------------- |
| anything to `blocked`              | `<worktree>: needs input`   | reply in the agent's thread |
| `working` to `done` or `idle`      | `<worktree>: finished`      | reply in the agent's thread |
| every 15 min while still `working` | `<worktree>: still working` | reply in the agent's thread |

The first of those for an agent starts its thread; the rest reply under it. A turn
merely starting sends nothing, so the thread opens on the first thing worth reading.

**Only the thread's first post is an Adaptive Card. The replies under it are formatted
text**, because Teams puts text in the phone notification, where a card only ever shows
up as "sent a card". Every call carries both shapes and the flow picks: the card out of
`attachments` when it is starting a thread, the HTML out of `text` when it is replying.

**A body too long for one post is split across replies**, so a long answer arrives whole
instead of stopping mid-sentence. The first chunk is the card, the rest reply under it
carrying `n/N` as their title rather than repeating the title and facts. The split is not
a plain character count: `md2html` below tells code from prose by counting ``` fences, so
a chunk holding an odd number of them would render every later segment inverted. A block
that has to be broken is closed at the break and reopened with its own language tag on
the far side, which is why the fence count goes up and the content still round-trips.

The cost is one phone notification per chunk, which is the reason `HERDR_TEAMS_CHUNK` is
2000 rather than something smaller. `HERDR_TEAMS_MAX_CHUNKS` stops a runaway body from
becoming fifty of them; past it the last chunk says how much was dropped.

## What is on the card

The title is the worktree and what happened. Under it, a `Task` fact carrying the pane
title, and `Took`, the length of the turn. As a reply that is `<b>title</b>` then one
`<b>Task:</b> value` line per fact, then a blank line and the body. Title, facts and
body are all HTML-escaped on the way in; Claude output is full of angle brackets, and
one unescaped `<Foo>` in a diff would swallow the rest of the message.

The body then has its markdown turned into HTML, because `text` is rendered as HTML and
nothing else: without it a `##` heading and a fenced block arrive as those literal
characters. Headings and `**bold**` become `<b>`, backticks become `<code>`, and a fence
becomes `<pre>`, which Teams stores as a `<codeblock>` and renders as one. Fences are
split off first, so a `#` inside a block stays a `#`. Headings are bold rather than
`<h2>` because the message already opens with a bold title and a real heading outranks
it. Single `*` and `_` are left alone: they would eat `pane_id` and shell globs, and
Claude writes `**` anyway.

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

One thread per agent instead of a card per event. The first card for a key starts a
thread and the flow answers with its id; every later card for that key carries the id
and lands as a reply under the first. An agent's whole run is one collapsible thread
rather than a dozen top-level cards.

The key is the Claude session id, which survives a watcher restart and a herdr session
restore, so an agent keeps the same thread from first sighting to the end.
`HERDR_WATCH_THREAD_KEY=worktree` keys on the directory instead, which gives a worktree
one thread across separate Claude runs and has two panes in the same worktree share it.

The id is remembered here rather than in the flow: one small file per key under
`~/.local/state/herdr/teams-threads` holding nothing but the id. Go a day without a
card and the file is dropped, so tomorrow's run opens a fresh thread instead of
replying under yesterday's (`HERDR_TEAMS_THREAD_TTL`, in seconds; every card refreshes
it). When a reply fails, which is what a card someone deleted looks like, the id is
forgotten and the same card is re-sent as a new thread, so one dead thread cannot
silence an agent for good.

There is no "rewrite the top card in place" any more. The flow posts and replies, so
every card notifies and the thread reads as a log rather than a status board.

Check it after touching the flow:

```bash
K=probe:$(date +%s)
herdr-teams-notify --thread "$K" "probe 1" "starts the thread"
herdr-teams-notify --thread "$K" "probe 2" "should sit under probe 1"
```

### The flow

Power Automate, **When a Teams webhook request is received**, "anyone" can trigger.
Replies exist only in channels: post to a chat and there are no threads at all.

```
Initialize variable  Body     = triggerBody()
Initialize variable  ThreadId = coalesce(triggerBody()?['threadId'], '')
Select                        attachments[] -> their .content
Initialize variable  Cards    = those contents, or [string(Body)] when there are none
Condition: ThreadId is empty
  yes   Post card in a chat or channel   (Cards[0])
        ThreadId = the new card's body/id
        foreach skip(Cards, 1)           reply under ThreadId
  no    Reply with a message in a channel  ThreadId, triggerBody()['text']
Response  200  { threadId, created }
```

The reply branch is a **message**, not a card, which is the whole of the formatting
change. The designer's rich text box wraps the token, so the stored parameter reads
`<p class="editor-paragraph">@{triggerBody()['text']}</p>`. That is fine: Teams renders
the inner HTML and drops the class. The `foreach skip(Cards, 1)` in the yes branch is a
no-op, since the notifier only ever sends one attachment.

Two things it turns on:

- **The `Response` action**, which is what hands the id back. The note here used to say
  that needs the premium HTTP-request trigger. It does not: the Teams webhook trigger
  answers with it, 200 and a body. That is what took the key-to-id map out of the flow,
  and with it a SharePoint list, a concurrency limit of 1 so two runs for one key cannot
  both start a thread, and a healing path for a deleted card. It is also why the
  notifier no longer sends a `threadKey` or a `threadAction`.
- **`body/id` from the Post action really being the message id.** Worth checking in one
  run's history, because a wrong value fails on the *next* card rather than this one.

## Replies

A reply typed under an agent's card goes back to that agent. `herdr-teams-listen` is
the way in, the mirror of the watcher.

Nothing can reach this box, for the same reason the cards go out through a webhook in
the first place, so the listener is not pushed to. It polls. No Teams trigger would
help anyway: **"When a new channel message is added" does not fire on replies**, only
on root messages.

What it polls is a second flow, not Graph. That is what keeps it clear of an Entra app
registration and of `ChannelMessage.Read.All` admin consent, which is where this idea
died the first time. The flow reads the thread under the Teams connection already
sitting there.

### The second flow

**Read herdr thread replies**, `4c197b4f-38d9-4de6-b82b-b490d2af6d33`. Three steps, all
standard tier:

- **When a Teams webhook request is received**, "Anyone" can trigger, same as the notify
  flow. Takes `{"threadId": "<the root card's message id>"}`.
- **List replies of a channel message** on the herdr team and channel, `Message` =
  `@triggerBody()?['threadId']`, latest replies count 50.
- **Response**, 200, body `@body('List_replies_of_a_channel_message')`.

The URL lives in `~/.config/herdr/teams-replies-webhook`, mode 600, out of the repo,
like the notify one. Treat it as the larger of the two: this flow *reads* channel
content, so the URL plus a message id is enough to read the replies under that card.

Two designer traps, both of which cost time:

- The expression box rejects `triggerBody()?['threadId']` as "This expression has a
  problem" and greys nothing out, it just refuses to add. Type it without the `?`. The
  designer stores it back as the safe `?['...']` form anyway, which Code view confirms.
- The Team picker does not list `herdr`, because it is a private channel. Take **Enter
  custom value** and paste the group id `57fa4060-5a10-4c09-8236-57c8a7e8956d`. The
  Channel dropdown then resolves and `herdr` is in it.

### What the listener polls

Every `HERDR_LISTEN_INTERVAL` seconds (default 180) it runs `herdr agent list` and polls
an agent's thread only when all of this holds:

- the agent is **not `working`**. A reply typed at an agent mid-turn lands in its prompt
  box rather than being answered, so it waits for the turn to end
- the agent has a thread, which is the file `herdr-teams-notify` already writes
- the thread has not expired, meaning its last card is inside `HERDR_LISTEN_DEAD`
  (default 86400s)
- it is that thread's turn. How often a thread is polled decays with the age of its last
  card, because nobody is usually mid-reply half an hour on and polling everything every
  pass burns the quota:

| tier      | last card                            | polled          |
| --------- | ------------------------------------ | --------------- |
| `hot`     | under `HERDR_LISTEN_HOT`, 1800s      | every pass      |
| `warm`    | under `HERDR_LISTEN_COLD_UNTIL`, 3600s | every `HERDR_LISTEN_COLD_EVERY`, 1800s |
| `cold`    | under `HERDR_LISTEN_DEAD`, 86400s    | every `HERDR_LISTEN_COLD_SLOW_EVERY`, 3600s |
| `expired` | past `HERDR_LISTEN_DEAD`             | never           |

A reply that lands puts its thread back on `hot`, so a conversation you are in the
middle of is read every pass whether or not a card is still arriving.

That ladder is the whole reason this is affordable, see below.

New replies are the ones newer than a per-thread cursor under
`~/.local/state/herdr/teams-replies`. A thread seen for the first time records the clock
and delivers nothing, the same rule the watcher uses for an agent it has not seen:
without it every restart replays the thread into the agent.

Every pass ends with a line saying what it did and when the next one is, because an idle
loop looks exactly like a dead one and nothing else answers "when will my reply be read":

```
4:22PM polled 1 thread(s), delivered 0; next 4:25PM, then 4:28PM and 4:31PM
4:25PM nothing to poll: 1 working, 11 with no thread, 0 gone cold; next 4:28PM, then 4:31PM and 4:34PM
```

The second form is the one worth having: it names which of the three gates above is
holding things up, so a reply that is going nowhere is not a silent wait. The two extra
times are dropped when the interval is under a minute, where they round to the same
clock minute and read as a bug.

### One line for a footer

`herdr-teams-toggle next` is the table's answer to "when will my reply be read", in one
line, for pasting at the bottom of something else. It reports the sync, the next pass,
and the calling agent's own thread:

```
teams-sync ON, next pass 5:12PM (in 2m); thread hot until 5:40PM, then every 30m
teams-sync ON, next pass 5:12PM (in 1m); thread warm, next poll 5:25PM (in 14m), cold at 5:30PM
teams-sync ON, next pass 5:12PM (in 1m); thread cold, next poll 5:45PM (in 35m), dropped at 3:47PM tomorrow
teams-sync PARTIAL: cards out only, no reply can come back
teams-sync OFF
```

The tier half is what makes it worth reading: on the hot tier a reply is picked up at the
next pass, and off it a reply waits for that thread's own slower poll instead. The clock
says when the fast window closes.

It finds its own row by `HERDR_PANE_ID`, which herdr sets in every agent's environment,
so the row is the one for the agent running the command. That is also why the status file
carries a pane per row: the display name is suffixed for duplicates and no session id is
written to the file. Outside an agent there is no row and the tier half is left off.

While an agent is working, the window is measured from now rather than from the card
already in the channel, because ending the turn sends a card and that card resets the
thread to hot. So the clock in a footer is the one that applies to the reply being read.
`next --sending` says that outright, for a caller posting a card right now: measure the
window from this card, not from the one it is about to replace.

`herdr-teams-watch` puts the line on every card it sends, as a `Sync:` fact, by calling
`next --sending` with that agent's own `HERDR_PANE_ID`. Nothing else has to add it.

This used to be Claude's job, told to it by the WSL `~/.claude/CLAUDE.md`, and it failed
the way an instruction to an agent fails: one session ended two replies with
`herdr-teams-toggle: command not found` having never run the command, on a machine where
it runs fine. A sender cannot forget the line and cannot invent it. The trade is that the
line now sits in a fact row at the top of the card rather than at the foot of the reply,
and that a missing or slow toggle costs the fact but never the card.

### The agent poll table

The journal says what the pass did as a whole. The panel says it per agent, which is
where "when will my reply be read" is actually answered:

```
agents:        pass 3:18PM, 11s ago
  tiers: hot under 30m polls every pass, warm under 1h every 30m, cold every 1h, dropped at 1d
  agent                      state    tier    card age every     last poll next       last pass
  momentum-aspire-local-dev  idle     hot     5m       each pass 2m ago    3:21PM     polled
  momentum-inbox             blocked  warm    33m      30m       12m ago   3:50PM     backoff
  momentum-docs              done     cold    1h23m    1h        41m ago   4:20PM     backoff
  momentum                   working  none    -        -         never     after turn working
```

Two agents in one worktree would otherwise be two rows called `momentum`, so a repeated
name is numbered `-1`, `-2` in pane order. The numbering is by pane rather than by the
order herdr lists agents in, so a row keeps its number for as long as both panes live. A
name used once is left alone.

`card age` is how long since the last card in that thread, which is what picks the tier;
`every` is that tier's cadence, `each pass` on `hot`. `next` is the clock its next poll
lands on, or the reason there isn't one: `after turn` for a working agent, `no thread`
for one that has never carded, `expired`. `last pass` is what the listener did with it
last time round: `polled`, `delivered`, `backoff`, `seeded`, `expired`, or `flow-down`
when the Power Automate call failed.

The listener writes the table itself at the end of every pass, to
`~/.local/state/herdr/teams-listen-status`, and the panel only renders it. That is the
point: the panel cannot report a tier the listener is not really using. It also means
the table is as old as the last pass, so the header carries the pass time, and the panel
marks it `STALE` when replies are off or no pass has landed in two intervals.

### How the text gets in

`herdr agent prompt` is the clean way, and it is what a non-blocked agent gets. It does
not work on a blocked one: **herdr rejects a prompt to a blocked agent with
`agent_blocked` before any input is sent**, which is right, because a blocked agent is
sitting at a menu and not at a prompt box. There the listener does what a person at the
keyboard would, `herdr pane send-text` then `herdr agent send-keys enter`.

So a reply of `2` answers a numbered permission prompt, and a sentence answers an
`AskUserQuestion` exactly as well as typing that sentence at the menu would, which is
the honest limit here. The prompt path, for an agent that has finished, takes anything.

Only replies whose author is `HERDR_LISTEN_USER_ID` are forwarded, and the unit pins it
to Joey's Entra object id. The channel is private, so that is a second lock rather than
the only one, but what is on the other end types into a live Claude with auto mode on.

**Before that filter runs, anything with no `from.user` is dropped, and that line is
load-bearing.** herdr's own replies are posted by the Flow bot, which carries
`from.application` instead. They used to be Adaptive Cards, whose `body.content` is just
`<attachment id="..."></attachment>` and strips to nothing, so they were harmless by
accident. Now that replies are real text, an unset `HERDR_LISTEN_USER_ID` without that
line would feed every card herdr sends straight back into the agent that caused it.
Tested: a thread holding two bot replies, listener with no user id set, nothing
forwarded.

### What it costs

Every action in a run is a Power Platform request and an Office 365 seeded licence is
6,000 per user per 24 hours, shared with the cards flow. This flow is four actions, so
one thread polled every 180s around the clock would be about 1,900 by itself. The
not-working gate and the tier ladder are what hold it to a few hundred: a thread only
costs full price inside the window where you might really be replying to it.

`HERDR_LISTEN_INTERVAL=60` is fine for one thread and not for four. Long polling is
worse, not better: a `Do until` with a 5s `Delay` spends about 60 requests per 100
seconds against about 35 for plain polling, for the same latency.

### Running it

```bash
herdr-teams-toggle replies        # or replies-on / replies-off
herdr-teams-toggle status         # both units, both URLs, the poll table, last cards and replies
herdr-teams-toggle next           # the same thing in one line, for a footer
journalctl --user -u herdr-teams-listen -f
herdr-teams-listen 60             # foreground, faster, for a test
```

`ctrl+alt+y` shows both halves, `[space]` flips the pair and `[i]` flips this one.

## Long runs

A loom run is one Claude turn that lasts an hour. Its subagents are Task calls inside
that turn, so herdr sees a single agent sitting in `working` the whole time: without a
heartbeat the first card arrives when the run is already over.

So every 15 minutes an agent that is still working gets a card, as a reply in its own
thread. The body is its newest tool call, and there are two facts: `Running`, how long
the turn has been going, and for a loom run `Loom`, read from the run ledger.

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

**A payload the flow cannot render now fails as a 502, and so does a stale thread id.**
It used to be worse: the webhook answered 202 to any JSON at all, so a shape it could
not render looked exactly like one it could and posted nothing. Now the trigger's answer
is the flow's own `Response`, so a payload with no `attachments` reaches the Post action
as raw text, the Teams connector rejects it, and the caller gets `502 NoResponse` with
no card. Louder, but note the ambiguity it buys: a reply to a card that no longer exists
fails identically. That is why the notifier treats a failed reply as a dead thread and
re-sends as a new one, and why it still builds one payload shape only.

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

The ceiling on a single post is not established. Teams and the flow both have one, but
neither is documented anywhere worth trusting, so `HERDR_TEAMS_CHUNK` is set well under
any size that has been refused rather than at a measured limit. Escaping is what makes
the margin necessary: every `<` becomes four bytes on the wire and every newline becomes
a `<br>`, so 2000 characters of body can reach roughly 8KB of payload.

Not output only any more. Replying from the phone works, see [Replies](#replies). It
needs no Entra app registration and no `Chat.ReadWrite` consent, because the second
flow reads the thread under Joey's own Teams connection and hands the text back over
the same kind of webhook URL.

## Notes

`/mnt/c` is mounted without the `metadata` option, so everything there reads as
`0777` and `chmod +x` is a no-op. The scripts run from the repo anyway, but do not
read the mode as meaningful.

Tunables, all read from the environment, all fine as they are:
`HERDR_WATCH_FINISHED` (default `done idle`), `HERDR_WATCH_HEARTBEAT` (default 900
seconds), `HERDR_WATCH_THREADS` (default `1`), `HERDR_WATCH_THREAD_KEY` (default
`session`, or `worktree`), `HERDR_TEAMS_THREAD_TTL` (default 86400 seconds of silence
before a thread is dropped), `HERDR_TEAMS_STATE_DIR` (default
`~/.local/state/herdr/teams-threads`), `HERDR_SUMMARY_MAX` (default 12000 characters of
body), `HERDR_TEAMS_CHUNK` (default 2000 characters per post), `HERDR_TEAMS_MAX_CHUNKS`
(default 12), `HERDR_TEAMS_CHUNK_DELAY` (default 1 second between posts), and the poll
interval as `$1`.
