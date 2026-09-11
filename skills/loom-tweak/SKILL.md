---
name: loom-tweak
description: One small change on a momentum ui-app branch, built red first and probed, by this session alone. No subagents, no rounds, no review debt - write the checks, watch them fail, implement, attack the diff, fix what broke, commit. Updates the branch's loom ledger when it has one. Invoke when the user types /loom-tweak, or asks to "tweak this", "small change on this branch", "red green probe this", or wants one more change without paying for a full loom round.
---

# loom-tweak: one change, four steps

You do the whole thing yourself, in this session. No subagents, no stage
handoffs, no round numbering, no debt accounting. Four steps and a commit:

```
red      write 1 to 4 specs, run them, watch them fail for the right reason
green    smallest implementation that turns them green
probe    attack your own diff with a fixed list, plus the cheap sweeps
fix      fix the must-fixes, re-run, delete the throwaway probe specs
```

Read [`../shared/loom-contract.md`](../shared/loom-contract.md) for the repo
facts: the commands, the platform ordering, the i18n and token rules, the git
rules, the hard stops. All of it binds you. Its **delegation and models
sections do not apply** - a tweak spawns nothing, so there is nobody to seed
and no agent type to pick.

Runs in place in the worktree the session is standing in. It creates no
worktree, cuts no branch, runs no install, and does not care whether loom has
ever touched this branch.

## Invocation

```
/loom-tweak <request>              red, green, probe, fix, commit
/loom-tweak                        a dirty tree is the request (adopt mode)
/loom-tweak <request> --refactor   no behavior change, so nothing is born red
/loom-tweak <request> --gate       plus the full local CI mirror before the commit
/loom-tweak <request> --no-commit  leave it in the tree
```

State the shape in your first line of output, before any tool call:
`Tweak    Mode: change | refactor | adopt   Gate: yes | no`.

## Step 0 - ground, and the guard

```bash
bash ~/.claude/skills/loom-tweak/scripts/ledger.sh find
```

`ok=no` is a hard stop, reported and never worked around. `ledger=none` is
normal and changes nothing except that there is nothing to update at the end.

Then, before writing anything:

- Read the file or files you are about to change **in full**, not the hunk.
- Confirm every component, composable and prop against the installed types
  (`node_modules/@nuxt/ui/dist/runtime/`, `.nuxt/imports.d.ts`,
  `node_modules/@vueuse/core/dist/index.d.ts`). Never name one from memory.
- Run the contract's platform ordering on the behavior, not just the markup.
  If you hand-roll, you owe one line naming the unit you passed over and what
  it could not do.

**The guard, one honest look.** A tweak is `src/ui-app` only, about three
production files, one observable behavior change, no new page or route, no new
shared state another unit will consume, and no new BFF route. If the change is
bigger than that, say so and stop. Do not shrink the request to fit. The right
answer is `/loom --in <worktree> <request>`, and saying so costs two minutes
where building the wrong shape costs a revert.

## Step 1 - red

Write the checks as co-located `*.spec.ts` (Vitest and Vue Test Utils), one
test per check, asserting on the channel a caller really looks at. Match the
nearest sibling specs for locator priority (`getByRole`, `getByLabel`,
`getByText`, then `getByTestId`, never `:nth-child`) and fixture shape, and
**import** their helpers rather than copying them.

```bash
cd src/ui-app && npx vitest run --project=unit <spec paths>
```

**Every new test must fail, and fail because the behavior is absent** - not
because an import is broken or the harness is misassembled. A test that passes
before the implementation exists is asserting nothing, so fix its channel now
rather than after green. This red run is the only evidence in the whole tweak
that cannot be reconstructed afterwards, so do not skip it and do not
paraphrase it later.

Where a check genuinely cannot go red first, mutation-prove it after green
instead: break the line it covers, see it fail, restore, confirm `git status`
is clean. Never skip both.

## Step 2 - green

The smallest code that turns the specs green. Contract conventions throughout:
`t()` with keys in `en.json` and no hardcoded user-facing string, palette
tokens and no hex, `<script setup lang="ts">`, semantic HTML first with
`data-testid` only where role or label cannot locate, keyboard operable.

While the specs are red you may iterate freely. Do not weaken a spec to reach
green. If a check turns out to be wrong once the code is in front of you,
change it deliberately and say so out loud - a check quietly loosened is the
one failure this whole shape cannot catch.

## Step 3 - probe your own diff

You wrote the code, so you are a poor skeptic about it. That is the price of
one agent, and the mitigation is that this step is a **fixed list you execute**
rather than a judgment call about whether the code looks fine.

**Executed attacks.** Throwaway `*.probe.spec.ts` beside the code, mounting the
real component. Work the list, skipping only what the change cannot reach:

- zero items, one item, several hundred
- a 400-character unbroken label, and non-ASCII or long-locale text
- a missing optional field, and null where the type says maybe
- the error state from the data source
- the double-submit, and the action fired while loading
- Esc and click-outside on anything transient

The assertion is that it stays usable: the empty state appears, the label
truncates rather than blowing the layout off, the placeholder shows. Run them.

**Cheap sweeps, always.** Over the diff:

```bash
cd src/ui-app
files=$(git diff --name-only HEAD -- . | grep -E '\.(vue|ts)$')
grep -nE '#[0-9a-fA-F]{3,8}\b' $files                 # hex where a token exists
grep -nE 'console\.log|\.only\(|\.skip\(' $files      # leftovers
grep -nE 'data-testid="[^"]*(index|\bi\b)' $files     # ids built from positions
python3 ~/.claude/skills/loom-probe/scripts/spec-copies.py
```

Then read the template diff for user-facing text that bypasses `t()`, and
check that every `en.json` key the diff added is referenced and every key it
references exists.

**Severity is two-valued.** `must-fix` is broken behavior, a crash, an i18n or
token violation, a test that cannot fail, or a spec helper now copied into a
third file. Everything else is `polish`: one line saying `path:line` and what
is wrong, and no fix. There is no middle band, because a middle band is where
nitpicks breed. An empty findings list is a good result - say what you attacked
and that it held.

## Step 4 - fix

For each must-fix: turn the reproduction into a failing spec first, then fix to
green, smallest change, nothing the finding does not concern. That spec is
promoted into the suite and stays. Every other probe spec is deleted, and
`git status` must show no `*.probe.spec.ts` left.

If a fix would change behavior one of your own checks locks in, stop and put
the disagreement to the human. Do not negotiate a locked-in check.

## Verify and commit

```bash
cd src/ui-app && npx vitest run --project=unit <spec paths>
npx nuxt typecheck
npx eslint --fix <touched paths>
```

Real exit codes, no exceptions and no paraphrasing. Two things the cheap pair
cannot see, both of which fail CI later:

- **A new `.vue` under `app/components`, `app/layouts` or `app/pages` needs a
  story in the same commit.** The a11y suite mounts stories and nothing else,
  so markup with no story is never scanned.
- **The coverage gate is 100 percent statements and branches.** A branch of new
  code no spec reaches fails `npm run test:ci` even though everything here was
  green.

`--gate` runs the whole mirror, which is the only way to know both before you
push:

```bash
bash ~/.claude/skills/shared/gate.sh <slug> origin/main HEAD
```

Read its `VERDICT` line and never pipe it: piping replaces its exit code with
the pipe's, which reads as a pass. It costs about three and a half minutes, so
the sane habit is once before pushing rather than once per tweak.

Then one commit: code, specs, `en.json` keys and the story together, subject
`[ui-app] <imperative>`, no trailers.

## The ledger

If step 0 found one, write the tweak into it. If it did not, skip this and say
nothing about it.

Write the block to a temp file and splice it:

```bash
bash ~/.claude/skills/loom-tweak/scripts/ledger.sh add /tmp/tweak.md
```

The script puts it above `## Needs human eyes` so the spine stays last, and
adds a one-line pointer to the report when the branch has one, because
`/paperwork` reads the report rather than the ledger.

```markdown
## Tweak <n> - [x]
- Timing: started <iso>, finished <iso>, took <hh:mm:ss>
- Request: <verbatim | uncommitted diff>    Mode: change | refactor | adopt
- Scope: <n> files, <n> checks, ui-app only
- Platform: <unit taken, confirmed at path:line> | hand-rolled <what>, passed over <unit>, <why>
- Red: <spec path> failed as expected | Mutation: <line broken, spec red, restored>
- Green: <commit> <subject>
- Probe: <attacks run> - F1 <finding> (must-fix, fixed in <commit>) | held, no findings
- Verify: specs n/n | typecheck exit 0 | eslint exit 0 | gate <READY | not run>
```

Eight lines, once, at the end. That is the whole bookkeeping.

`## Tweak <n>`, never `## Round <n>`: a round heading with no `### Land - [x]`
under it makes the branch look like it has a loom round that never finished.

Timings come from `date -Iseconds` read at the start and again once the ledger
write is done, and the duration from the shell. Never write a time you did not
read from the clock.

## The two other modes

- **`--refactor`.** Behavior does not change, so there is nothing to be born
  red. The existing suite is the check: it must be green before and after, and
  specs may move but may never be weakened or deleted. The test count after is
  at least the count before, and you record both. For each seam the refactor
  introduces, one mutation: break it, see the covering specs go red, restore,
  confirm `git status` is clean. A seam nothing would notice changing has been
  moved into a blind spot.
- **Adopt, a dirty tree with no request.** The human already wrote it and
  clicked it. **Do not revert it.** Read the diff for the behavior it
  demonstrates, write the checks against that, and prove each one by breaking
  the exact line it claims to cover, seeing it fail, and restoring. Then finish
  what the diff left rough. Be straight that this is the weaker proof: you are
  writing specs while holding the implementation. A prototype big enough to
  want the stronger proof is `/loom --retrofit`, and say so if that is what the
  diff turns out to be.

## When to stop instead

Say it plainly and hand back rather than stretching the shape:

- it needs a new BFF route, a new page, a new route, or shared state something
  else will read - that is `/loom`, whose ask moment 2 exists for the browser
  contract
- it touches anything outside `src/ui-app`
- it grew past about three production files while you were in it
- a must-fix finding is still open after one fix attempt
- the change turns out to want a reshape - `loom-shape` prices those, and it is
  not running here

## Invariants

- **Born red, or mutation-proved.** Whichever one, it is stated with the spec
  path and what failed. No third option.
- **The probe list is executed, not considered.** A finding is a reproduction.
- **Real exit codes.** Nothing is reported as passing that was not run.
- **Findings you do not fix are named**, with `path:line`, in the ledger and in
  what you tell the human.
- No subagents, no rounds, no debt line, no settle-up, no report generation, no
  merge, no push, no work item, no PR. Those are `/loom`, `/merge-main`,
  `/paperwork` and `/teardown`, on the human's word.
- The contract's hard stops hold: secrets, generated catalogs, `main`, the
  read-only default worktree. Report, never work around.
- No em dash, emoji, arrows or box-drawing characters in anything written.
