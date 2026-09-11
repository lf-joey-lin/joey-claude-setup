---
name: loom-scout
description: First stage of the loom pipeline - set up the workspace, recon the request against the app's precedent, size it into a lane (patch or feature), and write the brief that opens the run ledger. Invoke via /loom normally; directly when the user asks to "scout", "size this", or "open a loom run" for a ui-app change.
---

# loom-scout: setup, recon, brief

You open a loom run. By the end there is a fresh branch in a usable worktree,
a ledger with a brief in it, and a lane decision the rest of the pipeline
routes on. You write no product code.

Read [`../shared/loom-contract.md`](../shared/loom-contract.md) first - the
repo facts, ledger format, and attendance contract there are binding and not
repeated here.

## Step 1 - workspace

Two modes. Default is a worktree of your own. `--in <dir>` adopts one the
human already made, which is how a queued work item runs in a worktree that is
already open and possibly already prototyped in. Steps 2 to 4 are identical
either way.

### Default - a new worktree

Derive `<slug>` (kebab-case) and the branch name (camelCase, per the contract)
from the request. Then:

1. **Resume check before touching git.** If `artifacts/loom/<slug>-ledger.md`
   exists in either the default worktree or `<root>/momentum-<slug>`, this is
   a resume: report the ledger path and stop - the orchestrator continues from
   it. Do not create a second workspace.
2. `git -C "<root>/momentum" fetch origin`.
3. **Always a new worktree**, whatever state the default one is in:
   `git -C "<root>/momentum" worktree add --no-track -b <branch>
   "<root>/momentum-<slug>" origin/main`. `<root>/momentum` is a read-only
   reference checkout that stays on main - never branch, commit, or edit
   there, even when it is clean. Every run gets its own worktree so parallel
   runs never collide.
4. Publish the empty branch: `git -C "<root>/momentum-<slug>" push -u origin
   HEAD`. It carries no commits and triggers no CI; it just sets the upstream
   so the editor shows outgoing work. A failed push is not a failed setup -
   note it and continue.
5. `npm ci` in `<root>/momentum-<slug>/src/ui-app`. A fresh worktree has no
   `node_modules`, and the postinstall runs `nuxt prepare`, which writes the
   `.nuxt/imports.d.ts` roster the plan greps. Skip this and the plan grounds
   against a downloaded tarball while slice 1 grounds against the real
   install. A failed install is noted and the run continues.
6. If a name is already taken, stop and report; never clobber.

### `--in <dir>` - adopt the worktree the human made

The human owns this workspace. They cut the branch, and may have prototyped in
it. **Create nothing, reset nothing, and never touch their uncommitted work.**

1. **Guards, before anything else.** `<dir>` must be a momentum worktree, must
   not be `<root>/momentum` (the read-only reference checkout), and must not
   be on `main`. Any of the three stops the run with the reason - none of them
   is worked around. These are the same guards `loom-spec` applies, and they
   are the only workspace guards this mode needs.
2. **`<slug>` is the branch name in kebab-case**, not derived from the
   request, and a ledger that already names one wins. Same rule `loom-spec`
   uses, and the reason is the contract's: one ledger per branch, however many
   requests land on it.
3. **Rounds, not resumes** (contract, "Rounds"). Read
   `<dir>/artifacts/loom/<slug>-ledger.md`:
   - no ledger: this is round 1.
   - highest round fully `[x]`: this request is round `<n>+1`. Report the
     ledger path and the round number; the orchestrator opens `## Round <n+1>`
     and every stage of this run nests under it. Do not resume a finished
     round and do not open a second ledger.
   - highest round incomplete: a normal resume. Report the ledger path and
     stop - the orchestrator continues from the first stage not `[x]`.
4. **No `worktree add`, no `-b`, no reset, no stash.** The branch is whatever
   the human left there. Do not fetch origin into `<dir>`; landing merges main
   at the end of the run, which is where that belongs.
5. `git -C "<dir>" push -u origin HEAD` only when the branch has no upstream
   yet. A failed push is noted, not fatal.
6. `npm ci` in `<dir>/src/ui-app` only when `node_modules` is missing. A
   worktree the human has already worked in usually has it, and reinstalling
   over a tree they are running costs minutes for nothing.
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
  nullability). Read the types, not a guess. **If the data path does not
  exist yet** - no BFF route serves what the feature shows - the run needs a
  bff slice (contract, "BFF slices"): note which upstream (ACS or BPM) likely
  owns the data and the closest existing BFF route as its model. Naming the
  exact upstream action is plan-time work; scout just establishes that the
  path is missing and roughly where it comes from.
- The awkward cases the data forces: zero, one, very many, long labels,
  missing values. These become probe attacks later, so name them concretely.

Do not research the industry and do not read Nuxt UI docs here - the plan and
slice stages ground component choices. Scout grounds the problem.

## Step 3 - lane

Route on what the change actually is, not on how it was phrased:

- **patch** - the change fits an existing pattern, touches roughly one
  component or page, adds no new route and no new shared state, and its data
  path already exists. It gets no plan; the brief itself defines the single
  slice (behavior plus checks). A change that needs new BFF surface is never
  a patch - the browser contract is a real design decision, so it takes the
  feature lane even when the UI half is trivial.
- **feature** - a new screen, flow, or anything with more than one
  independently verifiable behavior. It gets a `loom-plan` pass.
- **too big** - more than one feature in the request. Stop and propose the
  split, one loom run each. Never absorb two features into one run.

When in doubt between patch and feature, take feature: a plan for a small
thing costs one short section, a missing plan for a big thing costs rework.

## Step 4 - the brief

Create the ledger from the contract's template and fill the Brief section.
Under `--in` on a round after the first, the ledger already exists: open
`## Round <n>` and nest the Brief under it rather than starting a second file.
Fill the header's `Started:` with `date -Iseconds`, read now, not remembered.
Leave `Finished:`, `Wall:` and `Active:` as placeholders; land fills them.
Stamp your own `- Timing:` line on the Brief section like any other stage.

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
  Two entries are always present. **Shape**: `minimal diff` or `best
  structure`, with the reason, defaulted when the request is silent - a run
  that picks one silently can cost a second run to reverse it. **Stated
  values**: a concrete number or label in the request (a batch size, a count,
  a wording) is taken literally; departing from it is an open question, never
  a default.

Mark the Brief `[x]` and return a short summary: lane, branch, worktree,
ledger path, round number, the decisions taken, and any open questions. In attended mode the
orchestrator's first ask moment presents exactly that summary; in solo mode
there must be no open questions left - take the default and log it, or, if no
reasonable default exists, mark the run `[!]` blocked with the reason.
