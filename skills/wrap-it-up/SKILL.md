---
name: wrap-it-up
description: Finish a momentum branch after the code is written and the human has verified it behaves correctly, and hand back a pushed branch plus a plain-language report of everything that changed. A pure orchestrator: it merges the latest origin/main into the branch and resolves any conflicts, fans out the read-only review passes (solidify, /code-review, /security-review, and review-ui when ui-app changed), fixes only the findings that are real and obvious, writes the suite with update-tests, runs the prepare-to-ship gate (lint, unit tests, the 100% coverage thresholds, build, a11y), commits and pushes with ship-it, then writes an eli5-style walkthrough explaining file by file what changed and why, so the human can read the branch and open the PR themselves. Low-priority nitpicks that would cost code simplicity are deliberately not fixed and land in the report instead. It never opens a PR and never creates a work item. Invoke when the user types /wrap-it-up, or asks to "wrap it up", "wrap this up", "finish this off", "close this out", "final pass before PR", or "get this branch ready for review" once implementation is done.
---

# wrap-it-up Skill

The last skill in a session. The code is written and the human has clicked through
it and is happy with how it behaves. What is left is everything between "it works"
and "someone else can review it": the merge with the latest main, the reviews,
the tests, the local gate, the commits, and an explanation the reviewer can
actually read.

You (the invoked agent) are the **orchestrator**. You do none of the work yourself.
You own the state file, the triage decisions, local git bookkeeping, and the final
report. Reading source, applying fixes, writing tests, running the gate - all of
that happens in subagents, so your context stays clean and your report stays
accurate. Same discipline as `../shared/turn-by-turn-loop.md`: if you catch
yourself reading the diff or editing code in your own context, stop and delegate.

Two deliverables, and nothing else:

1. the branch merged up to date with `origin/main`, pushed to `origin/<branch>`,
   and green on the local gate;
2. `artifacts/wrap-it-up/<branch>-report.md`, a plain-language walkthrough of the
   branch, also presented inline.

It stops there. The PR and the TFS work item stay with the human on purpose: they
are about to read the diff file by file, and the report exists to make that read
fast and to show them what changed after they last looked.

## Invocation

```
/wrap-it-up [hint]
/wrap-it-up --no-push        # commit, but leave the branch local
```

`hint` is optional context for the report and the PR draft ("this is the second
half of the widget story", "the config bit is a follow-up"). It never widens the
scope of what gets fixed.

Say the resolved shape in your first line of output, before any tool call:
`Branch: <branch>  Components: <list>  Passes: <the ones that apply>`.

## Preconditions, checked not assumed

- **The human has verified behavior.** That is the whole premise: it lets the
  reviews and the tests treat the current behavior as correct. Anything that would
  change verified behavior is a stop, not a fix (see the bar below).
- **The branch is not `main`.** If it is, stop and say so; nothing here commits to
  `main`.
- **The code compiles.** If it does not, this is not a wrap-up job. Stop, name the
  error, and hand it back to the implementation skill or the human.
- **There is something to wrap.** Empty diff against `origin/main` and a clean
  tree means stop and say so.

## The bar: what gets fixed here, and what does not

Four review passes run, and they will return more than is worth doing. Left
unfiltered, a review pass trades away simplicity for edge cases that cannot happen
with real inputs, and the branch ends up longer and harder to read than the one
the human already approved. So triage is the point of this skill, not a step in it.

**Fix a finding only when all four hold:**

1. **It is a real defect a reviewer would block on.** A correctness bug, a
   security hole, a missing or broken test, an accessibility violation, a
   hardcoded string or hex where the repo forbids it, superseded code the change
   left behind, or duplication that will silently drift.
2. **The fix is small and obvious.** A contained diff in the code the branch
   already touches. No new abstraction, no re-architecture, no new dependency.
3. **The code is no harder to read afterwards.** Simplicity wins ties. A guard for
   a state the callers cannot produce, a defensive branch nothing can reach, a
   rename that ripples through unrelated files - all excluded, however correct the
   reasoning behind them.
4. **It does not change behavior the human verified.** If a finding says the
   verified behavior is itself wrong, that is a real finding and a stop: report it,
   do not quietly change what they signed off on.

Everything else is **deliberately not fixed**, and every one of them lands in the
report under "Not fixed, on purpose" with a one-line reason. That list is useful
output, not an apology: it is how the human sees what was considered.

Two hard exclusions on top:

- **Never move a goalpost to get green.** No lowering a coverage threshold, no
  coverage excludes to dodge an uncovered branch, no deleting or skipping a
  failing test, no widening access to make something testable. A failing test is
  evidence until proven otherwise.
- **`en.json` only.** `fr.json`, `es.json`, `en-XA.json` and the XLIFF memory are
  pipeline output. Never edit them, never prune keys from them, never reach for
  `translate.ts --pseudo`.

## Model per pass

The orchestrator delegates everything, so its own context stays lean and it needs
no top tier. Spend it where judgment shows up.

| Pass | Model |
|---|---|
| conflict resolution (one subagent per conflicted file) | opus |
| review fan-out (solidify, code-review, security-review, review-ui) | opus |
| fixes (one subagent per file) | opus |
| update-tests | sonnet |
| prepare-to-ship | sonnet |
| ship-it | sonnet |
| the report | opus |

## Phase 0 - preflight and scope

Inline, cheap, no subagent.

```bash
cd "$(git rev-parse --show-toplevel)"
git branch --show-current
git fetch origin
git diff --name-only origin/main...HEAD      # committed
git status --porcelain                        # uncommitted and untracked
```

The repo is jj-colocated, so `git branch --show-current` and `git rev-parse HEAD`
can lie (empty, stale, detached). Cross-check with
`jj log -r @ --no-graph -T 'bookmarks.join(",") ++ "\n"'`, and if the three-dot
diff comes back empty or obviously wrong fall back to `git diff origin/main`
before concluding anything.

**Uncommitted work counts.** On this repo an unstaged change is review state, so it
is part of the branch and part of every pass's scope. Say so in each seed.

From the file list, resolve the **components** the branch touched: the path segment
right after `src/` (`cut -d/ -f2`), never the basename. That decides which passes
apply and what the gate will run. Then create the state file (see below) and state
the plan in one short block: branch, components, which passes will run, which are
skipped and why.

## Phase 1 - merge the latest origin/main

The branch has to sit on top of what `main` is now, not what it was when the work
started, and that has to happen before anything is reviewed, tested or gated.
Otherwise the run certifies a version of the code that never exists: the reviews
read stale neighbours, the coverage gate measures a suite main has already moved
under, and the human gets a report about a tree they still have to merge by hand.

Merge, never rebase. The branch may already be pushed, and a rebase rewrites
published history. `git merge origin/main`, nothing else.

**Is there anything to merge**

```bash
git fetch origin
git merge-base --is-ancestor origin/main HEAD && echo up-to-date
```

`up-to-date` means the branch already contains main: record the phase done with
that reason and go to phase 2.

**Can the merge start**

Uncommitted work is normal here, and `git merge` refuses to start when a dirty file
is one the merge also touches:

```bash
comm -12 \
  <(git diff --name-only HEAD...origin/main | sort) \
  <(git status --porcelain | cut -c4- | sort)
```

- **No overlap** - merge now; the dirty files ride along untouched.
- **Overlap** - run phase 6's `ship-it` early in commit-only mode (`--no-push`) so
  the working tree lands in real commits first, then merge. Never `git stash`: a
  stash is easy to lose and this is the human's review state.

**The merge**

```bash
git merge --no-edit origin/main
git diff --name-only --diff-filter=U     # conflicted files
```

A clean merge: record the merge commit, move on.

Conflicts get **one subagent per conflicted file** (opus). One file each, so they
cannot collide, so they run concurrently. Seed each with the worktree path, the
file, what the branch is trying to do, and this bar:

> Resolve this file's conflicts so both sides' intent survives. Read enough of both
> histories to know what each side was doing:
> `git log --oneline HEAD..origin/main -- <file>` for main's side,
> `git log --oneline origin/main..HEAD -- <file>` for the branch's. Never take one
> side wholesale because it is shorter or easier. Never delete someone else's
> change to make the markers go away. Leave no conflict markers and no
> commented-out losing side. Return the resolved hunks, and one line per hunk
> saying what each side wanted and how both survived.

Three kinds of file are not hand-merged:

- `fr.json`, `es.json`, `en-XA.json`, the XLIFF memory - take main's side
  (`git checkout --theirs <file>`) and let the pipeline regenerate. `en.json` is a
  normal hand-resolved conflict.
- lockfiles - take main's side and re-run the install so the lockfile is
  regenerated, never hand-stitched.
- anything else generated from a source file - resolve the source, regenerate the
  output.

**Stop, do not guess**, when the two sides genuinely disagree about behavior: main
changed the same thing the branch changed and keeping both is not possible.
`git merge --abort`, leave the tree as it was, and report the file, what each side
does, and the options. That is the human's call, not a merge resolution. Same stop
if a resolution would change behavior the human verified.

**After the merge**

A merge can conflict nowhere and still be broken: main renamed something the branch
calls, or changed a contract it relies on. So finish the merge commit if the
resolution left it open (`git commit --no-edit`), then have one subagent build the
touched components and report the real output. A broken build here is a stop with
the error. The suite, coverage and lint stay in phase 5.

Everything downstream now reads the merged tree. Useful side effect: with main
merged in, `git diff origin/main...HEAD` and `git diff origin/main` agree, so the
diff every later phase reviews is exactly the branch's own work.

## Phase 2 - the review fan-out (concurrent, read-only)

Four independent read-only passes. They do not edit, so they run **concurrently**:
one message, one Agent call each, each on its own fresh subagent.

| Pass | Runs when | Seed |
|---|---|---|
| `solidify` | always | SOLID / DRY / maintainability on the branch, in whole-app context. Report only, no edits. |
| `/code-review medium` | always | correctness and simplification on the branch diff. No `--fix`, no `--comment`. `medium` on purpose: fewer, high-confidence findings is exactly the bar here. |
| `/security-review` | always | the branch diff. |
| `review-ui` | `src/ui-app/**` changed | **report-only mode**, local branch scope. Nuxt UI component choice, i18n, theming tokens, a11y, repo standards. |

Every seed carries: the worktree path, that uncommitted changes are in scope, that
the human has already verified behavior, and this line so nothing gets applied
behind your back:

> Report only. Make no edits, no commits, no pushes. Return your findings ranked
> most important first, each with its `path:line`, what is wrong, and the smallest
> fix you would make. Where a fix would trade code simplicity for an edge case
> real inputs cannot reach, say so and rank it low.

Wait for all four. Record each pass's finding count in the state file.

## Phase 3 - triage, then fix

1. **Merge and dedupe.** The passes overlap: solidify and code-review both notice
   duplication, review-ui and security-review both notice unescaped output. One
   entry per defect, carrying every pass that raised it.
2. **Run each entry through the bar** above. Two buckets, and no third: `fix` or
   `not fixed, on purpose` with its reason. Record both in the state file before
   any edit happens, so the report cannot drift from what was decided.
3. **Apply the fixes, one subagent per file.** Group the accepted entries by the
   file they touch and give each file one subagent (files are independent, so
   these run concurrently; two agents in one file is the only real collision risk
   and grouping rules it out). Seed each with the entries verbatim, the
   instruction to make the smallest change that resolves each and nothing else,
   and to return the real applied diff per entry.
4. **Per-file verification is cheap only.** The subagent runs the file-scoped check
   and nothing more: `npx eslint --fix <paths>` for `ui-app`, a build of the
   touched project for C#. The suite and the coverage gate come later, once, in
   phase 5. A subagent must report "deferred to the ship gate", never claim a
   check it did not run.
5. **Bound it.** One fix round per file. If a fix subagent reports the change is
   bigger than the entry described, drop that entry to "not fixed" with the reason
   rather than letting it grow.

Do not ask the human to gate this list. The bar is the gate, and the report is
where they see it.

## Phase 4 - tests

Spawn one subagent for `update-tests`, seeded with the worktree path and the fact
that the code is now final (reviews applied). It scopes itself to what the branch
changed, covers it comprehensively, holds the component's real coverage gate, and
verifies test independence.

Reviews run before tests deliberately, whatever order the request arrived in: a
solidify fix that deletes superseded code or collapses two copies invalidates
tests written against the old shape, and rewriting a fresh suite is pure waste.
Code shape settles first, then behavior gets locked in.

Tell it to end its summary with an explicit `## Handbacks` list (`none` if empty) -
the three things it legitimately finds but does not own: a missing `data-testid`,
a genuinely dead branch that should be removed rather than covered, and code that
contradicts its design. On a non-empty list, spawn **one** fix subagent over the
items and re-run `update-tests` **once**. If the gate still does not hold after
that, stop with the real coverage output; do not loop a third time and do not let
a contrived test paper over the gap.

## Phase 5 - the ship gate

Spawn one subagent for `prepare-to-ship`. It owns lint, unit tests, the coverage
thresholds, build, and the ui-app storybook a11y suite, for the components the
branch touched, and it fixes test, coverage and lint failures in its own lane.

- **READY TO PUSH** - carry the scorecard into the report and continue.
- **NOT READY** - it already exhausted its fix rounds on the things it owns, so
  what came back is something it does not own. Make one targeted remediation pass
  (one fix subagent seeded with the real failing output), re-run the gate once,
  and if it still fails **stop the run**: no commit, no push. Report the failing
  output and what it blocks on. A faked pass here is the worst outcome this skill
  can produce.

## Phase 6 - commit and push

Spawn one subagent for `ship-it`, passing the hint if there was one. It splits the
tree into one commit per logical piece, writes the subjects in the repo's style,
commits explicit paths, and pushes the branch.

- If phase 1 already ran it in commit-only mode to clear the way for the merge,
  this run just commits what is left and pushes. The merge commit is already
  there; leave it alone.
- `--no-push` stops it after the commits; say so in the report.
- Its stops are still stops: `main`, anything that looks like a secret, a
  hand-edited translation catalog. Surface them and do not work around them.
- Local-only files stay uncommitted and untouched, including the state file and
  the report under `artifacts/`.

## Phase 7 - the report

The report is the deliverable the human actually reads, so it gets its own
subagent (opus) rather than being stitched together from your notes. Seed it with
the state file path, the accepted and rejected findings, the tests added, the gate
scorecard, the commit list, and this task:

> Read the final branch diff against `origin/main` and write
> `artifacts/wrap-it-up/<branch>-report.md` for a senior engineer who verified this
> feature by hand, has not seen the wrap-up edits, and is about to read the branch
> file by file before opening the PR. Explain in plain language. Define every term
> the code forces on the reader. Apply the `eli5` skill's method for the
> explanations and the `avoid-ai-writing` skill's rules to the prose.

Structure, in this order:

1. **What this branch does** - three sentences, in terms of what someone using the
   app would notice.
2. **The changes, in the order to read them** - one entry per file or tight group
   of files: what the file is, what changed in it, why it changed, and anything to
   look at closely. Reading order, not alphabetical: the thing that explains the
   rest goes first.
3. **New terms** - only if the branch introduced any (a composable, a BFF
   endpoint, a migration, a wire type). One plain line each.
4. **What changed after you last looked** - the wrap-up edits, grouped: the
   `origin/main` merge and how each conflict was resolved, each review fix with the
   finding that caused it, the tests added, the lint autofixes.
   This is the most important section in the report; the human verified the code
   before these edits existed.
5. **Verification** - the gate scorecard with its real verdict, coverage numbers
   per component, tests added, and the a11y result. Real numbers only.
6. **Not fixed, on purpose** - every triaged-out finding, one line each, with which
   pass raised it and why it was dropped.
7. **Still needs your eyes** - what no check can assert (visual polish, subjective
   UX feel, third-party behavior), each with what to look at and where.
8. **PR draft** - a title in the repo's `[area] Imperative summary` form and a
   short bullet body, plus the `## Related` work-item placeholder. Their PR to
   open; this is just the text ready to paste.

Then present it inline: the "what this branch does" paragraph, the read-order list,
"what changed after you last looked", the scorecard, and the not-fixed list. Point
at the file for the rest. Keep the inline version short enough to read in one
screen.

Two lines that always appear if they apply:

- any `en.json` changed - the PR needs the **`to-be-translated`** label before
  `pr-i18n-parity` can pass. Never try to fix parity locally.
- what CI still owns that the local gate cannot: the container builds, the
  migration apply, `pr-metadata`, the contract breaking-change check. So a green
  scorecard is not read as "CI will be green".

## The state file

One markdown file per branch at `artifacts/wrap-it-up/<branch>.md` (`artifacts/`
is gitignored repo-wide, so it works for a C#-only branch as well as a ui-app
one). Authoritative, resumable, updated after every phase and never in a batch at
the end. On invocation, an existing file for this branch means resume from the
first phase not marked done.

```markdown
# wrap-it-up: <branch>

- Components: <list>        Passes: <the ones that ran>
- Generated: <yyyy-mm-dd>
- Status legend: [ ] pending  [~] in progress  [x] done  [!] blocked

## Phases
### 0. preflight - [ ]
- Result: (branch, components, scope, what is skipped and why)
### 1. merge origin/main - [ ]
- Merged: <sha> | already up to date   Conflicts: none | (file: how it was resolved)
### 2. review fan-out - [ ]
- solidify: N findings | code-review: N | security-review: N | review-ui: N or skipped
### 3. triage and fix - [ ]
- Fixed: N   Not fixed: N
### 4. tests - [ ]
- Result:  Handbacks: (none, or the items and how each resolved)
### 5. ship gate - [ ]
- Scorecard:   Verdict:
### 6. commit and push - [ ]
- Commits: (hash + subject each)   Pushed: yes | no (--no-push) | error
### 7. report - [ ]
- Path:

## Findings
### 1. <short title> - fixed | not fixed
- Raised by: <pass(es)>   Location: `path:line`
- Finding: <one line>
- Decision: <which bar rule settled it>
- Applied: <the diff summary, or "-">

## Blockers
- <anything that stopped the run, with the real output>
```

## Autonomous mode (headless, under another orchestrator)

Every sub-skill is already driven headless here, so seed each one with the
autonomous line from `../shared/autonomous-pipeline.md` (naming wrap-it-up as the
host). When **wrap-it-up itself** runs with no human reachable, only two things
change: `ship-it`'s ambiguous-file question defaults to leaving the file
uncommitted, and the report is returned rather than presented. Everything else,
including every stop, is unchanged.

## Invariants

- The orchestrator delegates all work. It owns the state file, the triage, local
  git bookkeeping, and the human-facing report. No reading the diff or editing
  code in its own context.
- Gate on real results - exit codes and verification output - never on a
  subagent's prose claim of success.
- The bar in "what gets fixed here" is the only filter. Never fix a nitpick
  because it was raised, and never drop a real defect because the fix is dull.
- Never change behavior the human verified. That is a stop with a report, not a
  fix.
- No PR, no work item, no TFS edits. Deliberate: the human opens the PR after
  reading the report.
- Merge `origin/main` in, never rebase onto it. Never resolve a conflict by
  dropping a side, and never guess at one where the two sides genuinely disagree
  about behavior - that is `git merge --abort` and a report.
- Never push to any branch other than the one checked out, never force-push,
  never amend or rebase.
- Stop rather than fake: a NOT READY gate after its one remediation pass means no
  commit and no push.
- No em dash, emojis, arrows, or box-drawing characters in anything written.
