# Turn-by-turn loop (shared)

The shared engine behind the human-in-the-loop skills (`pr-review-fixer`,
`review-ui`). It defines HOW work is driven - one item at a time, tracked in a
markdown state file, with a fresh subagent per item - so each host skill only has
to define WHAT the items are and what the per-item subagent does. Read this
alongside the host skill; the host skill's own file always wins where they differ.

## The orchestrator model

**The main agent is the orchestrator, not the worker.** Its whole job is to build
the work list, own the state file, and run the human decision loop. The real
per-item work - reading code, judging, fixing, verifying - happens inside a
**fresh subagent per item**, so the orchestrator's context stays clean and each
item is evaluated on its own merits.

Do not analyze, judge, or fix an item yourself in the orchestrator. If you catch
yourself reading source to decide an item in the main context, stop and delegate.

Nothing here commits, pushes, posts to a remote, or resolves anything on its own.
Those are outward-facing and are offered only at wrap-up, with explicit
confirmation each time.

## What the host skill supplies

This engine is generic. The host skill fills in these hooks:

1. **The work list** - how items are gathered (PR comments from `gh`, review
   findings from the dimensions pass, etc.) and how they are ordered.
2. **The state-file path** - where the per-scope markdown file lives (under a
   gitignored `logs` folder) and how each item is titled.
3. **The per-item subagent task** - the exact prompt handed to the subagent for
   one item, and the report sections it returns.
4. **Wrap-up and outward actions** - what "done" means and which optional
   outward-facing offers apply (reply to a thread, resolve, etc.).

Everything below - the go-ahead gate, the state-file mechanics, the one-at-a-time
cadence, and the disposition loop - is the same regardless of host skill.

## 1. Present the work list, get a go-ahead

Before writing anything, state exactly what you found: how many actionable items,
where they came from, and how many were filtered out and why. Get a go-ahead from
the human. Do not start the loop on an assumption.

If there are no actionable items, say so and stop. Do not invent work.

## 2. Write the state file, resumable

One markdown state file per scope, at the host-defined path under the gitignored
`logs` folder (write to it directly - `logs` is gitignored, so nothing here is
committed).

If a file for that scope already exists, **read it and resume** rather than
overwriting - a prior session may have finished some items. Reconcile: keep done
items, add any newly-appeared items as pending.

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
- Location: `path/to/file:line`
- Source: <url / dimension / where it came from>
- Detail:
  > verbatim item text or finding
- Verdict: (filled after the subagent runs)
- Resolution: (what was done, or why not)
- Verify: (checks run + result)
- Files touched:

### 2. ...
```

The orchestrator's copy of this file is **authoritative** - the single source of
truth for progress. Update it after every item (section 4), never in a batch at
the end. This is what makes the run resumable: if the session ends, the next
invocation on the same scope picks up exactly where this left off.

## 3. Process one item at a time (spawn a subagent per item)

Work the pending list in order. For each pending item:

1. Mark it `[~] in progress` in the state file.
2. Spawn a **single subagent** (`general-purpose`, run synchronously - the human
   is waiting on the result), scoped to just this one item. Hand it the
   host-defined task prompt and everything it needs about this item and nothing
   about the others. The subagent does the real work; the orchestrator only
   relays.
3. Relay the subagent's report to the human **in full** - do not summarize the
   code away, the human decides by reading it. Always show, in order:
   - The item and its location.
   - **Code context**: the current code the item concerns, as a fenced,
     line-numbered block, shown every turn even for a no-change verdict.
   - Verdict + reasoning (one short paragraph).
   - **The diff**: the fenced ```diff block, `-`/`+` lines intact, exactly as the
     subagent returned it. If no change was made, say so.
   - Verification result (commands run + real pass/fail).

   Then ask the human how to proceed:
   **accept** (keep the change), **revise** (send specific follow-up direction
   back to a subagent), **skip** (leave for now), or **wont-fix** (disagree -
   capture the reason). Recommend an option when the verdict is clear-cut, but the
   human decides.
   - On **revise**, spawn a fresh subagent with the same item plus the human's
     added direction; repeat this step.
   - On **skip**/**wont-fix**, ensure the working tree is clean of that attempt
     (`git checkout -- <files>` if the subagent applied something the human
     rejected).
4. Record the outcome in the state file immediately (section 4).

Handle **one item fully before starting the next.** Never fan out subagents across
multiple items at once - the point is a deliberate, human-paced loop, and parallel
edits to the same files would collide.

## 4. Update the state file after each item

After the human decides, edit that item's entry:

- Status marker: `[x]` accepted, `[-]` skipped, `[!]` wont-fix.
- `Verdict:` the subagent's call, in a phrase.
- `Resolution:` what changed (or why nothing did). One or two lines.
- `Verify:` the checks run and their result.
- `Files touched:` the paths.
- Recompute the `## Summary` counts.

## 5. Wrap up

When the list is fully worked (nothing left `[ ]`/`[~]`):

- Report a summary from the state file: accepted / skipped / wont-fix counts and a
  one-line per item.
- Point out anything deferred: items marked skip, or work that needs a follow-up
  gate before shipping.
- Accepted changes are uncommitted working-tree changes (the user's review state).
  **Do not commit or push unless the user asks** (per the global git rules).
- **Optional, outward-facing - confirm each time, never automatic:** offer only
  the host-defined outward actions, and only with text the user has seen and
  approved.

## Invariants

- Human-paced and opt-in. One item per subagent, one scope at a time.
- The orchestrator never does the per-item analysis itself - always delegate.
- Grounded truth only: verdicts and verification come from the subagent actually
  reading code and running checks, not from restating the item.
- No em dash, emojis, arrows, or box-drawing characters in anything written here.
