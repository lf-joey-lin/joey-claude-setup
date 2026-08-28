---
name: update-tests
description: Write and verify the unit test suite for work done on the current branch of the momentum monorepo, in any component (C#/xUnit or ui-app/Vitest). Scopes itself to the code the branch actually added or changed, then covers it comprehensively - every case, every branch, every edge - not just enough to clear the repo's 100% coverage gate. Every test it writes stands alone: state is constructed or reset per test, so no test depends on another having run first or on the order the suite runs in, and it verifies that by running each new test file on its own and the suite in a shuffled order. Runs the real nx/dotnet/vitest commands and reports actual numbers. Unit tests only, no end-to-end. Every test it writes has to be able to fail: it names the channel a behavior is actually observable on, refuses an assertion that would hold whatever the code did, and proves each new test is real by breaking the line it guards and watching it go red. Invoke when the user asks to "add tests", "update tests", "cover this", "write the specs", "test what I changed", or "get coverage back to 100" for any part of momentum.
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

End-to-end tests are **out of scope**. The Playwright suite at
`tests/e2e/ui-app-e2e/` is a separate package with its own `CLAUDE.md`, and this
skill neither writes nor proposes a spec there. If the branch added a seam only a
real browser can prove, name it in the summary under what a human should verify
and move on.

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
   - `ui-app`: `vitest.config.ts` - the only place `coverage` is read, and the
     only current account of what `include` and `exclude` cover. Read it rather
     than assuming; every exclusion there carries a comment saying why it is
     out. `package.json`'s `test:ci` is the gate it feeds: `statements=100
     branches=100` on the `unit` project.

Reach internals via `InternalsVisibleTo`, which these components already use.
**Never widen a member's access to make it testable** - that is called out as a
rule in multiple component guides.

## Step 3 - name the channels, build the case matrix, then write to it

### Name the channel before you write the assert

For each behavior the branch added, write down the **channel** it is observable
on: the one thing a caller could look at to tell whether the behavior happened. A
returned value, a thrown exception, an emitted event, a router push, a request
that went out, a DOM attribute, a method called on another object, a rule in a
stylesheet. Then assert on *that* channel.

What this prevents: a spec file settles on the channel that is easiest to read
(`wrapper.emitted('...')`, a return value) and every behavior that does not use
that channel gets an assertion which reads fine and can never fail. A
double-click whose whole effect is pressing a link emits nothing, so
`expect(emitted()).toEqual([])` after one holds whether or not the double-click
is wired at all. Its channel is the link's `click`, and the test has to watch
that.

Channels that are easy to miss:

- A gesture whose whole effect is calling something else: `element.click()`,
  `focus()`, `preventDefault()`, `scrollIntoView()`, a callback prop.
- A binding in a `.vue` template. Its channel is that the handler runs at all
  when the event reaches the component from outside it.
- Something CSS decides: which of two competing rules wins, a `:not()` guard,
  specificity. The unit project runs the `nuxt` environment (happy-dom), which
  computes none of it, so the channel is the stylesheet. Read the rule out of the
  CSS file and assert on it.
- Suppression, where the code's job is that something did *not* happen. Then the
  channel has to be one you have separately shown can report that it did.

### The case matrix

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
- **Boundaries**: the usual set - zero/one/many, first and last, min/max and one
  past it, empty vs whitespace vs null, duplicate and unordered input.
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

### A test that cannot fail is not a test

Three shapes pass forever no matter what the code does. Each has a rule:

- **A negative assertion with no positive sibling.** `expect(x).toBe(false)`,
  `toEqual([])`, `not.toHaveBeenCalled()`. Every one of these needs a sibling
  test, on the same channel, where the thing does happen and the assertion
  flips. Without that sibling you have not shown the channel can report anything
  at all. A whole `describe` block that only asserts absence is the tell.
- **A test that never reaches production code.** Building a stand-in object with
  hardcoded returns and then asserting those returns checks the fake against
  itself. Where a stand-in is the point (a caller's own policy, a custom
  implementation of an interface), hand it to the real code that consumes it and
  assert what the real code does with it.
- **A claim about types written as a runtime assert.** "This interface is
  sufficient on its own", "these fields are optional", "the generic resolves".
  The compiler already decides those and `expect` over a literal cannot. Leave
  it to the type system, or prove it at a real call site.

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
- **Cover combinations of independent state, not only each state on its own.**
  Two flags that can both be on are four cases, not two. Where the branch adds a
  state a row, cell or control can wear at the same time as an existing one, test
  the overlap and assert which one wins.
- **A changed `.vue` file gets its own binding tests, separate from the
  composable it calls.** A composable's spec mounts its own harness host, so
  every line of the composable can read 100% covered while the real component
  never binds it. For each event, prop or callback the component wires to a
  composable, drive it from the component's own spec through the DOM the way a
  user reaches it, and check the effect. The test that matters is the one that
  goes red when the binding is deleted from the template.

## Step 4 - verify, and report the real output

Never claim a suite passes unchecked. Run what CI runs, from the repo root:

```bash
# what the shared PR gate runs for the affected projects
npx nx run-many -t test,coverage-threshold --projects=<affected projects>
```

Only the .NET test projects define `coverage-threshold`. `ui-app`'s gate rides on
its own `test` target, which runs `test:ci`. nx skips a target a project does not
define, so that one command is still right for a branch touching both.

Per component, while iterating:

```bash
# .NET: tests + scoped cobertura, as CI collects it
cd src/<component> && dotnet test tests/<Assembly>.Tests/<Assembly>.Tests.csproj -c Release \
  --settings coverage.runsettings --collect:"XPlat Code Coverage"

# .NET: the enforced gate. Run the nx target, do not retype its flags -
# Include/Exclude/Threshold differ per component, and a mis-copied flag reports a
# gate that is not the one CI runs.
npx nx run <Assembly>.Tests:coverage-threshold

# ui-app
cd src/ui-app && npm run test:coverage   # iterating: see uncovered lines/branches
cd src/ui-app && npm run test:ci         # the gate: 100% statements + branches
```

Then prove the new tests are independent, because a full in-order suite run does
not:

```bash
# ui-app: every spec file you touched, on its own, then the suite shuffled
cd src/ui-app && npx vitest run --project=unit <path/to/new.spec.ts>
cd src/ui-app && npx vitest run --project=unit --sequence.shuffle

# .NET: each test class you touched, on its own
cd src/<component> && dotnet test tests/<Assembly>.Tests/<Assembly>.Tests.csproj \
  --filter "FullyQualifiedName~<TestClass>"
```

The unit here is the **spec file** for `ui-app` and the **test class** for .NET,
not the individual test. The file is the process boundary: the shuffled full run
catches what leaks across files, the isolated file run catches what leaks within
one, and between them nothing is left for a per-test run to find. Do it for every
file you touched, not a sample.

A file that passes in the full suite but fails alone is depending on state
another file left behind: fix the test, do not reorder it. If a shuffled run
fails, report it and fix it before reporting coverage - order-dependent tests
that pass today are a broken gate tomorrow. A shuffled run prints its seed
(`Running tests with seed "..."`); re-run with `--sequence.shuffle
--sequence.seed=<seed>` to reproduce that order while you fix it.

### Then break the code

The two checks above prove the tests are *stable*. Neither proves a test can
*fail*, and a test that cannot fail passes a green suite off as coverage. So
every test you added has to be seen going red against a broken version of the
code it covers.

**Batch by mutated line, not by test.** One broken line should take several tests
down with it, and booting the test environment costs far more than running the
tests does, so mutate once and run the whole spec file. That is one run per
changed line instead of two per test. Work from the list of production lines the
branch added or changed:

1. Break one. Flip the boolean, delete the binding, drop the guard clause, return
   early, remove the `preventDefault`.
2. Run every spec that should notice, in a single run. Record which tests went
   red.
3. Restore the line and re-run those specs green.

```bash
# ui-app: one mutation, every spec that should notice it
cd src/ui-app && npx vitest run --project=unit <spec> [<spec>...]
```

The bar at the end: **every test you added must have gone red under at least one
mutation.** Any test green through the whole pass is the finding - wrong channel,
or asserting nothing. Confirm with a targeted mutation of the exact line it
claims to cover, then fix it by finding the channel the behavior is really
observable on (Step 3), not by adding a second assertion beside the one that did
not fail.

For a `.vue` binding the mutation is deleting the binding itself -
`@dblclick="onDblclick"` removed, suite still green, means nothing was testing
it.

**Never leave a mutation behind.** The branch diff is this skill's entire output,
so a stray edit to production code is the worst thing it can ship. Record the
baseline before the first mutation:

```bash
git status --porcelain && git diff --stat        # this is what you restore to
```

Copy each file before breaking it and restore from that copy, never from an
inverse edit made from memory. At the end of the pass re-run both commands and
confirm nothing outside the test files moved. If anything differs, restore it
before reporting a single number.

Report exit codes and actual numbers, not a paraphrase of the log. `imaging`
needs its Rust toolchain (`cargo test --workspace` in `native/`) and
`src/repository`'s `*.IntegrationTests` need live Postgres/Redis - both are
excluded from the PR gates for that reason. If you cannot run something, name the
command and say why rather than reporting around it.

## Step 5 - summarize

Report:

- Test files added or edited, and which component each belongs to.
- The case matrix you covered, grouped by behavior and naming the channel each
  behavior is asserted on, so a reviewer can see the edges were considered and
  not just the lines.
- Final coverage numbers per component, and whether the enforced threshold holds.
- The independence check: that every spec file and test class you touched passed
  run on its own, and that the shuffled run passed. Name any test that needed a
  reset hook to get there.
- The mutation check: which lines you broke, and that every test you added went
  red under at least one of them. Name any test whose channel had to change to
  get there, any binding that turned out to have nothing testing it, and confirm
  the tree is back to its pre-mutation state.
- Any branch you deliberately left uncovered, with the justification.
- Any missing test hook you had to flag back to a component.
- What a human should still verify by hand: visual, responsive, and third-party
  behavior that no unit test can assert.

## Autonomous mode (headless, under joey-bot)

When the invocation says you are running in autonomous mode (see
[`../shared/autonomous-pipeline.md`](../shared/autonomous-pipeline.md)), no human
is available. The "already manually approved" precondition has not happened yet -
human review comes later, at the final joey-bot gate. Proceed anyway:

- Write the suite against the diff, the code, and the design handoff as usual,
  and hold the component's real coverage gate.
- **There is no approval gate to stand in for.** This skill asks the human
  nothing, so nothing here is suppressed. You own the unit and coverage rung of
  the autonomous testing ladder and no other: end-to-end is out of scope for this
  skill entirely, and live browser verification is its own joey-bot stage, so do
  not drive a browser here.
- **The mutation check is not optional headless.** Interactively a reviewer
  eventually spots a test that cannot fail; unattended, nobody does, and a green
  100% number is the only thing the report carries. Run the full pass, and say in
  the summary both that every test went red under some mutation and that the tree
  was restored.
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

Test code follows the same style rules as production code, which step 2 already
sent you to read: the repo-root `CLAUDE.md` for C#, the existing sibling specs
for `ui-app` (TypeScript throughout, and the C# rules do not apply there). What
those files do not cover:

- xUnit with plain `Assert.*`. The repo has no fluent assertion library and does
  not want one.
- `Laserfiche.*` namespaces, mirroring the source folder layout.
- Test names state the behavior and the condition, matching the sibling files'
  existing pattern.
