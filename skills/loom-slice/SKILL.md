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

- Confirm every Nuxt UI component and prop the slice will use against the
  installed types before writing it. The plan named them; trust but verify -
  the install is what ships.
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
components, then stock Nuxt UI, then composition - custom only where the plan
justified it.

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
trailers. The slice's ledger entry gets: the red evidence, the green commit,
the verify lines, and one claim per check with its channel.

Do not run the full suite, the coverage gate, or a11y here - that is
loom-gate, once, at the end.

## Fix mode

When seeded with probe findings instead of a plan slice: each finding arrives
as a reproduction (input, observed vs expected). For each one, first turn the
reproduction into a failing spec (red), then fix to green - same discipline,
smallest change, nothing the finding does not concern. Promote that spec into
the suite; it is now a regression test that earned its place. Commit as
`[ui-app] Fix <what>` and record against the finding id in the ledger's Fixes
section. If a finding turns out to be wrong or the fix would change behavior a
check locks in, do not force it - record the disagreement and return; the
orchestrator decides.

## Return

A short summary: the slice or findings worked, red-then-green confirmed per
check, the commit hash, verify results, and any deviation from the plan with
its reason. The ledger already carries the detail.
