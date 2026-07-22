---
name: testing-ui
description: Write and verify the automated test suite for a ui-app feature after the human has manually tested and approved the implementation. Runs in a fresh context against the design.md and the implemented code, writes co-located Vitest + Vue Test Utils specs (and Playwright end-to-end tests where warranted), follows the testing conventions and locator priority in ui-app/CLAUDE.md, and confirms the suite passes and holds the repo's 100% branch-coverage gate. Invoke when the user asks to "test", "add tests", "write the specs", or "cover" a ui-app feature that is already built and human-approved.
---

# testing-ui Skill

You write the **automated tests** for a `ui-app` feature that is already built and
has been manually tested and approved by a human. This is the pass after
implement-ui, so the behavior is settled - you are locking it in, not shaping it.

Run in a **fresh context**: your inputs are the feature's design handoff
(`src/ui-app/logs/feature-design.md`, the gitignored standard handoff file
written by design-ui) and the implemented code, not the implement conversation.
Read both first.

## The substance lives in ui-app/CLAUDE.md - follow it

`src/ui-app/CLAUDE.md` is the source of truth for how this repo tests. Read its
"UI automation & testing" section and follow it exactly. In short:
- **Co-located `*.spec.ts`** next to the code (Vitest + Vue Test Utils), matching
  existing specs such as `SideNav.spec.ts` and `index.spec.ts`.
- **Locator priority:** `getByRole` / `getByLabel` / `getByText` first, then
  `getByTestId` for the hooks implement-ui added, then a CSS attribute selector as
  a last resort. Never XPath, never `:nth-child`. If nothing can locate an element,
  that is a missing test hook in the component - flag it, do not reach for fragile
  selectors.
- **Frugality:** before adding a test, check it is not subsumed by an existing one.
  Prefer one end-to-end test with good internal diagnostics over three overlapping
  tests.
- **Waiting/assertions:** built-in auto-waiting (`await expect(locator).toBeVisible()`),
  assert on `data-testid`'d state indicators for async state, not timing or
  localized text.
- **Playwright E2E**, when the feature warrants it, uses the 3-tier
  framework / steps / tests architecture in that doc - a locator change should only
  ever touch tier 1.

## What to cover

Drive coverage from the design and the code:
- Every state the design lists (loading, empty, error, disabled, validation) and
  every branch the implementation introduced.
- User-visible behavior and interactions, not implementation details.
The repo **gates PRs on 100% statement and branch coverage**, so untested branches
will fail CI - cover them, or remove genuinely dead branches rather than papering
over them with contrived tests.

## Verify (do not claim success unchecked)

From `src/ui-app`, run and report the actual output:
- `npm run test:ci` - tests pass AND the 100% statement/branch thresholds hold.
Use `npm run test:coverage` while iterating to see which lines/branches remain
uncovered. If a branch is truly unreachable, say so and justify it rather than
forcing coverage.

## Summarize

Report: test files added/edited, what behavior each covers, the final coverage
result (with numbers), any missing test hooks you had to flag back to the
component, and anything a human should still verify manually (visual/responsive
nuance that unit/component tests cannot assert).

## Conventions

- TypeScript for all test code (including Playwright). `<script setup lang="ts">`
  patterns as in existing specs.
- No em dash, emojis, arrows, or box-drawing characters in code or text.
