---
name: review-forms-pr
description: Review a PA Forms / BPM pull request on three things and post the findings straight onto the PR as inline comments: regression risk, whether the tests actually cover the linked work item, and the design and maintainability issues a `/solidify` pass would raise. Takes a TFS PR link (PA repos live on v-dev-tfs, not GitHub). The first question is not "is this code good" but "what that works today could this break". Grounds itself in the PA Forms knowledge base at `C:\code\forms_agent_kb\`, maps the blast radius outside the diff (other callers, in-flight process instances, published BP/form versions, queued messages, customer custom JS, the print/STR path), then runs all three passes in-process (no subagents, no review plugin), verifies every finding against the real code, rates each one High / Medium / Low, then posts one inline thread per finding plus a summary thread. Every comment is signed as an AI review with the model that produced it. It never edits code. Invoke when the user hands over a TFS PR link for any PA Forms repo, or asks to "review this PR", "review this Forms/BPM PR", "what could this break", or "regression review".
---

# review-forms-pr Skill

You are a **senior PA Forms engineer reviewing someone's pull request**. The review
answers three questions, in this order:

1. **Regression risk.** What works today that this change could break, and how would
   we find out. This is the main goal and gets most of the budget.
2. **Tests for the work item.** Does the PR add tests that would fail if the fix were
   reverted, against what the linked work item actually asked for.
3. **Design and maintainability.** The `/solidify` pass: does each concept the change
   expresses have exactly one home, and the SOLID / DRY / superseded-code half beneath
   it.

Nothing else is in scope. Style, naming, formatting and taste are dropped unless they
cause a defect. A correctness bug you trip over on the way is still worth posting; it
does not need a pass of its own.

PA Forms is a long-lived, multi-service product with running process instances,
published BP and form versions, queued messages, and customers who wrote JavaScript
against the form DOM. Almost every real regression in it comes from **outside the
diff**. So does most of this review.

**The output is comments on the PR, not a chat report.** Given a PR link, this skill
works the change, then posts one inline thread per finding plus a summary thread,
directly onto the PR. Every comment is signed as an AI review and carries the model
that produced it, so nobody mistakes it for a human reviewer. It **never edits
code** and never approves or rejects the PR.

`--dry-run` (or "don't post", "just show me") prints the same comments in the chat
and posts nothing.

## The standing rules

These hold across all three passes.

- **Judge the change by its blast radius, not its diff.** The diff tells you what
  changed. The review is about everything that depends on what changed.
- **Every finding names a concrete consequence.** "This could be risky" is not a
  finding. Regression: "a BP instance published before this change stores `X` in the
  routing XML, and the new parser at `file.cs:120` throws on it". Tests: the
  assertion that stays green when the fix is reverted. Design: the next edit, and the
  files it touches today versus after.
- **Old data and old versions are first-class inputs.** In-flight instances,
  already-published forms, already-submitted submissions, messages already sitting
  on RabbitMQ during a rolling deploy.
- **Style is out of scope.** Naming, formatting, and taste get dropped unless they
  cause a defect. Five real findings on the PR beat thirty opinions.
- **Unverified means unposted.** Step 5 kills anything you could not confirm in the
  actual code. These comments are permanent and the whole team reads them.
- **This is someone else's PR.** They are trying to ship. A finding they cannot act
  on inside this PR belongs in the summary thread as a follow-up, not in a thread on
  their code.

## Step 0 - Resolve the PR and its diff

**The expected input is a TFS PR link**
(`https://v-dev-tfs.laserfiche.com/DefaultCollection/<Project>/_git/<repo>/pullrequest/<id>`),
or enough to identify one ("PR 12345 in bpm"). Anything else narrows what the skill
can do:

- **A local branch, a pasted diff, or a file list** - review it, but there is
  nowhere to post. Print the comments in the chat instead, and say why.
- **No PR and no diff** - ask for the PR link. Do not review from a description.

**PA Forms repos are on TFS, not GitHub.** `gh` does not work here. The TFS MCP
tools are what this skill runs on, both for reading and for posting - if they are
not connected, say so up front, because the posting step will not work:

- `mcp__tfs__repo_get_pull_request_by_id` - title, description, source/target
  branch, status, linked work items, reviewers
- `mcp__tfs__repo_get_pull_request_iterations` then
  `mcp__tfs__repo_get_pull_request_iteration_changes` - the changed file list
  (use the latest iteration)
- `mcp__tfs__repo_get_file_diff` - the patch per file
- `mcp__tfs__repo_get_file_content` - any file **in full** at the PR head
- `mcp__tfs__repo_list_pull_request_threads` - existing review comments, so you do
  not repeat what another reviewer already raised
- `mcp__tfs__wit_get_work_item` - the linked bug/story, which tells you what the
  change is *supposed* to do. A fix that does not match its work item is itself a
  finding, and its repro steps and acceptance criteria are what Pass 2 measures the
  tests against. Read it in full, including the repro steps and any attached comments.
  **If the PR links no work item, say so in the summary thread** and measure the tests
  against the PR description instead - it is a weaker spec and the review should say
  that.

**Keep the posting identifiers.** Step 6 cannot anchor an inline comment without
them, and re-fetching later wastes a round trip. Record now:

| Value | Where it comes from |
|---|---|
| `repositoryId` | `repo_get_pull_request_by_id`, or `repo_get_repo_by_name_or_id` |
| `pullRequestId` | the link |
| `project` | the table below - **required** on this on-prem TFS |
| `iterationId` | the **latest** iteration from `repo_get_pull_request_iterations` |
| `changeTrackingId` **per file** | `repo_get_pull_request_iteration_changes` for that iteration |
| PR `status` | `repo_get_pull_request_by_id` - see the posting guard in Step 6 |

These tools need the **project** name, and it is not always `Cloud`:

| Repo | TFS project |
|---|---|
| `bpm`, `site-app-forms`, `site-app-bp-designer`, `site-app-bpm`, `site-app-forms-monitoring`, `site-app-tasks`, `site-app-documents`, `site-app-reports`, `svc-app-renode`, `svc-app-pdf-rasterization`, `svc-app-signalr`, `svc-app-users`, `svc-pa-platform`, `forms-layout`, `lf-angular-packages` | `Cloud` |
| `site-app-home`, `site-app-wf-frontend`, `svc-app-direct-approval`, `page-layout-designer`, `process-automation` | `WF` |
| `forms-cypress-tests`, `forms_agent_kb` | `Forms Process Automation` |

Confirm with `mcp__tfs__repo_get_repo_by_name_or_id` if a repo is not listed.

**Fallback when the TFS MCP is not connected.** Most PA repos are cloned under
`C:\code\<repo>`. Work read-only - these are the user's working checkouts, so never
switch branches, check out the PR, stash, or reset:

```bash
git -C "C:/code/<repo>" fetch origin <sourceBranch> <targetBranch>
git -C "C:/code/<repo>" diff --name-only origin/<targetBranch>...FETCH_HEAD
git -C "C:/code/<repo>" diff origin/<targetBranch>...FETCH_HEAD -- <path>
git -C "C:/code/<repo>" show FETCH_HEAD:<path>          # a changed file in full
```

If neither path is available, say so and ask for the diff rather than reviewing
from the PR description.

**Always read changed files in full, not just the hunks.** A hunk hides the method
it sits in, and the regression is usually in the part that did not change.

## Step 1 - Load the knowledge base

The PA Forms knowledge base at `C:\code\forms_agent_kb\` is the source of truth for
how the product behaves. Read `index.md` first, then
`domain-knowledge/feature-map.md` to map each changed path to its feature and
service, then pull only the architecture files the change touches:

| Changed area | Load |
|---|---|
| `bpm/Src/RoutingEngine/`, `Src/Processors/`, `Src/Reaction/` | `architecture/bp-runtime-architecture.md`, `architecture/bp-definition-xml-structure.md` |
| `bpm/Src/Forms/` (submission, drafts, validation, attachments) | `architecture/fields-architecture.md`, `architecture/rtf-architecture.md` |
| `bpm/Src/Forms/FormsGeneratorCtrl/`, `site-app-forms` print paths | `architecture/str-architecture.md`, `architecture/rtf-architecture.md` |
| `bpm/Src/AppServices/`, `Src/BusinessRules/` | `architecture/rules-architecture.md` |
| `bpm/Src/Analytics/`, report controllers, `site-app-reports` | `domain-knowledge/overview.md` (Custom Reports), `architecture/monitoring-architecture.md` |
| `forms-layout`, `page-layout-designer`, `site-app-bp-designer` | `architecture/forms-layout-architecture.md`, `architecture/fields-architecture.md` |
| `site-app-forms-monitoring`, `site-app-bpm` monitor | `architecture/monitoring-architecture.md` |
| `svc-app-renode`, `svc-app-pdf-rasterization` | `architecture/str-architecture.md`, the matching `architecture/server-logs/*.md` |
| `svc-app-direct-approval`, direct approval paths in `bpm` | `architecture/direct-approval-architecture.md` |
| Anything crossing two services | `architecture/system-architecture.md` |

Where the knowledge base contradicts your instinct about how PA behaves, the
knowledge base wins. It is your grounding, not something the posted comments mention -
state the PA behavior itself, never the KB file it came from.

## Step 2 - Map the blast radius before you look for bugs

Write this down first. It scopes everything after it.

1. **The changed public surface.** Every method, endpoint, DTO field, enum value,
   config key, DB column, S3 path, queue message shape, CSS class, and DOM
   structure the PR touched, added, or removed.
2. **Who depends on each one.** For C# in `bpm`, grep the whole repo for the symbol
   plus its interface. For TypeScript/Angular, load the LSP
   (`ToolSearch("select:LSP")`) and use `findReferences` / `incomingCalls`, then
   **also grep** - the LSP does not see `.html` templates or dynamic lookups, so
   its list is a floor, not the list.
3. **What crosses a service boundary.** Use `architecture/system-architecture.md`.
   A shape that travels over RabbitMQ, SQS, Redis, the renode callback, or the
   internal signed-token API is consumed by a **separately deployed** service.
4. **What is persisted.** Postgres columns, routing XML, form DC JSON, S3 keys,
   Redis keys. Persisted shapes outlive the deploy, so old rows must still parse.
5. **What is customer-visible surface.** The `LFForm` JS API, form DOM and CSS
   classes, public REST endpoints, email content, PDF output. Customers write
   custom JS and CSS against these.

Output a short list: *changed thing -> who consumes it -> is that consumer in this
PR*. Anything with a consumer outside the PR is where the review concentrates.

## Step 3 - The PA Forms regression hazard checklist

Walk this list against the blast radius. For each row, either rule it out in one
line or open a finding. Do not skip rows silently.

### Versioning and old data

| Hazard | What to check | Reference |
|---|---|---|
| **In-flight process instances** | Instances are running right now against the code being changed. Can a routing change, a variable-shape change, or a new required field strand an instance mid-process, or make its next step throw? | `bp-runtime-architecture.md` |
| **Published BP versions** | A published BP pins its definition XML. Does the new code still parse and route XML produced by the old designer? Are new `routingObj` fields optional? | `bp-definition-xml-structure.md` |
| **Published form versions and past submissions** | Form DC JSON and stored submissions were written by older code. Does a schema change break loading an old submission, an old draft, or a reprint of a year-old form? | `forms-api-catalog.md`, `FormVersionHandler.cs` |
| **Enum and status values** | A new enum member serialized into the DB or a queue message is unreadable by the old code still running during a rolling deploy, and old values must still deserialize. | `bp-api-catalog.md` |
| **DB migrations** | Is a migration required and present? Is it backward compatible with the previous release running against the same database? | `system-architecture.md` |

### Cross-service and async

| Hazard | What to check | Reference |
|---|---|---|
| **Mixed-version deploy window** | BPMAPI, BPM Server, the site-apps and the svc-apps deploy separately. A message queued by the old producer must still be handled by the new consumer, and the reverse. Renaming or requiring a payload field breaks this. | `system-architecture.md` |
| **Queue retry and idempotency** | RabbitMQ and SQS redeliver. Does the change make a retried message double-write, double-email, or double-save to the repository? | `server-logs/bpmserver-log-architecture.md` |
| **STR / render pipeline** | Anything touching form HTML, CSS, fonts, page size, or `PrintController` changes what renode's headless Chrome produces, which changes the saved PDF and its rasterization. None of that shows up in the browser. | `str-architecture.md`, `server-logs/renode-log-architecture.md` |
| **Redis locks and cache keys** | A changed key format silently splits the cache or drops a lock, which shows up as duplicate processing under load, not as an error. | `server-logs/bpmserver-log-architecture.md` |
| **Timeouts and retry policy** | Changing a timeout or a Polly policy shifts load onto the next service. Check `STRPollyRetry.cs` and the render timeouts. | `str-architecture.md` |

### Forms behavior

| Hazard | What to check | Reference |
|---|---|---|
| **Classic vs Modern forms** | Two generators and two renderers. A fix applied to one usually needs the other, or needs to be proven not to reach it. `PrintType` decides the path. | `fields-architecture.md` |
| **Field rules and hidden data** | Show/hide rules, rule priority, and whether hidden field data is kept or cleared. Changes here silently alter what gets submitted. | `fields-architecture.md` |
| **Collections and tables** | Repeating sections behave differently from plain fields on lookups, validation, reports, and export. Custom Reports do not support them at all. | `fields-architecture.md` |
| **Lookup rules and fill modes** | Replace vs Append, chained lookups, client-side trigger timing. A change to the lookup response shape breaks fills that looked fine in the designer. | `rules-architecture.md` |
| **RTF images** | Images migrate from `TemporaryFiles/` to `FormsSubmissions/` on submit. A change to URL handling, the scan regex, or S3 paths orphans images, and does it differently for old and new submissions. | `rtf-architecture.md` |
| **Customer custom JS and CSS** | The `LFForm` API, DOM structure, and CSS class names are a de facto public contract. Renaming a class or reshaping the DOM breaks customer forms with no compile error anywhere. | `forms-layout-architecture.md` |
| **Direct approval** | Encrypted link payloads, link expiry, and the validation constraints. An encryption or validation change invalidates links already sitting in users' inboxes. | `direct-approval-architecture.md` |

### Data correctness and scale

| Hazard | What to check | Reference |
|---|---|---|
| **Swallowed failure** | A caught exception in the routing engine or a processor does not surface to the user, it strands the instance. Silent failure here is worse than a crash. | `bp-runtime-architecture.md` |
| **Performance at real data sizes** | Collections of 400+ rows, lookups returning 200+ rows, exports over large submission sets. Does the change add per-row work, an N+1 query, or a full RoutingXML fetch? | `qa-conventions.md` |
| **Tenancy and permissions** | Does the change widen what a user or `ProcessAutomationUser` can see or do? Is a tenant filter still applied on every new query path? | `system-architecture.md` |
| **Culture, timezone, encoding** | Dates, numbers, and currency in form values, email tokens, routing conditions, and report exports. | `fields-architecture.md` |
| **Feature flags** | Is the change behind a flag, and is the flag-off path still correct? A flag that guards only half the change is a finding. | `direct-approval-architecture.md` (worked example) |

## Step 4 - The three passes

**No subagents, no review plugin.** The regression lens is the blast radius from
Step 2 plus the PA behavior from Step 1, and both of those live in this context. An
agent that does not have them reviews the diff in a vacuum and reports style, which
is what gets dropped anyway. Work the change here, in this session.

Run the passes in order. Pass 1 gets most of the budget, Pass 3 the least: on someone
else's PR a design comment is the easiest one to get wrong and the most annoying one
to receive.

### Pass 1 - Regression risk (the main goal)

Take the Step 3 hazard checklist and walk it against the blast radius from Step 2,
not against the diff top to bottom.

For each hazard row the blast radius makes relevant:

- Read the code that would break, at the PR head, in full.
- Either **rule it out in one line** (keep these - they go in the summary thread as
  hazards cleared) or **open a finding** naming the concrete old data, old version,
  or concurrent state that breaks it.
- Do not skip a relevant row silently. A row you could not check is "not covered",
  not "clear".

Work the highest-consumer areas first: anything from Step 2 with a consumer outside
the PR. If the change spans more subsystems than you can cover properly, cover the
ones with the most outside consumers and list the rest under "Not covered".

### Pass 2 - Tests for the work item

The question is not "is there coverage". It is **"if someone reverted the fix and
left the tests, would the suite go red"**. A test written against the new
implementation's shape passes either way and is worse than no test, because it reads
as covered.

Re-read the linked work item first - its repro steps, its acceptance criteria, the
customer scenario. That is the spec the tests are measured against, not the diff.

Then:

1. **Find the tests this PR added or changed.** PA tests live in the repo's own unit
   test projects, plus `forms-cypress-tests` and `FormsAutoTestTemplates`. A PR with
   no test files is not automatically a finding - work out first whether the change
   is testable at all.
2. **Map criterion to test.** One line per repro step or acceptance criterion: the
   test that covers it by `path:line`, or "none".
3. **Ask the revert question of each one.** Read the assertion. Does it assert the
   **reported behavior**, or the shape of the new code? Name the line that makes it
   pass either way when it does.
4. **Check what a test could pin from Pass 1.** Old-version parsing, an enum that must
   still deserialize, a retried message that must not double-write. These are the
   regression tests that stop the same bug coming back.
5. **Say what cannot be automated.** STR/PDF output, renode rendering, customer custom
   JS and CSS, email content, anything needing a published BP version. That is not a
   finding - it goes in the manual verification plan in the summary thread.

| What you found | Rating |
|---|---|
| No test for the reported bug, and the bug is automatable | Medium. **High** when this bug has regressed before, or the fix is a single condition a future edit will silently undo. |
| A test that passes against the pre-fix code | Medium. Quote the assertion and say why it passes either way. |
| An acceptance criterion with no test | Medium; Low when it genuinely needs a human and is named in the manual plan. |
| Happy path only, none of the Pass 1 hazards pinned | Low, with the specific cases named. |
| Nothing here is automatable | Not a finding. Manual verification plan. |

Cap at **three** test findings on the PR. Fold the rest into the summary thread's
tests block.

### Pass 3 - Design and maintainability (the solidify pass)

**Read [`../shared/structural-bar.md`](../shared/structural-bar.md) first.** It is
binding and must not be paraphrased from memory: it carries the structural altitude,
the pair-discovery frame, the ten tells, the seven-rule bar and the not-a-finding
list. This section carries only what changes when the target is **someone else's PR
on TFS** rather than your own branch.

Discovery is the pair frame, not a subsystem read. For each unit the PR introduced or
substantially rewrote, find its nearest sibling with the three searches (same folder,
other consumers of something shared it imports, its distinctive vocabulary grepped
repo-wide), write the pair table, then diff each pair part by part. Then the axis
check over the branch's own flags and discriminants.

Four things differ here:

- **Greps need the clone.** The pair searches are greps across the whole repo, and
  the TFS MCP cannot do that. With only MCP access, run the frame over the changed
  files and their declared siblings, and **say in the summary thread that pair
  discovery was limited to the diff**. Do not present a partial search as a complete
  site list - bar rule 3 is exhaustive or it is not a finding.
- **The bar and the veto both still gate, unchanged.** The seven-rule bar for
  structural findings; the over-engineering veto for maintainability ones (one call
  site raises the bar and does not close the door, one implementation means no
  interface, two is a note and three is a finding, the fix must pay for what it adds,
  no pattern names as justification, the repo's existing pattern wins, every finding
  traces back to what this change did). The full text is in
  [`../solidify/SKILL.md`](../solidify/SKILL.md). **PA repos are old and internally
  consistent** - a finding asking this PR to be the one file in the subsystem doing it
  differently is a wrong finding, and that rule does more work here than anywhere.
- **Budget: at most one structural finding and two maintainability findings.** If you
  have more, you have either misjudged the branch or found a design conversation, and
  a PR comment thread is the wrong place for that. Say so in the summary instead.
- **A rewrite is not a PR comment.** Bar rule 5 already downgrades anything you cannot
  stage. Here it goes further: if the fix cannot land in this PR, it does not get an
  inline thread. One line in the summary thread suggesting a follow-up work item, and
  move on. The author is trying to ship a fix.

The maintainability half runs off the reads you already did, with no second sweep.
Solidify's dimension table (`../solidify/SKILL.md`, Phase E) is the full list. On a PA
PR the four that actually land are:

- **Superseded code left behind.** The old method, endpoint, route, config key or
  classic-forms branch the fix replaced but did not remove. Zero live references is a
  deletion finding; **live references on both paths is the worse one** - say which.
- **Coupled constants.** A literal whose correctness depends on matching a value
  somewhere else: a timeout under its caller's, a Redis or cache key spelled twice, a
  page size matching the renode setup, a limit matching a DB column.
- **Substitutability.** A new override or implementation that lies about its
  contract - throws `NotSupportedException`, silently no-ops, narrows what the base
  accepts - where a caller can reach it through the base type.
- **DRY at three sites or more**, or two where the copies must agree to stay correct.

Rank them with superseded code first: it is cheap to fix and two live paths mislead
everyone who debugs this next. **Test design is Pass 2's** - do not review it here.

## Step 5 - Verify, then rate

A first pass produces plausible findings that are wrong. Take every finding from all
three passes and confirm it against the code before it goes anywhere near the PR:

- Read the actual lines, at the PR head, with surrounding context.
- Confirm the consumer a finding assumes exists actually exists (grep for it).
- Confirm the behavior claim against the knowledge base, not memory.
- Confirm the finding is caused by **this PR** and is not pre-existing. Pre-existing
  problems go in a separate "already broken, not this PR" section, or get dropped.
- Drop duplicates. The three passes often reach the same line from three directions -
  a flag that travels (Pass 3) is frequently the same defect as an untested mode
  (Pass 2) and a hazard nobody ruled out (Pass 1). Post it once, as the highest-rated
  of the three, and say the other two things in that one comment.

Anything you cannot confirm is either dropped or posted as an **open question** for
the author, clearly labelled as unverified and rated Low. Never present a guess as a
defect - it is going on the PR where the whole team reads it.

**Then rate every surviving finding.** The rating goes in the comment title and
drives the order things get posted:

| Rating | Means | Test |
|---|---|---|
| **High** | Ships broken. A concrete scenario where working behavior breaks, data is wrong or lost, an instance strands, or a customer-visible contract breaks. | You can name the exact input, old version, or timing that breaks, and point at the line that does it. |
| **Medium** | Real risk, narrower. A conditional break, a missing regression test for the bug being fixed, an unhandled edge on a path that will be hit, a hazard the change opens but does not itself trigger. | You can name the scenario, but it needs a specific configuration, or the damage is recoverable. |
| **Low** | Worth a look. No known breaking scenario - a maintainability point that cleared the veto, or an unverified open question for the author. | If you cannot state what breaks or what it costs later, it is Low or it is dropped. |

Rate on **consequence, not confidence**. A verified break with a narrow trigger is
still High. If confidence is what is low, say so in the comment or drop the finding.

**Two ceilings, so the main goal stays visible:**

- **A design finding never rates High.** High means it ships broken, and shape does
  not. A structural finding that clears all seven bar rules is Medium; everything else
  from Pass 3 is Low.
- **A test finding rates High only** when the bug has regressed before, or the fix is
  a single condition a future edit will silently undo. Otherwise Medium.

**Per-pass caps on what gets posted inline:** regression takes what it needs, tests
three, design three (at most one structural). Anything over a cap goes into the
summary thread as a list.

## Step 6 - Post the comments

Posting is the point of this skill. Do it without asking - the user invoked it on a
PR link, which is the instruction. Two exceptions where you stop and ask first:

- The PR is **not Active** (completed, abandoned, or already merged).
- The run produced **more than 15 findings**. That is a signal the review is
  noisy, not thorough. Cut to the 15 highest-consequence, fold the rest into the
  summary thread as one list, and say you did.

`--dry-run` prints the same comments in the chat and posts nothing.

### Before posting: do not repeat yourself

Read `mcp__tfs__repo_list_pull_request_threads` first.

- If a **human reviewer** already raised a point, drop it. They got there first.
- If a **previous run of this skill** posted a thread (recognise it by the
  `AI review` signature line, or `AI regression review` on a thread from before this
  skill covered three passes), do not post it again. If the finding is
  still live on new code, reply in that thread with
  `mcp__tfs__repo_reply_to_comment` instead of opening a second one. If the finding
  is gone, leave the thread alone - the author resolves it.

### The summary thread (post this first)

One thread with no `filePath`, so it lands on the PR overview. This is where the bot
identifies itself:

```markdown
## AI review

Automated review by **Claude Code**, model `<exact model id>`, run <YYYY-MM-DD>.
This is a bot, not a human review - every comment is a suggestion to verify, and any of them can be
wrong. Resolve or dismiss them like any other thread.

**Verdict.** <one line: what the change does, and the overall read on each of the three: regression risk, tests, design>

**Posted.** High: n · Medium: n · Low: n  (regression n / tests n / design n)
**Scope.** N files across <subsystems>. Diff read at iteration <n>.

### 1. Regression risk

| Area at risk | Blast radius | Risk |
|---|---|---|
| e.g. STR PDF output | every BP with a Save to Repository step | High |

**Hazards checked and cleared.** One line per relevant Step 3 hazard that came back clean. This is what
tells the author the review was actually thorough.

### 2. Tests for <work item id>

**Verdict.** <covered / gaps / none> - one line.

| Acceptance criterion or repro step | Test | Would it fail before the fix |
|---|---|---|
| e.g. Submitting a draft with an RTF image keeps the image | `FormsSubmissionTests.cs:214` | Yes |
| e.g. Reprinting a 2023 submission | none | - |

**Tests worth adding.** The specific regression cases, named.

**Manual verification plan.** What a human should run before this merges: the setup, the action, the
expected result. Everything from Pass 2 that cannot be automated lands here.

### 3. Design

One or two lines: does the shape hold. Name any structural concept with a second home, and say plainly
when the honest answer is "fine, and here is the one thing to watch". Anything too big to land in this
PR goes here as a suggested follow-up work item, not as an inline thread.

**Not covered.** Subsystems skipped, files that could not be read, checks that failed, and whether pair
discovery reached the whole repo or only the diff. Say it plainly - silence reads as "checked and clean".
```

The **model id** must be the one actually running this session, quoted exactly (the
session states it, for example `claude-opus-5`). Never guess a version. If you
genuinely cannot tell, write `Claude Code` with no model and say so.

### One thread per finding

Three shapes, one per pass. All three carry the rating in the title and the signature
line at the bottom.

**Regression finding**

```markdown
**[AI review · High]** <one-line title>

**What breaks.** The concrete scenario, in the order it happens.
**Why.** The code path, quoting the lines that prove it.
**Evidence.** `path/file.cs:120`, the consumer outside this PR, the behavior it depends on.
**Suggested direction.** What to change and what to watch out for. No patch.

<sub>AI review · model `<exact model id>` · verify before acting</sub>
```

**Test finding** - anchored on the code that is not covered, not on the test file.

```markdown
**[AI review · Medium]** <one-line title>

**Not covered.** The acceptance criterion or repro step from <work item id>, in its own words.
**Why it matters.** What reverting this line would do, and what would stay green if it did.
**Evidence.** The test that looked like it covered this and does not, by `path:line`, with the assertion quoted. Or "no test found", and where you looked.
**Suggested test.** The case, in one sentence: setup, action, expected. Say if it needs a manual check instead.

<sub>AI review · model `<exact model id>` · verify before acting</sub>
```

**Design finding** - Medium at most, and only if the fix can land in this PR.

```markdown
**[AI review · Medium]** <one-line title>

**The concept.** The idea in one noun phrase, and the homes it now lives in.
**Where it lives.** Every site, `path:line`. Say whether the list came from a repo-wide grep or only the diff.
**Price of the next change.** The realistic next edit to this area: files it touches today, files after.
**Suggested direction.** The target shape, and the first stage that compiles on its own.
**The case for leaving it.** The strongest argument against this finding, stated fairly.

<sub>AI review · model `<exact model id>` · verify before acting</sub>
```

Rules for the comment body:

- **Rating in the title**, every time: `[AI review · High]`, `[AI review · Medium]`,
  `[AI review · Low]`.
- **Signature line on every comment**, not just the summary. Someone reading one
  thread in isolation must be able to tell a bot wrote it.
- **No internal tooling detail in a posted comment.** The model id is the only
  machinery a reader gets. Never name the skill, the knowledge base or its files, or
  which tool found the issue. Say what breaks and where in
  the product code; where the grounding came from is not the author's problem.
- Write it the way the user's `CLAUDE.md` says to write: short, plain, no em dashes,
  no filler, no praise, no closing restatement. Four labelled lines and stop.
- **Low findings get two lines**, not the full shape. Title, what to look at, why.
- Ask, do not accuse. "Does an instance published before this still route here?"
  reads better than "this breaks published instances" when a human wrote the code
  and you might be wrong.
- Never claim you ran or verified something you did not.

### Anchoring the thread

Post with `mcp__tfs__repo_create_pull_request_thread`:

| Field | Value |
|---|---|
| `repositoryId`, `pullRequestId`, `project` | from Step 0 (`project` is required on this on-prem TFS) |
| `content` | the comment body above |
| `filePath` | the changed file, repo-relative |
| `rightFileStartLine` | the line in the **new** file the finding sits on (1-based). `rightFileEndLine` defaults to it for a single-line comment |
| `iterationId` | the latest iteration - **required**, or the comment lands in the wrong place |
| `changeTrackingId` | that file's id from `repo_get_pull_request_iteration_changes` - **required** for inline positioning |
| `status` | `Active` for all ratings. Let the author resolve |

Anchor on a line **the PR actually changed**. When the finding is about a consumer
outside the diff, an old data shape, or the change as a whole, there is no line to
anchor to: anchor it on the changed line that causes it and name the other
`file:line` in the Evidence line. If a file has no usable anchor, put the finding in
the summary thread rather than dropping it.

Post High first, then Medium, then Low, so the order in the PR reflects the order to
read them.

### If a post fails

Report which findings did not post and why, and print those comment bodies in the
chat so the work is not lost. Do not silently drop them, and do not retry the same
call more than once.

## Step 7 - Report back

In the chat, keep it to a few lines: one line each for the three verdicts (regression
risk, tests, design), the counts by rating, one line per High finding, a link to the
PR, and anything that failed to post. The detail lives on the PR now - do not paste
the whole review back.

**Optional, only when asked.** If the PR is the user's own branch and they ask for
the fixes to be applied, drive it with the shared turn-by-turn loop
([`../shared/turn-by-turn-loop.md`](../shared/turn-by-turn-loop.md)) - one finding per
turn, a subagent applies the minimal fix, the human keeps or reverts. This skill does
not edit code on its own.

## Behavioral guidelines

- **The knowledge base is the anchor.** Ground every PA behavior claim in
  `C:\code\forms_agent_kb\`. If the KB says something you did not expect, the KB
  wins. If the PR proves the KB wrong, tell the user - that is a KB update, per its
  `AGENTS.md`. Keep the KB out of the posted comments; it grounds you, it is not
  something the author reads.
- **Always sign the bot.** Every comment carries the `AI review` signature and the real model
  id, and nothing else about how the review was produced. Never post an unsigned
  comment, never inflate what the review did, and never name a model you are not
  running on.
- **A comment is public and permanent.** Post fewer, better findings. A wrong High
  costs the author an afternoon and costs the next review its credibility.
- **Read files in full.** Reviewing hunks is how a reviewer misses the caller two
  methods down.
- **Never touch the working tree.** The `C:\code\*` clones hold the user's own work.
  Read-only git only: `fetch`, `diff`, `show`, `log`.
- **Say what you did not cover.** A subsystem you skipped, a hazard row you could
  not check, a file you could not read. Silence reads as "checked and clean".
- **Keep the three in proportion.** Regression is the main goal. A review that posts
  one regression finding and five design notes has answered the easier question, which
  is the failure mode both this skill and `/solidify` are written against.
- **Be short.** Five real regressions land. Thirty findings of mixed quality get
  skimmed and ignored.
