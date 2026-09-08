---
name: loom-tidy
description: Maintainability stage of the loom pipeline - one pass over the finished branch against the whole app for duplication, superseded code, misleading names, and surface width, applying only small fixes that survive a strict veto. Invoke via /loom normally; directly when the user asks to "tidy the branch" before shipping.
---

# loom-tidy: one maintainability pass

You run once, after the last slice, its probe and `loom-shape`, when the shape
has settled - tidying mid-build is rework, tidying after push is a second PR.
Scope is the branch against the **whole app**, because the two defects that
matter most are invisible in the diff: the old code this branch superseded, and
the existing code that should now use what this branch built.

`loom-shape` ran just before you and may have moved code, so read the tree as
it stands rather than the diff you expected. It also owns the defect one level
up from yours: a concept living in two homes, which is a structural finding and
never a tidy fix however tempting the small version of it looks. Its ledger
section lists what it cleared and what it left as a follow-up. Anything it
recorded as a local defect is yours, and it is in your input list below.

Read [`../shared/loom-contract.md`](../shared/loom-contract.md), then the
ledger: the plan (it names every unit the branch introduced, which is your
search list), every probe section's `polish` findings, and `loom-shape`'s
"Local defects noticed" list. Those two lists are your other input - each entry
is fixed here if it survives the veto below, or closed with the rule that
killed it. Nothing else in the pipeline picks them up. Read changed files in full and their neighbors; a duplication or
responsibility claim from a diff alone is a guess.

## What you look for

Five questions, in order of payoff:

1. **Did the branch leave a superseded path live?** For each unit the plan
   introduced, find what it replaced and follow the threads: imports, barrel
   exports, routes, nav entries, `en.json` keys, `data-testid` references,
   stories, specs. Zero live references is a deletion; live references on both
   paths is worse - two ways to do the same thing - and the finding is to pick
   one. Never claim dead without the search behind it; cite `path:line`.
2. **Did the branch add a copy of something the app has?** Search by behavior
   (distinctive strings, props, the shape of the logic), not just names. The
   cheapest fix in this whole skill is deleting new code in favor of an
   existing unit. **Spec files count here**, and they are the ones most often
   missed: no earlier stage reviews them, so the branch's specs reach you
   unreviewed. The deep probe's spec-copy sweep names the sites - extracting a
   shared harness is this skill's fix, not a slice fix turn.
3. **Should existing code converge on the branch's new unit?** Two or more
   pre-existing sites doing the same real behavior, each named with what
   changes there. If absorbing them needs a flag per caller, they are not the
   same thing - drop it. A migration bigger than the branch is a follow-up
   note, not a fix.
4. **Did the branch hand-roll something the platform provides?** The backstop
   for the plan's sweep, and the one question a diff answers well: for each
   effect the branch wrote by hand - a listener, an observer, a timer, a
   lifecycle pair - check the contract's rosters for a unit that already does
   it. The veto still binds, so a swap that adds a direct dependency is
   recorded rather than done, with the unit named.
5. **Local warts the slices left**: a name that misleads, a prop or return no
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
- Nothing whose evidence is a concept in two homes rather than a defect in one
  file. That is `loom-shape`'s, it has already run and priced it, and a small
  fix aimed at a structural finding usually just hides it. Record it as a line
  pointing at the shape section.

## Fixing

Apply what survives, smallest diff first, one concern per commit
(`[<component>] <imperative>` per the contract). A deletion removes the whole
thread found in question 1 in one commit, `en.json` included (only `en.json` -
the generated catalogs are untouchable per the contract). After each fix,
re-run the spec files covering the touched code and the cheap check for that
side (`npx eslint --fix` on ui paths, the BFF build for C#); a fix that turns
a slice check red is reverted, not negotiated with.

Convergence migrations and anything sized beyond a small diff are **recorded,
not done**: the ledger's Tidy section lists them as follow-ups with the sites
named, so they become their own story instead of scope creep here.

## Return

Ledger Tidy section: fixes applied (commit each), follow-ups recorded, every
probe polish finding closed one way or the other, and a short "considered and
vetoed" list with the rule that killed each - that list is how the reader
knows you looked. A clean pass is a legitimate result; say
it plainly.
