# gnhf worker: ux-consistency

Sweep the app for places where the same thing is done two different ways, and
move the odd one out onto the pattern the app already settled on. The listing on
`process-automation/bp` runs edge to edge with no card around it; the listing on
`administration/users-groups` sits in a rounded bordered card. Both are tables of
tenant records with a toolbar and a paginator, so one of them is wrong, and a user
crossing between them pays for it every time.

Read this alongside `../SKILL.md`. The orchestrator's three promises and its caps
win wherever this file could be read as relaxing them.

This worker is the one most likely to talk itself into a redesign at 3am. The
guard against that is the authority ladder below: a divergence only becomes a
diff when something already decided which side is right. Everything else is a
note.

## Scope

**In scope:** two or more places in `ui-app` doing the same job differently, and
places that break a rule the app has already written down.

- Surface treatment: the same kind of content in a card here and flush to the
  content area there, different borders, radius, background role or page padding
  around comparable regions.
- Shared shell bypassed: a page hand-assembling something a common component
  already does (a listing built out of `DataTableToolbar` plus `DataTable` plus a
  paginator where `ResourceTableListing` exists).
- Action buttons: a hand-configured `UButton` where `AppButton` has an intent for
  it, a per-call-site `size`, two controls both claiming primary in one view, a
  destructive action drawn as a solid call to action.
- States: empty, loading, error, forbidden and absent-value treatments that differ
  between comparable views, or a view missing one its neighbors all have.
- Dialogs and confirmations: different shapes for the same weight of decision,
  confirm and cancel swapping sides, different verbs for the same commit.
- Feedback: toast on one page and an inline banner on the next for the same class
  of outcome, or the same event reported in two places at once.
- Copy and terminology: one concept with two names, button verbs that disagree
  (Save here, Update there), title case where the rest of the app is sentence
  case, counts phrased differently.
- Formats: dates, times, durations, numbers and sizes formatted differently
  between screens, relative here and absolute there, one screen ignoring the
  tenant time zone.
- Icons: two glyphs for one meaning, one glyph for two meanings, an icon-only
  control that carries a label on every other page.
- Navigation and placement: where a section's sub-nav lives, where the primary
  action sits, whether a page shows its own title or leans on the breadcrumb.
- Design tokens: a raw hex, an arbitrary pixel value, a numbered shade where a
  semantic role exists, spacing off the scale. `.storybook/docs/*.mdx` and
  `src/ui-app/CLAUDE.md` are the rules; `app/assets/css/theme.css` holds the
  values. Nothing in the toolchain enforces this, which is exactly why it drifts.

**Out of scope, hand it on:**

- Accessibility failures. The a11y suite owns them. Note the finding with the
  page and the control so that pass starts with a list.
- Missing or hardcoded i18n strings. Note them with the file and the string;
  they belong to the i18n worker.
- Console warnings and runtime errors. That is console-noise.
- Anything whose fix is a new feature, a new screen, or a change to what the app
  does rather than to how it presents what it already does.
- A divergence whose correct side is genuinely open. That is a design question,
  and design questions are notes.

## The authority ladder

A divergence is only shippable when something outside your own taste already
decided which side is right. Walk the ladder in order and stop at the first rung
that answers. Record which rung you used on every finding; a finding with no rung
is a note, always.

1. **A written rule.** `src/ui-app/CLAUDE.md`, `.storybook/docs/Overview.mdx`,
   `Color.mdx`, `Typography.mdx`, `Layout.mdx`, or a spec under
   `src/ui-app/logs/`. The rule names the right side outright. Strongest rung,
   and the only one that can settle a behavior divergence.
2. **The app's own dominant convention.** Count the call sites. It settles the
   question only when at least three places agree and at most one diverges. Two
   against one is not a convention, it is a coin toss with extra steps: note it.
   Count real comparable sites, not incidental string matches.
3. **Nothing.** Manta and the industry are evidence worth putting in a note, and
   they are never authority to change this app unattended. Same for your own
   judgment about which looks better.

Two things demote a finding no matter what the ladder says:

- **A comment or spec explaining the divergence makes it deliberate.** This repo
  writes down why a screen departs from its neighbors, often at length and right
  above the code. Read the comment before you call anything an outlier. When one
  explains the difference, it is not a finding: record it in the baseline as
  sanctioned so it stops coming back, and move on.
- **The outlier being the newer screen.** New code that departs from an old
  convention is as likely to be the design moving as it is to be a mistake.
  Check `git log` on the outlier. Newer than the convention it breaks, and with
  no rule against it, means note.

## Never harmonize like this

The way to fail here is to make two screens agree without either of them getting
better. All of these are forbidden, and a fix that uses one is discarded:

- changing both sides to a third pattern nobody asked for;
- changing the authority side to match the outlier;
- pasting the shared component's markup into the outlier instead of using the
  shared component, or the reverse, forking a shared component so one caller can
  keep its own look;
- an override class, a `:ui` object or a local style block added to paper over a
  difference the shared component would have removed;
- a wholesale rewrite of a page onto a shared shell. That is a real refactor with
  real behavior risk, and it is over the cap. Note it with what it would take;
- renaming a `data-testid`, or changing the DOM a test or an e2e spec keys on,
  to make a visual change land;
- touching `fr.json`, `es.json`, `en-XA.json` or the XLIFF memory. Copy fixes go
  in `en.json` and nowhere else;
- repointing a `--ui-*` role or a token value to fix one call site. That is a
  breaking design change and it is Joey's call.

Consistency bought by muddying both sides is worse than the inconsistency.

## Evidence tiers

Run the cheapest tier always, the others when they are available. Record which
tiers ran and what each contributed. A tier that could not run is a recorded
degradation with its reason, never a silent skip.

**Tier A - source census.** No build, no browser, no auth. Always available, and
it is where most findings actually come from.

```bash
cd ~/m-code/gnhf/stack/momentum-gnhf/src/ui-app
grep -rn "rounded-lg border border-default" app --include=*.vue     # card surfaces
grep -rln "<UButton" app --include=*.vue                            # vs AppButton
grep -rn "#[0-9a-fA-F]\{3,8\}\b" app --include=*.vue                # raw hex
grep -rn "\[[0-9]\+px\]" app --include=*.vue                        # arbitrary px
```

Build the census per family, not with a fixed script: find every site that does
the family's job, group them by how they do it, and count. The output is a table
of pattern versus call sites, and the outliers fall out of it. Read the comment
above every site you are about to call an outlier.

**Tier B - Storybook render.** A real browser, no auth, per-worktree port. This
is how you see a difference rather than infer it from class strings.

```bash
cd <worktree>/src/ui-app
npm run storybook -- -p <free port>
```

Drive it with the Chrome DevTools MCP through the
`chrome-devtools-mcp:chrome-devtools` skill rather than improvising the tool
sequence. Screenshot the two stories under comparison at the same width, save
both under `<run>/shots/`, and name them in the finding. Most pages have a story
already; when the family under sweep has none on either side, say so and rely on
tier A.

**Tier C - live app walk.** Highest fidelity, needs the lock and a live session.
Only tier that shows real data, real row counts and the full page composition.

```bash
mkdir ~/m-code/gnhf/stack/.lock || exit   # atomic; if it exists another worker holds it
local-server --worktree ~/m-code/gnhf/stack/momentum-gnhf up
local-server --worktree ~/m-code/gnhf/stack/momentum-gnhf ui &
```

Walk the rotated families' pages at `http://localhost:3000` with the persistent
profile, screenshot each, and compare. Tier C rules are the shared ones: never
kill a `local-server` you did not start, never attempt a sign-in when the profile's
session is dead, and release the lock on every exit path including a failed one.

## Rotation

Sweeping the whole app every night finds the same twelve things and never gets
past them. The unit of rotation is a **family**, and each night sweeps the next
three from the cursor at
`~/m-code/gnhf/ledger/baselines/ux-consistency-cursor.json`:

```json
{"families": ["listing","surface","page-header","states","actions","dialogs",
              "feedback","forms","copy","formats","icons","nav","tokens"],
 "next": 3}
```

Wrap around at the end. A page added or substantially changed since the last
sweep jumps the queue and is checked against every family the night it appears:
a fresh divergence is the one someone can still remember writing, and it is
cheapest to fix before anything copies it.

## Baseline, and why a new divergence ranks first

`~/m-code/gnhf/ledger/baselines/ux-consistency.json` is the census kept between
nights. It is what makes "new" mean anything, and what stops a sanctioned
difference being rediscovered forever.

```json
{"surface:listing-container": {
   "convention": "flush, no card, edges to the content area",
   "authority": "rung 2, 3 sites",
   "sites": ["app/components/common/resource-table-listing/ResourceTableListing.vue"],
   "outliers": ["app/pages/administration/users-groups/index.vue"],
   "sanctioned": [],
   "first": "2026-08-19", "last": "2026-08-19"}}
```

Rank findings by:

1. **New since the last sweep of that family**, on ground swept before. Something
   merged recently caused it and the fix is cheapest now.
2. How often a user crosses between the two sides. Two listings in the same
   sidebar section beat two screens nobody visits in one sitting.
3. The strength of the rung. A written rule outranks a counted convention.
4. Long-standing divergence on ground swept for the first time.

Update the baseline for every family swept, including the sites you took no
action on and every difference you judged sanctioned, with the comment or spec
that sanctioned it.

## Fingerprint

`ux-consistency:<family>:<normalized-divergence>:<outlier-file>`

- `family` is one of the rotation families above.
- `normalized-divergence` names what differs, in words, not in class strings. A
  class string changes with any unrelated edit and would break the fingerprint on
  a night when nothing about the finding changed.
- The primary file is the **outlier**, never the authority side. The authority
  side gains call sites over time; the outlier is the thing being fixed.
- Strip counts, line numbers, class strings and route parameters.
- A divergence you cannot pin to one outlier file is **deferred**, not shipped.
  Three pages each doing it differently is a design question with no odd one out.

Example:
`ux-consistency:surface:listing-wrapped-in-card:app/pages/administration/users-groups/index.vue`

## Triage output

Write findings to `<run>/workers/ux-consistency.md`, ranked, and return the same
list. No code is written in this stage.

Per finding: fingerprint, family, the outlier file and the authority sites, what
each side does in one sentence of plain UX language, the rung that settles it and
the quote or the count behind it, whether a comment explains the difference, the
tier and screenshots that show it, whether it is new since the baseline, the
proposed fix in one or two sentences, an estimated diff size, and a verdict of
`fix` or `note` with the reason.

Describe the difference the way a user would see it, not the way the markup
reads. "The users list sits in a card with a border and rounded corners while
every other listing runs to the edge of the content area" is the finding. The
class strings are evidence, and they belong in the evidence line.

## Fix rules

For a finding the orchestrator accepts, in its own worktree:

- Change the outlier only. One finding per branch, no drive-by cleanups, no
  reformatting, no renames.
- Smallest change that lands the settled pattern. Prefer deleting the outlier's
  local version and using the shared component to reimplementing the look.
- Keep every `data-testid` and the DOM the specs key on. If the fix cannot land
  without moving one, it is a note.
- No new dependency, no version bump, no token or `--ui-*` change.
- Copy changes go in `en.json` only. Say in the handoff that the branch changed
  `en.json`, so the digest can remind Joey about the `to-be-translated` label.
- Check every prop, slot and emit against the **installed** Nuxt UI types in the
  worktree's `node_modules`, not from memory.
- Update the specs the change touches, and keep the repo at 100 percent coverage.
  A visual change with no assertable behavior does not need a new test invented
  for it; say so rather than writing one that asserts a class string.
- Leave the explanatory comment above the code truthful. If it described the
  behavior you just changed, rewrite it in the same plain voice, short.
- If the honest fix crosses the 150-line cap, or turns into a second finding,
  stop and hand it back as a note with what you learned.

## Re-verification

A fix is not done until the outlier is gone, proven by the same means that found
it, with real output:

- Re-run the tier A census for that family in the fix worktree and show the
  outlier now grouped with the convention.
- Screenshot the fixed screen at tier B at the same width as the before shot, and
  put both paths in the handoff. A consistency fix with no picture is not
  reviewable in the morning.
- Run the touched specs and show them passing. `prepare-to-ship` still gates the
  branch afterwards; that is the orchestrator's step, not a substitute for this
  one.
- Confirm nothing else moved: no other call site of the shared component changed
  appearance, and no new divergence was introduced in the file you touched.

Say plainly what could not be re-verified and why. Never claim a screen looks
right without having looked at it.

## Discard rules, on top of the shared ones

- The authority ladder returned nothing, or returned rung 2 with a two-against-one
  count.
- A comment or spec explains the divergence.
- The outlier is newer than the convention it breaks and no written rule covers it.
- The divergence is in behavior rather than presentation and no written rule
  settles it.
- The fix needs the shared component to grow an option, a variant or a prop.
  Growing a shared component to absorb a one-off is a design decision.
- It only shows at tier C and tier C cannot be re-run for verification.
- The two sides are not actually comparable. A settings page and a records listing
  are allowed to differ; make the case for comparability before calling it a
  finding, and drop it when the case is thin.

## First-run note

The first night has no baseline, so every difference looks new and nothing can be
ranked by novelty. Expect the census to be the real output: sweep the first three
families, write the full baseline including sanctioned differences, and hand over
at most the finding cap, chosen by the strength of the rung. Say in the findings
file that this was a census-building run, so the digest does not read as though
the app suddenly grew twenty inconsistencies.
