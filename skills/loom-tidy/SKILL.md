---
name: loom-tidy
description: Maintainability stage of the loom pipeline - one pass over the finished branch against the whole app for duplication, superseded code, misleading names, and surface width, applying only small fixes that survive a strict veto. Invoke via /loom normally; directly when the user asks to "tidy the branch" before shipping.
---

# loom-tidy: one maintainability pass

You run once, after the last slice and its probe, when the shape has settled -
tidying mid-build is rework, tidying after push is a second PR. Scope is the
branch against the **whole app**, because the two defects that matter most are
invisible in the diff: the old code this branch superseded, and the existing
code that should now use what this branch built.

Read [`../shared/loom-contract.md`](../shared/loom-contract.md), then the
ledger (the plan already names every unit the branch introduced, which is your
search list). Read changed files in full and their neighbors; a duplication or
responsibility claim from a diff alone is a guess.

## What you look for

Four questions, in order of payoff:

1. **Did the branch leave a superseded path live?** For each unit the plan
   introduced, find what it replaced and follow the threads: imports, barrel
   exports, routes, nav entries, `en.json` keys, `data-testid` references,
   stories, specs. Zero live references is a deletion; live references on both
   paths is worse - two ways to do the same thing - and the finding is to pick
   one. Never claim dead without the search behind it; cite `path:line`.
2. **Did the branch add a copy of something the app has?** Search by behavior
   (distinctive strings, props, the shape of the logic), not just names. The
   cheapest fix in this whole skill is deleting new code in favor of an
   existing unit.
3. **Should existing code converge on the branch's new unit?** Two or more
   pre-existing sites doing the same real behavior, each named with what
   changes there. If absorbing them needs a flag per caller, they are not the
   same thing - drop it. A migration bigger than the branch is a follow-up
   note, not a fix.
4. **Local warts the slices left**: a name that misleads, a prop or return no
   consumer reads, two disjoint responsibilities in one component, a constant
   that must silently agree with a value somewhere else (name it once or
   derive it).

## The veto (before anything is fixed or even reported)

- One call site means no abstraction; one implementation means no interface.
- Two copies are a note, three are a finding - except two that must agree to
  be correct, where the fix is naming the value once.
- The fix must remove more than it adds: fewer lines or fewer live paths, and
  the caller no harder to read. State the cost.
- The repo's existing pattern beats generic best practice.
- Nothing that changes behavior a slice check locks in. If a finding says the
  locked-in behavior is itself wrong, that is a ledger entry for the human,
  never a fix.

## Fixing

Apply what survives, smallest diff first, one concern per commit
(`[ui-app] <imperative>`). A deletion removes the whole thread found in
question 1 in one commit, `en.json` included (only `en.json` - the generated
catalogs are untouchable per the contract). After each fix, re-run the spec
files covering the touched code and `npx eslint --fix` on the paths; a fix
that turns a slice check red is reverted, not negotiated with.

Convergence migrations and anything sized beyond a small diff are **recorded,
not done**: the ledger's Tidy section lists them as follow-ups with the sites
named, so they become their own story instead of scope creep here.

## Return

Ledger Tidy section: fixes applied (commit each), follow-ups recorded, and a
short "considered and vetoed" list with the rule that killed each - that list
is how the reader knows you looked. A clean pass is a legitimate result; say
it plainly.
