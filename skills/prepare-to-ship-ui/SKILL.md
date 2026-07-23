---
name: prepare-to-ship-ui
description: Final pre-PR gate for a ui-app change, run after review-ui has passed and the code is ready to ship. Runs the three hard gates the repo enforces - production build, unit tests at 100% coverage, and the accessibility suite - and reports a pass/fail scorecard grounded in real command exit codes, not log text. On any failure it surfaces the actual failing output and returns a NOT READY verdict; it does not fix the code (that is implement-ui / simplify). Invoke when the user asks to "prepare to ship", "ship check", "final gate", "last-minute checks", "pre-PR checks", or "prepare-to-ship-ui" for a ui-app feature that is built and reviewed.
---

# prepare-to-ship-ui Skill

You are the last gate before a `ui-app` change opens a pull request. It runs
**after** `review-ui` has passed and the code is considered done. Its only job is
to confirm the three checks CI enforces actually pass locally, so a PR does not
fail the pipeline on something the author could have caught in one pass:

1. **Build** - the production build compiles.
2. **Unit tests at 100%** - the unit suite passes and holds the repo's 100%
   statement and branch coverage gate.
3. **Accessibility** - the Storybook a11y suite passes.

**This skill runs commands but does not modify source.** If a gate fails, you
report the failure with its real output and stop at a NOT READY verdict. Fixing
the code is a separate step the human drives (typically back through
`implement-ui`, `testing-ui`, or `/simplify`). Do not edit files to make a gate
pass.

## Run in a fresh subagent when the context is dirty

This gate is invoked iteratively, often several times in one session, and the
three checks produce CI-length command output. To keep the main conversation
clean:

- **If the current context is dirty** - there is already unrelated conversation,
  prior tool output, or another skill's work in context (e.g. you were invoked
  right after a review/iterate run, or this is a repeat ship check) - do NOT run
  the gates below inline. Dispatch the whole run to a fresh `general-purpose`
  subagent (Agent tool) and have it return the scorecard and verdict. Relay that
  scorecard to the user concisely; do not dump the subagent's transcript. Each
  invocation spawns its own subagent, so repeated checks never accumulate in the
  main context.
- **If you ARE that dispatched subagent** (a fresh context), or the context is
  genuinely clean (a fresh session where this is the first substantive work), run
  the gates inline and do NOT dispatch again.

The only input is the `ui-app` change on the current branch, so the subagent
needs no special seeding beyond that. Tell it to follow this skill
(prepare-to-ship-ui) end to end - staying read-only - and return the three-line
scorecard, the verdict, and the actual failing output for any gate that fails.

## Step 0 - Confirm scope

This gate covers `src/ui-app/` only. Run every command from that directory:

```
cd src/ui-app
```

If the working tree has no `ui-app` changes on this branch, say so - there is
nothing to gate - but still run the checks if the user explicitly asks, since a
green gate on an unchanged tree is a valid answer.

## Step 1 - Run the three gates

Run all three regardless of individual outcome, so the user gets one complete
scorecard instead of fixing one thing at a time. They are independent (Vitest
compiles through Vite on its own and does not consume the `nuxt build` output),
so a build failure does not invalidate the test runs.

The exit code is authoritative - **never infer pass/fail from log text.** Capture
each command's exit code and its output.

```bash
# 1. Production build
npm run build

# 2. Unit tests + 100% coverage gate
#    (test:ci bakes in --coverage.thresholds.statements=100 --coverage.thresholds.branches=100,
#     so a coverage shortfall exits non-zero on its own - this IS the 100% check)
npm run test:ci

# 3. Accessibility suite (the Storybook project, driven by @storybook/addon-a11y)
npm run test:a11y
```

Notes:
- The a11y suite (`test:a11y` -> `vitest run --project=storybook`) drives a real
  browser via `@vitest/browser-playwright`. On a first run it can fail because the
  Playwright browser binary is not installed. If the failure is a missing-browser
  error rather than a real a11y violation, run `npx playwright install` once and
  re-run that gate - and say that is what you did.
- If a command hangs or needs a long time, let it finish; do not kill it and
  report a false failure. These are CI-length runs.

## Step 2 - Report the scorecard

Report one compact scorecard, one line per gate, then a verdict:

```
Build          PASS / FAIL
Unit + 100%    PASS / FAIL
Accessibility  PASS / FAIL
```

- **All three PASS** -> verdict: **READY TO SHIP**. State it plainly, no hedging.
- **Any FAIL** -> verdict: **NOT READY**. For each failed gate, surface the
  actual failing output so the user does not have to re-run to see it:
  - **Build**: the compiler/build error(s) - file and message.
  - **Unit + 100%**: whether it was a *test failure* (which test, the assertion)
    or a *coverage shortfall* (Vitest prints the uncovered files/lines and the
    threshold it missed) - name which, they are fixed differently.
  - **Accessibility**: the specific a11y violation(s) and the story/component they
    fired on, not just "a11y failed."

Keep it to the load-bearing lines, not a full log dump, but be specific enough
that the user can act without opening the run themselves. Point each failure at
the skill that owns the fix (`implement-ui` for build/a11y code, `testing-ui` for
tests and coverage), and stop - do not attempt the fix here.

## Autonomous mode (headless, under joey-bot)

This gate is already non-interactive, so autonomous mode changes almost nothing
(see [`../shared/autonomous-pipeline.md`](../shared/autonomous-pipeline.md)):

- You are already the dispatched subagent (joey-bot spawned you); run the three
  gates inline, do not dispatch again.
- Run all three gates, return the scorecard, the verdict, and the actual failing
  output for any gate that fails - exactly as in interactive mode. Still edit
  nothing: on a failure you report NOT READY and stop. The orchestrator, not this
  skill, decides whether to loop back through implement-ui / testing-ui to fix.

## Conventions

- Run every gate; report the real exit code for each. Do not short-circuit after
  the first failure.
- Never edit source to make a gate pass - this is a read-only gate.
- No em dash, emojis, arrows, or box-drawing characters in the report.
