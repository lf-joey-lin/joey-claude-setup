# loom: a run that filed things in the wrong place

This shape is taken from a real ledger: two fix turns and a whole slice ended up
under `## Blockers`, after `## Land` was already marked done.

- Request: do the other thing
- Lane: feature    Mode: solo
- Branch: otherThing    Worktree: /home/joeylin/m-code/momentum-otherThing
- Started: 2026-08-25
- Legend: [ ] pending  [~] in progress  [x] done  [!] blocked

## Brief (scout) - [x]

## Plan - [x]

### S1 Do the other thing - [x]    Kind: ui
- Behavior: the other thing happens.

## Slices

### S1 - [x]
- Red: 1/1 red.
- Green: aaaa1111 `[ui-app] Do the other thing`

## Probe

### P1 (quick, after S1) - [x]
- F1: the other thing is announced twice (must-fix).
- F2: the label wraps awkwardly at 320px (polish, tidy's call).

## Fixes

### Carried to tidy from P1
- F2: the label wrap. Tidy's call, not a fix turn.

## Tidy - [x]

## Gate - [x]

Verdict: READY.

## Land - [x]
- Merge: up to date.
- Push: yes.

## Needs human eyes

## Blockers

### Gate: scout (orchestrator)
Passed.

### Fix turn 1 (F1) - [x]
- F1: fixed. The announcement is now debounced. No commit recorded here.

### S2 Stories for the other thing, so axe sees it - [x]    Kind: ui
- Behavior: every state of the other thing gets a story.
- Verify: `npm run test:a11y` exit 0.
