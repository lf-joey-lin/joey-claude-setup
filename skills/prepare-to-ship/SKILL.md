---
name: prepare-to-ship
description: Local pre-push gate for a momentum branch, run once the code is done and reviewed. Works out which components the branch actually changed (ui-app, the BFFs, any C# service, tools, the e2e suite) and runs only their checks - lint, unit tests, the 100% coverage thresholds, build, and ui-app's storybook a11y suite - reporting a pass/fail scorecard grounded in real exit codes, not log text. Deliberately excludes anything needing Docker (container builds, migration apply) and anything that is a PR-level check (pr-metadata, translation parity, contract breaking-change). Missing tests, failing tests, a coverage shortfall or a lint failure it fixes in place and re-runs until green; anything else (a real code defect, an a11y violation) it stops on with a NOT READY verdict and the actual output. Invoke when the user asks to "prepare to ship", "ship check", "final gate", "pre-push checks", "run the local checks", "will CI pass", "get this ready to push", or names prepare-to-ship.
---

# prepare-to-ship Skill

The last local gate before a momentum branch is pushed. Its job: run the checks a
developer can actually decide locally, for the components this branch touched, so
the cheap CI failures are caught in one pass before the push.

**Not ui-app only.** Scope is the whole monorepo: `src/*` components including
`acs-bff`, `app-bff` and `bff-platform`, `tools/*`, and `tests/e2e/*`.

## What is in scope, and what is not

In scope: **lint, unit tests, the coverage thresholds, build, and ui-app's
storybook a11y suite** - and only for the components the diff touched.

Deliberately out of scope, so do not run these and do not report a row for them:

| Excluded | Why |
|---|---|
| `container` / `local-container` targets | Needs Docker plus a `dockerreg.laserfiche.com` login. CI owns it. |
| Migration append-only / lint / apply scripts (`pr-databases`) | Needs Docker. |
| `pr-imaging` | Rust plus vendored C/C++ toolchain, its own workflow. Exclude `src/imaging/**` from scope entirely. |
| `pr-repository-mover` chart checks | A deploy-chart check, not a code check. |
| `buf breaking` against `origin/main` | A PR-level contract check. `buf lint` is fine locally; the breaking comparison belongs to CI. |
| `pr-i18n-parity` | Cannot run locally (needs `MTRANS_*` and the authed mtrans image), and only the `to-be-translated` label resolves it. See Step 5. |
| `pr-metadata` | It checks the PR body and its linked work items, which do not exist yet. |
| `src/repository/*.IntegrationTests` | Needs live Postgres and Redis. |

If the user explicitly asks for one of these, run it and say it is outside the
skill's normal scope. Otherwise leave it to CI.

## What you fix, and what you do not

This skill **edits files**, but only in one lane.

| Failure | Action |
|---|---|
| A test fails, a test is missing, coverage is under the threshold | **Fix it here.** Write or repair the tests, re-run, keep going until the check holds. |
| Lint or formatting | **Fix it here** (`npm run lint:fix`, `dotnet format`), then re-run the linter to confirm. |
| Build or compile error, a real behavior defect the test exposes | **Stop.** NOT READY, with the error. Owner: `implement-ui` or the human. |
| Accessibility violation | **Stop.** NOT READY, naming the story and the rule. Owner: `implement-ui`. |

Rules that hold in every case:

- **Never move a goalpost to get green.** Do not lower a threshold, do not add a
  coverage exclude to dodge an uncovered branch, do not delete or skip a failing
  test, do not widen a member's access to make it testable. An
  `[ExcludeFromCodeCoverage]` or a vitest `exclude` entry is allowed only for
  genuinely unreachable code, with a comment saying why.
- **A failing test is evidence until proven otherwise.** If a test fails because
  the production code is wrong, that is a NOT READY, not a test to rewrite.
- **Do not commit and do not push.** Verdict is "ready to push"; the human pushes.

When writing tests, follow the `update-tests` skill's discipline rather than
inventing your own: build the case matrix first, cover both sides of every
branch, and make every test stand alone (see
[`../update-tests/SKILL.md`](../update-tests/SKILL.md), "Every test stands
alone"). If the gap is large enough to be real test work rather than a patch,
invoke `update-tests` for that component instead of hand-rolling it here.

## Run in a fresh subagent when the context is dirty

These runs produce CI-length output and this skill is often run more than once in
a session.

- **Context already dirty** (prior tool output, another skill's work, a repeat
  ship check): dispatch the whole run to a fresh `general-purpose` subagent and
  relay only its scorecard and verdict. Do not dump its transcript.
- **You ARE that subagent, or the context is clean**: run inline, do not dispatch
  again.

The subagent needs no seeding beyond the branch. Tell it to follow this skill end
to end and return the scorecard, the verdict, the list of files it changed, and
the real failing output for anything that failed.

## Step 0 - bootstrap

Everything runs from the **repo root**, not from a component directory.

```bash
cd "$(git rev-parse --show-toplevel)"
[ -d node_modules ] || npm ci          # nx itself; without this every nx call fails
```

A worktree freshly created by `new-work` has no root `node_modules`. Component
installs happen through nx's own `restore` targets, so do not pre-install them by
hand except for the standalone packages below (`tools/i18n`,
`tests/e2e/ui-app-e2e`), which are outside the nx graph.

## Step 1 - resolve scope

The branch's changed files decide which checks run. Nothing runs unconditionally.
**Uncommitted work counts** - on this repo an unstaged change is review state,
not scratch.

```bash
git fetch origin
git diff --name-only origin/main...HEAD          # committed
git status --porcelain                            # uncommitted and untracked
```

The repo is jj-colocated, so `git rev-parse HEAD` and `git branch
--show-current` can lie. If the three-dot diff comes back empty or obviously
wrong, fall back to `git diff --name-only origin/main` before concluding nothing
changed.

Two things come out of that file list:

1. **The changed components**, for the path-triggered checks in Step 2. A
   component is the path segment right after `src/` (`cut -d/ -f2`), never the
   basename: a component's projects nest arbitrarily deep.
2. **The affected nx projects**, for the shared lint/test/coverage/build run. Feed
   nx the same file list so uncommitted work is included:

```bash
FILES=$(git diff --name-only origin/main...HEAD; git status --porcelain | cut -c4-)
FILES_CSV=$(printf '%s\n' $FILES | sort -u | paste -sd,)
npx nx show projects --affected --files="$FILES_CSV" --json
```

Then drop, by each project's `root` (`npx nx show project <name> --json | jq -r
.root`) rather than by its name:

- anything under `src/imaging/` - different toolchain.
- `src/repository/*.IntegrationTests` - needs live Postgres and Redis.

State the resolved component list and project list before running anything. If
the branch changed nothing, say so and stop unless the user asked for a run
anyway.

## Step 2 - the check matrix

**The workflow files are the source of truth for each command, not this table.**
Read the ones covering the affected components before running them, so a drifted
command here cannot produce a false green. The table only decides *which* subset
runs locally.

| Check | Runs when | Command |
|---|---|---|
| lint, unit tests, coverage thresholds | any affected project | `npx nx run-many -t lint,test,coverage-threshold --projects=<csv>` |
| build | any affected project with no test target, or when the test run never compiled it | `npx nx run-many -t build --projects=<csv>` |
| storybook build + a11y | `src/ui-app/**` changed | `cd src/ui-app && npm run build-storybook && npm run test:a11y` |
| node-version parity | `src/ui-app/**` or `.nvmrc` changed | `.nvmrc` major equals `ARG NODE_VERSION` in `src/ui-app/Dockerfile`, and no `FROM ...node:<digit>` hardcoded. A file read, not a build. |
| dependency confinement (bvt) | the diff touched any `.csproj`, `Directory.Packages.props` or `Directory.Build.props` | `dotnet test tests/bvt/DependencyBoundary.Tests/DependencyBoundary.Tests.csproj -c Release` |
| i18n tools tests | `tools/i18n/**` changed | `cd tools/i18n && npm ci && npm test` |
| e2e test-id check | `tests/e2e/ui-app-e2e/**` changed | `cd tests/e2e/ui-app-e2e && npm ci && npm run check-test-ids` |
| contract lint | `src/sso-auth/contract/**` changed | `buf lint` only, via the workflow's pinned `npx --yes @bufbuild/buf@<version>` invocation. Not `buf breaking`. |
| repository build + unit tests | `src/repository/**` changed | `dotnet build momentum.slnx -c Release -p:SkipNativeBuild=true`, then that workflow's unit test projects with `--settings Laserfiche.repository/coverage.runsettings`. Integration tests excluded. |

Notes that matter:

- **The 100% gate lives in two different places.** For `ui-app` the `test` target
  already is the gate (`npm run test:ci` bakes in
  `--coverage.thresholds.statements=100 --coverage.thresholds.branches=100`). For
  every .NET component it is the separate `coverage-threshold` target in the test
  project's own `project.json`, and its flags differ per component (`app-bff` and
  `acs-bff` are `Threshold=100 ThresholdType=line,branch` scoped by `Include`).
  Running `test` alone does not enforce anything on a .NET project, so
  `coverage-threshold` is never optional.
- CI runs the bvt suite on **every** PR, not only when project files changed. The
  narrower local trigger is deliberate: those files are what can actually break
  confinement. Say which way it went, run or skipped.
- The a11y suite drives real Chromium. On a first run, a missing-browser error is
  not an a11y failure: run `npx playwright install --with-deps chromium` once,
  re-run that check, and say that is what you did.
- These are CI-length runs. Let them finish; do not kill one and report a false
  failure.

## Step 3 - run

Run every applicable check, even after one fails, so the user gets one complete
scorecard instead of a queue of single fixes. The **exit code is authoritative**;
never infer pass or fail from log text. Capture each command's exit code and its
output.

## Step 4 - fix, then re-run

For each failure, classify it against the table in "What you fix, and what you do
not" and act.

- Fix one check at a time; re-run **only that check** while iterating, so the loop
  stays fast.
- Bound it: at most **three** fix rounds per check. If it still fails after three,
  stop and report it as NOT READY with the real output, rather than grinding.
- After the last fix, **re-run every applicable check from clean**. A green
  scorecard has to come from one final full pass, not from stitching together the
  individual re-runs. New tests can break a sibling suite or a lint rule.
- Where a fix crossed into another component (a shared test helper, a fixture),
  say so - its checks are in scope now too.

## Step 5 - report

One compact scorecard, one line per check that actually ran, then a verdict. Do
not pad it with rows for components the branch never touched, or for the excluded
CI-only checks.

```
Component      Check                          Result
app-bff        lint / test / 100% coverage     PASS
ui-app         lint / test / 100% coverage     PASS
ui-app         storybook build + a11y          PASS
ui-app         node-version parity             PASS
repo-wide      dependency confinement (bvt)    SKIPPED (no project files changed)
```

- **Everything applicable PASS** -> verdict: **READY TO PUSH**, stated plainly.
  Add one sentence naming what CI still owns (the container build and the
  PR-level checks), so the verdict is not read as "CI will be green".
- **Any FAIL** -> verdict: **NOT READY**, with, per failed check:
  - **Build**: the file and the compiler message.
  - **Tests**: which test, and the assertion. Say whether it is a test defect or
    a production defect.
  - **Coverage**: the files, lines and branches still uncovered, and the
    threshold missed. Do not paraphrase the vitest or coverlet output.
  - **Accessibility**: the axe rule and the story it fired on.

Then also report:

- **Files you changed**, grouped by component, and what each change was (test
  added, lint autofix). If you changed nothing, say so.
- **Coverage numbers** per component you touched.
- **The `to-be-translated` label**, whenever the branch changed any `en.json`.
  One line: the label is still needed, `pr-i18n-parity` fails until it goes on.
  That is the human's step, not a check result, so it never affects the verdict.

## Autonomous mode (headless, under joey-bot)

See [`../shared/autonomous-pipeline.md`](../shared/autonomous-pipeline.md).

- You are already the dispatched subagent; run the checks inline, do not dispatch
  again.
- The fix lane is unchanged: tests, coverage and lint are yours to fix, and the
  three-round bound still applies. Everything else is still a stop.
- Return the scorecard, the verdict, the files you changed, and the real failing
  output for anything that failed. Do not commit; commit policy for the run
  belongs to joey-bot.

## Conventions

- Run every applicable check and report its real exit code. Do not short-circuit
  after the first failure.
- Never report a check you did not actually run, and never report a skipped or
  unavailable one as a pass.
- No em dash, emojis, arrows, or box-drawing characters in the report or in
  anything written.
