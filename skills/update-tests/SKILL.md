---
name: update-tests
description: Write and verify the unit test suite for work done on the current branch of the momentum monorepo, in any component (C#/xUnit or ui-app/Vitest). Scopes itself to the code the branch actually added or changed, then covers it comprehensively - every case, every branch, every edge - not just enough to clear the repo's 100% coverage gate. Every test it writes stands alone: state is constructed or reset per test, so no test depends on another having run first or on the order the suite runs in, and it verifies that by running each new test on its own and the suite in a shuffled order. Runs the real nx/dotnet/vitest commands and reports actual numbers. Proposes a UI end-to-end test only for an integration point the branch added that no existing spec crosses, one thin test per seam rather than one per page, and never writes one without human approval (or autonomous mode). Invoke when the user asks to "add tests", "update tests", "cover this", "write the specs", "test what I changed", or "get coverage back to 100" for any part of momentum.
---

# update-tests Skill

You write the **unit tests** for the work on the current momentum branch. The
implementation is settled; you are locking its behavior in.

Scope is the **whole monorepo**, not just `ui-app`: any component under `src/`,
any CDK app under `infrastructure/`. Two toolchains, and a branch can touch both:

| Kind | Where tests live | Framework |
|------|------------------|-----------|
| .NET component | `src/<component>/tests/<Assembly>.Tests/`, mirroring the source folder layout | xUnit, plain `Assert.*` |
| `ui-app` | co-located `*.spec.ts` next to the code | Vitest + Vue Test Utils |

End-to-end tests are a separate, gated question - see "UI end-to-end tests" below.

Run in a **fresh context**. Your inputs are the branch diff and the code, plus a
design handoff if the feature had one (`src/<component>/specs/design.md`, or
`src/ui-app/logs/feature-design.md` for a design-ui run). Read what exists; do
not depend on the implement conversation.

## Step 1 - scope to what this branch changed

```bash
git fetch origin
git diff --name-only origin/main...HEAD
git diff origin/main...HEAD          # the actual changes, read them
```

Also check `git status` for uncommitted work: on this repo an unstaged change is
Joey's review state and counts as part of the branch.

The repo is **jj-colocated**, so `git branch --show-current` and `git rev-parse
HEAD` can lie (detached HEAD, not tracking jj's working-copy commit). If the
three-dot diff looks empty or wrong, fall back to `git diff origin/main` and
`jj diff` before concluding nothing changed.

Group the changed production files by component (**the path segment right after
`src/`**, never the basename - a component's projects nest arbitrarily deep).
That grouping decides which toolchain, which test project, and which gate applies
to each file. Pre-existing untested code outside the diff is not your job unless
the user asks; say so rather than silently expanding scope.

## Step 2 - learn that component's conventions before writing anything

Read, in this order:

1. The repo-root `CLAUDE.md` (code style: no `var`, explicit types, `net10.0`,
   `Nullable enable`, no em dash / emoji / arrows / box-drawing).
2. `src/<component>/CLAUDE.md` - additive and authoritative for the component.
   Several state their own bar explicitly (`authz`: 100% line + branch;
   `repository`: 100% branch, verified before every commit;
   `preview-routing` / `queue-resilience`: 100% line + branch on code you touch).
3. The **existing sibling tests**. Match their naming, fixture style, fakes, and
   assertion style exactly. This beats any general convention you know.
4. The component's real gate configuration:
   - .NET: `src/<component>/coverage.runsettings` (which assembly coverage is
     scoped to) **and** the test project's `project.json` `coverage-threshold`
     target, which carries the exact enforced numbers. They differ per component:
     `authz` is `Threshold=100 ThresholdType=branch`; `sso-auth` is
     `ThresholdType=line,branch` with a generated-code exclusion. Read it, do not
     assume.
   - `ui-app`: `vitest.config.ts` (the only place `coverage` is read - `include`
     is `app/**/*.{ts,vue}`, with `plugins/`, `middleware/`, `nuxt-config/`,
     `mock-*.ts`, specs and stories excluded) and `package.json`'s `test:ci`,
     which enforces `statements=100 branches=100` on the `unit` project.

Reach internals via `InternalsVisibleTo`, which these components already use.
**Never widen a member's access to make it testable** - that is called out as a
rule in multiple component guides.

## Step 3 - build the case matrix, then write to it

The coverage gate is the floor, not the target. 100% branch coverage is
reachable with a handful of contrived tests that assert almost nothing; that is
not what this skill produces. Enumerate the cases first, from the changed code
and the spec/design if there is one, then write a test per case:

- **Every case, not every line.** One test per distinct behavior and per distinct
  reason a behavior can occur, even when an earlier test already executed those
  lines.
- **Both sides of every branch**, including the implicit ones: null-coalescing,
  optional chaining, default parameter values, `try`/`catch`/`finally` paths,
  short-circuit operands, pattern-match arms, and the fall-through nobody wrote
  a case for.
- **Boundaries**: zero, one, many; empty and single-element collections; first
  and last element; min/max and just-past-max; empty string vs whitespace vs
  null; duplicate and unordered input.
- **Failure paths**: what the code does when a dependency throws, times out, is
  cancelled (`CancellationToken`), returns nothing, or returns something
  malformed. Assert the observable outcome, including that the right exception
  type and message surface rather than being swallowed.
- **Globalization**, since the repo requires code that works for all languages,
  locales and regions: non-ASCII input, locale-dependent formatting and
  comparison, time zones and DST edges, and for `ui-app` the `en-XA`
  pseudo-locale plus missing-translation and fallback paths.
- **Regression cases**: a bug fix starts from a test that reproduces the bug and
  fails before the fix. If the branch is a fix, that test is mandatory.
- **Concurrency / idempotency** where the code is reentrant, cached, retried, or
  rotated (`db-auth`'s rotating data sources are the local precedent).

Test the **public contract and observable behavior**, not the implementation.
Rewriting the internals of a method should not break its tests.

### Every test stands alone

Each test must pass by itself, in any order, and on a second run in the same
process. A test never depends on an earlier test having run, and never leaves
state behind for a later one to find. Two tests that only pass as a pair are one
broken test.

- **Construct the state the test needs, inside the test** (or in a setup hook
  that rebuilds it per test). Never read state a previous test created, and never
  write a test whose arrange step is "the previous test already did this".
- **No shared mutable state.** No module-level `let` a test mutates, no static
  field on a test class, no collection appended to across tests, no singleton
  left configured. xUnit builds a new test class instance per test method, so
  instance fields are already per-test; statics and `IClassFixture` state are the
  trap. A fixture shared for cost reasons must be treated as read-only, and
  anything a test mutates gets built per test.
- **Reset the ambient state the code under test reaches for**: static and
  singleton caches, DI registrations, module registries, environment variables,
  `localStorage` / `sessionStorage` / cookies, fake timers and clocks, and the
  `fetch` / router / composable stubs a `ui-app` spec installs. Do it in
  `afterEach` (`vi.resetAllMocks()`, `vi.useRealTimers()`, unmount the wrapper)
  rather than relying on the next test to overwrite it.
- **No shared external handle**: a fixed temp file path, a fixed port, a fixed
  database row or id. Generate a unique name per test so two tests, or two
  parallel workers, cannot collide.
- **No dependence on ambient ordering or time.** Do not assert on `DateTime.Now`
  / `Date.now()`, on the enumeration order of a dictionary or set, or on a
  counter another test increments. Inject the clock and sort before comparing.
- **One scenario, one test.** If a flow needs sign in, then create, then check
  the list, that is a single test doing all three steps, not three tests chained
  through leftover state. Splitting it means the second test cannot be run or
  debugged on its own.
- If the code genuinely cannot be tested independently (a real process-wide
  singleton, an unavoidable static), say so and isolate it explicitly the way the
  component already does (its own xUnit collection, a per-test reset helper),
  rather than ordering the tests around it.

Do not chase coverage with a test that asserts nothing meaningful. If a branch is
genuinely unreachable, say so and justify it, or mark it the way the component
already marks such code (`[ExcludeFromCodeCoverage]` for a member that needs a
live Postgres, a `coverage.runsettings` or vitest `exclude` entry with a comment
explaining why) rather than papering over it.

### ui-app specifics

- Co-located `*.spec.ts`, Vitest + Vue Test Utils, matching existing specs.
- Locator priority in component tests: `getByRole` / `getByLabel` / `getByText`
  first, then `getByTestId` for the hooks the implementation added, then a CSS
  attribute selector as a last resort. Never XPath, never `:nth-child`. If
  nothing can locate an element, that is a **missing test hook in the component** -
  flag it, do not reach for a fragile selector.
- Assert on `data-testid`'d state indicators for async state, not on timing or
  localized text.
- Cover every state the design lists: loading, empty, error, disabled,
  validation.

## Step 4 - UI end-to-end tests (gated, and add only what earns its place)

The Playwright suite is a standalone package at `tests/e2e/ui-app-e2e/` (its own
`CLAUDE.md` owns the conventions: 3-tier page-objects / steps / specs,
`test-cases/*.md` as the statement of intent, `test-cases/MANIFEST.md` as the
catalog). It is **not** part of the unit pass.

What an end-to-end test buys you here is the **integration point**: the seam the
unit suite has to fake. A unit spec mounts a component with a stubbed fetch, a
stubbed router, and a fake clock. It proves the logic and it cannot prove the
wiring. The end-to-end test proves the wiring is real - the request goes out, the
route resolves, the browser does the thing. Once a seam is proven to work, the
behavior behind it is already covered by the comprehensive unit work above, so
one passing test per seam is enough.

So the unit of coverage is the integration point, **not the page**. Don't add a
test because the branch touched a page, and don't skip one because the page
already has a spec. Add one when the branch introduced a seam nothing exercises
yet. On most branches that is zero, and "no new integration points" is the whole
answer.

### What counts as an integration point

Something that leaves the app's own JavaScript and can only be proven by running
it for real:

- A call to a backend service the suite has never made: a new endpoint, a changed
  contract, a new error shape the UI has to react to.
- The auth or session boundary: sign-in, sign-out, token refresh, a route a
  permission gate can turn away.
- Routing that has to resolve for real: a new route, a deep link, a navigation
  guard or middleware, state carried in the URL, a reload that has to land back
  where it was.
- A browser capability a unit test can only fake: file upload or download,
  clipboard, storage that has to survive a reload, iframe or new-window handoff,
  drag and drop.
- A multi-step flow whose steps hand off to each other and that no single unit
  test owns end to end: a wizard, create-then-see-it-in-the-list,
  edit-then-navigate-away.
- The SSR / hydration boundary, when the branch adds server-rendered state the
  client has to pick up.

### What does not

Cover these in unit tests and move on:

- A control added to a page whose seam an existing spec already crosses.
- Presentational or layout work, theming, responsive behavior, copy, i18n.
- Validation rules, formatting, computed state, error messages the component
  produces itself.
- Loading, empty, error, and disabled states a unit test can drive by controlling
  the stub.
- A second path through a seam a passing spec already crosses. One crossing is
  the proof; the variations are unit work.

### The decision

1. List the integration points this branch added or changed, using the two lists
   above. Empty list, add nothing, say so.
2. For each one, look for an existing spec that crosses it: read
   `tests/e2e/ui-app-e2e/test-cases/MANIFEST.md` and grep `tests/` for the route,
   the endpoint, the flow. **Search by seam, not by page name** - the spec that
   already covers it may sit under a different area than the page you changed.
3. Propose one thin test per still-uncovered integration point. Usually that is
   zero or one. Propose more only when the branch really did add several distinct
   seams, and then say what makes each distinct.
4. Keep each one at the happy path, at the smoke level. Failure modes belong in
   unit tests against mocked failures, unless the failure *is* the integration (a
   permission gate turning a route away is the integration).
5. **Do not write it without approval.** Ask the human (`AskUserQuestion`) with
   the integration point, the proposed test-case title, and the evidence that
   nothing crosses it today. Only autonomous mode (below) may skip the ask.

If approved, follow that suite's own `CLAUDE.md`: write the `test-cases/*.md`
intent first, then the spec, keep the tiers strict, resolve URLs through
`src/helpers/TestConfig.ts`, and update `MANIFEST.md`.

## Step 5 - verify, and report the real output

Never claim a suite passes unchecked. Run what CI runs, from the repo root:

```bash
# what the shared PR gate runs for the affected projects
npx nx run-many -t test,coverage-threshold --projects=<affected projects>
```

Per component, while iterating:

```bash
# .NET: tests + scoped cobertura, as CI collects it
cd src/<component> && dotnet test tests/<Assembly>.Tests/<Assembly>.Tests.csproj -c Release \
  --settings coverage.runsettings --collect:"XPlat Code Coverage"

# .NET: the enforced gate itself (copy the exact flags from the test project's
# project.json coverage-threshold target - Include/Exclude/Threshold differ per component)
dotnet test --no-restore "/p:CollectCoverage=true" "/p:CoverletOutputFormat=cobertura" ...

# ui-app
cd src/ui-app && npm run test:coverage   # iterating: see uncovered lines/branches
cd src/ui-app && npm run test:ci         # the gate: 100% statements + branches
```

Then prove the new tests are independent, because a full in-order suite run does
not:

```bash
# ui-app: each new spec file on its own, then the suite in a randomized order
cd src/ui-app && npx vitest run --project=unit <path/to/new.spec.ts>
cd src/ui-app && npx vitest run --project=unit --sequence.shuffle

# .NET: each new test on its own, then its class on its own
cd src/<component> && dotnet test tests/<Assembly>.Tests/<Assembly>.Tests.csproj \
  --filter "FullyQualifiedName~<TestClass>.<TestMethod>"
```

Run the single-test check on every test you added, not a sample. A test that
passes in the full suite but fails alone is depending on state another test left
behind: fix the test, do not reorder the file. If a shuffled run fails, report it
and fix it before reporting coverage - order-dependent tests that pass today are
a broken gate tomorrow. A shuffled run prints its seed; re-run with
`--sequence.shuffle --sequence.seed=<seed>` to reproduce the same order while you
fix it.

Report exit codes and actual numbers, not a paraphrase of the log. `imaging`
needs its Rust toolchain (`cargo test --workspace` in `native/`) and
`src/repository`'s `*.IntegrationTests` need live Postgres/Redis - both are
excluded from the PR gates for that reason. If you cannot run something, name the
command and say why rather than reporting around it.

## Step 6 - summarize

Report:

- Test files added or edited, and which component each belongs to.
- The case matrix you covered, grouped by behavior, so a reviewer can see the
  edges were considered and not just the lines.
- Final coverage numbers per component, and whether the enforced threshold holds.
- The independence check: that every new test passed run on its own, and that the
  shuffled-order run passed. Name any test that needed a reset hook to get there.
- Any branch you deliberately left uncovered, with the justification.
- Any missing test hook you had to flag back to a component.
- The end-to-end decision, as the list of integration points the branch added and
  what happened to each: already crossed by `<spec>`, proposed and awaiting
  approval, or not an integration point. "No new integration points" is a
  complete answer.
- What a human should still verify by hand: visual, responsive, and third-party
  behavior that no unit test can assert.

## Autonomous mode (headless, under joey-bot)

When the invocation says you are running in autonomous mode (see
[`../shared/autonomous-pipeline.md`](../shared/autonomous-pipeline.md)), no human
is available. The "already manually approved" precondition has not happened yet -
human review comes later, at the final joey-bot gate. Proceed anyway:

- Write the suite against the diff, the code, and the design handoff as usual,
  and hold the component's real coverage gate.
- **The end-to-end approval gate becomes a decision you make.** The same rule
  applies: one thin happy-path test per integration point the branch added that
  no existing spec crosses, and nothing at all when it added none. Since nobody
  will click through the feature by hand, resolve a borderline seam toward
  writing the test - a new backend call or a new multi-step flow gets its one
  test rather than a note to check it manually. That leniency is about how
  readily you call something an integration point, not a licence to add a test
  for a seam already covered or for behavior the unit suite owns. You own the
  unit/coverage and E2E rungs of the autonomous testing ladder; live browser
  verification is a separate joey-bot stage, so do not drive a browser here.
- Behavior has not been human-confirmed, so be conservative: test what the spec
  specifies and the code implements, and do not invent requirements. Note in the
  summary that the suite locks in behavior still pending manual verification.
- **End your summary with an explicit `## Handbacks` list.** Three things you
  legitimately find are code changes outside your scope: an element you cannot
  locate without a missing `data-testid`, a dead branch that should be removed
  rather than covered, and code that contradicts the design you are testing
  against. Interactively you flag these to the human; headless there is no human,
  so list them here - one line per item naming the file and what needs to change,
  or `none`. joey-bot runs one implement pass over the list and re-runs you once.
  Never resolve one yourself with a fragile selector or a contrived test, and
  never leave one only in prose where the orchestrator can miss it.

Do not commit here - commit policy for the run belongs to joey-bot.

## Conventions

- C# test code follows the repo-root style: `net10.0`, `Nullable enable`, no
  `var` (explicit types), 4-space indent, `Laserfiche.*` namespaces, xUnit with
  plain `Assert.*`.
- TypeScript for all `ui-app` and Playwright test code; `<script setup lang="ts">`
  patterns as in existing specs. The repo's C# style rules do not apply there.
- Test names state the behavior and the condition, matching the sibling files'
  existing pattern.
- No em dash, emojis, arrows, or box-drawing characters in code or text.
