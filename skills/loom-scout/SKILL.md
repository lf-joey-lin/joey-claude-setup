---
name: loom-scout
description: First stage of the loom pipeline - set up the workspace, recon the request against the app's precedent, size it into a lane (patch or feature), and write the brief that opens the flight ledger. Invoke via /loom normally; directly when the user asks to "scout", "size this", or "open a loom run" for a ui-app change.
---

# loom-scout: setup, recon, brief

You open a loom run. By the end there is a fresh branch in a usable worktree,
a ledger with a brief in it, and a lane decision the rest of the pipeline
routes on. You write no product code.

Read [`../shared/loom-contract.md`](../shared/loom-contract.md) first - the
repo facts, ledger format, and attendance contract there are binding and not
repeated here.

## Step 1 - workspace

Derive `<slug>` (kebab-case) and the branch name (camelCase, per the contract)
from the request. Then:

1. **Resume check before touching git.** If `src/ui-app/logs/loom/<slug>.md`
   exists in either the default worktree or `<root>/momentum-<slug>`, this is
   a resume: report the ledger path and stop - the orchestrator continues from
   it. Do not create a second workspace.
2. `git -C "<root>/momentum" fetch origin`.
3. **Attended, default worktree clean and on main**: branch in place with
   `git checkout -b <branch> --no-track origin/main`.
   **Otherwise** (dirty, on a feature branch, or any solo/background run):
   `git -C "<root>/momentum" worktree add --no-track -b <branch>
   "<root>/momentum-<slug>" origin/main`. Solo runs always take a worktree so
   parallel runs never collide on the default checkout.
4. Publish the empty branch: `git push -u origin HEAD`. It carries no commits
   and triggers no CI; it just sets the upstream so the editor shows outgoing
   work. A failed push is not a failed setup - note it and continue.
5. If a name is already taken, stop and report; never clobber.

## Step 2 - recon

Read-only, and read for behavior. The question is "what does this app already
do for this kind of thing", because precedent answers most open questions
before anyone is asked.

- The two or three nearest screens under `src/ui-app/app/pages/` and the
  components they compose. Note what they settle: list shape, empty state
  wording, confirmation style, where actions sit.
- `src/ui-app/CLAUDE.md` for the house rules that apply.
- The data source, if the feature is data-driven: which BFF endpoint or
  composable feeds it, and the real shape of the data (fields, volume,
  nullability). Read the types, not a guess.
- The awkward cases the data forces: zero, one, very many, long labels,
  missing values. These become probe attacks later, so name them concretely.

Do not research the industry and do not read Nuxt UI docs here - the plan and
slice stages ground component choices. Scout grounds the problem.

## Step 3 - lane

Route on what the change actually is, not on how it was phrased:

- **patch** - the change fits an existing pattern, touches roughly one
  component or page, adds no new route and no new shared state. It gets no
  plan; the brief itself defines the single slice (behavior plus checks).
- **feature** - a new screen, flow, or anything with more than one
  independently verifiable behavior. It gets a `loom-plan` pass.
- **too big** - more than one feature in the request. Stop and propose the
  split, one loom run each. Never absorb two features into one run.

When in doubt between patch and feature, take feature: a plan for a small
thing costs one short section, a missing plan for a big thing costs rework.

## Step 4 - the brief

Create the ledger from the contract's template and fill the Brief section:

- **Intent** - one or two sentences, who uses it and for what.
- **Data shape and awkward cases** - from recon, concretely.
- **Precedent** - each path and the one thing it settles.
- **Lane**, with the one-line reason.
- **For a patch**: the slice inline - the observable behavior and its checks,
  each check phrased as an assertion with the channel a caller would look at.
- **Decisions** - every question the request left open, with the answer you
  took and where it came from (precedent, house convention, most idiomatic),
  marked `(defaulted)`. Anything that genuinely changes the shape of the work
  and has no defensible default is listed as an open question instead.

Mark the Brief `[x]` and return a short summary: lane, branch, worktree,
ledger path, the decisions taken, and any open questions. In attended mode the
orchestrator's first ask moment presents exactly that summary; in solo mode
there must be no open questions left - take the default and log it, or, if no
reasonable default exists, mark the run `[!]` blocked with the reason.
