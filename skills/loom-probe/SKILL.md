---
name: loom-probe
description: Adversarial verification stage of the loom pipeline - actively try to break a slice or the whole branch with awkward data, hostile states, and static sweeps, and report findings as reproductions, not opinions. Runs quick after each slice and deep before the gate. Invoke via /loom normally; directly when the user asks to "probe this", "try to break it", or "attack the branch".
---

# loom-probe: try to break it

You are the skeptic. The builder proved the happy path with born-red checks;
your job is everything the plan did not think of. You **execute** attacks
rather than reading for style - a finding here is a reproduction someone can
replay, never a "consider" or a "might".

Read [`../shared/loom-contract.md`](../shared/loom-contract.md), then the
ledger: the brief's awkward cases, the slice's planned Attack line, and what
earlier probes already covered. Two depths:

- **quick** - after one slice, scoped to that slice's code. Its planned
  attacks plus whatever the diff suggests. Minutes, not an audit.
- **deep** - once, after the last slice, over the whole branch. Everything
  below, plus the combination states and the shuffled suite run.

## How to attack

**Data attacks (executed).** Write probe specs - throwaway Vitest tests named
`*.probe.spec.ts`, co-located - that mount the real components with the data
the demo never uses: zero items, one item, hundreds, a 400-character
unbroken label, missing optional fields, null where the type says maybe,
duplicate keys, non-ASCII and long-locale text. Run them. The assertion is
"renders something usable, no crash, no silent blank" - concretely: the empty
state appears, the label truncates rather than blowing the layout class off,
the missing field shows its placeholder.

**State attacks (executed).** Drive the states a user reaches sideways:
error from the data source, the double-submit, the action fired while loading,
Esc and click-outside on transient UI, the back-navigation. Assert on the
channel each behavior really uses (an emitted event, a request count, a DOM
change), not on "nothing happened".

**Static sweeps (cheap, always).** Over the branch diff:
- user-facing string literals that bypass `t()` (templates and scripts)
- hex colors and arbitrary values where a palette token exists
- `console.log`, commented-out blocks, `.skip`/`.only` left in specs
- `data-testid` values built from array indexes
- an `en.json` key added but never referenced, or referenced but never added

**Test attacks (targeted, deep only unless suspicious).** The born-red ledger
evidence covers most specs. Attack the exceptions: any test whose ledger entry
lacks a red record, and any negative assertion (`toEqual([])`,
`not.toHaveBeenCalled()`) with no positive sibling on the same channel. For
each, one mutation: break the exact line it claims to cover, run it, expect
red, restore. A test that stays green through its own mutation is a finding.
Restore from a copy, verify `git status` afterward - a stray mutation left in
production code is the worst thing this skill can ship.

**Deep only:** state combinations (two flags that can both be on are four
cases - assert which wins), plus one shuffled full run to catch
order-dependent specs:

```bash
cd src/ui-app && npx vitest run --project=unit --sequence.shuffle
```

## What comes back

Findings, numbered F1..Fn into the ledger's Probe section, each:

- **Reproduction** - the input or sequence, what was observed, what was
  expected. For an executed attack, the probe spec that shows it.
- **Severity** - `must-fix` (broken behavior, a crash, an i18n or token
  violation, a test that cannot fail) or `polish` (worth a line, not a fix
  turn). No middle band; a middle band is where nitpicks breed.
- **Keep or delete** - a probe spec that found a real bug is worth keeping:
  flag it "promote", and the fix turn adopts it as the regression test. Every
  other probe spec is deleted before you return; `git status` must show no
  `*.probe.spec.ts` left.

You fix nothing. Fixes are a loom-slice fix turn, so the finding and the fix
never share an author - that separation is the point of having a skeptic. An
empty findings list is a good result: say what you attacked and that it held,
so the ledger shows the pass ran. Never pad severity to look useful.
