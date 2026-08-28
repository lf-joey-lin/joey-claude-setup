---
name: loom-plan
description: Feature-lane planning stage of the loom pipeline - turn the scout brief into an ordered list of vertical slices, each independently buildable and verifiable, with its acceptance checks and probe attacks named up front. Invoke via /loom normally; directly when the user asks to "slice this up" or "plan a loom feature".
---

# loom-plan: slice the feature

You turn the brief into a plan of **vertical slices**. A slice is the smallest
increment that changes what a user can see or do and can be verified on its
own. The pipeline builds and verifies one slice at a time, so the plan is the
backbone of the whole run.

Read [`../shared/loom-contract.md`](../shared/loom-contract.md) first, then
the ledger's Brief section. You write no product code; your only output is the
Plan section of the ledger.

## What a slice is

- **Vertical, not horizontal.** "The route renders the table with real data"
  is a slice. "All the composables" is not - a layer proves nothing on its
  own and cannot go red or green as a behavior.
- **Slice 1 is always the walking skeleton**: the route exists, the page
  shell renders inside the app's layout, and the real data path is wired far
  enough to show the empty state. Everything integration-shaped that can go
  wrong goes wrong here, in the cheapest slice.
- **Each later slice adds one behavior**: the populated list, then filtering,
  then row actions, then the error and edge states if they are not already
  forced by earlier checks. Two to six slices; more means the feature should
  have been split at scout.
- **Order by risk**: the slice most likely to invalidate the plan goes
  earliest, because a plan change after slice 1 is cheap and after slice 5 is
  rework.

## Grounding

Before naming any Nuxt UI component or composable in a slice, confirm it in
the installed types (`node_modules/@nuxt/ui/dist/runtime/`, per the
contract). Prefer the stock component, then composition of stock components,
then custom - and a custom component costs a one-line written justification
in the plan. Check `app/components/` for an existing app component first;
reusing one beats both.

While grounding, run one cheap prior-art check per new unit the plan
introduces (component, composable, state key, group of `en.json` keys): does
something in the app already do this, and does this supersede anything? A hit
changes the plan now, for one line, instead of surfacing in tidy after the
code exists. Cite `path:line` for what you found.

## Each slice's entry

Write into the ledger's Plan section, per slice:

- **Behavior** - one sentence, what a user sees or does afterward.
- **Checks** - the acceptance assertions, numbered C1..Cn. Each names its
  **channel**: the one observable thing a caller or test looks at (a rendered
  role/text, an emitted event, a request that goes out, a route change, a DOM
  attribute). A check with no channel is not a check. These become the specs
  loom-slice writes first, so phrase them as testable facts, not intentions.
- **Touches** - the files it will create or edit, with the Nuxt UI pieces
  confirmed above.
- **Attack** - what loom-probe should try to break it with, drawn from the
  brief's awkward cases: the empty list, the 400-character label, the missing
  field, the double-click, the narrow viewport behavior a unit test can reach.

## Finish

Mark the Plan `[x]` and return a summary: the slice list with one line each,
any custom component and its justification, prior art found, and any decision
you defaulted (logged in the ledger per the contract). In attended mode this
is the orchestrator's second ask moment; in solo mode there is nothing to
ask - the defaults are logged and the run continues.
