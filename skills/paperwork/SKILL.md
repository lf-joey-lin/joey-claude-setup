---
name: paperwork
description: File the paperwork for a finished momentum branch - find or create the TFS work item (story or bug) on Joey's Momentum board from what the branch actually did, then open the matching pull request and link the two together. Runs after loom (or loom-finish), which leaves the branch merged with origin/main, probed, gated, pushed, and explained in a report. paperwork reads that report, writes the description and the acceptance criteria from the work the branch really contains, searches the board for an item that already covers the work and uses that one when it finds it, otherwise creates the item in Active state assigned to Joey via create-tfs, then opens the PR from the repo's own template with the item linked in the body and adds the PR back as a Hyperlink relation on the item's Links tab, then hands the item's test plan to the draft-test-plan skill when that field is empty. Every run ends with one work item and one PR; the PR is a draft unless --pr asks for ready-for-review, and only a ready PR gets the to-be-translated label when the branch changed an en.json, and the dev-bot-laserfiche reviewer. Writes no code, runs no checks, and never creates a second item or a second PR. Invoke when the user types /paperwork, or asks to "do the paperwork", "file the paperwork", "create the item and the PR", "open the PR for this branch", or "wrap up the housekeeping" once loom has finished.
---

# paperwork: the work item and the PR for a finished branch

The last skill in a session. The code is written, reviewed, tested, gated, and
pushed. What is left is the bookkeeping two other people need: a work item on the
board saying what this was, and a pull request pointing at it.

Joey's workflow is `/loom <request>` -> `/paperwork`, and `/loom-finish` ->
`/paperwork` for a branch picked back up for another round. loom deliberately
stops at a pushed branch plus its report - it creates no item and opens no PR -
so this is the only place that does either. That matters because both are
outward-facing on shared systems: a wrong story quietly attributes the work to
someone else's scope, and a PR against `main` asks real people for their
attention.

**It writes no code and runs no checks.** `loom-land` already merged
`origin/main`, and `loom-gate` held the local check set - lint, typecheck, the
unit suites with their coverage thresholds, build, storybook a11y - with the
probe findings fixed before it. If any of that is not true, this is the wrong
skill (see Preconditions).

## Invocation

```
/paperwork [hint]                        # work item + draft PR (default)
/paperwork --draft-pr [hint]             # the same thing, said explicitly
/paperwork --pr [hint]                   # ... but the PR opens ready for review
/paperwork --item 698997                 # use this existing item, create nothing
/paperwork bug --pr                      # force the type instead of inferring it
```

- **Both halves always happen.** Every run ends with a work item, found or
  created, and an open PR. There is no item-only mode: a branch that is finished
  enough to file paperwork for is finished enough to have a PR sitting on it.
- **The work item comes first**, so the PR body can carry the link `pr-metadata`
  needs. With `--item <id>` the given item is used as-is. Without one, step 5
  searches the board before it creates anything: the work usually has an item
  already, and a duplicate is worse than no item at all.
- **The only real choice is draft or ready**, and the default is draft. A draft PR
  is cheap: CI runs, the diff is linkable, and nobody has been asked to look at it
  yet. `--draft-pr` is a synonym for the default, kept so the intent can be written
  down.
- Both run the same flow up to the moment the PR is created. What differs is
  whether the PR is asking for review yet, and that decides two side effects:

  | | `--pr` | default, `--draft-pr` |
  |---|---|---|
  | Opens as | ready for review | draft |
  | `to-be-translated` label when an `en.json` changed | added by this skill | not added; the report hands Joey the command |
  | `dev-bot-laserfiche` requested as reviewer | yes | no |

  `--pr` is the only thing that opens a ready PR. Every other path that reaches
  step 7 - the bare default, `--draft-pr`, step 6's mismatch fallback, headless
  mode - opens a draft and adds neither. A draft is not asking anyone for anything
  yet, so requesting review on one is noise, and a label on a PR nobody has been
  asked to look at is a translation run nobody wanted.
- A leading `story` or `bug` token forces the type. Otherwise step 3 infers it.
- `hint` is context for the prose ("this is the second half of the widget story",
  "the config bit is a follow-up"). It never changes what the branch contains.

Say the resolved shape in your first line of output, before any tool call:
`PR: draft | ready for review   Branch: <branch>   Type: story | bug   Item: new | <id>`.

## Preconditions, checked not assumed

Read them off the repo, do not take them on trust.

```bash
cd "$(git rev-parse --show-toplevel)"
git branch --show-current
git fetch origin
git status --porcelain
git log --oneline origin/main..HEAD
git merge-base --is-ancestor origin/main HEAD && echo main-is-merged
```

- **Not `main`.** If it is, or HEAD is detached, stop. Nothing here opens a PR
  from `main` into `main`.
- **The branch has commits `origin/main` does not.** Nothing there means there is
  no work to file paperwork for. Stop and say so.
- **The tree is clean, and the branch is pushed.** `git status --porcelain` empty,
  and `git log --oneline origin/<branch>..HEAD` empty. Uncommitted or unpushed
  work means the PR would not contain what the item claims. Stop and say so: a
  solo loom run never pushes, so this is usually `git push -u origin HEAD`
  waiting to be run. Do not commit or push anything yourself.
- **`origin/main` is merged in.** No `main-is-merged` means the branch has not
  seen current `main`, so its green gate answers the wrong question. `loom-land`
  merges main inside the run, so this normally holds; when it does not, stop and
  point at `/loom-land`. Do not merge here.
- **Nothing to do already done.** An open PR for this branch is not a stop, but it
  is a hard "do not create a second one" - see step 7.

## Step 1 - read what the branch did

The description, the acceptance criteria and the PR bullets all come from the same
place: what the branch actually contains. Get that from the paper trail first,
because it was written by something that read the whole diff.

In priority order:

1. **The loom report**, `src/ui-app/logs/loom/<slug>-report.md`. This is the
   intended input. The slug is the run's, not always the branch name, so find it
   with `ls src/ui-app/logs/loom/*-report.md` and match on the branch line under
   its title. "What this branch does" and "The slices, in order" are exactly the
   material this skill reformats; "Needs human eyes" is the gotcha line for the
   PR body, and "Decisions taken" is what step 10 reports as assumed.
2. **The branch's other handoffs**: the flight ledger
   `src/ui-app/logs/loom/<slug>.md` and its sidecars under
   `src/ui-app/logs/loom/<slug>/`, which carry the gate scorecard, the probe
   findings and the tidy vetoes in more detail than the report; a
   `src/ui-app/logs/*` spec or design handoff; a spec under
   `src/<component>/specs/`.
3. **The diff itself**, when there is no report:

   ```bash
   git log --oneline origin/main..HEAD
   git diff --stat origin/main
   git diff origin/main
   ```

   Say in the report that you read the diff because no loom report was there. It
   is not a stop; the prose is just working from less.

Resolve the **components** the branch touched while you are here: the path segment
right after `src/` (`cut -d/ -f2`), never the basename. That is the title's area
tag and the PR title's.

**One branch is one piece of work.** If the branch genuinely
carries two unrelated features, do not invent two items: say so, file the item for
the dominant one, name the other in the report, and let Joey decide whether it
needs its own story.

## Step 2 - the bullets

One bullet per change a reviewer reads as a single decision. Not one per file, not
one per commit, not one per hunk. The branch's commits are a good starting point
(`git log --oneline origin/main..HEAD`), because a loom slice is already one
verifiable behavior, but re-group them: a fix turn, a probe fix and a tidy commit
belong inside the bullet for the slice they correct, not next to it.

These bullets do double duty: they are the PR's "Description of changes", and they
are what step 6 lines up against the acceptance criteria. Do not derive a second
different list later.

Out of the bullets:

- **The `origin/main` merge.** It is not something this branch changes.
- **Tests, coverage, lint, build.** The gate covers them and the reviewer can see
  them. A bullet saying "added unit tests" tells nobody anything.
- **The wrap-up edits as their own bullets.** A review fix belongs inside the
  bullet for the code it fixed.

## Step 3 - story or bug

A leading `story` or `bug` token in the invocation settles it. Otherwise:

**Bug** when the branch corrects behavior that was already shipped and wrong. The
tells: the loom report describes a fix, a slice's checks were born red against
real broken behavior rather than absent behavior, the branch name says fix, the
change is a correction rather than an addition.

**Story** for everything else: new behavior, a new endpoint, a refactor, a
migration, config, test-only work, a dependency bump.

If the branch fixes a bug in code that was never released, that is still part of
the story that introduced it, not a bug of its own.

**Ambiguous** is a story, and say in the report that you assumed it. Getting this
wrong costs a field edit; stopping to ask costs Joey a turn.

## Step 4 - write the description and the acceptance criteria

Both are HTML fields on the item. The rules live in the "TFS work items" section
of `joey-writing-style.md` - **read it before writing these**, do not work from
memory. The short version:

- **Description** (`System.Description`): a short paragraph on what the branch
  changes and why. For a wiring change, name the endpoints or contracts involved
  so a reader knows what talks to what. Then a "Not in scope" list if the branch
  deliberately left something obvious out, one line and its reason each. The
  loom report's "Tidy" follow-ups and its deferred probe findings are where that
  comes from.
- **Acceptance criteria** (`Microsoft.VSTS.Common.AcceptanceCriteria`): a numbered
  `<ol>`, the main features one line each, plain language, usually three to six.
  However many the branch really has. Do not pad to a count.

Two filters kill a line before it gets written:

- **A person has to be able to check it sitting in front of the feature.** If it
  needs a rigged server, a forced backend failure, a devtools look at the request
  payload, or a malformed response, it is a unit test. Specific status codes too:
  "a 403 gets its own message" is code, not AC.
- **Anything a PR gate already blocks on is out.** Unit tests, the 100% coverage
  thresholds, lint, build, the a11y suite. CI fails without them, so the board
  gains nothing by repeating them.

Also out: implementation detail (which mapper, which composable, which query
validation), grouping headers, and edge cases nobody will exercise by hand.

**Writing the AC after the code is the trap this skill has to avoid.** The
acceptance criteria are what someone checks to call the work done, not a summary
of the diff. Write each line as the behavior a person sees, the way it would have
been written before the code existed. If a line only makes sense to someone who
has read the branch, it is a bullet, not a criterion.

Apply the standing writing rules to both fields: no em dashes, no emoji, sentence
case, no hedging, no filler, nothing that reads as generated.

## Step 5 - find or create the work item

**With `--item <id>`**, create nothing. Read the item and check it is a real
target before anything gets linked to it:

```
mcp__azure-devops__wit_get_work_item id=<id> project=Cloud expand=relations
    fields=["System.Title","System.State","System.AssignedTo","System.AreaPath",
            "Microsoft.VSTS.Common.AcceptanceCriteria"]
```

- Assigned to someone else, or outside `Cloud\Projects\Momentum`, is a signal, not
  a detail. Say so and confirm before linking. Never reassign it.
- `expand=relations` also shows whether a hyperlink to this PR already exists,
  which step 8 needs so it does not add a duplicate.
- Do not rewrite a pre-existing item's description or acceptance criteria to match
  the branch. Someone else may be waiting on the version that is there. Step 6
  reports the mismatch instead.

### No id given: search the board before creating anything

Most of this work already has an item. Somebody wrote the story at planning, or
Joey filed it before he started and did not pass the number along. A second item
for the same work splits the history and leaves a duplicate for somebody else to
close, so search first, on every run that was not given an id.

Search on what the branch does, not on the branch name alone. Two or three
passes, because these tools miss different things:

```
# the feature in one sentence, the way a person would say it
mcp__azure-devops__search_work_items_semantic
mcp__azure-devops__search_workitem searchText=<key terms> project=["Cloud"]
# where a story Joey filed before starting will be
mcp__azure-devops__wit_my_work_items type=assignedtome
```

Terms worth trying: the component from step 1, the nouns out of the title, the
route or endpoint the branch touches, and the words in the branch name.

Judge a candidate on what it asks for, not on how it is worded. An item whose
acceptance criteria describe the behavior this branch delivers is the item, even
if its title reads nothing like yours. An item covering a bigger feature this
branch is only one part of is not a match on its own.

- **Nothing plausible** - create it, per below, and say in the report what you
  searched for, so a miss is visible rather than silent.
- **One or more candidates** - stop and ask with `AskUserQuestion`: one option
  per candidate, each showing id, type, title, state and assignee, plus "create
  a new item". Never adopt an item silently; it is somebody's board column.
- **Adopted** - it is now exactly the `--item <id>` case. Read it with
  `expand=relations` as above, then go on to step 6, which is a real comparison
  for it rather than a read-back.

**Updating an adopted item means filling gaps, not rewriting.**

- **State**: `New` or `Open` goes to `Active` (`wit_update_work_item` on
  `System.State`), same reason a created item goes in Active - the work is done.
- **An empty description or empty acceptance criteria**: write step 4's into it,
  and say in the report that you filled them.
- **Anything already written stays.** Do not replace someone's description or
  criteria with your own version of the same thing. Step 6 reports a real
  mismatch and asks; that is where it gets settled.
- Never reassign it, never move its area path, never change its type.

**Nothing on the board covers it - create it** with the `create-tfs` skill,
passing the type from step 3, the description and acceptance criteria from step
4, and this:

> The work is already complete and about to go up as a pull request. Create the
> item in **Active** state, not `New`/`Open`.

`create-tfs` owns the field table, the identity form (`LASERFICHE\joey.lin`), the
area path, the current-sprint lookup, and the type mapping. Do not duplicate any
of it here, and do not hardcode a sprint.

`Active` is the point of the deviation from `create-tfs`'s default: the item exists
because the work is done, so a board column saying "not started" is wrong from the
moment it is created. Joey resolves it when the PR merges.

**One item per invocation.** If creation fails on anything other than an identity
error, check with `search_workitem` before retrying - a duplicate may already be
there. Never create a second item to get past an error.

Report the id and the board link before going near the PR:

```
https://v-dev-tfs/DefaultCollection/Cloud/_workitems/edit/<id>
```

## Step 6 - check the bullets against the acceptance criteria

For a **freshly created** item this is a read-back, not a comparison: both sides
came from the same branch a moment ago. Read the two lists next to each other once
anyway, and fix the item if step 4 wrote a criterion the branch does not actually
deliver. That is a bad criterion, not a gap.

For an item that **already existed** - given as `--item <id>`, or adopted from
the search - it is the real check. Line the step 2 bullets up against the item's
acceptance criteria one to one:

- **A criterion with no bullet delivering it** - the branch does not finish the
  item. This is the mismatch that matters.
- **A bullet no criterion asks for** - the branch does more than the item says.
  Worth reporting; it does not block on its own unless it is a whole feature.
- A bug with no acceptance criteria: compare against its repro /
  observed-versus-expected description instead, and say that is what you compared.

Judge on substance. Different wording for the same behavior is a match; a
criterion the branch half-does is not. A bullet about tests, coverage, lint, build,
or an error path like a 403 message is **not** a missing criterion - it is
deliberately not AC. Drop it from the comparison rather than pushing it onto the
board.

**Everything lines up** - say so in one line and carry on.

**Mismatch** - stop and ask with `AskUserQuestion`, the gaps listed concretely
(which criterion, which bullet). Two options:

1. **Open it as a draft and note the gap** - the PR body carries a short line
   saying which criteria are not delivered yet. Nothing on the board changes. Being
   a draft, it gets no label and no reviewer, so say in the report that both are
   waiting on it going ready.
2. **Trim the item to match** - remove the undelivered criteria
   (`wit_update_work_item` on the acceptance-criteria field) and open a normal PR.
   Show the exact criteria you would remove before touching the board, and say
   that anything still wanted needs its own item. Do not create that follow-up
   here.

Other direction (a bullet no criterion covers), same question, with option 2
reading "add it to the item's criteria". Only offer that for a real feature a
person can check in front of the app.

## Step 7 - open the PR

**A PR may already exist for this branch.** Check first:

```bash
gh pr view --json number,url,state,isDraft,body
```

An open PR already carries the branch's commits. Do not open a second one. Add the
work-item bullet to its body if it is missing (`gh pr edit <n> --body-file ...`),
carry on to step 8 for the link back, and say in the report that the PR was
already there.

**Read the template from the repo, do not write one from memory.**

```bash
cat docs/pull_request_template.md
```

It changes. As of 2026-08-19 it is a `Description of changes:` line and a
`## Work item links` section, both `TODO`. Fill every section it actually has. If a
checkout still carries the older impact and risk sections, fill them properly per
the global `CLAUDE.md` rather than dropping them.

- **Title**: `[area] Imperative summary`, area being the components from step 1.
  More than one is written `[repository, repository-mover]`.
- **Description of changes**: the step 2 bullets. Short, factual, skimmable. Under
  ten lines of body even for a big change. Then the gotcha, if the loom report
  surfaced one a reviewer would not guess from the diff.
- **Work item links**: one bullet per item, in the shape the board's own PRs use,
  which is also the shape `pr-metadata`'s regex accepts:

  ```
    * [User Story 698997](https://v-dev-tfs/DefaultCollection/Cloud/_workitems/edit/698997): <title>
  ```

  `pr-metadata` reads the body and fails without one, which is why the item is
  created before the PR and not after.
- Every claim comes from something you read. Where you could not determine
  something, write that you could not determine it. Never guess and never pad.
- Read the body back and cut the AI tells: hedging, filler, em dashes, a closing
  paragraph that restates the bullets. This is outward-facing prose on a shared
  repo. `joey-writing-style.md`'s "PR descriptions" section has the targets.

Write the body to a file in the scratchpad and pass it by path, so nothing gets
mangled by shell quoting:

```bash
gh pr create --base main --head "$(git branch --show-current)" \
  --title "<title>" --body-file <scratchpad>/pr-body.md [--draft]
```

`--draft` for `--draft-pr`, and for step 6's mismatch default. Report the URL `gh`
returns; do not claim it opened without one. If `gh pr create` fails, the item
still exists and is correct - report the real error and stop. Do not retry into a
second PR.

**Do not pass `--label` or `--reviewer` to `gh pr create`.** Either one failing -
a label that is not in the repo, a handle without access - fails the whole
creation, and then the PR that was already correct does not exist. Create first,
then add, so a failure there costs a line in the report instead of the PR.

### Ready-for-review only: the label and the reviewer

Skip this whole section for a draft. It applies when, and only when, `--pr` opened
a ready-for-review PR.

**The `to-be-translated` label, if the branch changed an `en.json`:**

```bash
git diff --name-only --diff-filter=ACMR origin/main...HEAD | grep -E '(^|/)en\.json$'
gh pr edit <n> --add-label to-be-translated
```

Only `en.json` counts. `fr.json`, `es.json`, `en-XA.json` and the XLIFF memory are
pipeline output, and a branch that touched one by hand should never have got this
far. No `en.json` in the diff means no label - do not add it "just in case", it
triggers a translation run over strings nobody changed.

This is the one thing that clears `pr-i18n-parity`, which fails on any branch that
changed an `en.json`. It needs `MTRANS_*` credentials and cannot run locally, so
the label is the whole remedy: the pipeline commits the regenerated catalogs back
to the branch. Never run `check-parity.ts` here, never reach for
`translate.ts --pseudo`, and never report `pr-i18n-parity` as a failure.

**The reviewer:**

```bash
gh pr edit <n> --add-reviewer dev-bot-laserfiche
```

`dev-bot-laserfiche` is the bot that reviews momentum PRs. The handle is exactly
that, not `dev-bot`. Request it on every ready PR, whatever the branch touched.

Neither of these is a reason to stop. If `gh pr edit` fails on either - the label
is missing from the repo, the bot has no access, the handle changed - report the
real error with the command so Joey can run it himself, and carry on to step 8.
The PR is open and correct; these are additions to it. Do not guess at another
handle, and do not create the label.

## Step 8 - link the work item back

The PR body points at the item; the item has to point back, as a **Hyperlink
relation on its Links tab**, not a comment. The `wit_*` MCP tools cannot add one
for a GitHub PR: `wit_link_work_item_to_pull_request` only handles ADO-hosted PRs,
and `wit_update_work_item` takes string field values, not relation objects. So it
goes through the TFS REST API with Windows integrated auth.

Skip it if the relation is already there - step 5's `expand=relations` read shows
the existing hyperlinks, and re-running adds a duplicate.

On WSL, integrated auth needs the Windows PowerShell interop (the WSL shell cannot
do it, so do not translate this to `curl`):

```bash
powershell.exe -NoProfile -Command "Invoke-RestMethod -Uri 'https://v-dev-tfs.laserfiche.com/DefaultCollection/Cloud/_apis/wit/workitems/<id>?api-version=5.0' -Method Patch -ContentType 'application/json-patch+json' -UseDefaultCredentials -Body '[{\"op\":\"add\",\"path\":\"/relations/-\",\"value\":{\"rel\":\"Hyperlink\",\"url\":\"<pr-url>\",\"attributes\":{\"comment\":\"<short desc>\"}}}]'"
```

On Windows, run the `Invoke-RestMethod` directly.

If it fails, say so with the real error and leave the PR open. The link back is
bookkeeping; a failed patch is not a reason to close or redo anything.

## Step 9 - the test plan

The item's `Laserfiche.BacklogItem.TestPlan` field is what somebody runs before the
story goes to Resolved. Do not write it here. Hand it to the **`draft-test-plan`**
skill, which owns the format, the rules, the HTML and the field write, the same way
`create-tfs` owns the field table. Do not duplicate any of it in this skill.

```
Skill(skill="draft-test-plan", args="<item id>")
```

It runs last because it needs both halves of the paperwork. It reads the item's
description, acceptance criteria and the code, so the item has to be settled; and its
PREREQUISITES section names the PR or deploy that put the code under test where a run
will find it, so the PR has to exist.

Hand it, in the invocation: the item id, the branch, the components from step 1, the
PR url, the preview namespace if the branch has one up, and the path to the loom
report from step 1. It does not go looking for that report itself.

**Leave the field alone in three cases:**

- **A plan is already there.** Same rule as the description and the acceptance
  criteria: filling an empty field is not a rewrite, replacing what somebody wrote
  is. Report that one is already there and that `/draft-test-plan <id>` refines it.
- **Test Results are already recorded on the item.** Somebody has run the plan.
  Renumbering it under their results is `draft-test-plan`'s own step 5 and needs a
  person, not a run that is really about a PR.
- **The item is assigned to someone else** - step 5 already flagged that. Do not
  write to their field.

Two things that are not stops. `draft-test-plan` is a repo skill
(`.claude/skills/draft-test-plan/`), so an older checkout may not carry it: say so
and skip. And it names `mcp__tfs__*` tools while the server configured here is
`azure-devops` - the `wit_*` tool names are the same, so use the `mcp__azure-devops__*`
ones. Either way a failure here is a line in the report, never a stop: the item and
the PR are already correct, and the plan can be drafted in its own run.

## Step 10 - report

Short. No praise for the change, no summary of what the code does.

- **the work item**: id, type, title, state, sprint, and where it came from -
  created new, adopted from the board search, or given as `--item`. For an
  adopted one, what you searched for and which fields you filled. For a created
  one, what you searched for before deciding nothing covered it. The clickable
  board link.
- **what you guessed**, so Joey can fix it in one pass: the type inference if it
  was ambiguous, the story points, the area tag when the branch touched more than
  one component.
- **where the prose came from**: the loom report, or the diff because there was
  no report.

Then:

- **the PR**: URL, draft or ready and why, or that one was already open.
- **the AC check**: matched, or the gaps and which option was taken.
- **the reviewer**: `dev-bot-laserfiche` requested, or not requested because the PR
  is a draft, or the real error.
- **the link back**: added, already present, or the real error.
- **the test plan**: drafted into the item by `draft-test-plan`, or left alone
  because one was already written or results were already recorded, or the real
  error.
- **the translation label**, if any `en.json` changed:
  - ready PR - say the **`to-be-translated`** label was added, and that the
    pipeline will commit the regenerated catalogs back to the branch.
  - draft PR - say the label is still needed and hand Joey the command,
    `gh pr edit <n> --add-label to-be-translated`, to run when he marks it ready.
    `pr-i18n-parity` fails until it goes on, and that is expected, not a broken
    branch.
- **what CI owns that nothing local covered**: the container builds, the migration
  apply, `pr-metadata`, and the contract breaking-change check. loom's green gate
  scorecard is not a promise that CI is green.

## Autonomous mode (headless, under another orchestrator)

See [`../shared/autonomous-pipeline.md`](../shared/autonomous-pipeline.md). Each
of this skill's questions gets a default:

| Interactive gate | Headless default |
|---|---|
| Step 5 search turned up candidates | adopt one only if it is assigned to Joey, sits in `Cloud\Projects\Momentum`, and its criteria clearly describe this branch. Anything else: **create a new item** and name the candidates in the report |
| Step 5 item assigned to someone else | **stop.** Do not link a shared item to work nobody asked this run to do |
| Step 6 mismatch question | open as a **draft** with the gap noted in the body; never edit a shared item's acceptance criteria unattended |
| draft versus ready | **draft**, unless the invocation carried `--pr`. A headless run does not decide to ping reviewers, so it adds no label and no reviewer either |
| Step 9 test plan on an adopted item | draft one only into an **empty** field. A plan already written, or any recorded Test Results, is left as it is and named in the report |

Nothing else softens. Every precondition is still a stop, and a stop is reported
rather than worked around.

A headless run opens a draft PR like any other run. What it must never do is open
a **ready** one: only an explicit `--pr` in the invocation does that, because
marking a PR ready is what pulls a human and a review bot in, and that is the one
thing in this pipeline nobody can un-see.

## Invariants

- **No code, no checks, no git writes to content.** This skill creates a board
  item and a PR, drafts the item's test plan through `draft-test-plan`, and
  nothing else. No commits, no pushes, no merges, no edits to
  source, tests, or translation catalogs. If the branch is not ready, that is a
  stop pointing at the push command or `/loom-land`, never a fix here.
- **One item and one PR per branch, ever.** Search the board before creating an
  item, and prefer the one that is already there; check for an existing PR before
  creating one; check with `search_workitem` before retrying a failed creation.
- **The item is settled - found or created - before the PR**, so the body can
  carry the link `pr-metadata` requires.
- **Ready for review is opt-in; the PR itself is not.** Every run opens a PR, and
  it is a draft unless the invocation carried `--pr`. The `to-be-translated` label
  and the `dev-bot-laserfiche` reviewer go on ready PRs only, and are added after
  creation, never as `gh pr create` flags.
- **A created item goes in as `Active`.** The work is done; a backlog column would
  be a lie.
- **Never rewrite a pre-existing item's description or acceptance criteria** to
  make the branch look finished. Filling a field that is empty is not a rewrite;
  replacing prose somebody wrote is. Report the gap and let a human decide.
- **Never invent a work item link.** No id in the body that step 5 did not return
  or read.
- Only `en.json` is ever hand-edited in this repo, and not by this skill.
- No em dash, emojis, arrows, or box-drawing characters in anything written. The
  board and the PR are read by other people.
