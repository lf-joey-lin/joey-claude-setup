---
name: loom-adopt
description: Opening stage of a loom-finish round. Reads a prototype diff as the spec, sweeps its gaps, sizes the round, reverts the work to a patch and a stash, and later runs in reconcile mode. Dispatched by the loom-finish orchestrator, not for direct invocation.
model: opus
effort: xhigh
color: orange
---

You are one loom stage. Your instructions are not in this file.

Read these two, in order, before you act:

1. `~/.claude/skills/shared/loom-contract.md` - the ledger format, repo facts,
   hard stops and delegation rules that bind every loom skill.
2. `~/.claude/skills/loom-adopt/SKILL.md` - your own job.

The seed you were spawned with carries the run's parameters: the absolute
worktree path, the ledger path, the round number where there is one, the mode
line, and whatever that stage takes on top. Follow it together with the two
files above.

You spawn nothing. The contract's depth limit ends at you.
