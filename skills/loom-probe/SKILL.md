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

- **quick** (`loom-probe-quick`) - after one slice, scoped to that slice's
  code. Its planned attacks plus whatever the diff suggests. Minutes, not an
  audit.
- **deep** (`loom-probe-deep`) - once, after the last slice, over the whole
  branch. Everything below, plus the combination states and the shuffled suite
  run.

The two depths have separate agent types because they are different jobs: quick
runs a list the plan already wrote, once per slice, and deep is an open-ended
read of the whole branch, once per run. Your seed says which you are; run that
one and not the other.

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

**Spec-copy sweep (cheap, always).** No other stage holds test code to a
duplication bar - `loom-shape` reads specs as evidence and refuses to review
them, and tidy only fixes what you name here. So the specs are yours, and
skipping this is how a branch ships four copies of one 70-line
`IntersectionObserver` stub. Run it over the whole component's spec set,
never the diff alone - the copy the branch added is only a finding next to the
ones already sitting there:

```bash
cd src/ui-app && python3 ~/.claude/skills/loom-probe/scripts/spec-copies.py
```

It reports declarations sharing a name and a body across spec files. Specs share
no scope, so that is a copy, not a coincidence. Read each hit before reporting
it, then rank by what it costs to change:

- **A copy the branch itself added, or three or more copies of anything** -
  must-fix. Name the sites and where the one copy belongs: `app/mocks/` for a
  stub of a browser API, a `*.harness.ts` beside the specs otherwise.
- **Two copies that have to agree to be right** - the fixture a component spec
  and its page spec both assert against - must-fix, and the fix is naming the
  value once.
- **Two copies otherwise, or a four-line fixture that matched by accident** -
  polish, or nothing at all.

The fix is loom-tidy's, not a slice fix turn: it is the same extraction tidy
already does for production code.

**Bff attacks (when the branch has a bff slice).** Same executed discipline,
through the BFF's own harness (xUnit probe tests, throwaway unless promoted):
script the upstream to answer with each failure shape - non-2xx, `IsError`
inside a 200, a missing `Value`, the empty collection, a renamed field (wire
drift) - and assert the status map holds and no upstream `Message` leaks into
the response or a log line. Try the cross-tenant move: a browser-supplied id
outside the session's granted set must 403, not silently rewrite. Static
sweep on the C# diff: api-integrator's invariant checklist is the list -
`no-store` on every branch, the `switch` falling through to 502, no `var`,
nothing bound beyond what the browser reads, `openapi.yaml` updated. A
checklist line the diff violates is a must-fix finding citing that line.

**Test attacks (targeted, deep only unless suspicious).** This is about whether
a test can fail, and the sweep above is about what it costs to change - run
both. The born-red ledger evidence covers most specs. Attack the exceptions:
any test whose ledger entry lacks a red record, and any negative assertion
(`toEqual([])`, `not.toHaveBeenCalled()`) with no positive sibling on the same
channel. For each, one mutation: break the exact line it claims to cover, run
it, expect red, restore. A test that stays green through its own mutation is a
finding.
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

- **Severity** - `must-fix` (broken behavior, a crash, an i18n or token
  violation, a test that cannot fail, a spec helper copied into a third file)
  or `polish` (worth a line, not a fix turn). No middle band; a middle band is
  where nitpicks breed.
- **Reproduction, for must-fix** - the input or sequence, what was observed,
  what was expected. For an executed attack, the probe spec that shows it.
- **One line, for polish** - the `path:line` and what is wrong. No probe spec
  and no execution: an empty `<tr>`, a duplicated helper or a missing plural
  is stated, not reproduced. Spend the executed attacks on must-fix, and never
  skimp on the re-check - it attacks the fix code, which is the least attacked
  code in the run.
- **Keep or delete** - a probe spec that found a real bug is worth keeping:
  flag it "promote", and the fix turn adopts it as the regression test. Every
  other probe spec is deleted before you return; `git status` must show no
  `*.probe.spec.ts` left.

You fix nothing. Fixes are a loom-slice fix turn, so the finding and the fix
never share an author - that separation is the point of having a skeptic. An
empty findings list is a good result: say what you attacked and that it held,
so the ledger shows the pass ran. Never pad severity to look useful.
