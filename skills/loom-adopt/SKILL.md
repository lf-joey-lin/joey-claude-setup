---
name: loom-adopt
description: Opening stage of a loom-finish round - read a prototype's uncommitted (or named) changes as the spec, separate the behavior it demonstrates from the gaps it skipped, revert it safely to a patch on disk, and write the round's slice list. Also runs in reconcile mode after the slice loop to prove the rebuild lost nothing. Invoke via /loom-finish normally; directly when the user asks to "adopt this prototype" or "turn my working changes into a loom round".
---

# loom-adopt: the prototype is the spec

You open a `loom-finish` round. A human has prototyped something and clicked
it, so the shape is already approved - what is missing is the proof. You read
their diff for the behavior it demonstrates, get it out of the tree so the
specs that lock it in can be born red, and leave a slice list behind.

Read [`../shared/loom-contract.md`](../shared/loom-contract.md) first. You
write no product code and you create no worktree - this round runs in the
worktree the session is standing in.

**The rule that shapes everything here**: a diff tells you what the code
does, not what it should do. Behavior that survives becomes a check; anything
the prototype visibly skipped becomes a gap, and a gap is never a check.
Blurring the two ships the prototype's accidents as locked-in behavior.

## Step 0 - ground and refuse

Read the clock (`date -Iseconds`) for the section's `- Timing:` line.

Then the three refusals, before touching anything:

- **The default worktree is read-only.** If the session is in
  `<root>/momentum`, stop and tell the user to move to a feature worktree.
- **Never on `main`.** `git rev-parse --abbrev-ref HEAD`.
- **Nothing to adopt.** A clean tree with no `--from` means there is no
  prototype. Stop and say so; do not invent a round.

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
(`git branch -r --contains <sha>` empty) before going near step 3. A pushed
commit is not yours to rewind: stop and report.

## Step 2 - capture, and verify the capture

Order matters. Two copies exist on disk before anything leaves the tree.

```bash
git add -N .                       # untracked files, or the diff misses them
git diff <base> > src/ui-app/logs/loom/<slug>/round-<n>.patch
git apply --check --reverse <patch>   # against the current tree, before revert
```

`git diff` without the intent-to-add pass silently drops every new file, which
on a prototype is usually the interesting half. If `--check` does not pass,
**stop with the tree untouched** and report - a patch that cannot be replayed
is not a capture.

`<slug>` is the branch name in kebab-case unless a ledger already names one.
`<n>` is this round's number (step 5).

## Step 3 - read the diff for behavior

Group the hunks by surface: a page, a component, a composable, a block of
`en.json` keys. For each group, one sentence of what a user can now see or do,
and the **channel** a caller would look at to prove it - a rendered role or
text, an emitted event, a request that goes out, a route change, a DOM
attribute. A group with no channel is not a behavior.

A hunk that changes nothing observable (a rename, a widened type, an import
move) is not a behavior of its own; it rides along with the slice that needs
it. Say which slice.

Read the neighbors of the touched files, not just the hunks. The precedent
that scout would have gone looking for is one directory away, and the
prototype already chose to sit next to it.

## Step 4 - the gaps sweep

What `prototype` defers by design (its own scope section says so) is what you
are looking for. Two kinds.

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

Then decide each gap's owner and record it:

- **close it in a slice** - the round should ship it (a missing empty state on
  a list the round introduces)
- **hand it to probe** - the behavior is there but unproven under stress
- **out of scope** - deliberately not this round's job, with one line of why

## Step 5 - size the round

Count the behaviors from step 3.

- **One to four behaviors, ui only**: this is the express path. Write the
  slices directly; there is no `loom-plan` pass, because the diff already
  supplies each slice's Touches. Slice 1 is the walking skeleton whenever the
  round adds a route. Order by risk.
- **More than four**: the prototype outgrew a round. Say so and recommend
  either splitting it into two rounds or running `/loom` with a real plan.
  Do not quietly build a nine-slice round.
- **The diff touches `src/acs-bff` or `src/app-bff`**: not express. The
  browser contract is a design decision a diff cannot approve for itself.
  Run `api-integrator` Steps 0 to 4 over what the prototype built, write the
  bff slice entry with its Upstream, Route, DTO and Status map fields per the
  contract, and mark the round as needing the orchestrator's contract gate.
- **The diff touches anything outside `src/ui-app` and the two realm BFFs**:
  loom does not gate it. Keep building the parts loom owns and record the rest
  for `prepare-to-ship`, per the contract.

Each slice entry carries what the contract's Plan template asks for: Behavior,
Checks C1..Cn each naming its channel, Touches, Attack. The Attack line comes
free from step 4 - the gaps you handed to probe are exactly what it should
try. Add one field the normal plan does not have:

- **Lifts**: the patch hunks this slice's green step will draw from, by file
  and rough line range.

## Step 6 - revert

Only now, and only because steps 2 through 5 all passed.

```bash
git stash push -u -m "loom-adopt round <n>: <slug>"
git stash list        # record the ref
```

`-u` and never `-a`: untracked files go, gitignored files stay, which is what
keeps the ledger and the patch you just wrote out of the stash.

For a `--from` source, the equivalent is `git reset --hard <base>` after the
unpushed check in step 1. Record the pre-reset SHA in the ledger; it is the
third copy.

**Never drop the stash.** Not here, not at the end of the round. It is the
human's prototype and the round reports its ref rather than tidying it away.

## Step 7 - the ledger

If no ledger exists for this branch, create it from the contract's template
and fill the header. Then append this round's section, per the contract's
rounds spine:

```markdown
## Round <n> (loom-finish) - [ ]
### Adopt - [ ]
- Timing: started <iso>, finished <iso>, took <hh:mm:ss>
- Source: <uncommitted | --from ...>    Patch: <path>    Stash: <ref>
- Behavior: <one line per behavior, with its channel>
- Prototype gaps: <one line each> - owner: slice R<n>.S<k> | probe | out of scope
### Slices
#### R<n>.S1 - [ ]    Kind: ui | bff
...
```

Slice ids carry the round prefix so they stay unique across rounds.

Mark Adopt `[x]` and return at most fifteen lines: the source, the patch path,
the stash ref, the slice list one line each, the gap count by owner, and
whether the round needs the contract gate. The detail is in the ledger.

## Reconcile mode

The orchestrator runs you a second time, after the last slice and before probe
deep. One question: **did the rebuild lose anything the prototype had?**

```bash
git stash show -p <ref> > /tmp/proto.patch      # or the saved round patch
git diff <round base>..HEAD > /tmp/built.patch
```

Compare them by hunk, not by line count. For every hunk in the prototype,
find its counterpart in the branch. Three outcomes:

- **Present** - rebuilt, possibly better. Nothing to record beyond the count.
- **Deliberately dropped** - it was a gap you marked out of scope, or a slice
  recorded changing it. Confirm the ledger actually says so.
- **Missing with no record** - the rebuild lost it. This is a finding, and it
  goes back as a `loom-slice` fix turn like any must-fix.

A behavior the human clicked and liked, silently absent from the branch, is
the one failure this whole flow could otherwise ship. It is also the only
reason reverting their work is safe to do at all.

Record into the round's `### Reconcile - [ ]` section: hunks compared,
present, dropped-with-record, and each miss as `M1..Mn` with the file and what
it did. Return the misses; you fix nothing.
