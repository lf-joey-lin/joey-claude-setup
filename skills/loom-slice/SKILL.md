---
name: loom-slice
description: Build stage of the loom pipeline - implement ONE slice from the plan, checks first: write the slice's acceptance specs, see them fail, implement to green, verify, commit. Also runs in fix mode over probe findings. Invoke via /loom normally; directly when the user asks to "build slice N" or hands over one small verifiable change.
---

# loom-slice: one slice, born red

You build exactly one slice. The defining rule: **every spec is written before
the code it locks in, and is seen failing first**. A test observed going red
and then green has already proven it can fail - that is the evidence the
ledger records, and it is why loom needs no separate after-the-fact test pass
over slice work.

Read [`../shared/loom-contract.md`](../shared/loom-contract.md), then the
ledger: the Brief, the Plan entry for your slice (or the brief's inline slice
on the patch lane), and any probe findings assigned to you in fix mode.

## Step 0 - ground

Read the clock first: `date -Iseconds`, kept for the slice's `- Timing:` line.
It is the one thing that cannot be recovered afterwards, and a slice that
forgets it has to report the time as unrecorded rather than invent one.

- Confirm every component, composable and prop the slice will use against the
  installed types before writing it. The plan named them; trust but verify -
  the install is what ships.
- The slice's `Platform:` line is binding. Build what it named. If the code in
  front of you makes that unit wrong, run the contract's ordering again before
  writing the effect yourself, and record the swap in the ledger with the unit
  passed over. A hand-roll that first appears at build time is a decision, so
  it is logged like one.
- Read the sibling specs nearest the code you will touch and match their
  style: locator priority (`getByRole`/`getByLabel`/`getByText`, then
  `getByTestId`, never `:nth-child` or XPath), fixture shape, naming.
- Read the component or page you are extending in full, not just the hunk.

## Step 1 - red

Write the slice's checks C1..Cn as co-located `*.spec.ts` (Vitest + Vue Test
Utils), one test per check, asserting on the **channel** the plan named. Then
run them:

```bash
cd src/ui-app && npx vitest run --project=unit <spec paths>
```

**Every new test must fail, and fail for the right reason** - the behavior is
absent, not the import is broken or the harness misassembled. A test that
passes before the implementation exists is asserting nothing: fix its channel
now, not after green. Record the red run in the ledger (the spec path and the
assertion that failed). This record is the falsifier evidence for the whole
slice.

Where a check cannot go red first because the harness needs a stub of the very
thing being built (rare), say so in the ledger and give that test a targeted
mutation check after green instead - break the line it covers, see it fail,
restore. Never skip both.

## Step 2 - green

Implement the smallest code that turns the specs green, holding the contract's
conventions throughout: i18n keys in `en.json` (never a hardcoded user-facing
string), palette tokens (never hex), `<script setup lang="ts">`, semantic HTML
first with `data-testid` only where role/label cannot locate, mobile-first
responsive, keyboard operability. Reuse before writing: the app's own
components and composables, then Nuxt UI, then a Nuxt or Vue built-in, then a
VueUse composable, then composition of those - custom only where the plan
justified it. That ordering covers the effects too, not just the markup.

While the specs are red you may iterate freely. Do not weaken a spec to reach
green: if a check turns out to be wrong once the code is in front of you,
change it deliberately and record why in the ledger - a check silently
loosened is the one failure mode this design cannot catch.

## Step 3 - verify and commit

```bash
cd src/ui-app && npx vitest run --project=unit <spec paths>   # all green
npx nuxt typecheck
npx eslint --fix <touched paths>
```

Real exit codes into the ledger. Then one commit for the slice - code, its
specs, and its `en.json` keys together, subject `[ui-app] <imperative>`, no
trailers. Read the clock again once that write is done, and record the
contract's `- Timing:` line from the two readings. The slice's ledger entry
gets: the timing, the red evidence, the green commit, the verify lines, and
one claim per check with its channel.

Do not run the full suite, the coverage gate, or a11y here - that is
loom-gate, once, at the end.

## Bff mode (a slice whose Kind is bff)

The plan already designed the browser contract (api-integrator's Steps 0 to
4, gated at ask moment 2). You build it. Read
[`../api-integrator/SKILL.md`](../api-integrator/SKILL.md) and follow its
**Steps 6 through 8** - the file table, the non-negotiable C# conventions,
the thin ui-app service composable shape - plus its **invariant checklist**,
which you walk before committing. Two loom-specific overrides:

- **Born red still holds, in xUnit.** Before the production files exist,
  write the slice's checks as tests in the BFF's existing harness
  (`AcsTestHarness` scripts the upstream; handlers are named methods so
  tests call them directly): the happy projection, and the failure mapping
  the plan's status map promises (`IsError` in a 200 becomes 502, expiry
  becomes 401 before the 403 branch). Run the test class, see it fail for
  the right reason, then build to green. Record the red run in the ledger
  exactly as for a ui slice.
- **Verify** is the BFF pair, from the repo root: `dotnet build
  src/<bff>/<bff>.slnx -c Release` and the new test class via `dotnet test
  ... --filter`. Then the ui-app cheap pair (`npx nuxt typecheck`,
  `npm run lint`) if the slice included the service composable. Commit
  subject `[acs-bff]` or `[app-bff]` (both halves in one commit when the
  composable rode along - it is one contract).

api-integrator's own step 7/8 hand-back points do not apply; loom's
orchestrator is the one you return to. Its "ask before the client slice"
question defaults to yes here - the composable is what makes the slice
vertical, and the next slice consumes it.

## Fix mode

When seeded with probe findings instead of a plan slice: each finding arrives
as a reproduction (input, observed vs expected). For each one, first turn the
reproduction into a failing spec (red), then fix to green - same discipline,
smallest change, nothing the finding does not concern. Promote that spec into
the suite; it is now a regression test that earned its place. Commit as
`[ui-app] Fix <what>` and record against the finding id in the ledger's Fixes
section, with its own `- Timing:` line - a fix turn is stage time and the run
total has to account for it. If a finding turns out to be wrong or the fix
would change behavior a check locks in, do not force it - record the
disagreement and return; the orchestrator decides.

## Return

A short summary: the slice or findings worked, red-then-green confirmed per
check, the commit hash, verify results, and any deviation from the plan with
its reason. The ledger already carries the detail.
