---
name: review-ui
description: Production-quality review gate for a ui-app change (Nuxt 4 / Vue 3 / @nuxt/ui v4), run before opening or while reviewing a pull request. Two modes. Fix mode (default, local scope) reviews the current branch diff against latest origin/main, or a named page/component in full, then works the findings one at a time with a human in the loop - a subagent per finding applies a minimal fix, shows the diff, and verifies; progress is tracked in a markdown state file. Report-only mode (a remote GitHub PR link/number, or when the user asks to review without editing) reviews someone else's PR diff and presents an inline report - ranked recommendations one by one, each with line-numbered code context and a concrete proposal - and makes no edits. Grounded in the live Nuxt / Nuxt UI API via the nuxt and nuxt-ui MCP servers plus the installed types. Focus is code quality: minimal code, preferring Nuxt UI components over custom ones, simplifying over-complicated patterns, keeping the exposed API minimal, i18n (no hardcoded strings), theming tokens (no hardcoded hex), and the repo's code standards / SOLID. Invoke when the user asks to "review", "review-ui", "gate", "check before PR", or "production-quality check" a ui-app feature, or hands over a GitHub PR link to review.
---

# review-ui Skill

You are the production-quality **gate** for a `ui-app` change (Nuxt 4 / Vue 3,
`@nuxt/ui` v4, Tailwind CSS v4). It runs after the prototype works and before a
pull request, or while reviewing someone else's PR. Its job is to catch the things
that separate a working prototype from code that should ship: unnecessary code,
custom markup that a Nuxt UI component already covers, over-complicated patterns,
and an API surface wider than the feature needs.

## Two modes

The mode is fixed by the input (Step 0 routes it):

- **Fix mode (default, local scope).** For your own change - the current branch
  diff against latest `origin/main`, or a named page/component in full. Discovery
  produces the ranked findings, each with a priority, summary, quick before/after,
  and recommendation; the human gates the whole list in one pass (the shared loop's
  section 1 - must-fix and recommended default to accept, minor to skip, flip any).
  Then each accepted finding is worked in its own turn - a subagent applies the
  minimal fix and runs tests, and the human keeps or reverts it and chooses whether
  to commit. Steps 3, then 5 through 7.

- **Report-only mode.** For a **remote GitHub PR** (a PR link or number - reviewing
  someone else's work), or whenever the user asks to review the local scope
  **without editing**. Reviews the diff and presents an inline report: ranked
  recommendations one by one, each with line-numbered code context and a concrete
  proposal. It makes no edits, writes no state file, and runs no fix loop. Steps 3,
  then 4.

**Fix mode runs on the shared turn-by-turn loop.** Read
[`../shared/turn-by-turn-loop.md`](../shared/turn-by-turn-loop.md) - it owns the
orchestrator model, the state-file mechanics, the one-finding-at-a-time cadence,
and the disposition loop. Report-only mode does not use that loop's state /
disposition machinery, but it keeps the same discipline: the orchestrator writes no
source code and reads no diff into its own context - discovery runs in a subagent.

## Scope (what this gate does and does NOT cover)

In scope (the review dimensions in Step 2):
- Minimal code, prefer Nuxt UI over custom, simplify complicated patterns,
  minimal exposed API, i18n, theming tokens, code standards / SOLID.

Out of scope - hand these to their owners so this gate stays focused:
- **Functional bugs / correctness / security** -> `/code-review`,
  `/security-review`.
- **Automated tests and coverage** -> the `testing-ui` skill (it owns the specs
  and the 100% branch gate). This gate may *note* that a test hook is missing if
  it blocks testability, but it does not write or evaluate tests.
- **Accessibility and test-hook/component-placement audits** are owned by
  `implement-ui`; do not re-litigate them here unless they directly cause a code
  simplification.

If while reviewing you spot a real bug or security issue, do not fix it - in fix
mode record it as a wont-fix finding pointing at the right skill; in either mode
list it under "Out of scope but worth noting" at the end.

## Step 0 - Establish the scope and mode

Route on the input:

- A **GitHub PR link or number** -> report-only mode, remote PR path.
- The user asks to review **without editing** (e.g. "just review", "report only")
  -> report-only mode, on the local scope below.
- Otherwise -> fix mode, on the local scope below.

**Local scope - the branch diff (default).** Review the current branch against the
latest `origin/main`, including committed **and** uncommitted (staged, unstaged,
and new) changes. Run from the repo root (`C:\code2\momentum`):

```bash
git fetch origin main -q
BASE=$(git merge-base origin/main HEAD)      # jj-colocated repo: HEAD/merge-base are the reliable pair; see root CLAUDE.md
git diff --name-only origin/main             # tracked files changed (committed + staged + unstaged)
git ls-files --others --exclude-standard     # new untracked files
```

On this default path, if there is no diff against `origin/main`, say so and stop -
there is nothing to review.

**Local scope - a specific target.** When the user named a page or component,
locate its file(s) under `src/ui-app/` (the page under `app/pages/`, the component
and any it composes). This reviews the target as it stands, so the no-diff stop
does not apply - review the named target even when the branch has no changes.

**Remote PR path (report-only).** Resolve the PR against `Laserfiche/momentum`, then
read its diff and file context **without disturbing the local working tree** (it may
hold the user's own in-progress work - never `gh pr checkout` or switch branches):

```bash
gh pr view <pr> --repo Laserfiche/momentum \
  --json number,title,author,headRefName,baseRefName,url,state,headRefOid,baseRefOid
gh pr diff <pr> --repo Laserfiche/momentum          # changed files + patch, against the PR's own base
git fetch origin pull/<number>/head                 # sets FETCH_HEAD to the PR head (works for forks too)
git show FETCH_HEAD:src/ui-app/<path>               # read any changed file in full at the PR head
```

Diff against the PR's own `baseRefName`, not a hardcoded `origin/main`.

Whichever path: filter to files under `src/ui-app/` (this gate only reviews the
front end), and treat each changed or added file **in full** for context, using the
diff only to scope which files matter. The orchestrator establishes scope cheaply
(the commands above), then hands the reading and reviewing to subagents from Step 3
on - do not read every changed file into the orchestrator's own context.

## Step 1 - Establish ground truth (do not review from memory)

The API is the source of truth, not your recollection. Before asserting that a
Nuxt UI component exists, covers a use case, or takes a given prop - or before a
fix subagent swaps one in - verify it:

- **nuxt-ui MCP** - the primary authority for the component library:
  `search-components` / `get-component` / `get-component-metadata` for exact
  props, slots, and emits; `get-example` and `list-examples` for idiomatic usage;
  `search-composables` for `@nuxt/ui` composables (e.g. `useToast`, `useOverlay`);
  `search-icons` for icon names; `search-documentation` / `get-documentation-page`
  for patterns.
- **nuxt MCP** - for framework-level questions (auto-imports, composables,
  data-fetching, config, SSR): `get-documentation-page`, `list-documentation-pages`,
  `search-documentation`, `get-module`.
- **The installed types** (offline, version-pinned - authoritative over any doc):
  `src/ui-app/node_modules/@nuxt/ui/dist/runtime/components/*.vue(.d.ts)` and
  `.../composables/`. If the MCP and the installed `.d.ts` disagree, the installed
  types win (the repo may be pinned to a different version). When reviewing a remote
  PR, the local `node_modules` is still valid ground truth unless that PR changes
  the `@nuxt/ui` version - if it does, verify against the version the PR pins.
- **The repo's own rules** - read `src/ui-app/CLAUDE.md` (component organization,
  theming tokens, i18n, code style) and the root `CLAUDE.md` (code standards).
  Match the app's existing patterns (`app/app.config.ts`, existing components and
  pages) over generic advice.

Never propose or apply a Nuxt UI component or prop you have not confirmed exists in
the installed API. A wrong "just use `UFoo`" is worse than no finding.

## Step 2 - Review dimensions

Go through each dimension against every changed/added file. For each issue,
capture: file and line, what the problem is, and a concrete proposed fix grounded
in the API you verified in Step 1.

1. **Prefer Nuxt UI over custom (headline check).** For every hand-rolled
   component, wrapper, or block of template + CSS, ask whether an installed
   `@nuxt/ui` component already does it (card, badge, button, input, modal/slideover,
   dropdown, table, tabs, accordion, tooltip, avatar, etc.). If yes, propose
   replacing the custom code with it, citing the component and a verified example.
   Custom is justified only when no component fits or the design genuinely requires
   it - say which when you accept a custom component.

2. **Minimal code.** Flag dead code, unused imports/props/refs/emits, commented-out
   blocks, redundant wrappers, needless intermediate variables, and abstraction that
   earns nothing (a composable/component used once with no reuse or testability
   gain). The smallest diff that meets the acceptance criteria wins.

3. **Simplify complicated patterns.** Where a pattern is more complex than the
   problem needs - manual state a composable/component already provides,
   hand-managed reactivity that `computed`/`v-model` handles, deep prop-drilling,
   an over-engineered generic - explore and propose the simpler implementation
   concretely (not "consider simplifying"; show the shape).

4. **Minimal exposed API.** For each composable and component, check the public
   surface: does it expose only what consumers actually need for the acceptance
   criteria? Flag returned refs/methods that no caller uses, props that are never
   read, and mutable state exposed where a readonly/computed value would do. Prefer
   the narrowest contract (props down, events up; `readonly()` for exposed state).

5. **i18n - no hardcoded strings** (`src/ui-app/CLAUDE.md` Localization). Every
   user-facing string must go through `t()` / `$t()` and live in
   `i18n/locales/en.json` (English only; other catalogs are generated). Flag any
   hardcoded literal in a template or script that renders to the user. If the diff
   adds keys to `en.json`, remind that the PR needs the `to-be-translated` label
   (the parity CI gate fails otherwise). Dynamic dates/numbers are formatted with
   `Intl` via `$formatLocale`/`$timeZone`, not translated - flag string-built dates.

6. **Theming tokens - no hardcoded hex** (`src/ui-app/CLAUDE.md` Conventions).
   Colors come from the theme palette tokens (`primary-800`, `gray-600`, ...), never
   arbitrary values like `bg-[#01426a]`. When you flag a hex, look it up in the
   palette and name the token it maps to. A genuinely token-less design color is a
   palette-gap to raise, not a one-off to keep.

7. **Code standards / SOLID** (root + `ui-app` `CLAUDE.md`).
   - TypeScript throughout; SFCs use `<script setup lang="ts">`. Explicit types, no
     `var`. Nullable- and globalization-aware.
   - Idiomatic Vue/Nuxt: rely on auto-imports and composables, `computed` over
     watchers where it fits, no SSR-unsafe access, no needless client-only.
   - SOLID for non-trivial logic: single responsibility per component/composable;
     depend on typed contracts, not concrete internals.
   - No em dash, emojis, arrows, or box-drawing characters in code or comments.
   - Comments only for non-obvious "why"; delete narrating comments.

8. **Coupled constants / implicit invariants (single source of truth).** A literal
   whose correctness depends on it matching another value elsewhere is a cleanliness
   defect even when it is not a color - the two copies drift the moment one changes.
   The hex-vs-token rule in dimension 6 is just the color-specific case of this;
   generalize it. Flag a spacing/size/offset that must equal a sibling's padding or a
   layout number (e.g. a brand inset hardcoded to match a nav link's `px-*`), a
   per-variant value that duplicates another variant's, or any magic number that
   encodes a relationship rather than a standalone constant. Propose one source of
   truth: derive it, or name it once (a shared const / a single token) so the copies
   cannot diverge. Two traps make these easy to miss, so check for both:
   - **Trace changed values out of the hunk.** The value a changed literal must agree
     with often lives on an unchanged line, so judging the diff in isolation never
     catches it. For each changed constant, find what it is implicitly coupled to and
     confirm they still agree.
   - **Re-check every variant, not just the default.** For a shared or variant-driven
     component (a `variant` prop, a theme map, slotted skins), run every dimension
     above against each configuration it produces - a change that is correct for the
     default path can be silently wrong for another variant.

9. **Theme-override merge semantics.** A `:ui` slot override or a `class` on a Nuxt UI
   component merges with the component's default classes through tailwind-variants and
   tailwind-merge; it does not replace them. Judge the merged result, not the string in
   the diff - utilities you did not set survive from the default, and a conflict only
   resolves in your favor when tailwind-merge recognizes both sides as the same group.
   This is the framework-idiom prerequisite that makes dimension 8's "trace out of the
   hunk" work for `@nuxt/ui`: the value a changed override is coupled to usually lives
   in the library theme, not the repo. Two silent failure modes to check for:
   - A default utility you meant to drop is still winning, because your override set a
     different property and left the one you cared about untouched (the NavRail brand
     inset had to equal the link's `px-2.5`, which was never written in NavRail - it
     rode through from `UNavigationMenu`'s default `link` slot).
   - An override you expect to win a conflict is not de-duped, so both it and the
     default end up in the class list and cascade order decides - common with arbitrary
     values (`before:bg-[...]`), `before:` / `data-[active]:` pseudo-variants, and
     custom classes tailwind-merge does not group.
   Detection: for each `:ui`, `class`, or `app.config.ts` override on a changed line,
   look up that slot's default string in the installed theme
   (`node_modules/@nuxt/ui/dist/shared/ui.*.mjs`, or `get-component-metadata`) and
   compute the merged class list before judging the restyle.

10. **Shared-unit blast radius.** When the change touches a shared unit - a component
    under `components/common/`, a composable, a `useState` / `useCookie` key, a theme
    token, an `en.json` key - review every consumer of that unit, not just the file in
    the diff. A change correct at the definition and correct for the consumer in the
    hunk can be silently wrong for a sibling consumer that never appears in the diff, or
    for the `app.config.ts` default path. Detection: grep the call sites (`<NavRail`,
    `useSidebarOpen(`, the token name, the i18n key) and open each consumer, including
    any layout that renders the component; confirm the change holds for all of them.
    This is the cross-file widening of dimension 8's "re-check every variant": that
    check stays within one variant-driven component's own output, this follows the
    coupling into the separate files that import or render the unit or share its state
    key (e.g. `useSidebarOpen`'s cookie backs both the desktop rail and the mobile
    overlay). It also gives dimension 2 its counterpart - a prop or return value no
    consumer reads, visible only once every consumer is open.

## Step 3 - Discover the ranked findings (both modes)

The findings are produced by a **discovery review** of the scope, not gathered from
an external source. Dispatch this to a fresh `general-purpose` subagent (run
synchronously) so the noisy diff-reading and MCP verification stay out of the
orchestrator's context. Seed it with the scope from Step 0 - the local branch-diff
path, the named page/component verbatim, or the remote PR (its `FETCH_HEAD` ref, the
changed `src/ui-app/` files, and the diff). Tell it to:

- Follow Step 1 (establish ground truth against the MCP servers / installed types)
  and Step 2 (run every review dimension against every changed/added file, or the
  named target in full).
- Return a **ranked findings list**, most to least impactful, and make **no code
  changes** - discovery is read-only in both modes. Group trivia (a lone unused
  import) into one finding rather than many headlines. For each finding return:
  `location` (`path:line`), a one-sentence `finding` (what and why it matters), and a
  concrete `proposal` grounded in the verified API (name the Nuxt UI
  component/prop/composable or show the reduced code shape) with a short
  before/after so the human can judge it at the gate, and a `priority` (must-fix /
  recommended / minor) that sets the finding's default at that gate.
- **In report-only mode, also return per finding the CODE CONTEXT block:** the
  current code the finding concerns, as a fenced, language-tagged block (```vue
  etc.), enough surrounding lines to be self-contained (the whole component / block /
  element), each line prefixed with its real line number. This is what the report
  shows for each recommendation.
- Also return an **"Out of scope but worth noting"** list: any bug / security /
  test / a11y observations, each pointing at the owning skill.

Then branch on mode: **report-only -> Step 4** (present and stop). **Fix mode ->**
run the shared loop's section 1 bulk gate over the whole ranked list - each finding
shown with its priority, summary, before/after, and recommendation; must-fix and
recommended default to accept, minor to skip, and the human flips any - plus the
out-of-scope notes, then **Steps 5 through 7**. If discovery finds nothing
actionable, say so and stop.

## Step 4 - Present the report (report-only mode, terminal)

Present the discovery result inline, recommendations **one by one** in rank order.
For each finding, show in this order:

- **Location** - `path:line`.
- **Code context** - the line-numbered fenced block discovery returned (the current
  code the recommendation concerns), so the reader sees exactly what is discussed
  without opening the file.
- **Finding** - one sentence on what and why it matters.
- **Recommendation** - the concrete alternative, grounded in the verified API (name
  the Nuxt UI component/prop/composable, or a short before/after as a fenced ```diff
  block). This is a proposal, **not applied** - make no edits and write no state
  file.

End with a short **verdict** (must-fix vs nice-to-have) and the **"Out of scope but
worth noting"** list, each item pointing at the owning skill (`/code-review`,
`/security-review`, `testing-ui`).

For a remote PR, the deliverable is this inline report. **Optional, outward-facing -
confirm each time, never automatic:** offer to post the review to the GitHub PR (a
review with the recommendations as inline comments), using only text the user has
seen and approved. Do not post without an explicit go.

## Step 5 - State-file path (fix mode)

One state file for the review scope, under the gitignored logs folder:

```
src/ui-app/logs/feature-review.md
```

Follow the shared loop's state-file template and resume rules; seed the `## Items`
list from the ranked discovery findings (most impactful first), each with its
`Priority` from discovery (it sets the section 1 gate default). Add these
review-specific fields to each item entry: `Proposal` (the concrete alternative
discovery returned) and `Dimension` (which review dimension it came from). Keep the
"Out of scope but worth noting" list in a trailing section of the same file.

## Step 6 - Per-finding subagent task (fix mode, apply the fix on accept)

For each pending finding, spawn the single synchronous `general-purpose` subagent
the shared loop calls for, seeded with only this finding:

> You are resolving ONE code-quality finding from a review of the momentum
> `src/ui-app`. Do not touch anything this finding does not concern.
>
> Finding: <one-sentence finding>
> Location: `<path>:<line>`
> Dimension: <which review dimension it came from>
> Proposed alternative from discovery: <the proposal, incl. any before/after>
>
> Do:
> 1. Read the current code at that location and enough around it to confirm the
>    finding still holds. Re-verify any Nuxt UI component / prop / composable the
>    fix would use against the installed API (nuxt-ui MCP or the installed
>    `.d.ts` under `src/ui-app/node_modules/@nuxt/ui`, per this skill's Step 1) -
>    never apply an API you have not confirmed exists. Decide: is the finding
>    VALID (a real, worthwhile simplification), INVALID (discovery misread it /
>    already handled / not applicable), or a JUDGEMENT CALL (a real trade-off the
>    human should weigh). Explain in 2-4 sentences, citing `file:line`.
> 2. Capture the CODE CONTEXT the finding lives on so the human can judge it
>    without opening the file: the current code as a fenced, language-tagged block
>    (```vue etc.), enough surrounding lines to be self-contained (the whole
>    component / block / element), each line prefixed with its real line number.
> 3. If VALID, make the smallest correct change that resolves it, matching the
>    surrounding style and the repo conventions (Nuxt UI over custom, i18n no
>    hardcoded strings, theming tokens no hardcoded hex, minimal exposed API,
>    data-testid conventions, SOLID). Apply it to the working tree.
> 4. Show the exact fix as a fenced ```diff block from `git diff -- <files>`
>    (unified diff, `-`/`+` lines intact). If nothing changed, say so explicitly.
> 5. Verify the change in scope: typecheck/lint the touched files and run the most
>    relevant existing unit test if there is one. Report the commands and their
>    real pass/fail output - do not claim success you did not observe. Note if a
>    full `npm run build` / coverage / a11y gate should run later before shipping.
> 6. If INVALID or a JUDGEMENT CALL, make NO code change; still provide the code
>    context from step 2 and explain what the human should weigh in on.
>
> Do NOT commit, push, or touch unrelated files. Return a structured report with:
> verdict, reasoning, the CODE CONTEXT block, files touched, the fix diff (fenced
> ```diff), verification result, and (if applicable) the open question.

Relay the report and drive the disposition exactly as the shared loop's section 3
describes (show code context + verdict + applied diff + verify, then revise / keep
/ revert, and the commit offer), and record the outcome per section 4. On revert,
undo the applied change with `git checkout -- <files>` so the working tree only
carries kept fixes.

## Step 7 - Wrap up (fix mode)

Follow the shared loop's wrap-up (section 5): summarize from the state file (kept /
skipped / wont-fix, one line each, with commit hashes where the user committed), and
make the final commit offer for any still-bundled fixes. Fixes the user leaves
uncommitted stay as working-tree changes; **never push** (per the global git
rules). Then:

- Give a short **verdict**: is the change gate-ready, or are there must-fix items
  still open (separate must-fix from nice-to-have).
- Surface the **"Out of scope but worth noting"** list - any bug / security / test
  / a11y observations, each pointing at the owning skill (`/code-review`,
  `/security-review`, `testing-ui`).
- Note that fixes touching a full gate (build / 100% coverage / a11y) should run
  through `prepare-to-ship-ui` before the PR.

The side effects of fix mode are the kept fixes - as working-tree changes, or local
commits the user chose - and the gitignored state file. It never pushes.

## Conventions

- Verify every API claim against the MCP servers or installed types before you
  assert or apply it (Step 1). Do not review from memory.
- Prefer the repo's existing patterns over generic best-practice advice.
- The orchestrator drives; the review and every fix run in subagents. Do not read
  the diff or edit source in the orchestrator's own context.
- Report-only mode makes no edits and writes no state file. The remote-PR fetch is
  read-only (`git fetch` + `git show`) - never check out or switch branches.
- No em dash, emojis, arrows, or box-drawing characters in the report.
