---
name: harden
description: Cover the current branch's new ui-app work with unit tests, then attack those tests with StrykerJS mutation testing and close the survivors that matter. Reads the branch diff to work out what the feature is meant to do, writes vitest specs against that intent, takes ui-app's 100% statement and branch gate as the floor rather than the goal, then breaks the changed files one operator at a time and adds the cases no test noticed. Scoped to src/ui-app only for now; a C# component is reported as uncovered rather than half-tested. Writes tests only, never production code, and never moves a threshold or adds a coverage exclude to reach one. Invoke when the user types /harden, or asks to "add tests for this branch", "cover this feature", "test what I just built", "get this to 100%", "run mutation testing on this", "stryker this", or hands over a finished ui-app change and wants a suite that would actually fail if the code were wrong.
---

# harden: tests that would fail if the code were wrong

`npm run test:ci` already pins statements and branches at 100%, so coverage cannot
tell you whether the suite is any good: a covered line only proves a test ran it,
not that anything would fail if it were wrong. This skill treats that gate as the
floor, then uses mutation testing to find the lines nothing is really guarding.

Arguments, all optional: a scope (a path or a directory under `app/`, narrowing the
branch's own diff), `--no-mutants` to stop after the coverage phase, and `--commit`
to commit the tests at the end. The default is the whole ui-app diff, mutants
included, nothing committed.

**Scope is `src/ui-app` only.** The .NET components have no mutation setup yet
(nothing in the repo references Stryker.NET), so this skill does not pretend to
cover them - see "Out of scope" at the end.

**You write tests. You do not write production code.** Not a fix, not a rename, not
a tidy, not an export widened to make something reachable. If the work needs a
production change to be testable, or a survivor turns out to be a real bug, stop
and report it (see "When a survivor is a bug").

## 1. Scope: what did this branch actually do

```bash
git fetch origin
git diff --name-only origin/main...HEAD   # committed work
git status --porcelain                    # uncommitted work counts too
```

Both lists matter, and neither is a plan. Split them: files under `src/ui-app`,
and everything else.

Three hard stops before anything else:

- **`~/m-code/momentum` is the read-only reference worktree.** If the session is
  standing in it, say so and stop. Tests are edits, and they do not go there.
- **Changed files outside `src/ui-app`** mean this run covers part of a branch.
  Name those components, say their own tests are not covered here, and carry on
  with ui-app. Never let a green ui-app scorecard read as a whole-branch verdict.
- **An empty ui-app diff is not a pass.** Nothing changed under `src/ui-app`, or
  nothing but generated catalogs (`fr.json`, `es.json`, `en-XA.json`) and docs, is
  a one-line report saying so.

## 2. Name the feature before testing it

ui-app has no `specs/` directory, so intent comes from what the branch itself
carries. In order: `artifacts/loom/<slug>/` if a loom run left a ledger or report
there (gitignored, and it states what each slice was meant to do), the linked TFS
work item's acceptance criteria if there is one, `src/ui-app/CLAUDE.md` and the
component's neighbours for the established pattern, and only then the diff.

**The diff is one implementation of the intent, not the intent.** A spec written
from the diff alone locks in whatever the code currently does, bugs included, which
is the most common way a 100% covered app still ships broken.

Write a short intent list into the scratchpad, not into the repo. Per new or
changed behavior:

- the inputs it accepts, and the ones it must reject or fall back on;
- what the user actually sees or gets: the rendered state, the emitted event, the
  request that goes out, the value returned;
- every boundary in the code - each comparison, each length or count limit, each
  default, each early return, each `??` and `?.`;
- what a unit test cannot reach here, and where that goes instead.

That last point is routing, not an excuse:

- **the Storybook a11y suite** (`npm run test:a11y`) for anything about roles,
  labels, contrast and focus order. It mounts stories and nothing else, so a new
  `.vue` under `app/components`, `app/layouts` or `app/pages` with no
  `*.stories.ts` is never scanned at all - flag a missing story rather than
  writing a unit test that pretends to cover it;
- **a named manual check** for what no local suite asserts: real navigation, real
  auth, scroll and focus behavior in a real browser, layout at a breakpoint. Say
  what to click and what to look for.

## 3. Write the specs

Match what the app already does. Read the two nearest existing specs first.

- Co-located `*.spec.ts`, beside the unit under test.
- Components mount with `mountSuspended` from `@nuxt/test-utils/runtime` (the unit
  project runs in the `nuxt` environment); `@vue/test-utils` helpers are used
  alongside it for wrappers and stubs. Both are established here - follow the
  neighbour, do not introduce a third way.
- Assert what a user or a caller can observe: rendered text, a prop the child
  really receives, the emitted event, the fetch that was issued. Not internal
  refs, not a snapshot of the whole component, and not an implementation detail
  that a refactor would break while the behavior stayed correct.
- The nuxt environment is slow to boot; the unit project already sets a 30s test
  timeout and a 60s hook timeout, so do not add per-test timeouts to paper over it.

The edge cases worth going after, roughly in the order they find bugs: each
boundary at value, value minus one and value plus one; empty, null, undefined,
whitespace and single-item inputs; a list of hundreds; a 400-character unbroken
label; missing optional fields, and null where the type says maybe; duplicates and
collisions; ordering and stability; **locale, timezone and DST** (the app is
globalization-first, and a spec that only passes under `en-US` is a latent bug);
non-ASCII and long-locale text; the error state from every data source, the
double-submit, and the action fired while loading.

Then run the real gate, from `src/ui-app`:

```bash
npm run test:ci   # the unit project with statements and branches forced to 100
```

`npm run test` and `npm run test:coverage` enforce nothing; `test:ci` is the gate.

**Never move a goalpost.** No lowered threshold, no new entry in `vitest.config.ts`'s
coverage `exclude`, no `/* v8 ignore */`, no skipped or `.todo` spec, no assertion
written to move a number rather than to state a behavior. The existing exclusions
(`app/plugins/**`, `app/mocks/**`, `app/middleware/**`, `app/nuxt-config/**`,
specs and stories) are documented decisions with reasons in that file - work within
them and do not extend the list. If 100% is unreachable without one of those, that
is a finding about the code, and it goes in the report.

## 4. Attack the specs with Stryker

Coverage is 100% now, which says nothing about test strength. Stryker breaks the
changed code one operator or literal at a time - `>=` becomes `>`, an `if` body is
emptied, a string becomes `''` - and reports which breaks no test noticed. Those
**survivors are the output. The score is not**, and this is deliberately not a
gate: nothing runs it in CI, `thresholds.break` is null, and no nx target depends
on it. Do not add one.

`src/ui-app/stryker.config.mjs` is already configured and
**`src/ui-app/README.md`'s mutation-testing section is the standing guide** for
running it and for reading survivors. Follow it; it is not restated here. What
this skill adds is scope, budget and proof.

### Running it, scoped to the diff

From `src/ui-app`, name the changed files explicitly, comma-separated in one flag:

```bash
npm run test:mutation -- --mutate 'app/utils/thing.ts,app/components/x/Thing.vue' \
  --reporters clear-text,progress,json
```

Three things that cost real time if you get them wrong:

- **`--mutate` replaces the config's array rather than merging with it**, so any
  glob loses the `!` exclusions and Stryker starts mutating your own specs and
  stories, whose survivors mean nothing. Name files explicitly, or append
  `,!app/**/*.spec.ts,!app/**/*.stories.ts` to a glob.
- **A repeated `--mutate` flag silently keeps only the last one.** One
  comma-separated value.
- **A big file with a small diff takes a line span**, not the whole file:
  `'app/utils/thing.ts:40-120'`.

**Budget it before it commits you.** Read the `Instrumented N source file(s) with M
mutant(s)` line, which prints within seconds. Measured on this machine: 9 mutants
in one util ran in 65 seconds, of which about 40 was fixed overhead (sandbox,
`nuxt prepare`, the initial test run). So it is roughly a minute flat plus a second
or two per mutant, and `.vue` mutants are the expensive ones. Over about 600
mutants, drop the `.vue` entries and say in the report that you did. A run you
killed on time is "not run", never a clean sweep.

### Reading the result

`--reporters ... json` writes `reports/mutation/mutation.json` (`reports/` is
gitignored). The clear-text reporter is configured to print every survivor, so the
console is readable on its own; the JSON is there when you want a sorted list:

```bash
~/.claude/skills/harden/scripts/survivors.sh reports/mutation/mutation.json
```

One line per actionable mutant, as `STATUS  file:line  mutator  replacement`, with
the status totals on stderr.

**Only three statuses are yours to act on: `Survived`, `NoCoverage`, `Timeout`.**
`Ignored` and `CompileError` are not survivors - a mutant that could not compile
was never a possible bug. And **a timeout is not a survivor either**: it was never
measured, and at the 60s `timeoutMS` each one eats a worker for a minute. Report
timeout counts separately rather than folding them into a sweep.

### Triaging a survivor

One question, per survivor: **is there an input a user could actually produce where
this mutation changes what they see?**

If yes, it is a missing test. Write the case. Then prove it, because a
plausible-looking test is exactly what this phase exists to catch: apply that exact
mutant by hand in the production file, run the new spec, see it go **red**, restore
the file, confirm the suite is green and `git status` is clean. A test that stays
green through its own mutation is worthless and must never be reported as a kill.
**A stray mutation left in production code is the worst thing this skill can ship**,
so restore from a copy and check `git status` before moving on.

If no, it is noise. The README's "Reading survivors" section names the three kinds
(unreachable, redundant code, not observable in a unit test) and it is the
authority. Two notes on top of it: deleting a redundant clause is a production
change, so it goes in the report rather than in the diff, and `disableTypeChecks`
hides guards that exist only to narrow a type, so never conclude a check is dead
without typechecking its removal.

A survivor is never on its own a reason to add an assertion. **If you cannot state
the user-visible consequence in one sentence, leave it alone** and say in the
report that you did, with the reason.

### When a survivor is a bug

Sometimes the mutant survives because the code is already wrong, and the mutation
changes nothing about a behavior nobody got right. Then:

- do **not** write a test asserting the buggy behavior - that is how a bug becomes
  a locked-in requirement;
- do **not** fix the production code; that is not this skill's job and not what
  was asked;
- stop and report it: the file and line, the input that shows it, what happens,
  and what should happen.

## 5. Re-run, then report

Re-run the same scope after adding specs, from clean, and read the new survivor
list rather than assuming. A final count comes from one full pass, never stitched
together from partial re-runs.

The report, short and factual:

- `npm run test:ci` and its **real exit code**;
- mutants instrumented, killed, survivors closed, timeouts, and survivors
  deliberately left with a one-line reason each;
- the specs added, by the behavior each one pins - not a list of file names;
- anything routed elsewhere: a missing story, an a11y check, a manual check, with
  what to run or click;
- any bug found, any production change the code needs to be testable, and any
  place 100% is only reachable by moving a goalpost;
- the components outside `src/ui-app` this run did not cover.

Leave the specs uncommitted - uncommitted changes are the review state - unless
`--commit` was passed, in which case commit the test files alone as
`[ui-app] Cover <behavior>`, and never push.

## Out of scope

- **The .NET components.** No Stryker.NET setup exists in the repo, and the .NET
  half of this workflow is a later job. A branch that touches one gets named in
  the report as uncovered, not half-tested. (When it does arrive: `dotnet-stryker`
  as a global tool, run from the test project directory with
  `--project <Assembly>.csproj --configuration Release`, and beware its per-file
  summary table, whose `# survived` column adds in `Ignored` mutants and overstates
  badly on a scoped run - `scripts/survivors.sh` reads the same report schema.)
- Lint, typecheck, build and the a11y suite as gates: that is `loom-gate`.
- Design and structure: that is `solidify`.
- Anything that changes production code.
