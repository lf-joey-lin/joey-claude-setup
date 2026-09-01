# loom: a plain feature run

- Request: make the widget do the thing
- Lane: feature    Mode: solo
- Branch: widgetThing    Worktree: /home/joeylin/m-code/momentum-widgetThing
- Started: 2026-08-20
- Legend: [ ] pending  [~] in progress  [x] done  [!] blocked

## Brief (scout) - [x]

### Intent
The widget does not do the thing.

### Precedent
- `app/pages/widget.vue` - the page to change.

## Plan - [x]

### S1 The widget does the thing - [x]    Kind: ui
- Behavior: clicking the widget does the thing.
- Checks: C1 the thing happens (channel: the emitted event).

### S2 The thing is undoable - [ ]    Kind: ui
- Behavior: the thing can be taken back.

## Slices

### S1 - [x]
- Red: `widget.spec.ts` 2/2 red before the code.
- Green: a1b2c3d4 `[ui-app] Make the widget do the thing`
- Verify: `npx nuxt typecheck` exit 0 | slice specs 2/2.
- Claims:
  - C1 the thing happens - evidence: the spec green - falsifier: no event emitted.

### S2 - [~]
- Red: `widget.spec.ts` 1/1 red.

## Probe

### P1 (quick, after S1) - [x]

Scope: S1 only.

- F1: the thing fires twice on a double click (must-fix). Red in
  `widget.probe.spec.ts`. Observed: two events. Expected: one.
- F2: the widget has no focus ring (polish, tidy's call). One missing class.

Attacked and held:
- A widget with no handler: nothing happens, no error.

## Fixes

- F1: fixed in beef1234 (S1 owns it).

## Tidy - [x]

### Maintainability pass
Nothing worth changing.

## Gate - [x]

Scope: 3 files, all under `src/ui-app`.

| Check | Command | Exit |
| --- | --- | --- |
| lint | `npm run lint` | 0 |
| build | `npm run build` | 0 |

Verdict: READY.

- Evidence: both exit codes captured from `$?`.

## Land - [x]
- Merge: up to date. Nothing merged.
- Push: yes. `git push -u origin HEAD` exit 0.
- Report: `logs/loom/widgetThing-report.md`

## Needs human eyes
- Click the widget and check the thing happens once.

## Blockers
