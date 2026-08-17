# Autonomous pipeline mode (shared)

The contract that lets the interactive `ui-app` pipeline skills (`spec-ui`,
`design-ui`, `implement-ui`, `update-tests`, `review-ui`, `prepare-to-ship`) run
**headless** under the `joey-bot` orchestrator, with no human available to answer
their gates. Each of those skills carries an `## Autonomous mode` section that
points here for the shared rules and states only its own gate replacements.

Interactive behavior is the default. Autonomous mode is strictly opt-in: a skill
enters it **only** when its invocation says so, so nothing regresses for normal
single-skill use with a human present.

## The trigger

A skill runs headless when, and only when, its invoking prompt contains an
explicit line to that effect, e.g.:

```
AUTONOMOUS MODE (joey-bot): no human is available for gates. Do not stop for
approval. Replace every human gate with its documented default per
../shared/autonomous-pipeline.md, make Joey's decisions yourself, and return your
normal handoff summary.
```

Without that line, the skill behaves exactly as written (interactive, human
gates intact). There is no arg-parsing machinery: the sentence in the prompt is
the signal.

## The universal rule

When headless:

1. **Never stop for human approval or feedback.** Every point where the skill
   would present something and wait (an `AskUserQuestion`, "iterate until the
   human approves", "hand off to the human to test") is replaced by the skill's
   documented default decision, taken autonomously.
2. **Decide as Joey, a senior engineer, would.** For any open choice, pick the
   most-recommended / most-idiomatic option and proceed.
3. **Never fork.** Do not spin up parallel worktrees or build multiple options
   for a close call. Pick the most-recommended option and record the alternative
   you did not take, with a one-line reason, in your handoff summary (and, where
   the skill writes a handoff file, in that file's open-questions/decisions
   section). This holds even for a genuine 50/50.
4. **Still write the same artifacts.** Handoff files, `data-testid` hooks, state
   files, and summaries are produced exactly as in interactive mode. The only
   thing suppressed is the human wait, not the output.
5. **Do not silently downgrade rigor.** All ground-truth discipline stays: verify
   Nuxt UI components/props against the installed API, run the real build/lint/
   test commands, and report actual exit codes. Autonomous means unattended, not
   sloppy.
6. **Test as high up the ladder as the work allows.** An unattended run has no
   human clicking through, so testing is not optional: cover the code with unit /
   component tests at the repo's coverage gate, warrant E2E for real flows, and
   leave for human verification only what genuinely cannot be automated, with the
   reason. joey-bot owns the full testing ladder (its "Testing ladder" section);
   these skills supply the rungs they own and never quietly downgrade rigor
   because no one is watching.
7. **Surface, do not swallow, a genuine blocker.** If the input is
   self-contradictory or conflicts with the live API such that no reasonable
   default exists, do not guess a fix that changes intent. Record the blocker in
   your summary and return; the orchestrator decides whether to stop the run.
8. **Keep the text rules.** No em dash, emojis, arrows, or box-drawing characters
   in anything written.

## Per-skill gate replacements

Each skill's own `## Autonomous mode` section is authoritative; this table is the
summary the orchestrator relies on.

| Skill | Interactive gate | Headless default |
|-------|------------------|------------------|
| spec-ui | Step 3 questions + Step 4 iterate-to-approval | answer each open question with the house default / most-recommended option, mark the choice and the alternative in "Conventions & deviations", write `feature-spec.md` without stopping |
| design-ui | Step 1/2 clarifying questions + Step 9 approve-then-write | resolve open questions most-recommended, record alternatives in "Open questions / risks", write `feature-design.md` without stopping |
| implement-ui | Step 4 hand off to human to test and iterate | after compile + lint pass, do not stop for manual testing; list the manual checks for the final review gate and return |
| update-tests | Step 4's end-to-end approval question (assumes prior human approval of the code) | run immediately after implement; enforce the component's real coverage gate; decide the end-to-end question yourself under the same "one thin happy path per new integration point no existing spec crosses, nothing if the branch added no seam" rule, resolving a borderline seam toward writing it since nobody clicks through; note that manual verification was deferred |
| review-ui | section 1 bulk gate + per-finding keep/revert/commit | auto-accept must-fix + recommended, apply and verify each, record; defer minor findings with a note; handle findings **inline** (no extra subagent layer) to cap nesting depth; make no commit here |
| prepare-to-ship | (already non-interactive) | unchanged; run the local checks the changed components trigger (no Docker, no PR-level checks), fix test/coverage/lint failures in place within its own bound, return the scorecard and verdict |

## Nesting note

Under `joey-bot`, a skill may already be running inside a stage subagent (the
orchestrator spawned it). Skills that would normally fan out a further subagent
per item (`review-ui` via the turn-by-turn loop) must **not** add that extra
layer in headless mode: handle the items inline in the current context. This
keeps the depth at orchestrator -> stage subagent, not a third level.

## What autonomous mode does NOT change

- The skill's scope boundaries (spec-ui writes no code, design-ui writes no code,
  review-ui fixes only quality findings, prepare-to-ship edits only tests, lint
  and coverage).
- The verification commands and the requirement to report real results.
- The handoff file names and formats.
- Commits and pushes: an individual skill still never pushes. Commit policy for
  the run as a whole belongs to `joey-bot`, not to these skills.
