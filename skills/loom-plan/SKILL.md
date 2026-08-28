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
- **Two kinds.** A slice is `ui` (the default) or `bff` - the browser-facing
  route plus its thin ui-app service composable, built when scout found the
  data path missing. A bff slice is still vertical: its behavior is "the
  browser can ask for X and gets the narrowed shape", provable on its own
  through the BFF test harness before any screen exists.
- **Slice 1 is always the walking skeleton**: the route exists, the page
  shell renders inside the app's layout, and the real data path is wired far
  enough to show the empty state. When the run has a bff slice, that slice
  comes first and the skeleton is slice 2, consuming it - everything
  integration-shaped that can go wrong goes wrong in the cheapest slice.
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

## Grounding a bff slice (api-integrator, steps 0 to 4)

The browser contract is the most consequential decision in the plan, so it is
designed here, where the human gate can see it - not improvised mid-build.
Read [`../api-integrator/SKILL.md`](../api-integrator/SKILL.md) and run its
**Steps 0 through 4** now: ground in the as-built BFF code, pin down the ask,
read the upstream contract from its own source (never guess a shape), pick
the BFF, and design the narrowed browser-facing contract - verb normalized,
fields cut to what the browser reads, the reused outcome type, the status
map. That file is the single source for all of it; follow it rather than a
summary, with two loom-specific overrides:

- Its Step 5 approval gate is **not** run as its own pause. The plan entry
  carries the same material (upstream route with where you read it, the
  route and verb, the DTO field for field with what is dropped, the status
  map, config or chart changes), and loom's ask moment 2 is the gate.
  In solo mode the contract design is the one decision that never defaults
  silently: log it in full in the ledger so the report shows exactly what
  shape was chosen.
- Its "no new realm" boundary is a loom blocker: if the upstream is neither
  realm, mark the run `[!]` with the reason and stop planning.

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
- **For a bff slice, additionally** (the contract's ledger template has the
  fields): the upstream route as read from source, the browser route and
  verb, the DTO with what is deliberately dropped, and the status map. Its
  checks are xUnit assertions through the BFF's existing test harness
  (`AcsTestHarness` or the app-bff equivalent), and its attack line covers
  the upstream failure shapes: non-2xx, `IsError` inside a 200, missing
  `Value`, the empty collection, wire drift.

## Finish

Mark the Plan `[x]` and return a summary: the slice list with one line each,
any custom component and its justification, prior art found, and any decision
you defaulted (logged in the ledger per the contract). In attended mode this
is the orchestrator's second ask moment; in solo mode there is nothing to
ask - the defaults are logged and the run continues.
