---
name: paperwork
description: File the paperwork for a finished momentum branch - find or create the TFS work item (story or bug) on Joey's Momentum board from what the branch actually did, then open the matching pull request and link the two together. Runs after loom, which leaves the branch merged with origin/main, probed, gated, pushed, and explained in a report. paperwork reads that report, writes the description and the acceptance criteria from the work the branch really contains, searches the board for an item that already covers the work and uses that one when it finds it, otherwise creates the item in Active state assigned to Joey via create-tfs, then opens the PR from the repo's own template with the item linked in the body, then hands the item's test plan to the draft-test-plan skill. The branch is the golden standard by default: an adopted item's description, acceptance criteria and test plan are synced to what the branch's specs say, and where the two disagree about the same work the branch wins. The one exception is a criterion or note on the item that the branch does not deliver - that is never reconciled silently: the run stops, warns with the gap concretely, and asks whether to stop so the work can be finished or to remove it from the item. `--no-sync` keeps the old behaviour of filling only empty fields. Every run ends with one work item and one PR, unless that gap question is answered by stopping; the PR is a draft unless --pr asks for ready-for-review, and only a ready PR gets the to-be-translated label when the branch changed an en.json, and the dev-bot-laserfiche reviewer. Writes no code, runs no checks, and never creates a second item or a second PR. Invoke when the user types /paperwork, or asks to "do the paperwork", "file the paperwork", "create the item and the PR", "open the PR for this branch", or "wrap up the housekeeping" once loom has finished.
---

# paperwork: the work item and the PR for a finished branch

The last skill in a session. The code is written, reviewed, tested, gated, and
pushed. What is left is the bookkeeping two other people need: a work item on the
board saying what this was, and a pull request pointing at it.

Joey's workflow is `/loom <request>` -> `/paperwork`, and `/loom --retrofit` ->
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
/paperwork --no-sync [hint]              # fill only empty item fields, do not sync
```

- **Both halves always happen.** Every run ends with a work item, found or
  created, and an open PR. There is no item-only mode: a branch that is finished
  enough to file paperwork for is finished enough to have a PR sitting on it. The
  single exception is step 6's gap question, and only if Joey answers it by
  stopping: an item asking for work the branch does not contain is a question for
  him before anything goes on a shared system.
- **The work item comes first**, so the PR body can carry the link `pr-metadata`
  needs. With `--item <id>` the given item is used as-is. Without one, step 5
  searches the board before it creates anything: the work usually has an item
  already, and a duplicate is worse than no item at all.
- **The branch is the golden standard.** What the branch's specs say the work is
  wins over what the item currently says it is. So step 6 syncs the item's
  description, acceptance criteria and test plan to the branch rather than
  reporting a difference and leaving it. The board is where the work gets read
  after the fact, and an item still describing the plan rather than the thing
  that shipped is worse than no item. Two limits on that, both in step 6: the
  branch never decides on its own **whether a requirement exists** (an item asking
  for something the branch does not deliver stops and asks, rather than being
  quietly rewritten or trimmed), and an item **assigned to someone else** is never
  synced without asking.
- **`--no-sync`** turns that off: empty fields still get filled, anything already
  written is left alone, and divergence is reported instead of applied. Reach for
  it when the item is somebody else's planning artifact, or when the branch is
  deliberately a partial delivery of it.
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
  step 7 - the bare default, `--draft-pr`, headless mode - opens a draft and adds
  neither. A draft is not asking anyone for anything
  yet, so requesting review on one is noise, and a label on a PR nobody has been
  asked to look at is a translation run nobody wanted.
- A leading `story` or `bug` token forces the type. Otherwise step 3 infers it.
- `hint` is context for the prose ("this is the second half of the widget story",
  "the config bit is a follow-up"). It never changes what the branch contains.

Say the resolved shape in your first line of output, before any tool call:
`PR: draft | ready for review   Branch: <branch>   Type: story | bug   Item: new | <id>   Sync: branch-is-golden | off`.

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

**"The branch's specs" means this material**, and it is what step 6 syncs the item
to. A committed spec file is the strongest form of it, because it was written as
requirements rather than reverse-engineered from a diff:

1. **A spec the branch added or changed**, `src/<component>/specs/spec.md` and its
   `design.md` sibling. Find them with
   `git diff --name-only origin/main...HEAD | grep -E 'specs/.*\.md$'`, and read
   the file at HEAD, not the diff. A spec-driven feature (see the repo
   `CLAUDE.md`) already carries the WHAT, the WHY and the acceptance criteria in
   the form the item wants, so the item's fields come from here nearly verbatim,
   with the two filters in step 4 still applied. A spec that exists on `main`
   untouched by this branch is context, not the branch's spec - the item can
   describe more than one branch's worth of work, and this branch only speaks for
   what it changed.
2. **The loom report**, `artifacts/loom/<slug>-report.md`. This is the
   intended input. The slug is the run's, not always the branch name, so find it
   with `ls artifacts/loom/*-report.md` and match on the branch line under
   its title. "What this branch does" and "The slices, in order" are exactly the
   material this skill reformats; "Needs human eyes" is the gotcha line for the
   PR body, and "Decisions taken" is what step 10 reports as assumed.
3. **The branch's other handoffs**: the run ledger
   `artifacts/loom/<slug>-ledger.md` and its sidecars under
   `artifacts/loom/<slug>/`, which carry the gate scorecard, the probe
   findings and the tidy vetoes in more detail than the report; a
   `src/ui-app/logs/*` spec or design handoff.
4. **The diff itself**, when there is neither:

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

Both are HTML fields on the item. **Write them on every run, including a run that
adopted an item with both fields already full** - this is the branch's version of
those fields, and step 6 is what decides how much of it lands. Where the branch
carries a spec (step 1's first source), its requirements and acceptance criteria
are the wording to keep, not a starting point to paraphrase; the diff and the loom
report only fill in what the spec does not say.

The rules live in the "TFS work items" section
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
  a detail. Say so and confirm before linking. Never reassign it. **An item
  assigned to someone else is also not synced**: ask first, and treat a no as
  `--no-sync` for that run. Somebody may be waiting on the version that is there,
  and a sync overwrites it.
- An item assigned to Joey and inside `Cloud\Projects\Momentum` goes through
  step 6's sync like any adopted item. Its current text is the plan; the branch is
  what shipped.

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

**Updating an adopted item: decided here, written after step 6 clears.**

- **State**: `New` or `Open` goes to `Active` (`wit_update_work_item` on
  `System.State`), same reason a created item goes in Active - the work is done.
  **Hold this until step 6 clears.** If the gap question ends in a stop, the board
  is meant to look untouched, and a state bump is the one write that would
  otherwise have got there first.
- **An empty description or empty acceptance criteria**: write step 4's into it,
  and say in the report that you filled them. Same hold: after step 6, not before.
  This happens under `--no-sync` too; filling an empty field is not a sync.
- **Text that is already there is step 6's business, not this step's.** Do not
  write over it here, and do not read it and move on either - step 6 needs both
  versions side by side to tell a divergence from a gap, and those two get
  opposite treatment.
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

## Step 6 - sync the item to the branch

**The branch is the golden standard.** The item's description, acceptance criteria
and test plan get brought into line with what the branch's specs say, not the
other way round. Nobody re-reads a story to find out what was planned; they read
it to find out what the software does.

One thing does not work that way, and it is the reason this step is not a blind
overwrite: the branch never decides **whether a requirement exists**. An item
asking for something the branch does not deliver is a stop, not a line to delete.
So the whole step is one classification, applied line by line, with three
outcomes.

For a **freshly created** item there is nothing to classify: both sides came from
the same branch a moment ago. Read the two lists next to each other once anyway,
and fix the item if step 4 wrote a criterion the branch does not actually deliver.
That is a bad criterion, not a gap.

For an item that **already existed** - given as `--item <id>`, or adopted from the
search - read everything it records before comparing anything:

```
mcp__azure-devops__wit_get_work_item id=<id> project=Cloud
    fields=["System.Description","Microsoft.VSTS.Common.AcceptanceCriteria",
            "Laserfiche.BacklogItem.TestPlan","Microsoft.VSTS.TCM.ReproSteps"]
mcp__azure-devops__wit_list_work_item_comments workItemId=<id> project=Cloud
```

The comments matter. A requirement added after the item was written usually lives
in one, so a comment asking for behavior the branch does not have is a gap like
any other. **Comments are never rewritten or answered by this skill** - they are
somebody's conversation, and they are read here only to find gaps.

### The classification

Line up the step 2 bullets and step 4's fields against what the item currently
says. Each line on the item's side is one of:

- **Divergence** - the item and the branch describe the same work, differently.
  The item says a filter is a dropdown and the branch built a typeahead; the item
  describes the endpoint that got renamed on the way; the wording is just older.
  **The branch wins.** No question, no gate.
- **Gap** - the item asks for something no bullet delivers at all. Not a different
  shape of the same thing, an absence. **This is the question**, below - the only
  thing in this step that is not the skill's call.
- **Extra** - the branch delivers something the item never asked for. **The branch
  wins**: it goes into the description, and into the acceptance criteria if it is a
  feature a person can check in front of the app.

Divergence versus gap is the only judgement that matters here, and it is a
judgement about behavior rather than wording. Ask what a person sitting in front
of the feature would find: something different from what the item said (divergence)
or nothing at all (gap). A criterion the branch **half** delivers is a gap for the
half that is missing - say which half.

Two things are out of the comparison entirely, same as they were out of step 4:
anything a PR gate already blocks on (tests, coverage, lint, build, a11y), and
error paths and implementation detail that were never AC. A bullet about test
coverage is not an extra, and a criterion about a 403 message body is not a gap.
Drop them from the comparison rather than pushing them onto the board.

A **bug with no acceptance criteria**: classify against its repro and its
observed-versus-expected description instead, and say in the report that is what
you compared.

### Applying it - divergence and extra

Write step 4's description and acceptance criteria over the item's
(`wit_update_work_item` on `System.Description` and
`Microsoft.VSTS.Common.AcceptanceCriteria`). Run this **after** the gap question
below has been settled, and honour its answer: an undelivered criterion Joey chose
to keep does not exist any more (he stopped the run), and one he chose to remove
comes out here as part of the same single write. Nothing gets dropped as a side
effect of the sync itself.

- Do this in **one** update per field. Do not patch line by line.
- **Quote what you replaced in the report**, both fields, so the old text is in
  front of Joey rather than only in the item's history. TFS keeps the revision
  either way (`wit_list_work_item_revisions`), and that is the undo path - say so
  if the change is large.
- The **title** is left alone unless it now describes different work than shipped.
  If it does, say what you would rename it to and let Joey do it; a title change
  moves what other people see on the board.
- `--no-sync` skips this whole subsection: report the divergences and change
  nothing. Empty fields still get filled per step 5.

### The gap question - the item asks for something the branch does not deliver

**Stop before writing anything** - no fields, no state bump, no PR - and put the
gap to Joey. This is the one case where the item knows something the branch does
not, and it has two legitimate answers that only he can pick between: the work is
still coming, or the item should never have asked for it. Reconciling it either way
without asking is how a requirement gets lost between a board and a merge.

Warn first, concrete enough to act on: the criterion, note or comment verbatim,
where it came from (acceptance criteria, description, comment and its author), and
one line on what the branch does instead or that it does nothing.

Then ask with `AskUserQuestion`, one question per gap when they are independent,
one question when they are the same missing feature:

1. **Stop here, the work is still coming** - nothing has been written and no PR is
   open. The gap gets built, or the item gets split, and `/paperwork` runs again
   after. Recommend this one when the criterion reads like real scope rather than
   an artifact of planning.
2. **Remove it from the work item** - the undelivered criteria come off the item,
   the sync then runs as normal, and the PR opens as normal. **Show the exact lines
   you would remove before touching the board**, and quote them again in the
   report, because once they are off the item that report is the only place they
   still exist. Say that anything still wanted needs its own item, and do not
   create that follow-up here.

Two gaps cannot be answered with option 2, so do not offer it for them. One on an
item **not assigned to Joey**: removing a criterion is a board edit somebody else
may be reading. And one that lives only in a **comment**: there is no field to trim,
and this skill does not edit or answer comments. Both are stop-only, with the gap
named in the report so Joey can settle it on the board himself.

**Everything lines up, or divergence only** - say so in one line, apply it, and
carry on.

## Step 7 - open the PR

**A PR may already exist for this branch.** Check first:

```bash
gh pr view --json number,url,state,isDraft,body
```

An open PR already carries the branch's commits. Do not open a second one. Add the
work-item bullet to its body if it is missing (`gh pr edit <n> --body-file ...`),
say in the report that the PR was already there, and carry on.

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

`--draft` for `--draft-pr`. Report the URL `gh`
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
real error with the command so Joey can run it himself, and carry on.
The PR is open and correct; these are additions to it. Do not guess at another
handle, and do not create the label.

## Step 8 - the link back is automatic

Nothing to do. `pr-metadata.yaml` adds the PR as a Hyperlink relation on every work
item the PR body links, and keeps that relation's comment in step with the PR's
state (open, draft, approved, merged). Do not patch one in by hand: the relation
would be a duplicate the pipeline does not maintain.

The PR body bullet from step 7 is what the pipeline reads, so that link is the one
thing that has to be right.

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

**A plan already in the field is refreshed, not left.** Same reason as step 6: a
plan written against the plan tests something nobody shipped, and a tester
following it either fails a step that was never built or passes one that no longer
means what it says. Say so in the invocation - that a plan is already there, that
the branch is the golden standard, and that it should be brought into line with
what the branch delivers - and quote the plan you replaced in the report. Under
`--no-sync`, an existing plan is left alone and the report says
`/draft-test-plan <id>` refines it.

**Leave the field alone in three cases:**

- **Test Results are already recorded on the item.** Somebody has run the plan.
  Renumbering it under their results is `draft-test-plan`'s own step 5 and needs a
  person, not a run that is really about a PR. This one outranks the sync: a
  rewritten plan under somebody's recorded pass makes their result unreadable.
- **The item is assigned to someone else** - step 5 already flagged that, and a no
  there covers this field too. Do not write to their field.
- **`--no-sync` and a plan is already there**, per above.

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
- **where the prose came from**: the branch's spec file, the loom report, or the
  diff because there was neither.

Then:

- **the PR**: URL, draft or ready and why, or that one was already open.
- **the sync**: which fields were written over and which were already right, with
  the replaced description, acceptance criteria and test plan quoted so the old
  text is readable here and not only in the item's revision history. Say
  `wit_list_work_item_revisions` is the undo path. Under `--no-sync`, the
  divergences you found and did not apply.
- **the gap check**: nothing on the item that the branch does not deliver, or the
  gap concretely, which answer Joey gave, and - if criteria were removed - those
  lines quoted in full, since the report is now the only place they exist.
- **the reviewer**: `dev-bot-laserfiche` requested, or not requested because the PR
  is a draft, or the real error.
- **the test plan**: drafted or refreshed into the item by `draft-test-plan`, or
  left alone because results were already recorded, or the real error.
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

Headless means no human is available for a gate: never stop for approval, take
the documented default below instead, decide as Joey would where a default runs
out, and surface a genuine blocker in the report rather than guessing past it.
Each of this skill's questions gets a default:

| Interactive gate | Headless default |
|---|---|
| Step 5 search turned up candidates | adopt one only if it is assigned to Joey, sits in `Cloud\Projects\Momentum`, and its criteria clearly describe this branch. Anything else: **create a new item** and name the candidates in the report |
| Step 5 item assigned to someone else | **stop.** Do not link a shared item to work nobody asked this run to do |
| Step 6 divergence | **sync it**, same as attended. This is the default posture, not a question, so headless needs no softening - but quote the replaced text in the report, because nobody watched it happen |
| Step 6 gap question | **stop.** No fields written, no PR. Removing a criterion is the one answer that destroys information, so it is never the unattended choice; name the gap in the report and let Joey pick |
| Step 6 sync on an item assigned to someone else | **stop**, per the row above on linking one at all |
| Step 9 test plan already written | refresh it, same as attended, unless Test Results are recorded |
| Step 9 recorded Test Results | leave the plan as it is and name it in the report |
| draft versus ready | **draft**, unless the invocation carried `--pr`. A headless run does not decide to ping reviewers, so it adds no label and no reviewer either |

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
  Step 6's gap question is the only path that can end with neither, and when it
  does it creates nothing on the way out.
- **The item is settled - found or created - before the PR**, so the body can
  carry the link `pr-metadata` requires.
- **Ready for review is opt-in; the PR itself is not.** Every run that gets past
  step 6's gap question opens a PR, and it is a draft unless the invocation carried `--pr`. The `to-be-translated` label
  and the `dev-bot-laserfiche` reviewer go on ready PRs only, and are added after
  creation, never as `gh pr create` flags.
- **A created item goes in as `Active`.** The work is done; a backlog column would
  be a lie.
- **The branch is the golden standard for how the work is described; never for
  whether a requirement exists.** Description, acceptance criteria and test plan
  are synced to what the branch delivers, and a divergence is applied without
  asking. A criterion, note or comment the branch does not deliver stops the run
  and asks: it is never reworded into something the branch does do, never dropped
  as a side effect of the sync, and only ever removed because Joey said to remove
  it. That asymmetry is the whole design: rewriting the description of shipped
  work costs nothing, and losing a requirement between a board and a merge costs a
  release.
- **Every field written over is quoted in the report.** A sync is silent on the
  board otherwise, and the item's revision history is not where somebody looks.
- **Never invent a work item link.** No id in the body that step 5 did not return
  or read.
- **An item that is not Joey's is not synced without asking**, and neither is its
  test plan. Adopting somebody's item is already a question in step 5; writing
  over their text is a second one.
- Only `en.json` is ever hand-edited in this repo, and not by this skill.
- No em dash, emojis, arrows, or box-drawing characters in anything written. The
  board and the PR are read by other people.
