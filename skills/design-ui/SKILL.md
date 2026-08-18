---
name: design-ui
description: Turn a list of specs and UI requirements into a Nuxt UI design and architecture plan for ui-app - DESIGN ONLY, no implementation. Grounds itself in the live Nuxt UI API installed in the repo (local node_modules types, plus the free ui.nuxt.com llms docs for prose/patterns), maps each requirement to Nuxt UI components/composables, calls out where a custom Vue component is genuinely needed, and outlines the layout/composition tree, theming, and open questions. It designs against the same shared ui-app quality dimensions that review-ui gates on, so the blueprint it produces passes review with nothing to flag. It then runs the solidify skill's bar over the finished blueprint as its own pass, so the design cannot bake in a SOLID/DRY defect: it reuses prior art instead of adding a second way to do the same thing, names the superseded code implement-ui has to delete, lists the existing sites that should converge on any shared unit it introduces, and holds every custom component to solidify's over-engineering veto. After the human approves the blueprint, it writes a design.md handoff document that implement-ui consumes. Invoke when the user asks to "design", "plan", "architect", "spec out", or "figure out the components for" a UI feature/page/screen in the ui-app, or hands over UI requirements and wants a component/architecture blueprint before any code is written.
---

# design-ui Skill

You are producing a **design and architecture plan** for a UI feature in `ui-app`
(Nuxt 4 / Vue 3, `@nuxt/ui` v4, Tailwind CSS v4). Your deliverable is a
**blueprint**: a mapping from requirements to the right Nuxt UI building blocks,
plus a clear, justified call on what has to be custom.

**Hard boundary: DESIGN ONLY. Write NO implementation.** No `.vue` files, no
`app.config.ts` edits, no SFCs, no runnable code. Component "contracts" you
describe are prose/tables (props, emits, slots, states), not source. The only
file this skill ever writes is the final `design.md`, and only after the human
approves (Step 10).

The value of this skill is choosing the *most idiomatic* Nuxt UI solution and
resisting the urge to hand-roll what the library already provides. Custom Vue
components are a last resort, justified in writing.

## Step 0 - Ground yourself in the LIVE installed Nuxt UI API (required)

Follow the shared **Ground truth first** section in
[`../shared/ui-quality-dimensions.md`](../shared/ui-quality-dimensions.md) - the
same discipline review-ui gates on. Do NOT design from memory. `@nuxt/ui` v4
differs substantially from v2/v3 (component names, `app.config.ts` theming,
Tailwind v4, Reka UI primitives). **Always use the version installed in the repo
as the source of truth** - it is exact, version-pinned, and offline. This skill
reaches ground truth through the local install and the free llms docs below (the
nuxt-ui / nuxt MCP servers are an option too when available):

1. **Local install (primary).** The installed package is what this app actually
   ships.
   - Component roster: list `node_modules/@nuxt/ui/dist/runtime/components/*.vue`
     (the `U`-prefixed set, e.g. `Button.vue` = `<UButton>`).
   - Exact props/slots/emits: read the matching `*.vue.d.ts` (e.g.
     `components/Table.vue.d.ts`). These are the real, typed contracts.
   - Composables: list `node_modules/@nuxt/ui/dist/runtime/composables/` and read
     their `.d.ts` (e.g. `useToast`, `useOverlay`, `defineShortcuts`).
   - Do this from `src/ui-app` so you get the pinned version, not guesses.
2. **Free Nuxt UI LLM docs (prose, patterns, examples).** Fetch via WebFetch when
   you need usage patterns beyond the types:
   - Index: `https://ui.nuxt.com/llms.txt`
   - Full docs: `https://ui.nuxt.com/llms-full.txt` (large; scope your prompt to
     the component/composable/topic you need).
   - A specific component page: `https://ui.nuxt.com/components/<name>`
     (e.g. `.../components/table`, `.../components/form`).
3. **WebSearch** only to locate the right doc page when unsure of a name.

Also read what the repo already ships before proposing anything:
- `src/ui-app/package.json` - confirm the actual `@nuxt/ui` / `tailwindcss` /
  `nuxt` versions.
- `src/ui-app/nuxt.config.ts` and `src/ui-app/app/app.config.ts` - registered
  modules, existing `ui` theme/color overrides.
- `src/ui-app/app/components/` and `app/pages/` - reuse existing app components
  (e.g. `SideNav`) and routes instead of re-designing them.

Only cite components/props you have confirmed in the local types or the docs. If
unsure a component exists in v4, look it up rather than assuming. Prefer the local
`.d.ts` over the web docs when they could disagree - the install is what ships.

## Step 1 - Digest the requirements

**Read the spec handoff first.** This skill runs in a fresh context; its input is
the standard handoff file `src/ui-app/logs/feature-spec.md` written by spec-ui
(see "Handoff folder & format" below). Read it in full - it is self-contained.
Take the `feature`/`slug` from its header. If the file is missing, ask the user
for the spec (or a path) rather than guessing.

Restate the specs in your own words as a short, numbered requirement list. Record
anything that changes a component choice as an assumption (do not block unless
genuinely blocking):
- Screens/routes involved and how the user navigates between them.
- Data shape and volume (a 5-field form vs. a 10k-row table drive different components).
- Interactions and states: loading, empty, error, disabled, validation, async.
- Responsive/breakpoint needs and accessibility requirements beyond the defaults.
- Reuse: does an existing app component or page already cover part of this?

Ask the user 1-3 clarifying questions ONLY when an answer would change the
architecture. Otherwise proceed and record assumptions.

## Step 2 - Map requirements to Nuxt UI (the core deliverable)

For every requirement, decide: Nuxt UI component, Nuxt UI component + light
composition, or custom Vue component. Prefer earlier options. Produce a table:

| # | Requirement | Solution | Nuxt UI pieces | Notes / why |
|---|-------------|----------|----------------|-------------|
| 1 | ... | Nuxt UI | `UForm`, `UInput`, `UButton` | schema validation via UForm |
| 2 | ... | Compose | `UCard` + `UTable` + `UPagination` | standard list pattern |
| 3 | ... | **Custom** | wraps `UModal` | no native fit - see contract below |

Rules:
- Reach for the idiomatic Nuxt UI component first (forms: `UForm`/`UInput`/`USelect`/etc.;
  data: `UTable`; overlays: `UModal`/`USlideover`/`UPopover`; nav:
  `UNavigationMenu`/`UTabs`/`UBreadcrumb`; feedback: `UAlert`/`UToast`/`UBadge`).
  Confirm exact names/props against the local `.d.ts`.
- Prefer **composition of stock components** over a custom component.
- Prefer **`app.config.ts` theming and the `ui` prop** over restyling; name the
  token/slot to change rather than proposing custom CSS.
- A custom Vue component is justified only when no Nuxt UI primitive fits, or the
  composition would be unmaintainable. State the reason explicitly.

## Step 3 - Composables and state

List the Nuxt UI and Nuxt composables the design relies on and what each is for
(e.g. `useToast` for notifications, `useOverlay` for programmatic overlays,
`defineShortcuts` for keybindings, `useState`/`useAsyncData` for shared/async state).
Do not write code - name them and say where they attach.

## Step 4 - Layout and composition tree

Give the page/component tree as an indented text outline (not code), showing where
Nuxt UI components sit, where custom components slot in, and where slots/layouts are
used. Reference the app's existing layout and `SideNav` where relevant. Note the
route(s) under `app/pages/` this maps to.

## Step 5 - Responsive and accessibility plan

State how the design behaves across breakpoints (mobile-first): what stacks,
collapses, or reflows at each Tailwind breakpoint, and which Nuxt UI responsive
props/slots handle it. Note accessibility beyond defaults: focus order, keyboard
interaction, ARIA roles/labels, and any reduced-motion or contrast needs. This
section is the contract implement-ui builds and tests against.

## Step 6 - Custom component contracts (design-level only)

For each custom component from Step 2, specify as prose/tables (NOT code):
- Purpose and the Nuxt UI primitives it composes/wraps.
- Props (name, type, required, default), emits, and named slots.
- States it must handle (loading/empty/error/disabled/validation).
- `data-testid` hooks it should expose, per `ui-app/CLAUDE.md` (icon-only buttons,
  inputs + validation messages, list rows keyed by stable entity ID, dialog actions,
  state indicators). Naming: `<feature>-<element>-<qualifier>`.

## Step 7 - Theming and design tokens

State the theming approach: which `app.config.ts` `ui` keys / component slots /
Tailwind v4 tokens to set (colors, radius, variants), reusing existing overrides.
Keep it to what the design needs; do not restyle globally without cause.

## Step 8 - Design to pass review (self-check against the shared dimensions)

The blueprint is what `implement-ui` builds from, so a design decision that violates
a quality dimension becomes a review-ui finding on the eventual PR. Head that off:
walk the blueprint against every dimension in
[`../shared/ui-quality-dimensions.md`](../shared/ui-quality-dimensions.md)
("The dimensions", 1 through 10) and confirm the design pre-satisfies each. Read
each as "the decision that would not be flagged":

1. **Prefer Nuxt UI over custom** - every custom component in the Step 2 map carries
   a written justification; nothing hand-rolled that a stock component covers.
2. **Minimal code** - the fewest components/layers that meet the spec; no
   abstraction introduced without a second consumer or a real testability gain.
3. **Simplify** - the composition is the simplest that works; no manual state a
   composable / `computed` / `v-model` already gives.
4. **Minimal exposed API** - each custom contract (Step 6) exposes only the
   props/emits/slots consumers need; exposed state is readonly/computed, not mutable.
5. **i18n** - every user-facing string in the contracts is a `t()` key, none
   hardcoded; note the `en.json` keys the feature adds (they need the
   `to-be-translated` label).
6. **Theming tokens** - the theming plan (Step 7) names palette tokens and
   `app.config.ts` / `ui` keys, never hex.
7. **Code standards / SOLID** - contracts are typed, single-responsibility,
   props-down / events-up.
8. **Coupled constants** - any value shared between pieces (an inset that must match
   a padding, a repeated size) is named once (a token / const) in the design, not
   left as a duplicated magic number for implement-ui to copy twice.
9. **Theme-override merge semantics** - where the design specifies a `:ui` / `class`
   override, it names the default slot class it layers on and accounts for
   merge-with-default behavior, so implement-ui does not fight tailwind-merge.
10. **Shared-unit blast radius** - when the design introduces or reuses a shared unit
    (a `components/common/` component, a composable, a `useState` / `useCookie` key,
    a theme token, an `en.json` key), it lists the consumers and holds for all of
    them.

Anything you cannot satisfy at design time goes into the Open questions / risks
section (Step 10, item 9) so implement-ui and review-ui see it, rather than being
silently deferred. Same "Out of scope" boundary as the shared file: correctness,
security, tests, and a11y are owned elsewhere (see Step 5 for the a11y plan this
skill does own).

## Step 9 - Solidify pass (run before you present anything)

review-ui is not the only gate the eventual branch faces. `/solidify` reviews it
for SOLID, DRY and maintainability, and it judges the branch against the whole
app rather than the diff. Most of what it finds was decided here, not during
implementation: a component that duplicates one three folders away, an old page
left live beside the new one, a composable built for a single call site. So run
its bar over the blueprint now, while a fix is one line of a table.

Read [`../solidify/SKILL.md`](../solidify/SKILL.md) for the current veto and
dimensions rather than working from the summary below - that file is the source
of truth, and this pass is its design-time application.

The two self-checks do not overlap. Step 8 covers what solidify hands to
review-ui (Nuxt UI component choice, i18n, theming tokens, accessibility). This
step covers what solidify keeps.

**The app-context searches.** Do these against the repo; do not reason from the
spec. Run them for every new unit in the blueprint - page, component, composable,
`useState` / `useCookie` key, helper, type, group of `en.json` keys:

- **Does something already do this?** Search `app/components/`, `app/composables/`
  and `app/pages/` by name, by the props and state it carries, and by the shape of
  the markup. Names diverge, behavior does not. If a hit is the same behavior, the
  design reuses it and the new unit comes out of the Step 2 map.
- **What does it supersede?** Name the old unit and every thread wired into it:
  imports and auto-import globs, route and nav entries, `en.json` keys,
  `data-testid` references, stories, tests. That list becomes the deletion
  checklist implement-ui works from. Two live paths to the same behavior is the
  expensive outcome - the next reader cannot tell which one is current.
- **Who else should use it?** When the blueprint introduces a genuinely shared
  unit, grep for the hand-rolled copies it makes redundant, open each, and decide
  whether it is the same behavior or only the same silhouette. Two or more real
  sites means the design names them and says whether the migration belongs to this
  feature or is follow-up work.

Cite what you find as `path:line`. A "nothing else does this" or "these three
places do the same thing" claim needs the search behind it.

**The veto binds harder here than in review.** Design is where speculative
abstraction is cheapest to add and most expensive to remove later. Before any
custom component, composable, wrapper or base type survives into the map:

- One call site means no abstraction. Existing hand-rolled copies elsewhere in the
  app do count as sites - cite them.
- One implementation means no interface, unless you can name the seam it sits on.
- Two copies are a note, three are a finding, and the fix is to name the thing
  once, not to build a framework.
- The fix must remove more than it adds; say what it costs in components and hops.
- The repo's existing pattern wins over generic best practice.

Anything that fails, collapse back into the page or the stock component, and say
so in the map's "why" column.

**Dimensions to walk the blueprint against** (solidify's Step 2, at design time):

- **Single responsibility** - a component in the tree that both fetches and renders
  where its siblings separate the two, or that holds two disjoint clusters of state.
- **Open/closed** - the design adds the second or third visibly parallel arm to an
  existing conditional, lookup or variant map.
- **Interface segregation** - a props contract carrying members some of its
  consumers will never use.
- **Dependency inversion** - a presentational component that reaches for its own
  data source instead of taking it through props or a composable, in an app whose
  siblings inject it.
- **DRY** - logic (not shape) the design repeats across two of its own components,
  or a third copy of something the app already has twice.
- **Naming and dead code** - names that mislead, and anything this feature orphans.
- **Coupled constants, public surface width, shared-unit blast radius** - already
  covered as Step 8 items 8, 4 and 10. Solidify counts them too; do not run them
  twice.

**What to do with a finding.** At design time a finding is an edit, not a report:
change the component map, the tree, or the contract, and move on. Only what you
cannot resolve here goes into Open questions / risks (Step 10, item 9) with the
reason. Keep one line for each thing you considered and vetoed, so the reader can
tell you looked and decided rather than missed it.

## Step 10 - Review, approve, then write design.md

First present the full blueprint **in the conversation** (all sections below,
including the Step 9 solidify result) and ask the human to review. Iterate until
they explicitly approve. Do NOT write any file before approval - the human gate is
the whole point of this skill. A deletion the solidify pass proposes needs the
human's explicit yes here, since implement-ui will act on it without asking again.

Once the human approves, write the blueprint to the standard handoff file
`src/ui-app/logs/feature-design.md` (see "Handoff folder & format" below; create
`src/ui-app/logs/` if it does not exist). Begin the file with the standard
handoff header, then the document body. This file is the **handoff contract**
that `implement-ui` consumes in a fresh context, so it must be self-contained - a
reader with no access to this conversation should be able to build from it alone.

Structure the document (after the header) with these sections:
1. **Feature** - one-line summary and the target route(s)/page(s).
2. **Requirements** (numbered, incl. assumptions).
3. **Component map** (the Step 2 table).
4. **Composables & state**.
5. **Layout / composition tree**.
6. **Responsive & accessibility plan**.
7. **Custom components** (contracts, with test hooks) - or "none needed".
8. **Theming**.
9. **Open questions / risks** (anything that could flip a decision).
10. **Solidify pass** - the Step 9 result, written for implement-ui to act on:
    prior art reused instead of rebuilt; the superseded code to delete, with every
    reference thread listed as a checklist; existing sites that should converge on
    a shared unit this design introduces, and whether that is in scope here or
    follow-up; abstractions vetoed, one line each. "None" is a valid answer to any
    of these, but say it rather than leaving the heading out.
11. **Pinned versions** - the `@nuxt/ui` / `nuxt` / `tailwindcss` versions you
    grounded against, so implement-ui can detect drift.

After writing, tell the user the path and state that this is a design only, no
implementation was written. Offer implement-ui as the explicit next step (run in
a fresh context - it reads this same `logs/feature-design.md`).

## Autonomous mode (headless, under joey-bot)

When the invocation says you are running in autonomous mode (see
[`../shared/autonomous-pipeline.md`](../shared/autonomous-pipeline.md)), there is
no human to approve the blueprint. Fold the Step 1/Step 2 clarifying questions and
the Step 10 approval gate into a headless pass:

- Do not ask clarifying questions and do not wait for the Step 10 approval. Resolve
  every open architectural choice with the most-idiomatic Nuxt UI option, still
  grounded in the live installed API (Step 0 is not optional in autonomous mode).
- Record each resolved choice and the alternative you did not take, with a one-line
  reason, in the "Open questions / risks" section so implement-ui and review-ui see
  it. Do not fork or produce multiple designs for a close call - decide and document.
- Write `feature-design.md` directly once the blueprint is complete, then return
  your summary.

Everything else is unchanged, including the DESIGN-ONLY boundary, the ground-truth
discipline, the Step 8 self-check against the quality dimensions, and the Step 9
solidify pass. The solidify pass is not optional headless either - its searches are
exactly what a fresh context would otherwise skip, and nothing downstream repeats
them before the branch reaches `/solidify`.

## Handoff folder & format (standard)

The three UI skills hand off through files in the gitignored folder
`src/ui-app/logs/` (already listed in the ui-app `.gitignore`). Each step runs
in a FRESH context and communicates only through these files - never assume the
previous or next step shares this conversation.

Standard files (fixed names; one feature in flight at a time):
- `src/ui-app/logs/feature-spec.md`   - written by spec-ui,   read by design-ui
- `src/ui-app/logs/feature-design.md` - written by design-ui, read by implement-ui

This skill reads `feature-spec.md` and writes `feature-design.md`. Every handoff
file starts with the standard header block, then the body. The header this skill
writes:

```
---
stage: design
feature: <human-readable feature name>
slug: <feature-slug>
produced-by: design-ui
consumed-by: implement-ui
---
```

Carry `feature`/`slug` through from the spec header unchanged.

## Conventions to honor (from ui-app/CLAUDE.md)

- TypeScript throughout; Vue 3 SFCs use `<script setup lang="ts">` (relevant when
  describing contracts, not for you to write).
- Prefer semantic HTML and correct ARIA so elements are locatable by role/label;
  add `data-testid` only where ambiguous/icon-only/repeated/dynamic.
- No em dash, emojis, arrows, or box-drawing characters in any text you produce.
