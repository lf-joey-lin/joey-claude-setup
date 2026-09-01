# loom board

Every momentum worktree and every loom run on one screen. Read-only: it runs
`git`, `herdr agent list` and reads the flight ledgers, and writes nothing.

```bash
m-board                      # the board
m-board --all                # expand finished and stalled runs too
m-board --run inboxScroll    # one run, every slice, every open finding
m-board --watch              # redraw every 5s until ctrl+c, and click a card
m-board --json               # the model, for another renderer
```

## Clicking a card

Under `--watch` the board turns on mouse reporting, so a left click on a slice
card opens a panel under the grid: the slice's name and kind, its timing, whether
it went red first, its commit, how many probe passes covered it, and the first
four findings still open on it. `--run <slug>` is still where the whole run goes.

Esc closes the panel, and so does a click on anything that is not a card. The
wheel scrolls the board, because reporting takes the wheel off the pane. It takes
the pane's own text selection too, so hold shift to select.

A panel stays open across a redraw, following the slice by its ledger path and
id. A slice that changes lane keeps its panel; one that disappears from the
ledger closes it.

`ctrl+alt+p` opens it in a popup, the same way `ctrl+alt+d` opens `m-dev`. The
popup runs `--watch --all`: `--watch` because the board prints and exits, so a
plain run would flash and close, and `--all` because the popup is where you go to
see everything. The bare `m-board` in a pane keeps the shorter default.

Not `ctrl+alt+m`: `ctrl+m` is carriage return, so that chord arrives as
`ctrl+alt+enter`. See the keys section of `herdr/README.md`.

Runs from anywhere. It finds the worktrees through `<root>/momentum`, where root
is `MOMENTUM_ROOT` or `~/m-code`, the same value `_m_root` uses in
`shell/momentum.sh`.

## What it reads

| Source | Gives |
| --- | --- |
| `git worktree list --porcelain` | the worktrees, their branches, prunable ones |
| `git status` / `rev-list` / `log` per worktree | dirty count, ahead and behind main, last commit |
| `herdr agent list` | idle, working or blocked per worktree, and the terminal title |
| `src/ui-app/logs/loom/*.md` | the runs: stages, slices, probe findings, gate verdict |

Each source degrades on its own. No herdr, no agent column. A worktree whose
directory is gone shows as prunable rather than disappearing.

## Lanes

A slice card's lane comes from evidence in the ledger, never from prose:

| Lane | Condition |
| --- | --- |
| blocked | a `[!]` on the slice or its probe. Only shows when occupied |
| planned | no Slices entry, or an entry with no red and no commit |
| building | started: a red record or a commit, but not finished |
| built | `[x]` with a commit, nothing has probed it yet |
| probed | probed, with a must-fix finding still open. Card carries the count |
| done | probed, and every must-fix finding for it resolved |

Polish findings never hold a slice back. They show in the run's trailer line and
in `--run`.

A run is `live` when an agent is working in its worktree, `waiting` when one is
there but idle or blocked, `finished` once Land is done, and `stalled` when it is
unfinished, unattended and a day untouched. Only live and waiting expand; the
rest collapse to the `inactive:` line unless you pass `--all`.

## The tolerance rule

`skills/shared/loom-contract.md` has the ledger template, but real ledgers drift
from it, so the parser requires none of it. What the two runs in
`momentum-inboxInfiniteScroll` already do that the template does not describe:

- no `- Timing:` line anywhere, though the contract says every stage stamps one
- the gate writes `Verdict: READY.` as prose after a markdown table
- commit hashes are bare in one ledger and backtick-wrapped in the other
- severity tags carry extra words: `(polish, tidy's call)`
- probe passes appear as `P2R (re-check, after fix turn 1)`, not just `P1 (quick,
  after S1)`
- two fix turns and the whole of slice S5 are filed under `## Blockers`, after
  `## Land` was already marked done

So: fixes and slice headings are collected document-wide, because a fix recorded
anywhere is still a fix. Anything that cannot be classified lands in the run's
`notes` and shows under the board as a `note:` line. **A stage is never reported
done because it failed to parse.** A board that quietly turns a stalled run green
is worse than no board.

## Tests

```bash
node --test loom-board/ledger.test.mjs
```

Parser only. The collectors and the renderer are IO shells and have none.

`fixtures/` holds one small ledger per drift case: `flat.md` a normal feature run,
`rounds.md` a `loom-finish` ledger where the stages nest under `## Round 1`, and
`misfiled.md` the slice-under-Blockers shape. The last suite parses whatever real
ledgers exist on the machine and asserts invariants only, so new drift gets caught
without copying a 2000-line corpus into this repo. It skips when there are none.

## Adding a renderer

`--json` is the seam. It emits the whole model, so an HTML page or a published
Artifact is a renderer over that and needs nothing from `ledger.mjs`.
