---
name: spec-ui
description: Turn a rough UI request into a complete, standardized UI spec that the design-ui skill can consume - SPEC ONLY, no design decisions and no code. Takes whatever the user hands over (a sentence, a bullet list, a screenshot description) and expands it into the standard template (Intent, Anatomy, Behavior, Data, Precedent, Resolved questions, Acceptance, Non-goals). Clarifies in rounds rather than in one pass: it keeps asking the human the questions only a human can answer (product intent, real data shape, scope) until a round turns up nothing that would change the shape of the UI, and it answers every pattern and behavior question itself by running the ux-review skill's method inline instead of putting the choice back on the human. Because a rough request is usually a guess at a solution, it treats the request as questionable by default - where ux-review finds a better behavior than the one asked for, it specs the researched behavior and says plainly what it changed and why. Grounds every choice in precedent first, so the feature is consistent with the rest of the app and with Manta, the company's other established app, and any divergence carries a stated reason. Applies house defaults for states/responsive/accessibility/theming and only spells out deviations. Iterates with the human until the spec is approved, then hands off to design-ui; in autonomous mode it takes the top recommendation for every open question instead of asking. Invoke when the user asks to "spec", "spec out", "write a spec", "turn this into a spec", "flesh out these requirements", or hands over rough UI requirements and wants them standardized before design starts.
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
- read the repo to pick design tokens, breakpoints, component versions, or
  components to build with. You *do* read this app and Manta for **behavioral
  precedent** (Step 2), and the line is that you are looking at what the UI does,
  never at what it is made of. Reference app conventions by intent ("reuse the
  app's existing design tokens", "the `md` breakpoint"); grounding those against
  the actual installed API is design-ui's job, not yours.

The value of this skill is disambiguation: everything a downstream designer needs
is either answered by the user, settled by researched precedent, or covered by a
stated house default, so design-ui never has to guess silently. Achieve that with
the *fewest* words: author what is feature-specific, and for convention-governed
concerns (states, responsive, accessibility, theming) rely on the house defaults
and only write down the **deviations**.

Two standing requirements sit behind everything below:

- **A rough request is a guess at a solution, not a statement of the need.** It
  is routine for the requested behavior to be the wrong behavior. Finding that
  out is your job, not the reviewer's after the screen is built.
- **The feature must be consistent with the rest of this app and with Manta.**
  Consistency is the default answer to most open questions, not a box ticked at
  the end. Divergence is allowed, and it costs a stated reason in the spec.

## Step 1 - Digest the rough input and triage it

Restate the user's request in one or two sentences so they can confirm you
understood it. Extract:
- the feature/screen/component being specced,
- any requirements the user *did* state explicitly (keep their wording),
- a short kebab-case `<feature-slug>` for the feature (e.g. `side-nav`,
  `submission-table`).

Then triage every piece of the request into three bins:

- **Stated** - the user said it and it holds up. Keep their wording.
- **Missing** - a gap. Steps 3 and 5 close it.
- **Questionable** - the request names a behavior or pattern that fights the
  app's existing conventions, contradicts another part of the same request, is a
  known weak pattern for this job, or falls apart under the real data. Do not
  spec a questionable item as written, and do not quietly rewrite it either. It
  goes to the ux-review pass in Step 3, which decides what the behavior should
  be.

Do not ask questions yet. Move on and let the gaps and the questionable items get
answered in the right order: precedent, then research, then the human.

## Step 2 - Ground in precedent (the consistency floor)

Do this before drafting anything. Read-only, and read for **behavior**: what a
user sees and does, never what the thing is built from.

- **This app.** `src/ui-app/app/pages/` and `app/components/` for the screens
  nearest this feature, plus `src/ui-app/CLAUDE.md` for house rules. What does
  the app already do for this kind of thing: how it lists, filters, confirms,
  reports an error, words an empty state, names an entity. If a neighboring
  screen already solves the problem, that is the answer unless something specific
  argues otherwise.
- **Manta**, the company's other established app, read-only at
  `<workspace root>/manta/manta-app` (root is `~/m-code` on WSL/Linux,
  `C:\code2` on Windows). It shares some users with this app, so what it ships is
  evidence about what those users expect. Four files answer most questions:
  `src/lib/design/DesignSystem.mdx` (voice, microcopy, button labels, empty
  states, toasts, confirmation dialogs, date/number/size/duration formats,
  glossary), `src/lib/design/FormValidation.mdx` (when validation fires),
  `src/lib/design/CONVENTIONS.md` (the Overview / List / Detail / Create / Modal
  shape each surface follows), and the component and page folders under
  `src/lib/design/`. If the checkout is not on this machine, say so in one line
  and continue on the app's own precedent.

Manta is a reference, not an authority, and it is built for a partly different
audience. ux-review's "Weighing Manta against the alternatives" section is the
rule for how much weight to give it; read that rather than treating a Manta
match as settling anything on its own.

Record what you found as a line or two per source. It becomes the "Precedent &
consistency" section of the spec, and it decides most of what you would otherwise
have asked the human about.

## Step 3 - Resolve the design questions with a ux-review pass

Everything still open after Step 2 splits into two bins, and they are answered
differently.

**Only the human knows.** Product intent: who is in front of this screen, what
the data really looks like at its worst, what the business rule is, which of two
goals wins, what is out of scope. Ask these, in Step 5.

**Research answers.** Pattern and behavior choices: modal vs side panel vs page,
where the primary action sits, single vs multi select, wizard vs one form, save
vs autosave, confirm vs undo, what a long label does, what an empty state offers.
Do not hand these back to the user as a menu. Resolve them, then show the answer.

Every **questionable** item from Step 1 goes in the research bin too. That is the
case this pass exists for: the request names a solution, the solution is not the
best behavior for the job, and nobody notices until the screen is built. When the
research lands somewhere other than the request, spec the researched behavior,
and say plainly in Step 5 what you changed and why so the human can overrule you.

**How to run it.** Read [`../ux-review/SKILL.md`](../ux-review/SKILL.md) and run
its method here, in this context. That file is the source of truth for how the
review works, so work from it rather than from a summary of it. Do not spawn a
subagent for the pass: spec-ui can itself be running as a stage subagent under
joey-bot, and the nesting stays flat.

Scale each question per ux-review's "Scaling the depth", and say which mode you
used:

- **Quick call** for most items - a label, a placement, an obviously conventional
  choice. A few paragraphs, no comparison table.
- **Standard review** for the one or two questions that decide the shape of the
  screen, and for any questionable item where you are proposing to depart from
  what the user asked for.
- **Deep review** only for a navigation model or a core flow.

Several quick calls beat one deep review of the wrong question. Do not inflate a
reversible choice into a research project.

Two of ux-review's own rules matter especially here. It is advisory and writes no
code, which keeps this pass inside the SPEC ONLY boundary. And it speaks in UX
language rather than implementation language, which is the same rule as this
skill's "name the behavior, not the widget".

Carry each result into the spec as behavior, not as an essay. The chosen behavior
goes into Anatomy, Behavior, or Data. One line per question goes into "Resolved
design questions": the question, what was chosen, the runner-up, and the
condition that would flip it.

## Step 4 - Draft the spec

Produce the spec using the **exact template in "The standard template" section
below**. Rules:

- Author the feature-specific sections (Intent, Anatomy, Behavior, Data,
  Precedent, Resolved design questions, Acceptance, Non-goals) from the user's
  input plus Steps 2 and 3.
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
  mark it `(default)` inline so the human can spot and veto it in Step 5. When it
  is a researched answer that departs from what the user asked for, mark it
  `(changed)` instead, so those never hide among the ordinary defaults.
- Honor the text rules: no em dash, emojis, arrows, or box-drawing characters.

## Step 5 - Clarify with the human, in rounds, until nothing shape-changing is left

This is a loop, not a single round of questions. A rough request rarely survives
one pass, and each answer opens the next layer.

Each round:

1. Present the spec (after the first round, present only what changed).
2. Say what you assumed, what precedent decided, and what the ux-review pass
   changed. Lead with the departures from the original request; those are what
   the human most needs to see and the easiest thing for them to overrule.
3. Ask **1 to 4 questions**, drawn only from the "only the human knows" bin.
   Prefer `AskUserQuestion` when the choices are discrete, so the human can
   answer fast.
4. Fold the answers in, dropping the `(default)` marker on anything they confirm
   or change. An answer usually raises the next question: "yes, multi-select"
   raises "what happens to the rows that fail a bulk action". Those are the next
   round's questions.

**Stop when** a full round produces no question whose answer would change
Anatomy, Behavior, Data, or Acceptance. Stop immediately if the human says to
stop or approves as-is. Hard cap of four rounds: anything still open after that
is written into the spec as a marked `(default)` and named to the user, not asked
about again.

**Never ask about:**
- anything the house conventions already cover,
- anything Step 2's precedent already answers,
- anything the ux-review pass answered - present the answer, do not put the
  choice back on the human,
- anything design-ui decides: components, sizing, spacing, layout mechanics.

A question that is really you not having read the app or not having run the
research pass is not a clarifying question. Go find the answer.

## Step 6 - Completeness gate, then approval

Before asking for approval, walk the finished spec once more with ux-review's
eye. Fix what you find rather than reporting it.

- Every part named in Anatomy has its behavior specified, and every state that
  actually matters is covered.
- The awkward data cases are answered: zero, one, very many, long labels, missing
  values.
- Nothing in the spec fights the Step 2 precedent without a stated reason.
- Nothing in the spec is an implementation or component decision that belongs to
  design-ui.
- Every acceptance criterion is testable as written.
- Nothing is still marked `(default)` or `(changed)` that the human has not seen.

Then present the full spec **in the conversation** and ask the human to review.
Iterate until they **explicitly approve**. Do not write any file before approval.

## Step 7 - Write the spec and hand off to design-ui

Once approved, write the spec to the standard handoff file
`src/ui-app/logs/feature-spec.md` (see "Handoff folder & format" below; create
`src/ui-app/logs/` if it does not exist). Begin the file with the standard
handoff header, then the spec body from the template. This is the handoff
contract design-ui consumes in a fresh context, so it must be self-contained: a
reader with no access to this conversation should be able to design from it alone.

After writing, tell the user the path, confirm this is a spec only (no design or
code was produced), and offer **design-ui** as the explicit next step (run it in
a fresh context - it reads this same `logs/feature-spec.md`).

## Autonomous mode (headless, under joey-bot)

When the invocation says you are running in autonomous mode (see
[`../shared/autonomous-pipeline.md`](../shared/autonomous-pipeline.md)), there is
no human to answer the rounds or approve the spec. Fold Steps 5 and 6 into a
headless pass:

- Do not ask the Step 5 questions and do not wait for the Step 6 approval. For
  every question you would have asked, take the first answer available from, in
  order: the precedent this app already sets, what Manta does where the two
  products meet, the house default, and failing all three the most-recommended
  option.
- **The ux-review pass (Step 3) is not optional headless.** It is the part that
  catches a request that does not make sense, and nothing downstream repeats it:
  design-ui grounds components, not behavior. Run it at quick-call depth by
  default, standard depth for a questionable item you are about to depart from
  the request on.
- Record every such decision in "Resolved design questions" or "Conventions &
  deviations": the choice made, and in one line the alternative not taken and
  why. A reader must be able to see what was assumed versus stated.
- Put any place the spec departs from the request **first** in "Resolved design
  questions", flagged as a change from what was asked for. That is the single
  thing the human most needs to see when they review the run.
- Write `feature-spec.md` directly (Step 7) and return your summary. Do not fork
  or produce multiple spec variants for a close call - decide and document.

Everything else (the hard SPEC-ONLY boundary, the Step 2 precedent grounding, the
template, the text rules) is unchanged.

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

Fill every section. Feature-specific sections are authored from the user's input
plus the precedent and research passes; "Conventions & deviations" defaults to a
single line and only grows when the feature departs from the house conventions.

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

## 5. Precedent & consistency
The existing screen in this app whose behavior this follows, named. Manta's
counterpart and whether this matches it; "no counterpart in Manta" is a fine
answer, say it in three words. Then any deliberate divergence from either, one
line each with the reason.

## 6. Resolved design questions
One line per question the ux-review pass settled: the question, the behavior
chosen, the runner-up, and the condition that would flip it. Anything where the
spec departs from what was originally asked for goes first, flagged as a change,
with the reason. Omit the section only if the pass settled nothing.

## 7. Conventions & deviations
State-of-play: the house conventions below apply as-is. List ONLY where this
feature deviates (a non-standard state, a specific responsive reflow, an
accessibility requirement beyond AA, a density or theming exception). If it
follows all conventions, write: "Follows house conventions; no deviations."

## 8. Acceptance criteria
A short list of testable "done" conditions - one per key behavior and per state
that actually matters.

## Non-goals (out of scope)
Explicitly what this feature will NOT do, to bound the design.
```

## House conventions (assumed unless the spec says otherwise)

These are standing defaults for `ui-app`. design-ui applies them by default; the
spec only records exceptions under "Conventions & deviations".

- **Consistency.** The feature behaves like the nearest existing screen in this
  app, and like Manta where the two products share vocabulary, formats,
  confirmations, and empty states. Divergence needs a stated reason in the spec.
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

`ux-review` (the advisory pass this skill runs on its own open questions) ->
`spec-ui` (this skill, requirements) -> `design-ui` (Nuxt UI component &
architecture blueprint) -> `implement-ui` (code) -> `update-tests` (tests). Stay in
your lane: settle what the UI should do, then hand the approved spec to design-ui.
