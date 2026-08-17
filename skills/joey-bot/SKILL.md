---
name: joey-bot
description: Run a full round of ui-app dev work autonomously, the way Joey (a senior engineer) would - from a brief spec through to a tested, ready-to-PR branch on its own worktree, then hand to a human to review and ship. joey-bot is a pure orchestrator: it owns a markdown state file and spawns one subagent per pipeline stage (new-work, spec-ui, design-ui, implement-ui, update-tests, review-ui, prepare-to-ship, a self-review), driving each headless via the shared autonomous-pipeline contract, and never does the work itself. Two modes - default pauses once after the spec, `auto` runs end to end with a single final review gate (this is the mode to spawn several of in parallel). Invoke when the user types /joey-bot, or asks to "have joey-bot build/implement <feature>", "do an autonomous dev run on <feature>", or "run the whole pipeline on <feature>" for the ui-app.
---

# joey-bot: autonomous senior-engineer dev run for a ui-app feature

Take a brief spec, and drive the full `ui-app` pipeline to a tested, ready-to-PR
branch without a human in the loop, then stop and hand it back for review. The
deliverable is a branch on its own worktree, built and reviewed and passing the
repo's gates, plus a readable state file explaining every decision made along the
way. Housekeeping (the TFS work item and the PR) happens only after the human
approves.

You (the invoked agent) are the **orchestrator**. You do none of the work
yourself. You build the state file, spawn one subagent per stage, gate each stage
on its real returned result, and record the outcome. Reading source, writing
code, running the pipeline skills - all of that happens in subagents, so your
context stays clean and accurate. This is the same orchestrator discipline as
`../shared/turn-by-turn-loop.md`: if you catch yourself reading source or writing
code in your own context, stop and delegate.

## Invocation and modes

```
/joey-bot <spec>                     # default: one checkpoint after the spec, then autonomous
/joey-bot <spec> auto                # full auto: no mid-run gate, single final review gate
/joey-bot <spec> auto --balanced     # override the model profile (default is --thorough)
/joey-bot <spec> auto --economy
```

- `<spec>` is a brief description of the work (a sentence or a short bullet list).
  Required - if missing, ask what to build before doing anything.
- **default mode** is interactive: it pauses once, after the spec stage, so you
  can catch a wrong direction cheaply, then runs autonomously to the final gate.
  Use it for a single run you are watching.
- **`auto` mode** takes no mid-run input. It runs straight through and ends at the
  final review gate (a ready-for-review report). This is the mode to spawn several
  of **in parallel** (see "Running several in parallel").
- Undecidable decisions are never forked. Pick the most-recommended option and
  record the alternative in the state file. This holds even for a genuine 50/50.

## Model profile (be deliberate about token spend)

The orchestrator delegates all real work, so its own context stays lean; the
expensive tokens are in the stage subagents. Spend the top tier only where
senior-engineer quality shows up (implementation, review), and run mechanical
stages cheap. Pick a model per stage from the active profile and pass it as the
Agent tool's `model` when you spawn that stage.

| Stage | `--thorough` (default) | `--balanced` | `--economy` |
|-------|------------------------|--------------|-------------|
| setup (new-work) | haiku | haiku | haiku |
| spec-ui | sonnet | sonnet | sonnet |
| design-ui | opus | sonnet | sonnet |
| implement-ui | opus | opus | opus |
| update-tests | sonnet | sonnet | sonnet |
| review-ui | opus | opus | sonnet |
| self-review | opus | sonnet | sonnet |
| prepare-to-ship | sonnet | sonnet | sonnet |
| live verification (Chrome MCP) | sonnet | sonnet | sonnet |

Live verification is sonnet across all profiles: its cost is in tool output
(screenshots, DOM snapshots, console/network dumps), not reasoning, and that cost
multiplies across parallel runs, so there is no reason to pay a higher tier there.

The orchestrator itself needs no top tier: when you spawn joey-bot as a background
agent for a parallel run, spawn it on **sonnet** (gating and bookkeeping, not
code). Fable is not wired in - if a profile should use it, confirm its
positioning first rather than guessing.

## Setup (before the pipeline)

1. Derive a short kebab-case `<slug>` from the spec (e.g. `user-status-widget`)
   and the camelCase branch name per the global git rules
   (e.g. `userStatusWidget`).
2. Spawn the **setup subagent** (model: haiku) to run the `new-work` skill,
   **forced to a new worktree, always** - never branch in place in the default
   `C:\code2\momentum` worktree. Parallel runs would collide on it, and even a
   single run should stay off the default checkout. Seed it:

   > Invoke the `new-work` skill for "<spec>". Do NOT branch in place under any
   > circumstances: always create a fresh worktree at
   > `C:\code2\momentum-<slug>` off fresh `origin/main` (new-work's step 3b),
   > even if the default worktree is clean. Return the branch name and the
   > absolute worktree path.

   Capture the branch name and worktree path. Every downstream subagent runs from
   that worktree.
3. Create the state file (see "The state file") at
   `<worktree>/src/ui-app/logs/joey-bot-<slug>.md`. If one already exists for this
   slug, read it and resume rather than overwrite.

## Testing ladder (autonomous code is properly tested)

The whole point of an unattended run is that nobody is watching it work, so the
code it produces must be tested as thoroughly as it can be without a human, and
the report must show that it was. Climb the ladder from cheapest to most
expensive, and go as high as the feature allows:

1. **Static** - compiles and lints clean (implement, Step 3).
2. **Unit / component** - Vitest + Vue Test Utils at the repo's 100% statement and
   branch gate (update-tests).
3. **Accessibility** - the Storybook a11y suite (ship gate).
4. **End-to-end** - one thin Playwright happy-path spec per **integration point**
   the work added that no existing spec crosses: a real backend call, the auth
   boundary, a route that has to resolve, a browser capability the unit tier can
   only fake, a multi-step flow (update-tests). Not one per page - the page is not
   the unit of coverage, the seam is, and once a seam is proven the unit tier
   proves the rest. Work that adds no seam gets no spec. Autonomous runs resolve a
   borderline seam toward writing the test, since no one is clicking through by
   hand.
5. **Live verification** - drive the actually-running app with the Chrome DevTools
   MCP: load the feature, exercise its routes and states, check the rendered DOM,
   console, and network, and capture screenshots as evidence (the live-verify
   stage below).
6. **Human verification** - only what genuinely cannot be asserted (subjective
   visual polish, subtle UX feel). This is the *remainder* after rungs 1 to 5, not
   the default dumping ground: push work down the ladder first, and for anything
   left here, say in the report **why** it cannot be automated.

Every rung that runs must land in the report with its real result and evidence
(coverage numbers, a11y outcome, E2E pass/fail, screenshots and console/network
observations). A rung that could not run (e.g. no browser available for rung 5)
is recorded as such, and its checks move to rung 6 with the reason - never
silently skipped.

## The pipeline

Run the stages in order. For each one: mark it in progress in the state file,
spawn **one synchronous subagent** with the stage's model, seeded with the
worktree path, the autonomous-mode line, and the stage inputs. Wait for its
summary, gate on the real result (exit codes and verification output, not prose),
record the outcome, and move on. Never fan subagents out across stages - the
pipeline is sequential and later stages depend on earlier ones.

Every stage seed includes this line verbatim so the skill runs headless:

> AUTONOMOUS MODE (joey-bot): no human is available for gates. Do not stop for
> approval. Replace every human gate with its documented default per
> `../shared/autonomous-pipeline.md`, make Joey's decisions yourself, decide
> most-recommended and document alternatives (never fork), and return your normal
> handoff summary. Work in the worktree at `C:\code2\momentum-<slug>`.

Stages:

1. **Spec** (spec-ui, sonnet) -> writes `logs/feature-spec.md`. Seed: the raw
   `<spec>`.
   - **default mode only: checkpoint here.** Present the spec summary and its
     recorded assumptions with `AskUserQuestion` (approve / revise / abort). On
     revise, re-run the spec subagent with the feedback. On approve, continue
     autonomously to the end. In `auto` mode, skip this and continue.
2. **Design** (design-ui, per profile) -> writes `logs/feature-design.md`. Seed:
   points it at `logs/feature-spec.md`.
3. **Implement** (implement-ui, opus) -> writes code; verifies compile + lint.
   Seed: points it at `logs/feature-design.md`.
4. **Test** (update-tests, sonnet) -> writes co-located specs; holds the 100%
   coverage gate. Seed: the design handoff and the implemented code, and tell it
   this is an unattended run, so it decides the end-to-end question itself instead
   of asking: one thin happy-path spec per integration point the work added that
   no existing spec crosses, nothing when it added no seam. Tell it to end its
   summary with an explicit `## Handbacks` list, `none` if it has no items.
   - **Handbacks are the code changes update-tests cannot make itself.** It owns
     tests, not components, so three things it legitimately finds fall outside its
     scope: an element it cannot locate without a **missing `data-testid`**, a
     **genuinely dead branch** that should be removed rather than covered by a
     contrived test, and code that **contradicts the design** it is testing
     against. Implement (stage 3) is finished by the time these surface, so
     without this loop the tester either files the flag into a void or reaches for
     the fragile selector it was told not to use, and a dead branch becomes a
     stage-6 coverage failure with no owner.
   - On a non-empty list: spawn **one** implement-ui subagent (opus) seeded with
     the handback items verbatim, the files they name, and the instruction to make
     the smallest change that resolves each and nothing else. This is a freeform
     minimal-change pass, not a re-implementation - it does not revisit the design.
     Then re-run update-tests **once**, seeded with the original inputs plus what
     changed. Record both passes and each item's resolution in the state file.
   - Bound it there. If update-tests still cannot hold the coverage gate after that
     one round trip, stop the run and return a NOT READY report naming the
     unresolved handbacks and the real coverage output. Do not loop a third time
     and do not let it paper over the gap with a contrived test.
   - A design contradiction that implement-ui cannot resolve without changing
     intent is a blocker, not a fix: record it and stop the run, per the
     autonomous-pipeline contract's "surface, do not swallow a genuine blocker".
5. **Review** (review-ui, per profile) -> fix mode, local scope, headless; applies
   quality fixes and writes `logs/feature-review.md`.
6. **Ship gate** (prepare-to-ship, per profile) -> runs the local checks the
   branch's changed components trigger (lint, unit tests, coverage thresholds,
   build, ui-app a11y; no Docker and no PR-level checks), fixes
   test/coverage/lint failures itself, returns the scorecard.
   - On **NOT READY**: it already exhausted its own fix rounds on tests, coverage
     and lint, so what comes back is something it does not own. Make one targeted
     remediation pass - spawn implement-ui with the failing output - then re-run
     the ship gate once. If it still fails, stop the run and return a NOT READY
     report naming the stage and the real failing output. Do not fake a pass.
7. **Self-review** (pr-review-toolkit:code-reviewer via `agentType`, per profile)
   -> a final read of the branch diff against `origin/main` for anything the
   dimension-scoped review-ui does not cover (correctness, obvious bugs, repo
   conventions). Record findings; fix any must-fix via one implement-ui/simplify
   subagent; if code changed, re-run the ship gate.
8. **Live verification** (Chrome DevTools MCP, sonnet) -> rung 5 of the testing
   ladder, run once the code is settled and the ship gate is green. Seed: invoke
   the `chrome-devtools-mcp:chrome-devtools` skill; start the dev server from the
   worktree (`npm run dev`) on a **per-worktree port** (derive it so parallel runs
   never collide - e.g. base it on the slug, and pass it explicitly rather than
   letting two runs both grab the default); navigate to the feature's route(s) and
   exercise each behavior and state the design lists (empty / loading / error /
   validation), at mobile, tablet, and desktop widths. For each, capture evidence:
   a screenshot, plus any console errors and failed network requests. Return a
   pass/fail per checked behavior with the evidence, and a list of anything that
   still needs a human eye (subjective visual/UX judgment) with the reason.
   - **Degrade gracefully.** If no browser or dev server can run in this
     environment (common in a headless/background run), do not fail the run:
     record that rung 5 could not execute, move its checks to "needs human
     verification" with that reason, and continue to the final gate. A missing
     browser is a deferred check, not a build failure.
   - Tear down the dev server when done so a parallel run's port stays free.

**Commit policy.** After each stage that produced or changed code (implement,
test, review fixes, self-review fixes) and passed its verification, make one local
commit on the feature branch with a clear imperative subject (writing rules
applied, no trailers). This is git bookkeeping the orchestrator owns, like the
state file - it does not count as "doing the work". **Never push.** The branch is
the review artifact; pushing and the PR are Phase 2, after the human approves.

## The final review gate

When the pipeline completes (or stops on a hard failure), produce the
**ready-for-review report** and stop. This is the single human gate in `auto`
mode. The report states:

- branch name, worktree path, and the absolute state-file path;
- one line per stage: what it did and its outcome;
- the ship-gate scorecard (build / unit+100% / a11y) with the real verdict;
- the **testing ladder performed**, rung by rung, with evidence: coverage numbers,
  a11y outcome, E2E pass/fail, and for live verification the behaviors checked with
  their screenshots and console/network observations. This is the proof the code
  was actually exercised, not just built;
- **needs human verification** - only the checks that genuinely could not be
  automated (or a rung that could not run, e.g. no browser), each with the reason
  it is here and what to look at (`npm run dev` in the worktree, the specific
  route/state/breakpoint);
- the decisions taken and the alternatives not taken (from the state file);
- the "out of scope but worth noting" items review-ui surfaced (bugs / security /
  a11y), each pointing at its owning skill.

In **default mode** (interactive), present this and ask the human to approve with
`AskUserQuestion`, then proceed to Phase 2 on approval. In **`auto` mode**, the
agent cannot prompt - end here, returning the report. The human reads it in the
main session and runs Phase 2 there.

## Phase 2 - housekeeping (only after the human approves)

Never automatic. Each step confirmed with the human, in the main session:

1. **Work item** - run the `create-tfs` skill to create the story/bug on Joey's
   board.
2. **PR** - push the branch (`git push -u origin HEAD`) and open the PR with `gh`:
   title `[ui-app] <imperative summary>`, body = bullets + a `## Related` link to
   the TFS work item (writing rules applied).
3. **Link back** - add the PR as a **Hyperlink relation** on the work item's Links
   tab via the TFS REST API (the `wit_*` MCP tools cannot add a GitHub PR
   relation) - use the `Invoke-RestMethod` snippet in the root `CLAUDE.md`.

## The state file

One markdown file per run, at `<worktree>/src/ui-app/logs/joey-bot-<slug>.md`
(gitignored; written directly, resumable across sessions). It is the authoritative
record and what the human reads at the review gate. Update it after every stage,
never in a batch at the end.

```markdown
# joey-bot run: <feature name>

- Spec: <the raw spec, verbatim>
- Mode: auto | default        Profile: thorough | balanced | economy
- Branch: <branch>            Worktree: C:\code2\momentum-<slug>
- Generated: <yyyy-mm-dd>
- Status legend: [ ] pending  [~] in progress  [x] done  [!] blocked

## Stages
### 1. setup - [ ]
- Result: (branch + worktree, or blocker)
### 2. spec - [ ]
- Result:  Handoff: logs/feature-spec.md  Commit: -
- Decisions: (choices made, alternatives not taken + one-line why)
### 3. design - [ ]
### 4. test - [ ]
- Result:  Handoff: -  Commit: -
- Handbacks: (none, or one line per item and how each was resolved)
...through self-review and live verification...

## Ship-gate scorecard
- Build: -  |  Unit + 100%: -  |  Accessibility: -   Verdict: -

## Testing ladder (what ran + evidence)
- 1 Static (compile/lint): -
- 2 Unit + coverage: -  (numbers)
- 3 Accessibility: -
- 4 E2E (Playwright): - (warranted? which flows)
- 5 Live verification (Chrome MCP): - (behaviors checked, screenshot paths,
  console/network notes; or "could not run - <reason>")

## Needs human verification (the irreducible remainder)
- <check> - why it cannot be automated - what to look at

## Out of scope but worth noting
- <bug / security / a11y note> -> <owning skill>

## Decisions log
- <stage>: chose <X> over <Y> because <reason>
```

## Running several in parallel

Parallelism is at the joey-bot level: the main session spawns N background
joey-bot agents, each on its own spec. Because each run makes its own worktree
(setup forces a fresh one) and its own state file, they never collide.

From the main session, for each spec, one Agent call (all in one message so they
run concurrently):

- `subagent_type`: `general-purpose` (needs the Skill and Agent tools).
- `model`: `sonnet` (the orchestrator is light; the run picks heavier models per
  stage itself).
- `run_in_background`: true.
- prompt: "Invoke the joey-bot skill in `auto` mode with this spec: <X>. Follow it
  end to end and return the ready-for-review report."

`auto` mode is required for parallel runs - a background agent has no human to
answer a checkpoint. When they finish, review each report and drive Phase 2 per
run in the main session, one at a time.

Depth note: a parallel run nests two levels (background joey-bot -> stage
subagent). The headless pipeline skills are written to stay inline rather than
add a third level (see `../shared/autonomous-pipeline.md`, "Nesting note").

Port note: the only shared resource parallel runs can still collide on is the dev
server's port in live verification (rung 5). Each run must derive a distinct
per-worktree port from its slug and tear the server down when the stage ends, so
two runs never fight over one port.

## Invariants

- The orchestrator delegates all work. It owns only the state file, local git
  bookkeeping (commits, never pushes), the gate decisions, and the human-facing
  report. No reading source or writing code in its own context.
- Every stage runs headless via the autonomous-mode line and runs from the
  feature worktree, on the model its profile assigns.
- Gate on real results - exit codes and verification output - never on a
  subagent's prose claim of success.
- Never fork a worktree for a decision; decide most-recommended and document the
  alternative.
- Never push, and never do Phase 2 (work item, PR) without explicit human
  approval, confirmed each time.
- No em dash, emojis, arrows, or box-drawing characters in anything written.
