---
name: loom-gate
description: Gate stage of the loom pipeline - run the ui-app CI checks locally (lint, typecheck, unit suite with the 100% coverage thresholds, build, storybook a11y) plus the BFF build and coverage-threshold targets when a slice touched acs-bff or app-bff, fix only lint and coverage shortfalls, and return a scorecard on real exit codes. Invoke via /loom normally; directly for a quick "will CI pass" check on those components.
---

# loom-gate: the local CI mirror

You run what CI will run for `ui-app`, so the cheap failures die here instead
of on the PR. Exit codes are authoritative; log text is not. Read
[`../shared/loom-contract.md`](../shared/loom-contract.md) for the commands -
they are listed there once and not retyped here.

Scope check first: `git diff --name-only origin/main...HEAD` plus
`git status --porcelain` (uncommitted work counts). Files outside `src/ui-app`
and the realm BFFs (`src/acs-bff`, `src/app-bff`) mean this gate covers only
part of the branch - say so and name the components whose own checks still
have to be run; do not silently certify half a branch as whole.

Then the story check. Every `.vue` file the branch added under
`app/components`, `app/layouts` or `app/pages` must be rendered by some
`*.stories.ts` - grep the component name across the story files. The a11y
suite mounts stories and nothing else, so a component with no story is never
scanned and a green a11y pass does not cover it. A miss is NOT READY naming
the component, owner loom-slice; never a caveat on a READY verdict.

## The checks, in cheap-first order

All run even after one fails, so the scorecard is complete in one pass.

For `src/ui-app` changes, from `src/ui-app`:

1. lint
2. typecheck
3. the coverage gate (`npm run test:ci` - the unit suite with the enforced
   100% statement and branch thresholds)
4. build
5. storybook build plus the a11y suite, when any component or page changed.
   On a first run in a fresh worktree, a missing-browser error is not an a11y
   failure: `npx playwright install --with-deps chromium` once, re-run, and
   say that is what happened.

For a changed BFF, from the repo root (the contract's BFF command table):

6. `dotnet build src/<bff>/<bff>.slnx -c Release`
7. `npx nx run-many -t test,coverage-threshold --projects=<bff test
   projects>` - the `coverage-threshold` target is the enforced .NET gate
   (100% line + branch on the BFFs); running `test` alone enforces nothing.

## The fix lane, and its edges

You fix exactly two kinds of failure, at most three rounds each, then re-run
the full set from clean (a green scorecard comes from one final pass, never
stitched from partial re-runs):

- **Lint**: `npx eslint --fix`, then re-lint.
- **Coverage shortfall**: the slices' born-red specs cover what they built, so
  a gap here is usually incidental code the slices touched but no check
  exercises. Write the missing test properly: name the channel, and because
  this test is after-the-fact it does not carry born-red evidence - prove it
  with one targeted mutation (break the covered line, see red, restore,
  confirm `git status` clean). Never a contrived assert to move a number.
  Same rule on the .NET side, in the BFF's existing harness; reach internals
  through `InternalsVisibleTo`, never by widening access.

Everything else stops the gate:

- **A failing test is evidence until proven otherwise.** A red slice check
  means the branch broke locked-in behavior - NOT READY, with the output,
  owner loom-slice. Never rewrite a check to get green.
- **Build or typecheck error**: NOT READY with the compiler output.
- **An a11y violation**: NOT READY naming the story and the rule.
- **Never move a goalpost**: no lowered threshold, no coverage exclude to
  dodge a branch, no skipped test, no widened access. An exclusion is for
  genuinely unreachable code only, with a comment saying why.

## Return

The scorecard into the ledger's Gate section - one line per check with its
real result, SKIPPED rows only for checks that did not apply - and the
verdict: READY (with one line naming what CI still owns: container builds,
`pr-metadata`, translation parity) or NOT READY with the failing output and
the owner. Commit any tests you wrote (`[ui-app] Cover <what>`); nothing else,
and never push.
