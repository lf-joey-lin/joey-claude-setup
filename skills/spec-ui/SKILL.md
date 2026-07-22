---
name: spec-ui
description: Turn a rough UI request into a complete, standardized UI spec that the design-ui skill can consume - SPEC ONLY, no design decisions and no code. Takes whatever the user hands over (a sentence, a bullet list, a screenshot description) and expands it into the standard template (Intent, Anatomy, Behavior, Data, Acceptance, Non-goals, plus a Conventions & deviations section), applying house defaults for states/responsive/accessibility/theming and only spelling out where the feature departs from them. Iterates with the human until the spec is approved, then hands off to design-ui. Invoke when the user asks to "spec", "spec out", "write a spec", "turn this into a spec", "flesh out these requirements", or hands over rough UI requirements and wants them standardized before design starts.
---

# spec-ui Skill

You are turning a **rough UI request** into a **complete, standardized UI
specification** for a feature in `ui-app`. Your deliverable is a *requirements
document* that a designer (the `design-ui` skill) can pick up cold and turn into
a component/architecture blueprint.

**Hard boundary: SPEC ONLY.** You capture *what the UI must do and be*, not *how
to build it*. Do NOT:
- choose components, libraries, or composables (that is design-ui's job),
- describe a component tree, props, or slots,
- specify sizing, spacing, or exact dimensions (that is design-ui's job),
- write any code or any file besides the final spec document,
- read the live repo to discover real design tokens, breakpoints, component
  versions, or existing components. Reference app conventions by *intent*
  ("reuse the app's existing design tokens", "the `md` breakpoint"); grounding
  those against the actual installed API is design-ui's job, not yours.

The value of this skill is disambiguation: everything a downstream designer needs
is either answered by the user or covered by a stated house default, so design-ui
never has to guess silently. Achieve that with the *fewest* words: author what is
feature-specific, and for convention-governed concerns (states, responsive,
accessibility, theming) rely on the house defaults and only write down the
**deviations**.

## Step 1 - Digest the rough input

Restate the user's request in one or two sentences so they can confirm you
understood it. Extract:
- the feature/screen/component being specced,
- any requirements the user *did* state explicitly (keep their wording),
- a short kebab-case `<feature-slug>` for the feature (e.g. `side-nav`,
  `submission-table`).

Do not ask questions yet. Move to Step 2 and let the gaps surface there.

## Step 2 - Fill the standard template

Produce the spec using the **exact template in "The standard template" section
below**. Rules:

- Author the feature-specific sections (Intent, Anatomy, Behavior, Data,
  Acceptance, Non-goals) from the user's input.
- Do NOT write a section restating a house default. States, responsive behavior,
  accessibility, and theming are governed by the standing conventions in the
  "House conventions" section. In the spec, put only the **deviations** from
  those conventions under "Conventions & deviations"; if there are none, say so
  in one line.
- Keep every entry testable and concrete. "Handles errors" is not a spec;
  "on load failure, show an inline error state with a retry action" is.
- Stay implementation-neutral: name the behavior/state, not the widget. Say
  "collapsible left rail", not "UNavigationMenu with collapsed prop".
- When something you would write is really an assumption the user did not state,
  mark it `(default)` inline so the human can spot and veto it in Step 4.
- Honor the text rules: no em dash, emojis, arrows, or box-drawing characters.

## Step 3 - Ask only the questions that change the shape of the UI

After drafting, list any assumptions you made, then ask **1 to 4 targeted
questions** - only for gaps where a wrong assumption would send design-ui down
the wrong path (e.g. "single-open vs multi-open accordion", "does collapsed state
persist across reload"). Do not ask about anything the house conventions cover
well enough to proceed. If nothing is genuinely blocking, say so and go straight
to Step 4.

Prefer batching the questions with the AskUserQuestion tool when the choices are
discrete, so the human can answer fast.

## Step 4 - Review and iterate to approval

Present the full spec **in the conversation** and ask the human to review. Fold
their answers and edits back in, dropping the `(default)` marker on anything they
confirm or change. Repeat until the human **explicitly approves**. Do not write
any file before approval.

## Step 5 - Write the spec and hand off to design-ui

Once approved, write the spec to the standard handoff file
`src/ui-app/logs/feature-spec.md` (see "Handoff folder & format" below; create
`src/ui-app/logs/` if it does not exist). Begin the file with the standard
handoff header, then the spec body from the template. This is the handoff
contract design-ui consumes in a fresh context, so it must be self-contained: a
reader with no access to this conversation should be able to design from it alone.

After writing, tell the user the path, confirm this is a spec only (no design or
code was produced), and offer **design-ui** as the explicit next step (run it in
a fresh context - it reads this same `logs/feature-spec.md`).

## Handoff folder & format (standard)

The three UI skills hand off through files in the gitignored folder
`src/ui-app/logs/` (already listed in the ui-app `.gitignore`). Each step runs
in a FRESH context and communicates only through these files - never assume the
previous or next step shares this conversation.

Standard files (fixed names; one feature in flight at a time):
- `src/ui-app/logs/feature-spec.md`   - written by spec-ui,   read by design-ui
- `src/ui-app/logs/feature-design.md` - written by design-ui, read by implement-ui

Every handoff file starts with this exact header block, then the body:

```
---
stage: spec
feature: <human-readable feature name>
slug: <feature-slug>
produced-by: spec-ui
consumed-by: design-ui
---
```

## The standard template

Fill every section. Feature-specific sections are authored from the user's input;
"Conventions & deviations" defaults to a single line and only grows when the
feature departs from the house conventions.

```
# UI Spec: <feature name>

## 1. Intent & context
Who uses it, their primary goal, and where it sits in the app.

## 2. Anatomy
The parts and their hierarchy (parent/child, what nests in what), top to bottom
or outer to inner, with a short placement hint per top-level part (e.g. "fixed
left rail", "centered overlay", "top toolbar"). This is the basic picture of the
UI; leave exact sizing and spacing to design-ui.

## 3. Behavior & interactions
Each interaction as trigger -> response -> transition (timing/easing only where it
matters), what dismisses transient UI (click-outside, Esc, route change), which
element reflects the current route/selection, and any state that must survive
reload or route change (persistence).

## 4. Data & content model
What drives the UI (static vs dynamic, nesting depth) and the awkward cases only:
long labels, many items, zero items, required vs optional fields/icons. Skip if
the UI is not data-driven.

## 5. Conventions & deviations
State-of-play: the house conventions below apply as-is. List ONLY where this
feature deviates (a non-standard state, a specific responsive reflow, an
accessibility requirement beyond AA, a density or theming exception). If it
follows all conventions, write: "Follows house conventions; no deviations."

## 6. Acceptance criteria
A short list of testable "done" conditions - one per key behavior and per state
that actually matters.

## Non-goals (out of scope)
Explicitly what this feature will NOT do, to bound the design.
```

## House conventions (assumed unless the spec says otherwise)

These are standing defaults for `ui-app`. design-ui applies them by default; the
spec only records exceptions under "Conventions & deviations".

- **States.** Every interactive element has default, hover, focus-visible,
  active/selected, and disabled. Data-driven parts also have loading, empty, and
  error. The current route/selection is visibly marked.
- **Responsive.** Mobile-first. Below the `md` breakpoint, side rails become an
  off-canvas drawer with a backdrop and multi-column content stacks to one column.
- **Accessibility.** WCAG AA: full keyboard operability, visible focus, correct
  landmarks/roles, `aria-label` on icon-only controls, respect reduced-motion.
- **Theming.** Reuse the app's existing design tokens; support light and dark; no
  hard-coded colors; default density.
- **Transient UI.** Dismisses on click-outside, Esc, and route change.
- **Content.** Long labels truncate with a tooltip; every data-driven list
  defines an empty state.
- **Persistence.** None unless the interaction implies it (e.g. a collapse toggle
  persists across reload).

## Relationship to the other UI skills

`spec-ui` (this skill, requirements) -> `design-ui` (Nuxt UI component &
architecture blueprint) -> `implement-ui` (code) -> `testing-ui` (tests). Stay in
your lane: capture requirements, then hand the approved spec to design-ui.
