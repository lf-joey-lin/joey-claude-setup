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

This is where the run's component and composable choices are really made. A
slice inherits them and builds; nothing downstream reopens them. So the sweep
below runs before you write a single slice entry, and it is a search, not a
check on names you already chose.

### The platform sweep (per behavior, not per component)

Write down the behaviors the brief asks for, in plain words, before naming any
file. Include the effects underneath the visible ones: loading more as a list
ends, debouncing a search box, trapping focus in an overlay, reading an
element's size, watching an element enter the viewport, persisting a
preference, copying to the clipboard, reacting to the page going hidden. Those
are the ones that get hand-rolled, because nobody thinks of them as a
component.

For each behavior, find what already does it, in the contract's order: an app
component or composable, a Nuxt UI component, a Nuxt or Vue built-in, a VueUse
composable, composition of those, custom. Search by behavior, not by the name
you expect to find. The rosters are in the contract and `grep -i` over them is
the whole technique:

```bash
ls src/ui-app/app/components/ src/ui-app/app/composables/
ls src/ui-app/node_modules/@nuxt/ui/dist/runtime/components/
grep -i 'scroll\|debounce\|clipboard' src/ui-app/.nuxt/imports.d.ts
grep -i 'scroll\|debounce\|clipboard' src/ui-app/node_modules/@vueuse/core/dist/index.d.ts
```

A behavior is not planned until you can name which of those answered it, at a
`path:line`. Nothing here is a component-only rule: a stock `UTable` with sixty
lines of hand-written observer wiring beside it is the exact defect the sweep
exists to catch, and it passes every check that only looks at component names.

### Writing the choice down

Every slice entry carries a `Platform:` line, per the contract's template:
either the unit taken with the `path:line` that confirmed it, or the hand-roll
with the platform unit it passed over and what that unit could not do. A
hand-roll with no named alternative means the sweep did not run, and the plan
is not done.

Two things that are **not** a trade-off on their own, because both were used as
one before:

- **"It is not auto-imported."** True of every `@vueuse/core` composable, and
  it costs one `import { x } from '@vueuse/core'` line. The package is a
  declared dependency and `app/` already ships a consumer, so this is not a
  decision for the human and not a reason to write the effect by hand - see
  the contract's VueUse bullet. Confirm the name in
  `node_modules/@vueuse/core/dist/index.d.ts`, not in `.nuxt/imports.d.ts`
  where it will never appear.
- **"It is only about fifteen lines."** Fifteen lines of lifecycle and
  teardown is where the edge cases live - the server render with no observer,
  the double fire in one frame, the listener that outlives the element. That
  is an argument for the platform unit, not against it.

A custom component still costs its own one-line justification on top of the
`Platform:` line.

### Prior art and shape

While grounding, run one cheap prior-art check per new unit the plan
introduces (component, composable, state key, group of `en.json` keys): does
something in the app already do this, and does this supersede anything? A hit
changes the plan now, for one line, instead of surfacing in tidy after the
code exists. Cite `path:line` for what you found.

Then three questions over what that search turned up, written into the ledger
as a short `### Shape check` block under the Plan. They are cheap by
construction - each is answerable from the search you just ran plus the
slices' own `Touches:` lines - and they sit here rather than in tidy because
tidy cannot fix any of them: its veto stops at a diff bigger than the branch,
and by then a slice check has locked the shape in.

1. **Count the copies.** For each pattern the plan follows rather than reuses,
   count the sites already following it. Three or more means this plan adds
   the Nth: say which N, and say in one line why copying still beats
   extracting. "It matches the others" is the question, not the answer.
2. **Price a widening.** Does a slice add a prop, option or mode to an
   existing shared unit for fewer callers than that unit has? Name the unit,
   the caller that wants it, and the callers it will be meaningless for.
3. **Follow a new mode.** Does a flag or discriminant the plan introduces get
   read in more than one file, or passed through more than one level? List the
   sites off the `Touches:` lines. Then the test that decides it: **name the
   two cases it tells apart, both shipping today.** A mode with one real case
   is not a mode, it is a hard-coded answer with a switch in front of it, and
   the honest plan writes the answer. A mode whose second case is expected
   later is the same thing with optimism attached. Two cases live now, or the
   slice carries no flag.

One line each, whether or not it fires. A question that fires also gets a line
in the return, and ask moment 2 carries it the way it carries a hand-roll.
Nothing firing is the normal result and is recorded as such, so a reader can
tell the sweep from a skipped sweep.

Stop there. This is a sweep over the shape the plan is about to commit to, not
a structural review. A concept genuinely smeared across the subsystem belongs
to `loom-shape`, which runs after the last slice, when the shape has settled
and the evidence is code rather than a prediction. Naming a suspicion here
costs nothing and helps it: write it as one line under the shape check, and
`loom-shape` will either build it into a finding or clear it.

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
- **Platform** - what the sweep answered each of the slice's behaviors with,
  confirmed at `path:line`, plus any hand-roll with the unit it passed over and
  why. Required on every slice; "all stock" is a valid answer, an empty line is
  not.
- **Checks** - the acceptance assertions, numbered C1..Cn. Each names its
  **channel**: the one observable thing a caller or test looks at (a rendered
  role/text, an emitted event, a request that goes out, a route change, a DOM
  attribute). A check with no channel is not a check. These become the specs
  loom-slice writes first, so phrase them as testable facts, not intentions.
  More than six checks, or a check whose behavior an earlier slice already
  carries, means the boundary is in the wrong place: move the check or split
  the slice now, because loom-slice will report it as a check that could not
  go red.
- **Touches** - the files it will create or edit, with the platform pieces
  confirmed above.
- **A11y** - the story file that puts the slice's new markup in front of the
  a11y suite. That suite mounts `*.stories.ts` under `app/components`,
  `app/layouts` and `app/pages` and nothing else, so a component with no
  story is never scanned and a green a11y pass says nothing about it. Name an
  existing story that renders the new markup, or the story the slice will add.
  `none` is valid only for a slice that adds no markup.
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
every hand-roll with the platform unit it passed over, any custom component and
its justification, prior art found, any shape-check question that fired, and
any decision you defaulted (logged in the ledger per the contract). A
hand-roll whose only obstacle is a package this repo does not already depend on
is called out by name in the return, because adding a dependency is the human's
to answer, not yours. `@vueuse/core` is not one of those: it is declared and
already consumed, so it needs no line. In
attended mode this is the orchestrator's second ask moment; in solo mode there
is nothing to ask - the defaults are logged and the run continues.
