---
name: prototype
description: Build an implementation plan into working code the fastest way possible, so the human can exercise it in a real running app before anything is committed. Takes a plan (a design handoff, a plan file, a bullet list, or a plan already agreed in the conversation) and writes only the production code that plan calls for. No tests written or run, no coverage, no docs, no refactors, no review passes. Verification is the minimum that proves the code compiles and lints for the components it touched, and nothing else. Ends by handing back what to click and what was deliberately left undone. Invoke when the user types /prototype, or asks to "prototype this", "just make it work", "rough it in", "quick pass on this plan", "build this so I can try it", or hands over a plan and wants running code rather than a finished branch.
---

# prototype Skill

Turn a plan into code the human can run, in the fewest steps that still produce a
working app. This is the fast half of the loop: prototype, the human tries it,
feedback, prototype again. Everything that makes a branch shippable happens later,
in `loom-finish`.

Optimise for time to a testable app, not for a finished branch.

## Scope

**In:** production code changes the plan calls for, and the cheapest check that
proves they compile and lint.

**Out, without asking:** unit tests, running the test suite, coverage, storybook
or a11y runs, docs, READMEs, changelogs, comments elsewhere in the repo,
refactors the plan did not ask for, review passes, committing, pushing. Leaving
that gap is the point of this skill. Name it in the handoff, do not fill it.

Two rules still hold because breaking them costs more than it saves:

- **Never edit the default worktree.** `~/m-code/momentum` (`C:\code2\momentum`
  on Windows) is read-only reference. If the session is standing in it, stop and
  tell the user to move to a `momentum-<feature>` worktree first.
- **Localized strings: `en.json` only.** Never touch `fr.json`, `es.json`,
  `en-XA.json` or the XLIFF memory. Those are pipeline output.

## Run inline

Do not dispatch a subagent for the ordinary case. The dispatch, the re-read of
the plan, and the summary relay all cost more than they save on a short run, and
this skill is invoked over and over in one session.

The one exception: a plan covering several components that do not touch each
other's files. Then one `general-purpose` subagent per component, in parallel, is
genuinely faster. Seed each with the plan slice for its component and this skill.

## Step 1 - take the plan as given

The plan arrives as a `design.md` or `logs/feature-design.md`, a spec, a file the
user names, a bullet list in the prompt, or a plan already agreed earlier in the
conversation. Read it once, in full, and take it as the contract.

- Do not redesign, do not widen it, do not add the thing it obviously forgot.
- If a step is ambiguous, pick the most reasonable reading and note it in the
  handoff. Ask only when the readings produce materially different code.
- If a step is wrong or blocked, do every other step, then say plainly which one
  you skipped and why. Scaling the plan down is the user's call.
- If there is no plan at all and the ask is a one-liner, treat the user's words
  as the plan and restate it in a sentence before you build.

State the file-level plan in two or three lines (what you will create, what you
will edit), then build. Skip formal task tracking for anything under about five
files; it is overhead on a run this short.

## Step 2 - write the smallest diff that makes it real

Match the surrounding code. Reuse what is already there rather than inventing a
parallel way to do the same thing. Repo style still applies (no `var` in C#,
`<script setup lang="ts">` in Vue, no em dash, no emoji), because complying is
free and cleaning it up later is not.

What "quickest" means in practice:

- Reach for the existing component, composable, helper or endpoint before writing
  a new one.
- Wire the real path end to end before polishing any single layer. A screen that
  renders with real data beats a perfect mapper with nothing to click.
- Stub only where the plan says to stub, and make the stub obvious.
- Do not read files you do not need. Grep to the touch points, use the LSP for a
  shared export's real call sites, and leave the rest alone.

Add `data-testid` hooks as you go where `ui-app/CLAUDE.md` calls for them. That
is not test work, it is markup, and adding them later means editing the same
files twice.

## Step 3 - minimum verification

Only for the components the diff actually touched, and nothing else. The exit
code decides, never the log text.

| Touched | Run |
|---|---|
| `src/ui-app/**` | `cd src/ui-app && npx eslint <the files you changed>` then `npm run build` |
| a C# project | `npx nx run <project>:build` (Debug, and it restores first) |
| several C# projects | `npx nx run-many -t build --projects=<csv>` |
| a standalone package (`tools/i18n`, `tests/e2e/ui-app-e2e`) | its own `npm run build` or `npx tsc --noEmit` if it has one |

Notes:

- `eslint` on the changed files is seconds; `eslint .` is not. Scope it.
- `npm run build` in `ui-app` is the typecheck too. Run it once, at the end of
  the round, not after every file.
- Debug, not Release. Release belongs to the ship gate.
- Nothing here runs Docker, tests, coverage, storybook or a11y. If a run needs
  one of those to be meaningful, say so in the handoff rather than running it.
- Fix what these checks report and re-run. If a check still fails after three
  rounds, hand it back with the real output rather than grinding.

## Step 4 - hand back for the human to try

Short. The human wants to start clicking.

1. **What changed** - one line per file, grouped by component.
2. **How to exercise it** - the command (`cd src/ui-app && npm run dev`, or the
   Aspire AppHost for a service), the route or entry point, and the specific
   states worth trying.
3. **Check results** - lint and build, pass or fail, per component.
4. **Deviations** - anything the plan said that you read differently, skipped, or
   could not do, and why.
5. **Deliberately not done** - one line: no tests, no coverage, no docs, no a11y
   run, nothing committed. Then name where that happens once the behavior is
   settled: `loom-finish` for `ui-app` and the realm BFFs; for anything else, say
   the branch still needs its own tests and gate by hand.

Then stop. Do not volunteer the next step, do not start on tests, do not commit.

## Iterating

Feedback comes back, you repeat Steps 2 and 3 only. Do not re-read the whole plan
each round, and do not re-verify components the round did not touch. Keep the
handoff to the delta.

When the human says the behavior is right, point them at the finisher. For
`ui-app` and the realm BFFs that is `loom-finish`: it adopts the working tree as
the spec, reverts it so the specs can be born red, rebuilds it slice by slice,
then probes, tidies, gates, merges main and pushes. It runs in place, so nothing
here needs a new worktree, and it can run again on the same branch after the next
round of prototyping. A branch touching anything outside loom's scope has no
finisher skill: say so, and name what it still needs - `merge-main`, a review pass,
tests, that component's own checks, then a push.

Either way, leave the work uncommitted. The finisher reads the working tree as its
input, and committing first only means naming a ref for it to read instead.
