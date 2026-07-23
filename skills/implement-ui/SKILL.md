---
name: implement-ui
description: Implement a UI feature in ui-app, either from an approved design handoff (logs/feature-design.md) produced by design-ui, or from a freeform request the user provides directly for a small tweak or addition that does not need the full spec/design pipeline. Works in a fresh context and builds idiomatic Nuxt UI + Vue 3 code following SOLID principles, the app's design language and theming, mobile-first responsive layout, accessibility, and the repo's data-testid conventions, then verifies it compiles and lints and hands off to the human to test and iterate. Writing the automated test suite is a separate testing-ui pass, done after the human is satisfied. Invoke when the user asks to "implement", "build", "code up", or "start on" a UI design, hands over a design handoff for the ui-app, or asks for a small UI change/addition described inline.
---

# implement-ui Skill

You are implementing a UI feature in `ui-app` (Nuxt 4 / Vue 3, `@nuxt/ui` v4,
Tailwind CSS v4). You work from one of two inputs (see Step 0 for how to tell
which):

- **Design handoff (default).** A `logs/feature-design.md` produced and
  human-approved by the design-ui skill. When present, it is your single source
  of truth - implement what it specifies, do not redesign.
- **Freeform request.** A small tweak or addition the user describes directly in
  the prompt, for changes that do not warrant the full spec -> design -> implement
  pipeline (e.g. adjust a button, add a field, fix a layout, add a small
  component). Here the user's words are the spec; there is no design document.

Scope boundary: this skill builds the feature and gets it compiling, linting, and
ready for a human to exercise. It does **not** write the automated test suite -
that is the `testing-ui` pass, run after the human has manually tested and
iterated, so tests lock in settled behavior instead of being rewritten each round.
You still add `data-testid` hooks (Step 2); those live in the components and serve
both manual and later automated testing.

## Run in a fresh subagent when the context is dirty

This skill is invoked iteratively, often several times in one session, and
implementation generates a lot of file-read and command noise. To keep the main
conversation clean:

- **If the current context is dirty** - there is already unrelated conversation,
  prior tool output, or another skill's work in context (e.g. you were invoked
  from inside a design/spec conversation, or this is a repeat implement/iterate
  run) - do NOT run the steps below inline. Dispatch the whole run to a fresh
  `general-purpose` subagent (Agent tool), seeded only with the inputs it needs
  (see below), and have it return the Step 5 handoff summary. Relay that summary
  to the user concisely; do not dump the subagent's transcript. Each invocation
  spawns its own subagent, so repeated iterations never accumulate in the main
  context. For a large feature, one subagent per component/page is a good split.
- **If you ARE that dispatched subagent** (a fresh context seeded only with these
  inputs), or the context is genuinely clean (a fresh session where this is the
  first substantive work - e.g. a small freeform tweak), run the steps inline and
  do NOT dispatch again.

Seed the subagent with: the input mode and its payload - in design-handoff mode,
the handoff path (`src/ui-app/logs/feature-design.md` or the path the user gave);
in freeform mode, the user's request restated verbatim - plus any human feedback
from a prior iteration. Tell it to follow this skill (implement-ui) end to end
and return the Step 5 summary (files changed, test hooks added, compile/lint
results, deviations, and the manual checks for the human).

## Step 0 - Determine the input, load it, and re-ground on the live install

1. **Determine the input mode and load it.**
   - **Design handoff (default).** If the user gives no inline requirements, the
     input is the standard handoff file `src/ui-app/logs/feature-design.md`
     written by design-ui (see "Handoff folder & format" below); read it in full
     unless the user hands you a different path. It is the contract - implement
     what it specifies, do not redesign. Take the `feature`/`slug` from its
     header.
   - **Freeform request.** If the user describes the change directly in the
     prompt (a small tweak or addition), treat their words as the spec and skip
     the handoff file entirely. Do NOT go read `logs/feature-design.md` - it may
     belong to an unrelated feature. Restate the request in one or two sentences
     so the user can confirm scope before you build. If the ask is actually large
     or design-heavy (multiple screens, new data flows, non-obvious layout),
     recommend running spec-ui / design-ui first rather than improvising a design.
   - If you cannot tell which mode applies (no inline requirements and no handoff
     file), ask the user rather than guessing.
2. **Re-ground on the live installed API** (the install is the source of truth,
   offline and version-pinned):
   - Component roster: `node_modules/@nuxt/ui/dist/runtime/components/*.vue`.
   - Exact props/slots/emits: the matching `*.vue.d.ts`.
   - Composables: `node_modules/@nuxt/ui/dist/runtime/composables/` and their `.d.ts`.
   - Only use the free `https://ui.nuxt.com/llms-full.txt` / component pages for
     usage patterns when the types are not enough.
3. **Detect drift (design-handoff mode only).** Compare the design's "Pinned
   versions" against the current `src/ui-app/package.json`. If a component/prop
   the design cites no longer matches the installed `.d.ts`, STOP and flag it - do
   not silently invent a substitute. Freeform requests have no pinned versions;
   just build against the live API from step 2.
4. **Absorb the app's design language.** Read `src/ui-app/app/app.config.ts`
   (color/theme tokens), `nuxt.config.ts`, `app/layouts/`, and existing components
   (e.g. `app/components/SideNav.vue`) and pages so new code matches what already
   ships.

If the design or freeform request is ambiguous, self-contradictory, or conflicts
with the live API, ask the user rather than guessing.

## Step 1 - Plan the work

Turn the design (or the freeform request) into an ordered implementation plan and
track it with TaskCreate: files to create/edit (pages, components, composables),
and the order that lets you verify incrementally. Keep the diff tightly scoped to
the request. For a one-file freeform tweak, a lightweight plan (or none) is fine -
do not over-ceremony a small change.

## Step 2 - Implement

Follow these throughout:

**SOLID and composition.**
- Single responsibility: small, focused components; a page composes components, it
  does not become a monolith.
- Extract non-trivial logic into composables under `app/composables/` (or the
  app's existing location), not inline in SFCs. Keep view and logic separable.
- Props down, events up. Depend on typed contracts (interfaces/types), not
  concrete internals, so pieces stay swappable and testable.
- Reuse existing app components and Nuxt UI components before writing anything new;
  build custom only where the design justified it.

**Company design language and theming.**
- Use `@nuxt/ui` components and the `ui` prop plus `app.config.ts` tokens for
  styling. Do not hand-roll CSS that a token or component slot already covers.
- Match the existing color/spacing/radius conventions and the app's layout shell.

**Mobile-first and responsive.**
- Build mobile-first; layer Tailwind v4 responsive utilities and Nuxt UI responsive
  props up to larger breakpoints, per the design's responsive plan (in freeform
  mode, follow the house mobile-first conventions in `ui-app/CLAUDE.md`).
- Verify what stacks/collapses/reflows at mobile, tablet, and desktop widths.

**Accessibility.**
- Semantic HTML and correct ARIA roles/labels so elements are locatable by
  role/label. Keyboard operability and sensible focus order. Honor the design's
  a11y plan and any reduced-motion needs (in freeform mode, the WCAG AA house
  defaults in `ui-app/CLAUDE.md` apply).

**Test hooks (per ui-app/CLAUDE.md).**
- Prefer role/label locatability first; add `data-testid` only where an element is
  ambiguous, icon-only, dynamic, or repeated. Naming `<feature>-<element>-<qualifier>`,
  lowercase, hyphenated, stable across refactors. For repeated rows/cards use a
  stable entity ID in the value, never the array index. Note which hooks you added
  and why - testing-ui and manual testers both rely on them.

**Code style (root + ui-app CLAUDE.md).**
- TypeScript throughout; SFCs use `<script setup lang="ts">`. Explicit types, no
  `var`. Nullable/globalization aware. No em dash, emojis, arrows, or box-drawing
  characters in code or text.

## Step 3 - Verify it compiles and lints (do not claim success unchecked)

Run from `src/ui-app` and report the actual output:
- `npm run build` - the app compiles.
- `npx eslint .` (or the repo's lint script) - clean.

Do NOT run or write the test suite here. If a check fails, fix it and re-run.

## Step 4 - Hand off to the human to test and iterate (the gate)

Stop and hand control to the human. Tell them to run `npm run dev` and exercise the
feature - behavior, layout at mobile/tablet/desktop widths, empty/loading/error
states, keyboard and a11y. Call out specifically what to look at (routes, states,
breakpoints) since those are not deterministically assertable here.

Iterate with the human: apply their feedback, re-verify compile/lint (Step 3), and
repeat until they are satisfied. Do not proceed to writing tests on your own - the
human decides when the behavior is settled.

Once the human confirms the feature is good, point them to the `testing-ui` skill
(run in a fresh context against the design handoff, if any, and the implemented
code) to write the automated suite and satisfy the coverage gate.

## Step 5 - Summarize the handoff

Report: what was built (files created/edited), the `data-testid` hooks added and
why, compile/lint results, any deviation from the design (or from what the
freeform request asked for) and the reason, and the concrete manual checks the
human should run (routes, states, breakpoints, a11y).

## Autonomous mode (headless, under joey-bot)

When the invocation says you are running in autonomous mode (see
[`../shared/autonomous-pipeline.md`](../shared/autonomous-pipeline.md)), there is
no human to exercise the feature. Replace the Step 4 gate:

- Do NOT stop and hand control to the human at Step 4. After Step 3 (compile +
  lint) passes, go straight to Step 5. Manual UI verification (dev server,
  breakpoints, states, a11y) cannot be auto-asserted here, so it is not skipped -
  it is **deferred**: list the concrete manual checks in the Step 5 summary so the
  final joey-bot review gate carries them to the human.
- Resolve any ambiguity in the design or freeform request with the most-reasonable
  interpretation and record it as a deviation in the Step 5 summary, rather than
  asking. Only a contradiction with no reasonable default is a blocker to surface.
- You are already the dispatched subagent (joey-bot spawned you), so run the steps
  inline; do not dispatch a further subagent.

Do not commit here - commit policy for the run belongs to joey-bot. Everything
else (SOLID, theming, mobile-first, a11y, test hooks, the real compile/lint
verification) is unchanged.

## Handoff folder & format (standard)

The three UI skills hand off through files in the gitignored folder
`src/ui-app/logs/` (already listed in the ui-app `.gitignore`). Each step runs
in a FRESH context and communicates only through these files - never assume the
design conversation is in context.

Standard files (fixed names; one feature in flight at a time):
- `src/ui-app/logs/feature-spec.md`   - written by spec-ui,   read by design-ui
- `src/ui-app/logs/feature-design.md` - written by design-ui, read by implement-ui

In design-handoff mode this skill reads `feature-design.md` (in freeform mode
there is no handoff file - the user's prompt is the spec). The handoff file
starts with a standard header, then the design body:

```
---
stage: design
feature: <human-readable feature name>
slug: <feature-slug>
produced-by: design-ui
consumed-by: implement-ui
---
```

If you need the original requirements, `src/ui-app/logs/feature-spec.md` is the
upstream spec. This skill writes code, not handoff files.

## Commands (from src/ui-app)

- `npm run dev` - run the app locally for manual/visual checks.
- `npm run build` - production build (use to confirm it compiles).
- Automated tests (`npm run test:ci` and the coverage gate) are owned by the
  `testing-ui` pass, not this skill.
