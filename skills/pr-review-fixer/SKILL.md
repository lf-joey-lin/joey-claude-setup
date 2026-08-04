---
name: pr-review-fixer
description: Work through the review comments on an open pull request one at a time, with a human in the loop. Takes a PR link or number, gathers the inline and summary comments left by other reviewers, then runs one concurrent analysis subagent per file that judges each comment (agree or disagree) and drafts its patch without applying it. The human gates the whole list in one pass with the real drafted diffs in front of them, the verdict setting each comment's default, and accepted patches are then applied file by file with a single keep/commit/revise/revert question each. Verification runs once at the end, not per comment. Progress is tracked in a per-PR markdown state file under ui-app/logs. Invoke when the user types /pr-review-fixer, or asks to "address PR review comments", "go through the review feedback", "fix reviewer comments on PR <n>", or hands over a PR link and wants the review threads worked one by one.
---

# pr-review-fixer: work review comments one at a time, human in the loop

Drive a pull request's review feedback to resolution, one comment at a time. The
comments come from **other reviewers** (never the PR author's own). One analysis
pass, a subagent per file running concurrently, judges each comment on its own
merits and drafts the patch it would apply. The human then gates the whole list in
one pass with the real drafted diffs in front of them, the analysis verdict setting
each comment's default (agreed accepts, contested skips, flip either way). Accepted
patches are applied file by file, each with a single keep / commit / revise /
revert question. The orchestrator records every outcome in a state file, and the
full typecheck / lint / test pass runs once at the end.

The code is read **once per file, for the whole run**. Nothing downstream
re-derives what the analysis pass already produced - that duplication, plus running
a whole-project verification per comment, is what makes a naive version of this
loop crawl.

**This skill runs on the shared turn-by-turn loop.** Read
[`../shared/turn-by-turn-loop.md`](../shared/turn-by-turn-loop.md) first - it owns
the orchestrator model, the state-file mechanics, the file-grouped work unit, the
section 1 bulk gate, the combined per-item disposition, and the verify-once rule
(section 3a). This file supplies the five host hooks the loop leaves open: the work
list (section 1), the state-file path (section 2), the per-file subagent task
(section 3), the verification commands (section 4), and wrap-up plus the GitHub
outward actions (section 5).

## Invocation

```
/pr-review-fixer <pr-url-or-number>
```

- Accepts a full GitHub PR URL, or a bare PR number (resolve against the current
  repo - org `Laserfiche`, repo `momentum`).
- If no argument is given, ask for the PR. Do not guess from the current branch
  unless the user confirms it.

## 1. Work list - resolve the PR and gather comments

Resolve owner / repo / number, then pull the review feedback. Use `gh`.

Basic metadata (author, branch, state):

```bash
gh pr view <pr> --json number,title,author,headRefName,baseRefName,url,state
```

The author's login is the **exclude list** - never treat the author's own
comments as review feedback to address.

Inline review-thread comments with file, line, resolved state, and threading come
from GraphQL (the REST `pulls/{n}/comments` endpoint does not expose resolved
state or thread grouping):

```bash
gh api graphql -f query='
query($owner:String!, $repo:String!, $number:Int!) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100) {
        nodes {
          isResolved
          isOutdated
          comments(first:50) {
            nodes { author { login } body path line originalLine diffHunk url createdAt }
          }
        }
      }
    }
  }
}' -F owner=Laserfiche -F repo=momentum -F number=<number>
```

Also capture review summary bodies and general PR (issue) comments, which often
carry feedback that is not tied to a line:

```bash
gh api repos/Laserfiche/momentum/pulls/<number>/reviews \
  --jq '.[] | select(.body != "") | {author:.user.login, state:.state, body:.body, url:.html_url}'
gh api repos/Laserfiche/momentum/issues/<number>/comments \
  --jq '.[] | {author:.user.login, body:.body, url:.html_url}'
```

Then filter into the work list:

- **Exclude** the PR author, and bots (`login` ending in `[bot]`, e.g.
  `github-actions[bot]`, coderabbit, dependabot) unless the user asks to include a
  specific bot's feedback.
- **Skip resolved threads by default** - note the count, and ask the user if they
  want resolved/outdated ones included. Outdated (the code moved) threads are worth
  a quick look but flag them as such.
- For a thread with a back-and-forth, the actionable item is usually the first
  comment plus any follow-up that changes the ask; keep the whole thread's text so
  the subagent has context.
- Keep each comment's reviewer as a field on it. The work is grouped by file, not
  by reviewer (see below and section 2).

**Pre-analysis - judge each comment and draft its patch, in one pass.** Get an
independent read on every gathered comment so the human is not rubber-stamping raw
feedback. This is the **only** pass that reads the code: it produces everything the
gate and the apply step need, so nothing downstream re-reads the same files.

Group the gathered comments **by file**, and spawn one analysis subagent per file,
handling every comment on that file. These are read-only and each owns a distinct
file, so run them **concurrently**. Comments not tied to a file (review summary
bodies, general PR comments) group into one further subagent. Seed each with its
file's comments verbatim, their `file:line`s, diff hunks, and threads.

Each returns, **per comment**:

- A verdict, **agree** (a real issue worth changing) or **disagree** (a misread,
  already handled, or not worth doing), with a 2-4 sentence rationale citing
  `file:line`.
- The CODE CONTEXT block: the current code the comment concerns, as a fenced,
  language-tagged block (```vue etc.), enough surrounding lines to be
  self-contained (the whole function / block / element), each line prefixed with
  its real line number.
- For an **agree**, a **proposed patch**: the smallest correct change, as a fenced
  ```diff block against the current file, matching the surrounding style and repo
  conventions (Nuxt UI over custom, i18n no hardcoded strings, theming tokens no
  hardcoded hex, data-testid conventions, SOLID). **Drafted, not applied** - the
  subagent makes no edit to the working tree.
- Whether its patch **overlaps** any other patch it drafted for the same file
  (same or adjacent lines). The human may accept only a subset at the gate, so
  each patch must stand alone or say that it does not.

The verdict, context, and patch carry straight into the gate and the apply step
(section 3). The code is read once per file, for the whole run.

**Gate everything in one pass.** Agreements and disagreements go to the human
together, in the shared loop's single section 1 bulk gate - not as a disagreement
round followed by a second gate. The verdict sets each comment's **default**, which
is what the two-stage version was really encoding:

- Analysis **agreed** - defaults to **accept**. Reviewer comments carry no severity,
  so there is no priority ranking to apply.
- Analysis **disagreed** - defaults to **skip**, recorded as `[!]` wont-fix with
  the analysis rationale if the human leaves it there.

State the totals first: how many actionable comments, from which reviewers, how
many the analysis contested, and how many resolved/bot were filtered. Present each
with its reviewer, `file:line`, thread text, the verdict and rationale, and **the
drafted patch**. Showing the real diff at the gate is the point of drafting it
early - the human judges the actual change, not a description of one.

The human flips any item in either direction, so accepting a comment the analysis
disagreed with is one toggle rather than its own question. Only if a contested
comment genuinely needs discussion (the human asks, or the rationale turns on
something only they know) fall back to a follow-up `AskUserQuestion` for that one
comment.

## 2. State-file path

One state file per **PR**, under the gitignored logs folder:

```
src/ui-app/logs/pr-<number>-review.md
```

The scope is the PR, not the reviewer, because two reviewers routinely comment on
the same file and the work is grouped by file (section 3). A per-reviewer file
would split one file's edits across two state files.

Follow the shared loop's state-file template and resume rules. Reviewer comments
carry no severity, so leave the template's `Priority` as `-` (every comment
defaults to accept at the gate). Add these PR-specific fields to each item entry:
`Reviewer` is the login, `Location` is the `path:line` with an `(outdated: yes/no)`
note, `Thread` is the comment URL, and `Analysis` is the pre-analysis verdict
(agree, or accepted-over-disagreement) plus its drafted patch.

Group the `## Items` list by file, matching the order section 3 applies them in, so
a resumed run picks up where it left off without regrouping.

If the human wants one reviewer's comments handled first, apply that as a **filter
at the gate** (skip the others for now), not as a second state file.

## 3. Apply the accepted patches

Section 1 already produced a drafted patch for every accepted comment, so the
default path spawns **no further subagent**. Applying a diff another agent wrote is
mechanical, and the shared loop's invariants allow the orchestrator to do it
directly.

Work file by file, and within a file in list order:

1. Mark the comment `[~] in progress` and apply its drafted patch to the working
   tree with `Edit`.
2. Show the human the CODE CONTEXT from section 1, the reviewer comment, and the
   **real** applied diff from `git diff -- <path>` - not the drafted patch echoed
   back. Confirming what actually landed is what makes this safe to skip a
   re-reading agent.
3. Drive the disposition with the shared loop's single combined `AskUserQuestion`
   (keep / keep and commit now / revise / revert) and record the outcome per the
   shared loop's section 4. On revert, undo with `git checkout -- <path>`.

**Respawn a fix subagent only when the drafted patch is not usable**, which is the
exception, not the rule:

- The patch does not apply cleanly (the file moved under it, or the human accepted
  only part of an overlapping set that section 1 flagged as overlapping).
- The human chose **revise**.
- The comment was accepted over the analysis's disagreement, so no patch was
  drafted.

In those cases spawn one synchronous `general-purpose` subagent for that file,
seeded with only the affected comments plus the section 1 verdict, context, and any
revise direction:

> You are applying review-comment fixes to ONE file in the momentum repo
> (`src/ui-app`): `<path>`. Do not touch anything these comments do not concern.
>
> For each comment below you are given the reviewer's text, the diff hunk it was
> left on, the pre-analysis verdict, and the code context as of analysis.
> <per-comment blocks: reviewer, file/line and outdated flag, diffHunk, verbatim
> thread, verdict, drafted patch if any, revise direction if any>
>
> Do:
> 1. Read the current code. These comments were already judged in pre-analysis and
>    cleared by the human, so do not relitigate them - confirm each still holds
>    against the current code (it may have moved) and apply the smallest correct
>    change. Only if the code changed enough that a comment no longer applies,
>    report that one INVALID and make no change for it. Explain each in 2-4
>    sentences citing `file:line`.
> 2. Match the surrounding style and repo conventions (Nuxt UI over custom, i18n
>    no hardcoded strings, theming tokens no hardcoded hex, data-testid
>    conventions, SOLID). Apply to the working tree.
> 3. Show the exact result as a fenced ```diff block from `git diff -- <path>`
>    (unified diff, `-`/`+` lines intact). If nothing changed, say so explicitly.
> 4. Run ONLY `npx eslint --fix <path>` and report its real output. Do NOT run
>    typecheck, the test suite, or a build - the orchestrator runs those once at
>    wrap-up. Reporting "deferred to wrap-up verification" is correct here; never
>    claim a check you did not run.
>
> Do NOT commit, push, post to GitHub, resolve the thread, or touch other files.
> Return, per comment: verdict, reasoning, the code context it lives on, and the
> applied diff; then the lint result for the file as a whole.

## 4. Verification commands

Per comment, the only check is `npx eslint --fix <path>` on the touched file. Run
everything else **once**, at wrap-up, from `src/ui-app` (the shared loop's section
3a):

```bash
npx nuxt typecheck          # ~13s; typescript.typeCheck is already on in nuxt.config.ts
npm run lint                # ~5s, whole app
npx vitest run --project=unit   # ~36s, 69 files / 417 tests
```

These are named here so no subagent has to discover them. Note there is no
`typecheck` npm script - `npx nuxt typecheck` is the working invocation. The
coverage and a11y gates (`npm run test:ci`, `npm run test:a11y`) are **not** run
here; they belong to `prepare-to-ship-ui`.

## 5. Wrap up (GitHub outward actions)

Follow the shared loop's wrap-up (section 5). **Run the section 4 verification
commands once**, over everything that landed, and report their real output. If
typecheck or a test fails, show the failing output and offer to work it as a new
item - do not report the run as clean. Then summarize from the state file (with
commit hashes where the user committed), flag anything deferred, and make the final
commit offer for any still-bundled fixes. Fixes the user leaves uncommitted stay as
working-tree changes; **never push** unless the user asks.

The outward-facing offers for this skill, **confirmed each time, never
automatic**:

- Reply to a reviewer's thread summarizing what was done -
  `gh api ... /pulls/<n>/comments/<comment-id>/replies` or a thread reply.
- Resolve a thread - a GraphQL `resolveReviewThread` mutation.

Only send text the user has seen and approved. Do neither without an explicit go.
Point out that fixes needing a full gate (build / 100% coverage / a11y) before the
PR ships should run through `prepare-to-ship-ui`.
