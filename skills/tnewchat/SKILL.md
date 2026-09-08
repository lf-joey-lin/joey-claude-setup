---
name: tnewchat
description: Start a fresh Claude session in the main momentum worktree and open a Teams thread for it, so a new chat can be carried on from the phone. Takes an optional first prompt, which is handed to the new session verbatim rather than answered here. Invoke when the user types /tnewchat, or asks to "start a new chat", "open a new claude in momentum", "give me a fresh Teams thread", or "spin up a session and ask it X".
---

# tnewchat: a fresh session, announced in Teams

Start a new Claude in `~/m-code/momentum` (the read-only reference worktree, the
home for work that is not about one branch) and post the card that opens its
Teams thread. Replies typed under that thread reach the new session through
`herdr-teams-listen`, so this is how a chat gets started from away from the desk.

This skill starts a session and stops. It writes no code, and when a first prompt
is given it hands that prompt over rather than answering it here.

## Invocation

```
/tnewchat [first prompt]
```

With no argument the new session just comes up idle and the card says
`New chat ready`. With an argument the text is delegated to the new session
verbatim, and this session does not wait for the answer - the new session's own
finished card carries it.

## Steps

Run these from wherever the calling session already is; nothing depends on the cwd.

1. **Find the momentum space.**

   ```bash
   herdr workspace list |
     jq -r '.result.workspaces[] | select(.worktree.checkout_path == "/home/joeylin/m-code/momentum") | .workspace_id'
   ```

   Empty means the space is not open. Create it and take
   `.result.workspace.workspace_id`:

   ```bash
   herdr worktree open --cwd /home/joeylin/m-code/momentum \
     --path /home/joeylin/m-code/momentum --label momentum --no-focus
   ```

2. **New tab in that space**, and take `.result.root_pane.pane_id`:

   ```bash
   herdr tab create --workspace <ws> --cwd /home/joeylin/m-code/momentum \
     --label chat --no-focus
   ```

   `--no-focus` because this usually runs for someone who is not at the desk.

3. **Start Claude in that pane.** The name must match `[a-z][a-z0-9_-]{0,31}` and
   the momentum space holds other agents, so make it unique. Take the session id
   from `.result.agent.agent_session.value`:

   ```bash
   herdr agent start "chat-$(date +%H%M%S)" --kind claude --pane <pane>
   ```

   It blocks until the pane really has a Claude ready for input. A failure leaves
   a plain shell in the tab: say so rather than prompting into it.

4. **Post the card yourself.** This is the step the skill exists for:

   ```bash
   herdr-teams-notify --thread "ag:<session-id>" \
     "momentum: new chat" "New chat ready" "Task=<agent name>"
   ```

   With a first prompt, make the body `New chat ready. Working on: <prompt>`.

   Do not leave this to `herdr-teams-watch`. It only cards an agent that *leaves*
   `working`, so a session sitting fresh at its prompt is never announced, and its
   5 second poll misses a turn shorter than that outright (measured: two one-line
   answers, no card either time). `ag:<session-id>` is the watcher's own thread
   key, so its later cards for this agent reply under this thread rather than
   starting a second one.

5. **Delegate the first prompt**, when there is one. No `--wait`: the job is to
   hand it over, and waiting would hold this session's turn open for as long as
   the new one takes.

   ```bash
   herdr agent prompt <name> '<the prompt, verbatim>'
   ```

6. **Check both halves are up**, because a session nobody can card or poll is a
   session nobody can reach:

   ```bash
   systemctl --user is-active herdr-teams-watch herdr-teams-listen
   ```

## Report back

Two lines at most: the agent name and pane, whether the card posted, and the
prompt that was handed over if there was one. Say which step failed instead, when
one did: no space, agent did not start, notify non-zero, prompt rejected, either
service inactive. Never claim the card arrived in Teams - a non-zero exit from
`herdr-teams-notify` is the only evidence this session has, and it means nothing
was posted.

## Notes

- The listener only polls an agent that is **not `working`** and whose thread file
  is warm, so a reply typed while the delegated prompt is still running waits for
  that turn to end.
- `herdr agent prompt` is rejected with `agent_blocked` when the new session comes
  up on a trust or permission prompt. That is an answer, not a retry: report it,
  since somebody at the keyboard has to clear it.
- Leave the tab open. Closing it ends the chat the card just advertised.
