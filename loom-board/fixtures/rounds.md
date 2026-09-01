# loom: a loom-finish rework

- Request: rebuild the widget properly
- Lane: feature    Mode: solo
- Branch: widgetThing    Worktree: /home/joeylin/m-code/momentum-widgetThing
- Started: 2026-08-22
- Legend: [ ] pending  [~] in progress  [x] done  [!] blocked

## Brief (scout) - [x]

### Intent
The first run took a minimal-change approach. Reverse it.

## Plan - [x]

### S1 Split the widget - [x]    Kind: ui
- Behavior: two components instead of one.

## Slices

### S1 - [x]
- Red: three specs red against inert stubs.
- Green: `9f8e7d6c` `[ui-app] Split the widget`
- Verify: `npm run lint` exit 0.

## Probe

### P1 (quick, after S1) - [x]
- F1: the split loses the aria-label (must-fix). Red in `widget.probe.spec.ts`.

## Fixes

- F1: fixed in cafe0001.

## Tidy - [x]
## Gate - [x]

Verdict: READY.

## Land - [x]
- Merge: up to date.
- Push: local only. Solo mode never pushes.

## Needs human eyes
## Blockers

## Round 1 (loom-finish) - [~]

### Adopt - [x]
- Source: uncommitted    Patch: `logs/loom/widgetThing/r1.patch`    Stash: refs/stash@{0}
- Behavior: the widget remembers its last state.

#### Prototype gaps
- No test for the remembered state - owner: slice R1.S1.

### Slices

#### R1.S1 - [x]    Kind: ui
- Red: `widget.spec.ts` 1/1 red.
- Green: `1234abcd` `[ui-app] Remember the widget state`
- Verify: `npx nuxt typecheck` exit 0.

#### R1.S2 - [ ]    Kind: bff
- Behavior: the state persists across a reload.

### Probe

#### R1.P1 (quick, after R1.S1) - [x]
- F2: the remembered state survives a logout (must-fix). Observed: it persists.

### Fixes

### Reconcile - [ ]
### Tidy - [ ]
### Gate - [ ]
### Land - [ ]
