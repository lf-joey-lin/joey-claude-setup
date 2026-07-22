---
name: pr-review-fixer
description: Work through the review comments on an open pull request one at a time, with a human in the loop. Takes a PR link or number, gathers the inline and summary comments left by other reviewers, writes a per-reviewer markdown state file under ui-app/logs, then for each comment spawns a subagent that judges whether it is valid, applies a minimal fix, shows the real diff, and verifies it. The main agent stays an orchestrator: it owns the state file, drives the human decision loop, and records each outcome. Invoke when the user types /pr-review-fixer, or asks to "address PR review comments", "go through the review feedback", "fix reviewer comments on PR <n>", or hands over a PR link and wants the review threads worked one by one.
---

# pr-review-fixer: work review comments one at a time, human in the loop

Drive a pull request's review feedback to resolution, one comment at a time. The
comments come from **other reviewers** (never the PR author's own); each one gets
its own turn: a subagent judges it, proposes and applies a minimal fix, shows the
diff, and verifies; the human decides accept / revise / skip; the orchestrator
records the outcome in a state file.

**This skill runs on the shared turn-by-turn loop.** Read
[`../shared/turn-by-turn-loop.md`](../shared/turn-by-turn-loop.md) first - it owns
the orchestrator model, the state-file mechanics, the one-comment-at-a-time
cadence, and the accept / revise / skip / wont-fix disposition loop. This file
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

Present this list and get the go-ahead per the shared loop's section 1: how many
actionable comments, from which reviewers, and how many resolved/bot were filtered.

## 2. State-file path

One state file per reviewer, under the gitignored logs folder:

```
src/ui-app/logs/pr-<number>-review-<reviewer>.md
```

`<reviewer>` is the reviewer's login, lowercased, non-alphanumerics to `-` (e.g.
`pr-119-review-catherine.md`). Follow the shared loop's state-file template and
resume rules. Add these PR-specific fields to each item entry: `Location` is the
`path:line` with an `(outdated: yes/no)` note, and `Thread` is the comment URL.

If there are multiple reviewers, ask the human which reviewer's file to start with
(or go in turn) - one reviewer's file at a time.

## 3. Per-comment subagent task

For each pending comment, spawn the single synchronous `general-purpose` subagent
the shared loop calls for, seeded with only this comment:

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
>
> Do:
> 1. Read the current code at that location and enough around it to judge the
>    comment. Decide: is it VALID (a real issue worth changing), INVALID (based
>    on a misread / already handled / not applicable), or a QUESTION/PREFERENCE
>    (needs a human call, no clear fix). Explain your reasoning in 2-4 sentences,
>    citing `file:line`.
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
> 6. If INVALID or a QUESTION, make NO code change; still provide the code context
>    from step 2 and explain what the human should weigh in on.
>
> Do NOT commit, push, post to GitHub, resolve the thread, or touch unrelated
> files. Return a structured report with these sections: verdict, reasoning, the
> CODE CONTEXT block (the old/current code the comment lives on), files touched,
> the fix diff (fenced ```diff), verification result, and (if applicable) the open
> question for the human.

Relay the report and drive the disposition exactly as the shared loop's section 3
describes (show code context + verdict + diff + verify, then accept / revise /
skip / wont-fix), and record the outcome per section 4.

## 4. Wrap up (GitHub outward actions)

Follow the shared loop's wrap-up (section 5): summarize from the state file, flag
anything deferred, and leave the accepted fixes as uncommitted working-tree
changes - do not commit or push unless the user asks.

The outward-facing offers for this skill, **confirmed each time, never
automatic**:

- Reply to a reviewer's thread summarizing what was done -
  `gh api ... /pulls/<n>/comments/<comment-id>/replies` or a thread reply.
- Resolve a thread - a GraphQL `resolveReviewThread` mutation.

Only send text the user has seen and approved. Do neither without an explicit go.
Point out that fixes needing a full gate (build / 100% coverage / a11y) before the
PR ships should run through `prepare-to-ship-ui`.
