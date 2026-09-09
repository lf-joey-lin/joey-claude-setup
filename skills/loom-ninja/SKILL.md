---
name: loom-ninja
description: A fast round on a momentum branch loom already finished - one small tweak or small refactor built checks-first, probed against its own diff, gated on the full local CI mirror, merged and pushed, with the branch-scoped review passes deferred to a settle-up instead of paid per round. Requires a branch whose last loom round landed. Invoke when the user types /loom-ninja, or asks to "ninja this", "quick round on this branch", "small tweak, fast", or wants one more change on a finished loom branch without paying a full round.
---

# loom-ninja: the fast round

A branch has already been through loom. It landed, it gated READY, and its
whole-branch review passes cleared it. Now it needs one more small thing: a
tweak, a rename, a small refactor, a value someone changed their mind about.

Your job is that one thing, in about twenty minutes instead of about fifty-five,
**without checking less**. Read
[`../shared/loom-contract.md`](../shared/loom-contract.md) first; its ledger
format, repo facts, hard stops and delegation rules bind you exactly as they
bind `loom`.

## The thesis, because every cut below follows from it

Measured on this repo, the six ui-app CI checks cost 4 minutes 47 seconds
sequential and 3 minutes 24 seconds in three parallel lanes. A finished
patch-lane loom round on a two-file tweak (`groupedSortToggle`) took 54 minutes
52 seconds. The gate was 5 minutes 37 of it.

**The checks are cheap. The stages are expensive.** So ninja keeps every check
and removes stages. It runs two subagents where loom runs nine, and it runs the
gate as a script rather than delegating it, because a fixed list of commands
compared against real exit codes needs no judgment.

The one thing ninja genuinely defers is the three branch-scoped review passes -
`loom-probe-deep`, `loom-shape`, `loom-tidy`. On a fourth tweak those re-read
code nothing has touched since they last cleared it. Ninja tracks that as
**review debt** in the ledger and pays it in one settle-up scoped to the
accumulated delta. The review is deferred and amortized, not skipped.

## Invocation

```
/loom-ninja <request>              # attended: no planned asks, push confirmed
/loom-ninja                        # a dirty tree is the request (adopt mode)
/loom-ninja <request> --refactor   # no behavior change; reshape discipline
/loom-ninja <request> --solo       # zero asks, never pushes
/loom-ninja <request> --no-push    # attended, land leaves the branch local
/loom-ninja --settle               # pay the review debt now, then land
/loom-ninja --settle --no-mutants  # settle up without the mutation sweep
```

Runs in place, in the worktree the session is standing in. It creates no
worktree, cuts no branch, and runs no install - the branch already has all
three.

State the resolved shape in your first line of output, before any tool call:
`Ninja round <n>   Mode: tweak | refactor | adopt   Attend: attended | solo   Debt: <n> rounds, <lines> lines`.

## Step 0 - the licence

```bash
bash ~/.claude/skills/loom-ninja/scripts/debt.sh
```

One block of `key=value` lines. `ok=no` stops the run: report the `reason` and
the `next` line verbatim and do nothing else. That is not a failure, it is the
skill declining work it has no licence for.

The licence is one fact: **the branch's last loom round landed.** Land is only
ever marked `[x]` after a gate was accepted, so it is the single line that
proves the whole review tail ran over this branch. With no ledger, or a round
still open, ninja's deferrals are unfunded and the right answer is `/loom --in`
or `/loom-finish`.

`debt_over_cap=yes` never stops the run. It changes what you report: the round
proceeds, and the debt line goes in the ledger, in the appended report section,
and in your closing message to the human. Warning loudly is the whole
mitigation, so do not soften it and do not bury it.

## Step 1 - build

One `loom-slice` subagent (`subagent_type: "loom-slice"`, never a plain
`general-purpose` agent and never with a `model` you chose). Seed it per the
contract's delegation section - absolute worktree path, ledger path, round
number, mode line - plus: the request verbatim, the ninja mode, and the
instruction to read **"The build stage" below** in this file on top of its own
skill file.

Gate it on the ledger entries it appended: the guard verdict, a red record (or
a recorded mutation, in adopt mode) for every check, a green commit that
`git log --oneline` really shows, and the cheap verify lines at exit 0.

A `BOUNCE` return is a clean stop, not a blocker: report which guard criterion
failed and point at `/loom --in <worktree> <request>`. Do not argue with it and
do not retry it smaller.

## Step 2 - probe

One `loom-probe-quick` subagent, scoped to this round's diff. Seed it with the
commit range (`<green commit>^..<green commit>`) and the Attack line the build
stage wrote into the ledger.

Gate on findings carrying reproductions and severities, and on `git status`
showing no `*.probe.spec.ts` left behind.

**One fix turn, not two.** A must-fix finding goes back as one `loom-slice` in
fix mode, then one probe re-check scoped to that finding. A must-fix still open
after that stops the round. Loom allows two turns because a slice of a large
feature is worth another attempt; a tweak that needs two is not a tweak, and
the honest move is to stop and let the human decide.

Polish findings are recorded and carried. They are settle-up input, not this
round's work.

## Step 3 - gate

You run this yourself. Running a fixed list of commands and comparing real exit
codes is not reading source and not writing code, so it does not breach the
conductor rule; delegating it would only add a context load and a handoff to a
result a script already produces.

```bash
bash ~/.claude/skills/loom-ninja/scripts/gate.sh <slug> origin/main <round base>
```

Every check `loom-gate` runs, in three lanes: lint alone, then typecheck to
build to storybook build to the a11y suite (serial, because all three write
`.nuxt`), then the coverage gate alone. Plus the scope check against
`origin/main` and the story check against this round's base commit, since
components an earlier round added were certified by that round's gate.
Storybook and a11y are always run: the coverage lane is 122 seconds and the
nuxt lane is 155, so they cost about 33 seconds of wall time and skipping them
would mean betting that a `.ts` change cannot alter rendered markup.

**Read the VERDICT line, and never pipe the script.** Piping replaces its exit
code with the pipe's, which reads as a pass. Redirect to a file if you want the
output kept.

**A `story check REVIEW` line is yours to answer before land.** The script
flags a new `.vue` no story file names, and it deliberately does not fail on
it: a parent's story mounting a child is real coverage, and a literal grep
cannot see that. Verified on the `groupedSortToggle` branch, where this check
named three components its own loom gate had already traced to `Grouped*`
stories. Hand the line to the build stage to name what mounts each file. A
component nothing mounts is NOT READY, owner build, exactly as `loom-gate`
would have it.

`VERDICT READY`: continue. `VERDICT NOT READY`: one `loom-gate` subagent,
seeded with the failing log paths and told the checks have already run, that
its fix lane is **lint and coverage shortfalls only**, and that it must re-run
this script from clean rather than stitch a pass from partial re-runs.
Re-run once. Still NOT READY: stop the round, ledger `[!]`, the output in
Blockers, no push. A faked pass is the worst thing this pipeline can produce
and ninja's speed buys it no exemption.

## Step 4 - land

Scripted, with one agent only where a merge needs semantics.

1. `git fetch origin`, then `git merge-base --is-ancestor origin/main HEAD`.
   An ancestor means record "up to date" and skip to 3.
2. `git merge --no-edit origin/main`. Generated catalogs and lockfiles take
   main's side per the contract. Every other conflicted file goes to one
   `subagent_type: "loom-merge-conflict"`, seeded as `loom-land` seeds it.
   Sides that genuinely disagree about behavior are `git merge --abort` and a
   human call. If the merge brought any `src/ui-app` or BFF commits, re-run
   step 3's script at the merge commit.
3. Push: attended, confirm with one `AskUserQuestion` first, unless
   `--no-push`. Solo never pushes.
4. Write the ledger round entry (below), **append** a section to the existing
   `artifacts/loom/<slug>-report.md` rather than regenerating it, and write the
   contract's end-of-run receipt. The receipt is not optional: `mqueue.sh`
   waits on that line and a round that skips it holds a queue open for hours.

The report is appended because regenerating it costs an agent reading the whole
ledger to restate rounds nothing changed. `/paperwork` reads the file top to
bottom and gets the same story either way.

## The build stage

`loom-slice` reads this section when its seed says ninja. Everything in its own
skill file still holds; this is what a ninja round adds and removes.

**You are your own scout and plan.** There is no brief and no `Platform:` line
waiting for you. So: read the ledger's last round for the area you are about to
touch, read the file or files in full, confirm every component, composable and
prop against the installed types, and run the contract's platform ordering
yourself, recording the unit you took or the one you passed over and why. For a
one-unit change the recon is reading the file you are about to edit, which is
why this collapses into one stage rather than three.

**The guard, before you write anything.** All of these, or you return
`BOUNCE | <the criterion that failed>` and stop:

- `src/ui-app` only. A slice that needs a new BFF route is never ninja work:
  a browser contract is a real design decision and it belongs to loom's ask
  moment 2.
- No new page, no new route, no new shared state another unit will consume.
- The data path already exists.
- At most about three production files.
- One observable behavior change, expressible as one to four checks.

Bouncing costs two minutes. Building the wrong shape costs a round and a
revert, so bounce early and without hedging.

**The tripwire, one line, before you commit.** Did this change put a second
tenant into a unit that had one - a second mode, a second caller shape, a
second vocabulary in one type? If yes, write
`- Tripwire: fired - <the concept in one noun phrase>` in the ledger and name
the sites. You do **not** reshape it: `loom-shape` prices reshapes and it has
not run. A fired tripwire puts the round over its debt cap on its own, which is
the point.

**Two tidy questions, diff-scoped, before you commit.** Not the five
`loom-tidy` asks over the whole app, because the other three need the branch
against the app and that is settle-up work. These two a tweak can genuinely
fail, and both are answered from the diff:

1. Did this leave the superseded path live? Follow the threads - imports,
   barrel exports, routes, nav entries, `en.json` keys, `data-testid`,
   stories, specs. Two live ways to do one thing is worse than dead code.
2. Did this hand-roll something the platform already provides? The contract's
   rosters are the list.

Fix what you find in the same commit if it is smaller than the change itself.
Record anything bigger as settle-up input.

**Verify is the cheap pair plus your own specs**, exactly as normal: your spec
files, `npx nuxt typecheck`, `npx eslint --fix <touched paths>`. Do not run the
full suite, the coverage gate or a11y - step 3 owns those and runs them in
parallel a few minutes later.

### The three modes

- **tweak** (default). Normal born-red discipline. One to four checks written
  first, seen failing for the right reason, then green.
- **refactor** (`--refactor`). Behavior does not change, so there is nothing to
  be born red. Borrow reshape mode's discipline instead, from your own skill
  file: the existing suite is the check, specs may move but may never be
  weakened or deleted, the test count after is at least the count before, and
  every seam you introduce gets one mutation - break it, see the covering specs
  go red, restore, confirm `git status` clean. Record both test counts; that
  pair is this mode's headline evidence.
- **adopt** (a dirty tree, no request). The human already wrote it and clicked
  it. **Do not revert it.** Read the diff for the behavior it demonstrates,
  write the checks against it, and prove each one with a targeted mutation
  rather than a red record: break the exact line it claims to cover, see it
  fail, restore, confirm the tree is otherwise unchanged. Then finish the work
  the diff left rough.

  Be straight about this in the ledger: it is the one place ninja's proof is
  weaker than loom's, because you are writing specs while holding the
  implementation. It buys back `loom-adopt`'s patch, stash, gap sweep and
  reconcile, which measured about eleven minutes on this repo and exist only to
  make reverting a human's work safe. Nothing is reverted here, so nothing
  needs making safe. A prototype big enough to want the stronger proof is
  `/loom-finish`, and say so if the diff turns out to be that.

## Review debt and the settle-up

The ledger header carries one line, which ninja writes on its first round and
rewrites on every round after:

```markdown
- Ninja debt: <n> rounds since <sha> (last full review: round <k>, <iso>)
```

`<sha>` is the commit the branch-scoped review passes last covered. Ninja
carries it forward untouched. Only a settle-up moves it.

The cap is 3 ninja rounds, or 150 unreviewed production lines, or 5 unreviewed
production files, or a fired tripwire. **Over the cap warns and never blocks.**
The debt line then goes in three places every round: the ledger, the appended
report section, and your closing message, with one sentence naming what is
unreviewed and the command that fixes it.

`/loom-ninja --settle` runs the deferred tail, in this order, each as one
subagent by agent type:

1. `loom-probe-deep`, `loom-shape`, then `loom-tidy` - **seeded with the ninja
   delta as their search list**, not the whole branch: the units the ninja
   rounds touched, from `git diff --name-only <reviewed base>..HEAD`. That is
   the same narrowing `loom-tidy` already does off the plan's unit list, and
   it is what keeps the tail proportional to what changed instead of to the
   branch's age. Their comparison set is still the whole app; only their input
   list is narrowed. The mutation sweep takes that reviewed base as its own
   argument (`node stryker.changed-ranges.mjs <reviewed base>`), so it covers
   the unreviewed rounds and nothing already swept.
2. At most one `loom-slice` reshape turn, if shape priced a finding executable,
   under `loom`'s budget rules unchanged.
3. Step 3's gate script, then step 4's land.
4. Rewrite the debt line to `0 rounds since <new HEAD>` and name the round that
   reviewed it.

A settle-up is its own round and gets its own `## Round <n> (ninja settle-up)`
heading. Run one before `/paperwork` whenever the debt line is not zero, and
tell the human that plainly rather than letting a PR open over unreviewed work.

## The ledger entry

A ninja round is a round, numbered off the highest already present, and it
nests under its own heading exactly as a `loom-finish` round does. `(ninja)` in
the heading is what a later settle-up finds the unreviewed rounds by, so it is
not decoration.

```markdown
## Round <n> (ninja) - [ ]
- Timing: started <iso>, finished <iso>, took <hh:mm:ss>
- Request: <verbatim | uncommitted diff>    Mode: tweak | refactor | adopt
- Debt at start: <n> rounds, <lines> lines, <files> files since <sha>

### Build - [ ]
- Guard: in scope - ui-app only, no new route or shared state, <files> files, <checks> checks
- Platform: <unit taken, confirmed at path:line> | hand-rolled <what> - passed over <unit>, <why>
- Red: <spec path> failed as expected | Mutation: <line broken, spec went red, restored>
- Green: <commit> <subject>
- Verify: typecheck exit 0 | eslint exit 0 | slice specs n/n
- Tripwire: no second tenant | fired - <concept>, sites <path:line>
- Tidy: superseded path <none live | fixed in this commit>; hand-roll <none | recorded>
- Claims: C1 - evidence: <cmd + result> - falsifier: <what would disprove>

### Probe - [ ]
- F1: <input -> observed vs expected> (must-fix | polish)
- Promoted specs: <paths | none>
#### Fix turn R<n>.1 - [ ]     (at most one)

### Gate - [ ]
- <scorecard, one line per check with its real exit code>    Verdict: READY | NOT READY

### Land - [ ]
- Merge: <sha | up to date>    Push: <yes | local only>    Report: appended
- Debt after: <n> rounds, <lines> lines - settle up before the PR | clear
```

Stage headings are unnumbered, as the contract's round template has them; only
ids that must stay unique across rounds carry the prefix, which here is the fix
turn. `scripts/debt.sh` reads `### Land - [x]` under the round heading as the
proof the round finished, so that heading is the one line a round must not
improvise.

Everything else the contract says about the ledger holds: append after every
stage, evidence lines carry a command and an exit code, output past about
twenty lines goes to a sidecar under `artifacts/loom/<slug>/`, timings are read
from `date -Iseconds` and never remembered, and the `- Gate:` line you write is
the last line of the section you judged.

## Blockers and asks

- **No planned ask moments.** Attended, the only pause is the push
  confirmation. Loom's two asks approve a brief and a plan, and ninja has
  neither: the guard is what replaces the plan approval, and a tweak is cheap
  enough to redo that trusting the request is the right trade. Any other
  question is a bug in this skill.
- An open question takes the contract's default order - this app's precedent,
  then `src/ui-app/CLAUDE.md`, then the most idiomatic Nuxt UI shape - and is
  logged `(defaulted)` with the alternative.
- Blockers stop the round with a ledger entry and a `blocked` receipt: a guard
  bounce (report it as a clean stop, not a failure), a must-fix open after the
  one fix turn, a gate still NOT READY after its retry, a merge whose sides
  disagree about behavior, or any contract hard stop.

## Invariants

- **Ninja checks the same things loom checks.** Born red, the full unit suite
  at 100 percent statements and branches, build, storybook a11y, lint,
  typecheck, the story check, finder never the fixer. Anything ninja is
  tempted to drop from that list is a bug report against this file, not a
  flag.
- **What it defers, it records.** Every skipped branch-scoped pass is a number
  in the debt line, in the report, and in the closing message. A ninja round
  that ships without its debt line has broken the one promise that makes it
  defensible.
- **The licence is checked by script, not by judgment.** No landed round, no
  ninja round.
- Two subagents on the happy path, both spawned by agent type. The gate and the
  merge are scripts; the orchestrator runs them and reads exit codes, and still
  never reads source or edits code itself.
- One change at a time. Ninja has no slice loop and no crew, because there is
  nothing to partition.
- The bar is identical attended and solo. Attendance changes only who confirms
  the push.
- The contract's hard stops hold: secrets, generated catalogs, `main`, the
  read-only default worktree. A stop is reported, never worked around.
- No work item, no PR, no teardown, no worktree. Those are `/paperwork` and
  `/teardown`, on the human's word.
