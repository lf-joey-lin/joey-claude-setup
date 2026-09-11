---
name: loom-spec
description: Opening stage of a loom adopt-lane run - read the branch's own uncommitted (or named) changes as the spec, separate the behavior they demonstrate from the gaps they skipped, capture them to a patch, and write the brief as bullet-point specs for a human to approve before anything is reverted. Invoke via /loom --retrofit (or /loom with no request) normally; directly when the user asks to "read my prototype as a spec" or "what did I actually build here".
---

# loom-spec: the branch is the spec

You open a `loom` run that has no written request, because the code is the
request. A human prototyped something and clicked it, so the shape is already
approved. What is missing is a statement of what they built, and the proof.

Your job is to turn their diff into **bullet-point specs a human can read and
approve in under a minute**, and to capture their work so it can be safely
taken out of the tree afterwards. You do not revert anything. The orchestrator
does that with a script, after the human approves your bullets.

Read [`../shared/loom-contract.md`](../shared/loom-contract.md) first. You
write no product code and you create no worktree - this run happens in the
worktree the session is standing in.

**The rule that shapes everything here**: a diff tells you what the code does,
not what it should do. Behavior that survives becomes a spec bullet; anything
the prototype visibly skipped becomes a gap, and a gap is never a bullet.
Blurring the two ships the prototype's accidents as locked-in behavior.

## Step 0 - ground and refuse

Read the clock (`date -Iseconds`) for the section's `- Timing:` line.

Then the three refusals, before touching anything:

- **The default worktree is read-only.** If the session is in
  `<root>/momentum`, stop and tell the user to move to a feature worktree.
- **Never on `main`.** `git rev-parse --abbrev-ref HEAD`.
- **Nothing to adopt.** A clean tree with no `--from` means there is no
  prototype. Stop and say so; do not invent a run.

## Step 1 - resolve the source

| Invocation | Source |
| --- | --- |
| default | uncommitted work against `HEAD`, tracked and untracked |
| `--from <sha>` | that commit alone; base is its parent |
| `--from <a>..<b>` | that range; base is `<a>` |
| `--from branch` | everything on this branch not on `origin/main` |

The default deliberately ignores committed work. If part of the prototype was
already committed, the human names it - do not guess a range.

For any `--from` form, verify every commit in it is unpushed
(`git branch -r --contains <sha>` empty). A pushed commit is not yours to
rewind: stop and report, because the revert that follows your approval would
be rewriting published history.

## Step 2 - capture, and verify the capture

Nothing leaves the tree here. You are writing the copy that makes the revert
safe, so it exists before anyone is asked to approve one.

```bash
git add -N .                          # untracked files, or the diff misses them
git diff <base> > artifacts/loom/<slug>/round-<n>.patch
git apply --check --reverse <patch>   # against the current tree, as it stands
```

`git diff` without the intent-to-add pass silently drops every new file, which
on a prototype is usually the interesting half. If `--check` does not pass,
**stop and report with the tree untouched** - a patch that cannot be replayed
is not a capture, and the run must not reach a revert without one.

`<slug>` is the branch name in kebab-case unless a ledger already names one.
`<n>` is this round's number.

Record the current SHA too. The patch and the SHA are the two copies the
orchestrator's `adopt.sh` relies on, and the stash it makes is the third.

## Step 3 - read the diff for behavior

Group the hunks by surface: a page, a component, a composable, a block of
`en.json` keys. For each group write **one bullet**: what a user can now see or
do, and the **channel** a caller would look at to prove it - a rendered role or
text, an emitted event, a request that goes out, a route change, a DOM
attribute. A group with no channel is not a behavior.

Write the bullets for the human, not for the pipeline. Short, concrete, in the
words they would use about their own feature:

```markdown
- Ticking rows on the deleted list enables Restore, and pressing it calls
  POST /bff/app/processes/deleted/restore once per click.
  Channel: the request that goes out, and the button's disabled state.
- A failed restore leaves exactly the refused rows ticked and names one
  reason per row.
  Channel: rendered text, and which checkboxes stay checked.
```

A hunk that changes nothing observable (a rename, a widened type, an import
move) is not a bullet of its own; it rides along with the behavior that needs
it. Say which one.

Read the neighbors of the touched files, not just the hunks. The precedent
scout would have gone looking for is one directory away, and the prototype
already chose to sit next to it. Record it as the `Precedent:` line so `plan`
does not go looking again.

For each bullet also record **Lifts**: the patch hunks its green step will
draw from, by file and rough line range. That is what lets `loom-plan` slice
your bullets without re-reading the whole diff.

## Step 4 - the gaps sweep

What a prototype defers by design is what you are looking for. Two kinds.

**Greppable, over the diff:**

```bash
grep -nE '#[0-9a-fA-F]{3,8}\b'      # hex where a palette token exists
grep -nE 'console\.(log|debug)'     # left-behind logging
grep -nE '\.(only|skip)\('          # focused or skipped specs
grep -nE ':\s*any\b'                # any that a real type should replace
```

Plus, by reading: user-facing string literals that bypass `t()`, an `en.json`
key added and never referenced or referenced and never added, and a
`data-testid` built from an array index rather than an entity id.

**Absences, which no grep finds.** These are the ones that matter: no empty
state, no error branch, no loading state, a click handler with no keyboard
path, an icon-only control with no accessible name, a list with no key.

Then give each gap an owner and record it:

- **close it in a slice** - the run should ship it (a missing empty state on a
  list the prototype introduces)
- **hand it to probe** - the behavior is there but unproven under stress
- **out of scope** - deliberately not this run's job, with one line of why

The gaps are the half of your output the human is most likely to correct at
the approval, so state them plainly rather than burying them.

## Step 5 - size and route

Count the bullets from step 3.

- **One to four bullets, ui only**: the patch lane. Say so; `loom-plan` is
  skipped and the run builds from your bullets directly.
- **Five or more, or any bff work**: the feature lane, so `loom-plan` runs and
  slices your bullets.
- **More than about eight**: the prototype outgrew one run. Say so and
  recommend splitting it, rather than letting a fifteen-bullet run through.
- **The diff touches `src/acs-bff` or `src/app-bff`**: feature lane always.
  The browser contract is a design decision a diff cannot approve for itself,
  so run `api-integrator` Steps 0 to 4 over what the prototype built and fill
  the Upstream, Route, DTO and Status map fields per the contract. Plan's ask
  moment 2 is where that gets approved.
- **The diff touches anything outside `src/ui-app` and the two realm BFFs**:
  loom does not gate it. Say which parts loom owns and record the rest as
  unchecked by this run, per the contract.

## Step 6 - the ledger, and what you return

If no ledger exists for this branch, create it from the contract's template.
Then write your section, at the nesting the contract's rounds spine gives it:

```markdown
### Spec - [ ]
- Timing: started <iso>, finished <iso>, took <hh:mm:ss>
- Source: <uncommitted | --from ...>    Patch: <path>    Base SHA: <sha>
- Precedent: <the sibling the prototype sat next to, path:line>
- Lane: patch | feature - <why>
- Specs:
  - S1 <the bullet> - Channel: <what a caller looks at> - Lifts: <file:range>
  - S2 ...
- Gaps: <one line each> - owner: slice | probe | out of scope
```

Mark it `[x]` and return in the contract's fixed shape: the source, the patch
path, the base SHA, the lane with its reason, one line per spec bullet, and
the gap count by owner. The detail stays in the ledger.

## What you do not do

Four things, each owned by something else. Doing any of them here is a bug.

- **You never revert.** The orchestrator runs `skills/loom/scripts/adopt.sh`
  after the human approves your bullets. A stage that reverts before the
  approval has destroyed work nobody agreed to lose.
- **You never write slices.** `loom-plan` does, from your bullets, on the
  feature lane. On the patch lane the bullets are the slice.
- **You never reconcile.** `loom-probe-deep` proves the rebuild kept every
  hunk, after the slice loop.
- **You never write product code**, here or later.
