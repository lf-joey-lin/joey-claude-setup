---
name: pr-review-fixer
description: Work through the review comments on an open pull request one at a time, with a human in the loop. Takes a PR link or number, gathers the inline and summary comments left by other reviewers, analyzes each in a subagent to agree or disagree with it and surfaces any disagreement for the human to accept or reject first, writes a per-reviewer markdown state file under ui-app/logs, then for each accepted comment spawns a subagent that applies a minimal fix, shows the real diff, and verifies it. The main agent stays an orchestrator: it owns the state file, drives the human decision loop, and records each outcome. Invoke when the user types /pr-review-fixer, or asks to "address PR review comments", "go through the review feedback", "fix reviewer comments on PR <n>", or hands over a PR link and wants the review threads worked one by one.
---

# pr-review-fixer: work review comments one at a time, human in the loop

Drive a pull request's review feedback to resolution, one comment at a time. The
comments come from **other reviewers** (never the PR author's own). First an
analysis subagent judges each comment on its own merits and agrees or disagrees with
it; the human settles any disagreement before the gate. The human then gates the
whole surviving list in one pass (each comment defaults to accept), and each
accepted comment gets its own turn: a subagent applies a minimal fix, shows the
diff, and verifies; the human keeps or reverts it and chooses whether to commit; the
orchestrator records the outcome in a state file.

**This skill runs on the shared turn-by-turn loop.** Read
[`../shared/turn-by-turn-loop.md`](../shared/turn-by-turn-loop.md) first - it owns
the orchestrator model, the state-file mechanics, the one-comment-at-a-time
cadence, the section 1 bulk gate, and the per-comment disposition. This file
supplies the four host hooks the loop leaves open: the work list (section 1), the
state-file path (section 2), the per-comment subagent task (section 3), and
wrap-up plus the GitHub outward actions (section 4).

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
- Group the remaining comments **by reviewer**.

**Pre-analysis - judge each comment before the gate.** Get an independent read on
every gathered comment so the human is not rubber-stamping raw feedback. Spawn an
analysis subagent per comment - read-only, no edits, so these may run concurrently -
seeded with the comment text, its `file:line`, the diff hunk, and the thread. Tell
it to read the code the comment concerns and return: a verdict, **agree** (a real
issue worth changing) or **disagree** (a misread, already handled, or not worth
doing), with a 2-4 sentence rationale citing `file:line`; its own **recommendation**
(the change it would make, or why nothing should); and the CODE CONTEXT block
(current code, line-numbered). This verdict and recommendation become the comment's
gate context and carry into the fix subagent (section 3), so the judgment is made
once, not twice.

**Resolve disagreements before the gate.** For each comment the analysis
**disagreed** with, run an iterative `AskUserQuestion` loop, one contested comment
at a time: show the reviewer comment, the subagent's disagreement and rationale, and
the code context, then ask the human to **accept** (keep the comment and address it
anyway) or **reject** (drop it - record as `[!]` wont-fix with the rationale).
Comments the analysis agreed with pass straight through. Only once every
disagreement is settled does the gate run.

**Gate the surviving list.** Run the shared loop's section 1 bulk gate over the
survivors: state how many actionable comments, from which reviewers, and how many
resolved/bot were filtered. Each carries its reviewer, `file:line`, thread text, and
the analysis verdict + recommendation as gate context, and **defaults to accept**
(reviewer comments are not severity-ranked); the human toggles off any to skip or
wont-fix before the loop starts.

## 2. State-file path

One state file per reviewer, under the gitignored logs folder:

```
src/ui-app/logs/pr-<number>-review-<reviewer>.md
```

`<reviewer>` is the reviewer's login, lowercased, non-alphanumerics to `-` (e.g.
`pr-119-review-catherine.md`). Follow the shared loop's state-file template and
resume rules. Reviewer comments carry no severity, so leave the template's
`Priority` as `-` (every comment defaults to accept at the gate). Add these
PR-specific fields to each item entry: `Location` is the `path:line` with an
`(outdated: yes/no)` note, `Thread` is the comment URL, and `Analysis` is the
pre-analysis verdict (agree, or accepted-over-disagreement) plus its recommendation.

If there are multiple reviewers, ask the human which reviewer's file to start with
(or go in turn) - one reviewer's file at a time.

## 3. Per-comment subagent task

For each pending comment, spawn the single synchronous `general-purpose` subagent
the shared loop calls for, seeded with only this comment and the pre-analysis
verdict and recommendation from section 1:

> You are evaluating ONE pull request review comment in the momentum repo
> (`src/ui-app`). Do not look at or fix anything the comment does not concern.
>
> Reviewer: <login>
> File/line: `<path>:<line>` (outdated: <yes/no> - if outdated, the line may have
> moved; locate the relevant code by content, not line number)
> Diff hunk the comment was left on:
> ```
> <diffHunk>
> ```
> Reviewer comment (full thread):
> """
> <verbatim text>
> """
> Pre-analysis verdict: <agree, or accepted-over-disagreement>
> Pre-analysis recommendation: <what to change>
>
> Do:
> 1. Read the current code at that location. This comment was already judged in
>    pre-analysis and cleared by the human, so do not relitigate it - confirm the
>    finding still holds against the current code (it may have moved since
>    analysis) and follow the pre-analysis recommendation. Only if the code has
>    changed enough that the finding no longer applies, report it INVALID and make
>    no change. Explain in 2-4 sentences, citing `file:line`.
> 2. Capture the CODE CONTEXT the comment lives on, so the human can see exactly
>    what is being discussed without opening the file. Quote the current code at
>    the location as a fenced block (language-tagged, e.g. ```vue), with enough
>    surrounding lines to be self-contained (the whole function / block / element,
>    not a single line), and prefix each line with its real line number. If the
>    thread is outdated and the code has moved, quote where it lives now and say so.
> 3. If VALID, make the smallest correct change that addresses it, matching the
>    surrounding code style and the repo conventions (Nuxt UI over custom, i18n
>    no hardcoded strings, theming tokens no hardcoded hex, data-testid
>    conventions, SOLID). Apply it to the working tree.
> 4. Show the exact fix as a fenced ```diff block from `git diff -- <files>`
>    (unified diff, `-`/`+` lines intact). If nothing changed, say so explicitly.
> 5. Verify the change in scope: typecheck/lint the touched files and run the
>    most relevant existing unit test if there is one. Report the commands and
>    their real pass/fail output - do not claim success you did not observe. Note
>    if a full build / coverage / a11y gate should be run later before shipping.
> 6. If the finding no longer applies (INVALID above), make NO code change; still
>    provide the code context from step 2 and explain what changed since the review.
>
> Do NOT commit, push, post to GitHub, resolve the thread, or touch unrelated
> files. Return a structured report with these sections: verdict, reasoning, the
> CODE CONTEXT block (the old/current code the comment lives on), files touched,
> the fix diff (fenced ```diff), verification result, and (if applicable) the open
> question for the human.

Relay the report and drive the disposition exactly as the shared loop's section 3
describes (show code context + verdict + applied diff + verify, then revise / keep /
revert, and the commit offer), and record the outcome per section 4. On revert, undo
the applied change with `git checkout -- <files>` so the working tree only carries
kept fixes.

## 4. Wrap up (GitHub outward actions)

Follow the shared loop's wrap-up (section 5): summarize from the state file (with
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
