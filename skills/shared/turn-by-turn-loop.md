# Turn-by-turn loop (shared)

The shared engine behind the human-in-the-loop skills (`pr-review-fixer`,
`review-ui`). It defines HOW work is driven - one item at a time, tracked in a
markdown state file, with a fresh subagent per item - so each host skill only
defines WHAT the items are and what the per-item subagent does. Read this
alongside the host skill; the host skill wins where they differ.

## The orchestrator model

The main agent is the orchestrator, not the worker. It builds the work list, owns
the state file, and runs the human decision loop. The real per-item work - reading
code, applying the fix, and verifying it - happens in a fresh subagent per item,
spawned only for items the human accepted in the section 1 gate, so the
orchestrator's context stays clean. If you catch yourself reading source to decide an item in the main
context, stop and delegate.

Nothing here commits, pushes, posts to a remote, or resolves anything on its own.
A local commit is offered per item after its fix is applied (section 3); pushing
and every other outward-facing action is offered only at wrap-up. Each takes
explicit confirmation every time.

## What the host skill supplies

1. **The work list and its gate context** - how items are gathered (PR comments
   from `gh`, findings from a review pass, etc.), how they are ordered, and what
   each carries into the section 1 gate: a priority, a one-line summary, a quick
   before/after of the proposed change where the host produces one, the
   recommendation, and each item's default disposition (accept or skip).
2. **The state-file path** - the per-scope markdown file's location under the
   gitignored `logs` folder, the descriptive slug its name is built from, and how
   each item is titled.
3. **The per-item subagent task** - the fix prompt (read the code, apply the fix,
   run verification) and the report sections it returns.
4. **Wrap-up and outward actions** - what "done" means and which optional
   outward-facing offers apply (reply to a thread, resolve, etc.).

Everything below is the same regardless of host skill.

## 1. Present the work list, gate it in one pass

Before writing anything, present the full list of gathered items as a numbered
list, each with its gate context - priority, one-line summary, the quick
before/after where the host produced one, and the recommendation - so the human can
judge importance at a glance. State the totals: how many items, where they came
from, how many filtered out and why. If there are no actionable items, say so and
stop - do not invent work.

Then run a single `AskUserQuestion` bulk gate over the whole list. Each item starts
at its host-set default - recommended findings default to accept, minor ones to
skip, or the host defaults everything to accept - and the human flips any in either
direction: accept a skipped item, skip a recommended one. Use one multi-select
question when the list is short enough to list as options; when it is longer,
present the items numbered with their defaults and let the human name the flips as
free-text, treating unnamed items as their default. For anything set to wont-fix,
capture a reason; ask if not given.

Items left accepted enter the loop in order. Record the dropped ones in the state
file (section 2) as `[-]` skipped or `[!]` wont-fix before the loop starts.

## 2. Write the state file, resumable

One markdown state file per scope, at the host-defined path under the gitignored
`logs` folder (write to it directly; nothing here is committed). This file is the
authoritative source of truth for progress - update it after every item (section
4), never in a batch at the end. That is what makes a run resumable across
sessions.

Name it for the work it covers with a descriptive kebab-case slug (e.g.
`home-widgets.md`, `pr-142-review.md`), not `state.md` or a bare timestamp - the
next invocation on the same scope finds and resumes the run by matching this name.
If a file for the scope already exists, read it and resume rather than overwrite:
keep done items, add newly-appeared items as pending.

State-file template (the host skill may add fields, but keep this spine):

```markdown
# <scope title>

- Scope: <what this file covers>
- Generated: <yyyy-mm-dd>
- Status legend: [ ] pending  [~] in progress  [x] accepted  [-] skipped  [!] wont-fix

## Summary
- Total: N  |  Accepted: 0  |  Skipped: 0  |  Wont-fix: 0  |  Pending: N

## Items

### 1. <short title> - [ ] pending
- Priority: <host's priority/severity, used for the gate default>
- Location: `path/to/file:line`
- Source: <url / dimension / where it came from>
- Detail:
  > verbatim item text or finding
- Verdict: (filled after the subagent runs)
- Resolution: (what was done, or why not)
- Verify: (checks run + result)
- Files touched:
- Commit: (hash if committed, `bundled` if carried forward, else `-`)

### 2. ...
```

## 3. Process one item at a time

Work the accepted list in order. Handle one item fully before starting the next -
never fan out subagents across items, since parallel edits to the same files
collide.

1. Mark it `[~] in progress`. Spawn a single `general-purpose` subagent, run
   synchronously, scoped to just this item. Hand it the host-defined fix prompt and
   nothing about the other items. It reads the code, applies the fix, runs the
   host-defined verification (build / lint / tests as applicable), and returns the
   actual applied diff and the real pass/fail result.

2. Relay the applied diff and verification result to the human in full - do not
   summarize the code away. If verification fails or the change looks wrong, ask
   with `AskUserQuestion`:
   - **revise** - send follow-up direction; spawn a fresh fix subagent with the
     item plus that direction, then relay again.
   - **keep** - accept the change as applied.
   - **revert** - undo it; record as skipped or wont-fix.

   Free-text via "Other" is a **revise** with that text. On a clean pass, proceed
   to the commit offer; the human can still ask to revise or revert there.

3. Record the outcome in the state file immediately (section 4).

4. **Offer to commit** - only when a change was kept, confirmed each time, local
   commit only. Ask with `AskUserQuestion`:
   - **commit now**: one commit for this item plus any earlier bundled items.
     Follow the git rules for the message (short imperative subject, no trailers,
     writing rules applied), record the hash, and clear the bundle.
   - **bundle**: leave uncommitted and carry forward to ride with the next
     `commit now`. Mark the item `bundled` and keep it in the running bundle.

## 4. Update the state file after each item

After the human decides, edit that item's entry:

- Status marker: `[x]` accepted, `[-]` skipped, `[!]` wont-fix.
- `Verdict:` the subagent's call, in a phrase.
- `Resolution:` what changed, or why nothing did. One or two lines.
- `Verify:` the checks run and their result.
- `Files touched:` the paths.
- `Commit:` the hash once committed, `bundled` while riding forward, or `-`. When a
  `commit now` lands, backfill the hash onto every item that was in that bundle.
- Recompute the `## Summary` counts.

## 5. Wrap up

When nothing is left `[ ]`/`[~]`:

- Report a summary from the state file: accepted / skipped / wont-fix counts, one
  line per item.
- Point out anything deferred: skipped items, or work needing a follow-up gate.
- If any applied changes are still `bundled`, make a final **commit now / leave
  uncommitted** offer (`AskUserQuestion`) so nothing is stranded. Never push -
  commits here are local, and pushing needs an explicit ask.
- **Optional, outward-facing** - offer only the host-defined outward actions, only
  with text the user has seen and approved, confirmed each time.

## Invariants

- Human-paced and opt-in. One item per subagent, one scope at a time.
- Every human decision point is an `AskUserQuestion` call, never a plain-text
  prompt - the section 1 bulk gate (accept-all by default, toggle to drop noise)
  and each per-item disposition alike.
- The orchestrator never does the per-item analysis itself - always delegate.
- Verdicts and verification come from the subagent actually reading code and
  running checks, not from restating the item.
- No em dash, emojis, arrows, or box-drawing characters in anything written here.
