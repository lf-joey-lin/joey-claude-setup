---
name: gnhf
description: Run the nightly unattended maintenance pass over the momentum repo (gnhf), so the morning starts with a short digest and a handful of small, already-green branches to merge or discard over coffee. A pure orchestrator: it owns a dated run folder, a durable ledger of what was already shipped and already rejected, and one subagent per worker (the first is console-noise); workers investigate, each accepted finding gets its own worktree and branch, every branch must pass prepare-to-ship before it is handed over, and anything too big or too uncertain is discarded with a written reason instead of landing. Never opens a PR, never creates a work item, never touches the default worktree. Invoke when the user types /gnhf, or asks to "run the nightly", "do the nightly maintenance pass", "run gnhf", "rebuild last night's digest", or wants a single gnhf worker run by hand.
model: sonnet
---

# gnhf: the nightly maintenance run

Spend the night finding small, real problems in momentum and fixing them, so the
morning is a short read and a few merge-or-discard decisions. The deliverable is
one digest and a handful of pushed branches, each one small, each one already
green.

You (the invoked agent) are the **orchestrator**. You do none of the work
yourself: workers investigate in their own subagents, fixers apply diffs in their
own subagents and worktrees, and you own the run folder, the ledger, the caps,
and the digest. Same discipline as `../joey-bot/SKILL.md`: if you catch yourself
reading source or writing a fix in your own context, stop and delegate.

## What the morning has to look like

Three promises, and they outrank every other instinct in this file:

1. **Nothing red is handed over.** A branch reaches the digest only after
   `prepare-to-ship` returns a green verdict on it. A red branch costs more to
   triage than no branch at all, so it gets discarded, not reported as work.
2. **Nothing big is handed over.** Hard cap of 150 changed lines per branch. Over
   the cap, the finding becomes a written note in the digest, not a diff.
3. **Nothing that needs a decision is handed over.** A fix that turns on a product
   or design question is a note, not a branch. The night makes changes Joey would
   wave through, not changes he has to think about.

A night that explores eight findings and hands over two is a good night. Discard
is the expected outcome, not a failure.

## Invocation

```
/gnhf                              # the full nightly: every enabled worker
/gnhf --only console-noise         # one worker, useful by hand in daylight
/gnhf --dry-run                    # investigate and report, create no branches
/gnhf --digest                     # rebuild today's digest from the run folder
/gnhf --reject <fingerprint> "<reason>"   # record a rejection by hand
```

- No argument is required. The default is the full run.
- `--only <worker>` runs one worker end to end, caps and gates intact. This is the
  debugging path and the way to try a new worker before enabling it.
- `--dry-run` stops after triage. No worktrees, no branches, no ledger writes
  beyond suppressed-duplicate counts. The digest lists what it would have done.
- Say the resolved mode in your first line of output, before any tool call:
  `Mode: <full|only <worker>|dry-run|digest>, run folder <path>`.

There is **no human in the loop**, ever, in a full run. Every fork this file has
no default for is decided most-recommended, recorded in the digest's skill-gaps
section, and never asked about. Under `--only` in the main session you may still
present the result and stop; you may not ask mid-run.

## Layout on disk

Run state is dated. The ledger is not, because it only works if it outlives the
night.

```
~/m-code/gnhf/
  ledger/                          durable, never reaped
    rejected.jsonl                 explored and dropped, with reason + fingerprint
    shipped.jsonl                  handed over, and what Joey did with it
    baselines/                     per-worker baselines and rotation cursors
  stack/                           the fixture (see below), never reaped
    momentum-gnhf/                 long-lived worktree, detached on origin/main
    chrome-profile/                signed-in Chrome profile for live sweeps
    .lock                          held while a worker owns the live stack
  logs/                            cron output, one file per night
  2026-08-19/                      local date at run start (-2 for a second run)
    run.md                         the state file, authoritative
    digest.md                      the morning report
    digest-url.txt                 published artifact URL, if one was published
    workers/console-noise.md       per-worker findings and evidence
    logs/console-noise.log         raw sweep output, real exit codes
    work/<worker>-<slug>/          one worktree per accepted finding
```

Nothing about this lives in the repo. Nightly state has to survive the worktrees
it describes being deleted, and must not sit in a tree that switches branches
under it.

## The fixture stack

Investigation needs a checkout of `main` with `node_modules` installed and, for
live sweeps, a signed-in browser. Rebuilding that every night is waste, so it is
a fixture, not run state.

- **`stack/momentum-gnhf`** is a long-lived worktree, detached at `origin/main`,
  with its own `src/ui-app/node_modules` (728M) that persists between nights.
  Create once, refresh every night:

  ```bash
  git -C ~/m-code/momentum worktree add --detach ~/m-code/gnhf/stack/momentum-gnhf origin/main   # once
  git -C ~/m-code/gnhf/stack/momentum-gnhf fetch origin
  git -C ~/m-code/gnhf/stack/momentum-gnhf checkout --detach origin/main
  git -C ~/m-code/gnhf/stack/momentum-gnhf clean -fd    # safe: nothing is ever authored here
  ```

  It is **read-only for workers**. No worker edits a tracked file in it. Fixes
  happen in the finding's own worktree.
- **`stack/chrome-profile`** is a persistent Chrome user-data dir that Joey signs
  into by hand once. Live sweeps reuse its `lf_session` cookie, because sso-auth
  federates to WebSTS and an unattended run cannot complete a sign-in. When the
  session is dead, the live tier is unavailable: record it, degrade, and put
  "re-auth the gnhf Chrome profile" at the top of the digest's blockers.
- **`stack/.lock`** serializes the live stack. `local-server` binds fixed ports
  (3000 for the proxy, 17080 for sso-auth), so exactly one worker may run it at a
  time. Take the lock with `mkdir` (atomic), release it in every exit path.
- **Never kill a stack you did not start.** If ports 3000 or 17080 are already
  in use at preflight, that is Joey's own `local-server` session on his own
  worktree. Leave it alone, mark the live tier unavailable with that reason, and
  run the tiers that do not need it.

New worktrees for findings copy `node_modules` from the fixture rather than
running `npm ci`:

```bash
cp -r ~/m-code/gnhf/stack/momentum-gnhf/src/ui-app/node_modules <new-worktree>/src/ui-app/
```

Seconds instead of minutes. Use `cp -r`, never `cp -al`: a build writing into
`node_modules` would corrupt the fixture through the hardlinks.

## Preflight

Run these before building any work list, and stop the run on a hard failure:

1. **Resolve the run folder.** `date +%F` gives the folder name; if it exists and
   holds a completed `run.md`, use `-2`, `-3`. If it exists and holds an
   unfinished `run.md`, this is a resume: read it and continue from the first
   incomplete item.
2. **Read the default worktree, read only.** `git -C ~/m-code/momentum fetch
   origin`, then `status --porcelain` and `branch --show-current` for the record.
   You never check out, stash, or reset there, and never write to it. It is
   routinely dirty on a feature branch and that is Joey's review state.
3. **Refresh the fixture** per the commands above. Create it if missing.
4. **Probe the tiers** each enabled worker declares it needs, and record what is
   actually available with the reason (see the worker file for what the tiers
   mean). An unavailable tier is a recorded degradation, never a silent skip.
5. **Check disk.** Need roughly 1G free per expected finding worktree. Under 20G
   free, cut the finding cap and say so in the digest.
6. **Load the ledger.** Read `rejected.jsonl` and `shipped.jsonl` in full if
   small, otherwise the last 200 lines of each, and hold the fingerprints for
   dedupe.
7. **Reap verdicts** from the previous nights (see "Learning from what Joey did").
8. **Set the deadline.** Record a wall-clock stop time (default: 5 hours from
   start). Past it, spawn no new work, finish what is running, and write the
   digest. An unfinished night with a digest beats a finished night with none.

## The run loop

For each enabled worker, in registry order:

1. Mark it in progress in `run.md`.
2. **Investigate.** Spawn one subagent (model per the registry) seeded with:
   - the absolute path of the worker file, told to read it and follow it;
   - the fixture worktree path, and that it is read-only;
   - the run folder path, and where to write findings and raw logs;
   - the available tiers and the unavailable ones with reasons;
   - the ledger excerpt: every fingerprint already rejected or shipped, plus the
     last 100 ledger lines verbatim for judging near-duplicates;
   - the unattended line:

     > AUTONOMOUS MODE (gnhf): no human is available. Do not stop for approval or
     > ask questions. Decide as Joey, a senior engineer, would, take the
     > most-recommended option at every fork, and record alternatives you did not
     > take. Report real command output and real exit codes. Surface a genuine
     > blocker in your summary instead of guessing past it.

   It returns a ranked finding list, each with a fingerprint, evidence, a
   suspected file, and a proposed fix. It writes no code.
3. **Dedupe.** Drop findings whose fingerprint is in `rejected.jsonl` (count them
   as suppressed, do not re-litigate) or in `shipped.jsonl` with a branch that is
   still unmerged. Log the suppressed count for the digest.
4. **Fix, one subagent and one worktree per surviving finding**, up to the
   worker's finding cap, highest ranked first:
   - Create the worktree and branch off fresh `origin/main`:

     ```bash
     git -C ~/m-code/momentum worktree add --no-track -b gnhf/<slug> \
       ~/m-code/gnhf/<date>/work/<worker>-<slug> origin/main
     ```

     Do not call `new-work`: it publishes at setup and owns a different naming
     convention. Copy `node_modules` from the fixture after creating.
   - Spawn the fixer (model per the registry) seeded with the finding verbatim,
     the worktree path, the worker file's fix rules, the 150-line cap, and the
     unattended line. Smallest change that resolves the finding and nothing else.
   - Gate on the worker's own re-verification: the fixer must prove the finding is
     gone by the same means that found it, with real output. A fix with no
     re-verification is discarded, not shipped.
   - Spawn `prepare-to-ship` (sonnet) in that worktree. On NOT READY, make one
     targeted remediation pass, then re-run it once. Still red: discard the
     finding, delete the branch and worktree, and write the real failing output to
     the ledger reason.
   - On green: commit (one commit, imperative subject, writing rules applied),
     `git push -u origin HEAD`, append to `shipped.jsonl`, and record the compare
     URL for the digest.
5. Record the outcome of every finding in `run.md` and the ledger, shipped and
   discarded alike.

Workers run in parallel up to 3 at a time, except that a worker holding
`stack/.lock` runs alone against the live stack. Findings within a worker are
fixed one at a time, so a single worker never has two fixers competing for the
same review attention.

## Caps and budgets

| Cap | Default | Why |
|-----|---------|-----|
| changed lines per branch | 150 | anything larger is not a coffee review |
| findings shipped per worker per night | 2 | keeps the digest short |
| branches handed over per night | 4 | the real limit is Joey's morning |
| worktrees alive at once | 4 | disk and node_modules copies |
| wall clock | 5 hours | leaves the machine free before the day starts |
| remediation passes per finding | 1 | past that it is not a small fix |

Every cap that actually bit gets a line in the digest. A silently truncated night
reads as "there was nothing else", which is a lie.

## Discarding well

A discard is a real output and needs a real reason. Discard when:

- the finding cannot be reproduced by the means that found it;
- the fix needs a product, design, or API decision;
- the diff exceeds the cap;
- the cause is third-party code the repo does not own;
- `prepare-to-ship` stays red after the one remediation pass;
- the fix would change behavior rather than remove noise.

Append the reason to `rejected.jsonl`, delete the branch and worktree, and put a
one-line note in the digest only when the finding is worth Joey knowing about.
Routine discards stay in the ledger and out of the digest.

## The ledger

Two append-only JSONL files. One line per finding, ever.

```json
{"fp":"console-noise:vue-warn:missing-required-prop:UBadge@app/pages/tasks.vue","worker":"console-noise","date":"2026-08-19","verdict":"shipped","branch":"gnhf/badgeLabelProp","files":["app/pages/tasks.vue"],"diffstat":"1 file, +3 -1","reason":"","evidence":"logs/console-noise.log:214"}
```

Fields: `fp`, `worker`, `date`, `verdict` (`shipped` | `rejected` | `deferred` |
`merged` | `discarded`), `branch`, `files`, `diffstat`, `reason`, `evidence`.

**The fingerprint is the whole mechanism.** It must be stable across nights and
must not contain anything that changes on its own: strip line numbers, hashes,
generated ids, timestamps, and counts. Shape it
`<worker>:<class>:<normalized-signature>:<primary-file>`. When a worker cannot
produce a stable fingerprint for a finding, it defers the finding rather than
shipping something that will be rediscovered every night.

## Learning from what Joey did

The branch state in the morning already carries the verdict, so read it instead of
asking. At preflight, for every `shipped` line whose branch is not yet resolved:

- **merged into `origin/main`** (`git branch -r --merged origin/main`): append
  `merged`. The approach was right; do more of it.
- **remote branch gone, never merged**: append `discarded` with reason
  `branch deleted without merge`, and treat the fingerprint as rejected from then
  on. This is the zero-friction feedback loop: Joey deleting a branch is the
  rejection.
- **still open**: leave it, and list it in the digest's pending section with its
  age. Anything older than 7 days gets a nudge line.

`/gnhf --reject <fp> "<reason>"` records a reason by hand when the reason matters
more than the fact.

## The digest

`digest.md` in the run folder, ranked by what deserves the first sip. Publish it
as an Artifact and save the URL to `digest-url.txt`, so it can be read on a phone.
If a push notification tool is available, send one line with the count of branches
waiting. Writing rules apply: this is prose Joey reads, so keep it compact and cut
anything the diff already says.

```markdown
# gnhf 2026-08-19

4 branches waiting, 6 findings discarded, 1 blocker.

## Waiting for you
### gnhf/badgeLabelProp - 1 file, +3 -1
Kills: [Vue warn] Missing required prop "label" on UBadge, /tasks
Ship gate: green (build, unit+100%, a11y)
Verified: warning gone on a re-sweep of /tasks
Eyeball: the badge still reads the same on the tasks list
Compare: https://github.com/Laserfiche/momentum/compare/main...gnhf/badgeLabelProp

## Pending from earlier nights
- gnhf/hydrationSpacesIndex - 3 days old, still open

## Blockers
- Live tier unavailable: the gnhf Chrome profile's session expired. Sign in once at
  http://localhost:3000 with the profile at ~/m-code/gnhf/stack/chrome-profile.

## Notes, no diff
- <finding worth knowing about> - why there is no branch

## Caps that bit
- console-noise found 5 shippable findings, capped at 2

## Suppressed
- 11 findings already in the ledger (7 rejected, 4 on open branches)

## Skill gaps
- <a fork gnhf had no rule for> - took <X>; this file needs a rule
```

## The state file

`run.md` in the run folder, updated after every step, never in a batch at the end.
It is what a resumed run reads and what explains a night that died halfway.

```markdown
# gnhf run: 2026-08-19

- Mode: full | only <worker> | dry-run     Started: <local time>  Deadline: <time>
- Default worktree at read time: <branch>, <clean|dirty>  (never touched)
- Fixture: refreshed to <sha>
- Tiers available: <list>   Unavailable: <tier> (<reason>)
- Status legend: [ ] pending  [~] in progress  [x] done  [!] blocked

## Workers
### console-noise - [ ]
- Investigate: <result, findings file, raw log>
- Findings: <n> raw, <n> suppressed, <n> attempted, <n> shipped, <n> discarded
- Per finding: <fp> - <verdict> - <branch or reason> - <diffstat> - <ship verdict>

## Ledger writes
- <n> appended to shipped.jsonl, <n> to rejected.jsonl

## Decisions log
- <where>: chose <X> over <Y> because <reason>

## Skill gaps hit
- <the fork> - took <X>
```

## Retention

At the end of every run, reap. Delete dated folders older than 14 days, but never
the ledger, the fixture, or a folder holding an **unmerged, still-open** branch
that Joey has not looked at. Before deleting, remove the worktrees properly, then
prune:

```bash
git -C ~/m-code/momentum worktree remove --force <path>
git -C ~/m-code/momentum worktree prune
```

Deleting a folder without `worktree remove` leaves stale metadata behind, so the
prune is not optional. List anything the reaper chose to keep, and why, in the
digest.

## Worker registry

| Worker | File | Investigate model | Fix model | Tiers needed | Findings cap | Enabled |
|--------|------|-------------------|-----------|--------------|--------------|---------|
| console-noise | `workers/console-noise.md` | sonnet | sonnet | A, B, C | 2 | yes |
| ux-consistency | `workers/ux-consistency.md` | opus | sonnet | A, B, C | 2 | yes |

Tier letters are per worker, not shared. Each worker file defines its own A, B
and C, so read them there before probing at preflight.

Model choice follows joey-bot's rule: mechanical and tool-output-heavy stages run
cheap, and only work where senior judgment shows up pays for a higher tier. A
worker whose fixes turn out to need real judgment gets its fix model raised in
this table, not in an ad hoc decision at 3am.

## Adding a worker

A worker is one file in `workers/`, plus one row above. The file must define:

1. **Scope**, and explicitly what it hands to another skill instead of fixing.
2. **Evidence tiers**, cheapest first, each with the command that produces it and
   what it means when the tier is unavailable.
3. **Rotation**, so successive nights cover different ground, with the cursor kept
   in `ledger/baselines/`.
4. **A stable fingerprint recipe.**
5. **Fix rules**, including what makes a finding a note instead of a diff.
6. **Re-verification**: how the fixer proves the finding is gone.
7. **Discard rules** on top of the shared ones.

Nothing in a worker file may relax the three promises or the caps.

## Invariants

- The orchestrator delegates all work. It owns the run folder, the ledger, the
  caps, git bookkeeping, and the digest. No reading source, no writing fixes.
- The default worktree at `~/m-code/momentum` is read-only, always. No checkout,
  no stash, no reset, no writes.
- Never push to `main`. Push only `gnhf/*` branches, only after a green gate.
- Never open a PR and never create or edit a TFS work item. Handover is a pushed
  branch and a digest line; the decision is Joey's. When he keeps a branch, he
  runs `paperwork` on it himself - do not run it, and do not seed it.
- Localized strings: `en.json` only. Never touch `fr.json`, `es.json`,
  `en-XA.json`, or the XLIFF memory, never run `translate.ts --pseudo`, and never
  report `pr-i18n-parity` as a failure. A branch that changed an `en.json` gets a
  digest line reminding Joey the PR needs the `to-be-translated` label.
- Never add a dependency, and never bump one. Both are Joey's call.
- Gate on real exit codes and real command output, never on a subagent's prose
  claim of success.
- Release `stack/.lock` on every exit path, including a failed one.
- Ask the human nothing. A fork with no rule here gets the most-recommended option
  plus a digest skill-gap line.
- No em dash, emojis, arrows, or box-drawing characters in anything written.
