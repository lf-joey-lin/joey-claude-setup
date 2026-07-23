# ui-app quality dimensions (shared)

The production-quality bar for any change to the momentum `src/ui-app` (Nuxt 4 /
Vue 3, `@nuxt/ui` v4, Tailwind CSS v4). These are the dimensions that separate a
working prototype from code that should ship: no unnecessary code, no custom markup
a Nuxt UI component already covers, no over-complicated patterns, no wider API than
the feature needs, and the repo's i18n / theming / SOLID standards held.

Two skills share this one bar, from opposite ends:

- **review-ui** audits an existing change against every dimension and files a
  finding for each violation. Read each dimension as "what to flag."
- **design-ui** makes design decisions that pre-satisfy every dimension, so the
  blueprint it hands to `implement-ui` produces code that passes review-ui with
  nothing to flag. Read each dimension as "the decision that would not be flagged,"
  and self-check the blueprint against the list before handing off.

The host skill owns HOW it consumes these (audit a diff and gate findings; or
design against them and self-check). This file owns WHAT the bar is. Read it
alongside the host skill; the host skill wins where they differ.

## Ground truth first (do not work from memory)

The installed API is the source of truth, not recollection. `@nuxt/ui` v4 differs
substantially from v2/v3 (component names, `app.config.ts` theming, Tailwind v4,
Reka UI primitives). Before asserting that a Nuxt UI component exists, covers a use
case, or takes a given prop - whether you are proposing it in a design, flagging
its absence in review, or swapping one in as a fix - confirm it against the live
sources:

- **The installed types (authoritative, offline, version-pinned).**
  `src/ui-app/node_modules/@nuxt/ui/dist/runtime/components/*.vue` (the `U`-prefixed
  set, e.g. `Button.vue` = `<UButton>`) and their `*.vue.d.ts` for exact
  props/slots/emits; `.../composables/` and their `.d.ts` (`useToast`, `useOverlay`,
  `defineShortcuts`); the theme defaults in `.../dist/shared/ui.*.mjs`. When any doc
  or MCP disagrees with the installed `.d.ts`, the installed types win - that is
  what actually ships. (Read from `src/ui-app` so you get the pinned version.)
- **The nuxt-ui and nuxt MCP servers** (when available): `search-components` /
  `get-component` / `get-component-metadata` for exact props/slots/emits,
  `get-example` / `list-examples` for idiomatic usage, `search-composables`,
  `search-icons`, and `search-documentation` / `get-documentation-page` /
  `list-documentation-pages` for patterns and framework-level questions.
- **The free Nuxt UI LLM docs** for prose/patterns when MCP is not on hand
  (fetch via WebFetch): `https://ui.nuxt.com/llms.txt` (index),
  `https://ui.nuxt.com/llms-full.txt` (large - scope your prompt to the
  component/topic), `https://ui.nuxt.com/components/<name>`.
- **The repo's own rules** - `src/ui-app/CLAUDE.md` (component organization,
  theming tokens, i18n, code style) and the root `CLAUDE.md` (code standards).
  Match the app's existing patterns (`app/app.config.ts`, existing components and
  pages) over generic advice.

Never propose, flag, or apply a Nuxt UI component or prop you have not confirmed
exists in the installed API. A wrong "just use `UFoo`" is worse than saying nothing.

## The dimensions

1. **Prefer Nuxt UI over custom (headline check).** For every hand-rolled
   component, wrapper, or block of template + CSS, ask whether an installed
   `@nuxt/ui` component already does it (card, badge, button, input,
   modal/slideover, dropdown, table, tabs, accordion, tooltip, avatar, etc.). If
   yes, use it, citing the component and a verified example. Custom is justified
   only when no component fits or the design genuinely requires it - say which when
   you accept a custom component. (Design: every custom component in the map carries
   a written justification. Review: propose replacing the custom code with the
   stock component.)

2. **Minimal code.** No dead code, unused imports/props/refs/emits, commented-out
   blocks, redundant wrappers, needless intermediate variables, or abstraction that
   earns nothing (a composable/component used once with no reuse or testability
   gain). The smallest solution that meets the acceptance criteria wins.

3. **Simplify complicated patterns.** No pattern more complex than the problem
   needs - manual state a composable/component already provides, hand-managed
   reactivity that `computed`/`v-model` handles, deep prop-drilling, an
   over-engineered generic. Reach for the simpler shape concretely (not "consider
   simplifying"; name the shape).

4. **Minimal exposed API.** For each composable and component, the public surface
   exposes only what consumers actually need for the acceptance criteria. No
   returned refs/methods no caller uses, no props never read, no mutable state
   exposed where a readonly/computed value would do. Prefer the narrowest contract
   (props down, events up; `readonly()` for exposed state).

5. **i18n - no hardcoded strings** (`src/ui-app/CLAUDE.md` Localization). Every
   user-facing string goes through `t()` / `$t()` and lives in
   `i18n/locales/en.json` (English only; other catalogs are generated). No
   hardcoded literal in a template or script that renders to the user. Keys added
   to `en.json` mean the PR needs the `to-be-translated` label (the parity CI gate
   fails otherwise). Dynamic dates/numbers are formatted with `Intl` via
   `$formatLocale`/`$timeZone`, not translated - no string-built dates.

6. **Theming tokens - no hardcoded hex** (`src/ui-app/CLAUDE.md` Conventions).
   Colors come from the theme palette tokens (`primary-800`, `gray-600`, ...), never
   arbitrary values like `bg-[#01426a]`. When a hex is unavoidable, look it up in
   the palette and name the token it maps to. A genuinely token-less design color is
   a palette-gap to raise, not a one-off to keep.

7. **Code standards / SOLID** (root + `ui-app` `CLAUDE.md`).
   - TypeScript throughout; SFCs use `<script setup lang="ts">`. Explicit types, no
     `var`. Nullable- and globalization-aware.
   - Idiomatic Vue/Nuxt: rely on auto-imports and composables, `computed` over
     watchers where it fits, no SSR-unsafe access, no needless client-only.
   - SOLID for non-trivial logic: single responsibility per component/composable;
     depend on typed contracts, not concrete internals.
   - No em dash, emojis, arrows, or box-drawing characters in code or comments.
   - Comments only for non-obvious "why"; no narrating comments.

8. **Coupled constants / implicit invariants (single source of truth).** A literal
   whose correctness depends on it matching another value elsewhere is a cleanliness
   defect even when it is not a color - the two copies drift the moment one changes.
   The hex-vs-token rule in dimension 6 is just the color-specific case of this;
   generalize it. Watch for a spacing/size/offset that must equal a sibling's
   padding or a layout number (e.g. a brand inset that must match a nav link's
   `px-*`), a per-variant value that duplicates another variant's, or any magic
   number that encodes a relationship rather than a standalone constant. One source
   of truth: derive it, or name it once (a shared const / a single token) so the
   copies cannot diverge. Two traps make these easy to miss:
   - **Trace values out of the local change.** The value a literal must agree with
     often lives on a line you are not touching, so judging a change in isolation
     never catches it. For each constant, find what it is implicitly coupled to and
     confirm they still agree.
   - **Re-check every variant, not just the default.** For a shared or
     variant-driven component (a `variant` prop, a theme map, slotted skins), run
     every dimension above against each configuration it produces - a choice correct
     for the default path can be silently wrong for another variant.

9. **Theme-override merge semantics.** A `:ui` slot override or a `class` on a Nuxt
   UI component merges with the component's default classes through tailwind-variants
   and tailwind-merge; it does not replace them. Judge the merged result, not the
   string you wrote - utilities you did not set survive from the default, and a
   conflict only resolves in your favor when tailwind-merge recognizes both sides as
   the same group. This is the framework-idiom prerequisite that makes dimension 8's
   "trace out of the local change" work for `@nuxt/ui`: the value a changed override
   is coupled to usually lives in the library theme, not the repo. Two silent
   failure modes:
   - A default utility you meant to drop is still winning, because your override set
     a different property and left the one you cared about untouched (the NavRail
     brand inset had to equal the link's `px-2.5`, which was never written in NavRail
     - it rode through from `UNavigationMenu`'s default `link` slot).
   - An override you expect to win a conflict is not de-duped, so both it and the
     default end up in the class list and cascade order decides - common with
     arbitrary values (`before:bg-[...]`), `before:` / `data-[active]:`
     pseudo-variants, and custom classes tailwind-merge does not group.
   Detection: for each `:ui`, `class`, or `app.config.ts` override, look up that
   slot's default string in the installed theme
   (`node_modules/@nuxt/ui/dist/shared/ui.*.mjs`, or `get-component-metadata`) and
   compute the merged class list before judging the restyle.

10. **Shared-unit blast radius.** When the change touches a shared unit - a
    component under `components/common/`, a composable, a `useState` / `useCookie`
    key, a theme token, an `en.json` key - it must hold for every consumer of that
    unit, not just the file in front of you. A change correct at the definition and
    correct for one consumer can be silently wrong for a sibling consumer that never
    appears in the change, or for the `app.config.ts` default path. Detection: grep
    the call sites (`<NavRail`, `useSidebarOpen(`, the token name, the i18n key) and
    open each consumer, including any layout that renders the component; confirm the
    change holds for all of them. This is the cross-file widening of dimension 8's
    "re-check every variant": that check stays within one variant-driven component's
    own output, this follows the coupling into the separate files that import or
    render the unit or share its state key (e.g. `useSidebarOpen`'s cookie backs
    both the desktop rail and the mobile overlay). It also gives dimension 2 its
    counterpart - a prop or return value no consumer reads, visible only once every
    consumer is open.

## Out of scope for this bar

These dimensions are code quality only. They do NOT cover functional
bugs / correctness / security (`/code-review`, `/security-review`), automated tests
and coverage (`testing-ui`), or accessibility and test-hook/component-placement
audits (owned by `implement-ui`). If while applying this bar you spot a real bug,
security issue, or missing test, note it against the owning skill rather than
folding it in here.
