# gnhf worker: console-noise

Sweep the console output `ui-app` produces at runtime, and remove the noise the
repo itself owns. Warnings that everyone has learned to scroll past are where real
bugs hide, and each fix is usually a few lines, which makes this the ideal first
worker: it reliably finds something, and what it finds is reviewable in seconds.

Read this alongside `../SKILL.md`. The orchestrator's three promises and its caps
win wherever this file could be read as relaxing them.

## Scope

**In scope:** console and dev-server output caused by code in this repo.

- Vue warnings: missing or wrong-typed required props, missing or duplicate `key`
  in a `v-for`, extraneous non-emits listeners, attribute fallthrough onto a
  fragment root, injection not found, invalid watch source.
- Hydration mismatches: server and client markup disagreeing.
- Nuxt and Nitro warnings from our own code: deprecated composable or prop usage
  checked against the installed types, a route that resolves twice, a plugin that
  runs on the wrong side.
- Unhandled promise rejections raised by our own code paths.
- `console.log` / `console.debug` left behind in committed source.
- Requests failing for reasons the repo owns: a 404 on an asset we reference, a
  malformed URL we build, a fetch fired before its dependency exists.

**Out of scope, hand it on:**

- Anything originating inside `node_modules`. Note it, never patch it.
- Missing i18n key warnings. They belong to the future i18n worker; note them with
  their keys so that worker starts with a list.
- Backend errors and 500s. That is a bug for the board, not a nightly fix. Note it.
- Accessibility findings. The a11y suite owns them.
- Anything whose fix is a behavior, product, or design change.

## Never silence

The one way to fail at this worker is to make the message go away without fixing
what caused it. All of these are forbidden, and a fix that uses one is discarded:

- a `warnHandler`, log filter, or any global mute;
- an `eslint-disable`, `@ts-expect-error`, or `v-bind` spread added to hide a prop
  warning;
- a `try`/`catch` that swallows the rejection instead of handling it;
- deleting the call site rather than fixing the call;
- a `key` that is an index when the real fix is a stable id.

If the honest fix is bigger than the cap, the finding is a note. Noise removed by
muting is worse than the noise.

## Evidence tiers

Run the cheapest tiers always, the expensive one when it is available. Record which
tiers ran and what each contributed. A tier that could not run is a recorded
degradation with its reason, never a silent skip.

**Tier A - SSR and dev-server log.** No browser, no auth, no backends.

```bash
cd ~/m-code/gnhf/stack/momentum-gnhf/src/ui-app
npm run dev -- --port <free port> > <run>/logs/console-noise-ssr.log 2>&1 &
# wait for ready, then request each rotated route so it renders server side
curl -sS -o /dev/null "http://localhost:<port>/<route>"
```

Catches server-side Vue warnings and Nitro complaints. Its limit is real and worth
stating in the findings: with no session, protected routes redirect rather than
render, so tier A only sees what renders unauthenticated.

**Tier B - components in a real browser.** No auth, parallel safe, per-worktree
port. This is the workhorse.

```bash
cd <worktree>/src/ui-app
npm run test:a11y            # the storybook vitest project, real browser
npm run storybook -- -p <free port>   # for a per-story console capture with Chrome MCP
```

Every warning the storybook project prints is attributable to one story, which
means a precise fingerprint and a precise re-verification.

**Tier C - the live app.** Highest fidelity, needs the lock and a live session.

```bash
mkdir ~/m-code/gnhf/stack/.lock || exit   # atomic; if it exists another worker holds it
local-server --worktree ~/m-code/gnhf/stack/momentum-gnhf up      # backends, detached
local-server --worktree ~/m-code/gnhf/stack/momentum-gnhf ui &    # dev server
```

Then drive `http://localhost:3000` with the Chrome DevTools MCP using the
persistent profile at `~/m-code/gnhf/stack/chrome-profile`, and per route call
`list_console_messages` and `list_network_requests`. Invoke the
`chrome-devtools-mcp:chrome-devtools` skill rather than improvising the tool
sequence.

Tier C rules:

- If the profile's session is dead, the app redirects to sso-auth. Do not attempt a
  sign-in: WebSTS cannot be driven unattended. Record the blocker and drop to tiers
  A and B.
- Never kill a `local-server` that was already running. Occupied ports mean Joey's
  own session; skip tier C with that reason.
- `local-server ... down` and release the lock in every exit path, including
  failure.

## Rotation

There are far more routes and stories than one night should sweep, and always
starting at `index.vue` means the same ground forever. Keep a cursor:

`~/m-code/gnhf/ledger/baselines/console-noise-cursor.json`

```json
{"routes": {"list_sha": "<sha of the sorted route list>", "next": 12},
 "stories": {"next": 40}}
```

Each night: rebuild the route list from `app/pages/**/*.vue` (sorted, so it is
stable), sweep the next 8 routes and the next 40 stories from the cursor, wrap
around, and write the cursor back. When the route list's shape changes, keep the
cursor but note the drift; a brand new page jumps the queue and is swept the first
night it exists, because fresh noise is the most likely to be a real regression
someone just merged.

## Baseline, and why new noise ranks first

`~/m-code/gnhf/ledger/baselines/console-noise.json` holds every message ever seen:

```json
{"<fingerprint>": {"first": "2026-08-02", "last": "2026-08-19", "seen": 7, "tier": "B"}}
```

Rank findings by:

1. **New tonight** on ground that was swept before. Something merged recently
   caused it, the cause is fresh in someone's head, and it is the highest-value
   fix of the night.
2. Frequency, then how central the route or component is.
3. Long-standing noise on ground swept for the first time.

Update the baseline for every message observed, including ones not acted on. The
baseline is what makes "new" mean anything.

## Fingerprint

`console-noise:<class>:<normalized message>:<primary file>`

- `class` is one of `vue-warn`, `hydration`, `nuxt-warn`, `rejection`,
  `stray-log`, `request-fail`.
- Normalize the message: drop line and column numbers, hashes, generated ids,
  element indexes, timestamps, counts, and absolute paths. Keep the component or
  prop name, which is the part that identifies the problem.
- `primary file` is the repo-relative source file the message is attributable to.
  When it cannot be attributed to one file, the finding is **deferred**, not
  shipped: an unattributable fingerprint gets rediscovered every night and poisons
  the ledger.

Example: `console-noise:vue-warn:missing-required-prop:UBadge@app/pages/tasks.vue`

## Triage output

Write findings to `<run>/workers/console-noise.md`, ranked, and return the same
list. No code is written in this stage.

Per finding: fingerprint, class, the message verbatim, the tier and route or story
that produced it, how often, whether it is new since the baseline, the suspected
file and line, the proposed fix in one or two sentences, an estimated diff size,
and a verdict of `fix` or `note` with the reason. Anything you would rather explain
than patch is a `note`.

## Fix rules

For a finding the orchestrator accepts, in its own worktree:

- Smallest change that removes the cause. One finding per branch, no drive-by
  cleanups, no reformatting, no renames.
- No new dependency, and no version bump.
- User-facing strings go in `en.json` and nowhere else. Never touch `fr.json`,
  `es.json`, `en-XA.json`, or the XLIFF memory. Say in the handoff that the branch
  changed `en.json`, so the digest can remind Joey about the `to-be-translated`
  label.
- Check every prop, slot, and emit against the **installed** Nuxt UI and Nuxt
  types in the worktree's `node_modules`, not from memory. A prop warning fixed
  from memory is how the wrong prop name gets committed.
- Add a regression test when the noise is assertable, and prefer one: a component
  or story test that fails while the warning is present. The repo gates on 100%
  statement and branch coverage, so any new source line needs coverage anyway.
- If the honest fix crosses the 150-line cap, or turns into a second finding, stop
  and hand it back as a note with what you learned. Do not grow the branch.

## Re-verification

A fix is not done until the message is gone, proven by the same tier that found it,
with real output in the log:

- Tier B finding: re-run `npm run test:a11y` in the fix worktree, or reload the one
  story, and show the message absent from output that previously contained it.
- Tier A finding: restart the dev server in the fix worktree and re-request the
  route.
- Tier C finding: re-verify at tier B when the component can be reached there.
  Otherwise take the lock again, point `local-server` at the fix worktree, and
  re-walk the route. Release the lock afterwards.

Also confirm nothing new appeared. A fix that removes one warning and adds another
is discarded.

State plainly what could not be re-verified and why, per the shared rule: never
claim a fix works without having watched it work.

## Discard rules, on top of the shared ones

- The message could not be attributed to one repo file.
- It only reproduces at tier C and tier C cannot be re-run for verification.
- The cause is a missing backend rather than a code defect, which is what an
  unauthenticated or backend-less sweep produces by the dozen. These are artifacts
  of the sweep, not findings: do not ship them, and do not clutter the ledger with
  them either.
- Removing it needs a real i18n, a11y, or product decision.

## First-run note

The first night has no baseline, so everything looks new and nothing can be ranked
by novelty. Expect it to be the noisiest run: sweep the rotation, write the full
baseline, and hand over at most the finding cap, chosen by how central the
component is. Say in the findings file that this was a baseline-building run, so
the digest does not read as though the repo suddenly grew 40 warnings.
