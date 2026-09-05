---
name: m-pr-review
description: Big-picture review of a momentum GitHub pull request. Checks the PR branch out into its own throwaway worktree, installs ui-app so the code can be read with real types, explains what the PR does at two altitudes (a plain summary, then a file-by-file walk so the shape of the change is clear), then runs the solidify2 structural pass over the diff. Deliberately narrow: no bug hunt, no security pass, no test or coverage review, no lint, no build, no a11y, no style nits, and no comments posted on the PR. REVIEW ONLY, never edits code. Invoke when the user types /m-pr-review, or hands over a momentum PR number or github.com/Laserfiche/momentum PR link and asks to "review this PR", "what does this PR do", "is this the right shape", or "give me the big picture on this PR".
---

# m-pr-review: big-picture review of a momentum PR

You are reading **someone else's momentum pull request** and answering two
questions, in this order:

1. **What does this change actually do?** First in a few lines, then in enough
   detail that the reader knows which files matter and why.
2. **Is it the right shape?** Structural quality only, via `solidify2`.

That is the whole skill. It is narrow on purpose - see the boundary below - and
it produces a chat report. It **posts nothing on the PR and edits no code**.

## Hard boundary

**In scope:** what the PR does, which files carry the change, and the structural
review `solidify2` performs.

**Out of scope, at any severity.** Do not run these passes, do not fan out
subagents for them, and do not sneak them into the report as "while I was in
there":

- functional bugs and correctness -> `/code-review`
- security -> `/security-review`
- tests, coverage, missing specs -> `update-tests`
- Nuxt UI component choice, i18n, theming, accessibility -> `review-ui`
- lint, build, typecheck, the CI gates -> `prepare-to-ship`
- file-level nits: naming, comments, duplication counting, dead code -> `solidify`
  (note: `solidify2` already parks these under "Local defects noticed"; leave
  them exactly there)

If something out of scope is genuinely alarming - a credential in the diff, a
migration that looks destructive - say it in one line at the end under
`Noticed, out of scope` and name the skill that owns it. One line, no analysis.
Anything less than alarming gets dropped.

**Never post to the PR.** No `gh pr review`, no `gh pr comment`, no approve, no
request-changes. The output is chat only.

## Invocation

```
/m-pr-review <pr number | github PR url>
```

- A bare number (`655`), a URL
  (`https://github.com/Laserfiche/momentum/pull/655`), or a branch name all
  resolve. A branch name resolves through `gh pr list --head <branch>`.
- **Nothing given** - list the open PRs (`gh pr list --repo Laserfiche/momentum
  --limit 20`) and ask which one. Do not guess, and do not review the current
  worktree's branch just because it is there.
- momentum is on **GitHub**, so `gh` is the tool. A PA Forms PR on
  `v-dev-tfs.laserfiche.com` is a different skill (`review-forms-pr`) - if the
  link is a TFS one, say so and stop.

## Step 1 - resolve the PR

```bash
gh pr view <N> --repo Laserfiche/momentum \
  --json number,title,body,author,state,isDraft,headRefName,baseRefName,headRefOid,additions,deletions,changedFiles,commits,labels,url
```

Record `headRefName`, `headRefOid`, `baseRefName` and the URL - the rest of the
skill needs them. Note the state: a **closed or merged** PR still reviews fine,
but say so up front so nobody acts on a review of something already landed.

Also pull, once:

- `gh pr diff <N> --repo Laserfiche/momentum --name-only` - the changed file list
- existing review comments (`gh pr view <N> --comments`) - so the report does not
  repeat a point a human already made. Mention overlaps rather than restating them.
- the linked TFS work item, if the body has one. It says what the change is
  *supposed* to do, which is what makes "does the diff match its intent" answerable.

## Step 2 - the review worktree

Reviews get their own throwaway worktree, same as work does. Two reasons: the
default checkout at `<root>/momentum` is a read-only reference on `main` and must
stay there, and installing `node_modules` for a review must not disturb the
worktree the user is actually working in.

Resolve the workspace root first (`uname -s`: Linux/WSL -> `~/m-code`, anything
MINGW/MSYS/CYGWIN -> `C:/code2`) and substitute the real path into every command -
shell state does not carry between calls.

```bash
# 1. resume check - if the path exists, reuse it rather than making a second one
git -C "<root>/momentum" worktree list

# 2. fetch the PR head by its pull ref (works for fork PRs too, unlike a branch fetch)
git -C "<root>/momentum" fetch origin main "pull/<N>/head"

# 3. check it out into its own worktree on a visibly-not-work branch
git -C "<root>/momentum" worktree add -b "pr-<N>" "<root>/momentum-pr-<N>" FETCH_HEAD
```

- **The branch is named `pr-<N>`, not camelCase**, on purpose: repo convention
  reserves `veryShortCamelCase` for real work, so a `pr-` branch reads at a glance
  as a review checkout nobody should commit to.
- **Never `fetch origin <headRefName>` instead.** A fork PR has no branch on
  `origin`, and the fetch fails with nothing useful.
- **On resume**, bring the existing worktree to the current PR head rather than
  reviewing a stale one:
  `git -C "<root>/momentum-pr-<N>" fetch origin "pull/<N>/head" && git -C "<root>/momentum-pr-<N>" reset --hard FETCH_HEAD`.
  Safe only because this worktree is disposable and the skill never edits it. If
  it somehow has local changes, stop and report instead.
- **On WSL keep it under `~/m-code`**, never on `/mnt/c` - the 9p mount is slow
  enough to break the install in step 3.
- If the worktree path or branch name is taken by something that is *not* a prior
  run of this skill, stop and report. Never clobber.

Everything after this point runs against `<root>/momentum-pr-<N>`. State that path
in the report so the user can open it, and tell them how to remove it when done:
`git -C "<root>/momentum" worktree remove "<root>/momentum-pr-<N>" && git -C "<root>/momentum" branch -D "pr-<N>"`.

## Step 3 - install ui-app

```bash
cd "<root>/momentum-pr-<N>/src/ui-app" && npm ci
```

Run this every time, even when the PR touches no ui-app file. It is grounding,
not verification:

- a fresh worktree has no `node_modules`, so the TypeScript/Vue language server
  cannot resolve a single import and `hover`/`findReferences` come back empty or
  wrong - which is worse than not using them, because the answers look real
- the postinstall runs `nuxt prepare`, which writes `.nuxt/imports.d.ts`: the
  roster of auto-imported composables. Without it, reading a `.vue` file means
  guessing where a bare `useThing()` comes from
- it is also what makes `npx nx` calls resolvable if the walk needs the project
  graph to work out which component a file belongs to

**A failed install is not a failed review.** Note it, say that type resolution is
degraded and that reference lists are a floor rather than a list, and carry on.

**Install only. Do not then run the build, the tests, lint, or nx targets** - all
four are out of scope, and CI already runs them on the PR.

## Step 4 - the diff, at the right base

Always diff against the **merge base**, never against `origin/main`'s tip - a
two-dot diff drags in every commit that landed on main since the branch cut and
attributes them to this PR.

```bash
cd "<root>/momentum-pr-<N>"
git merge-base origin/main HEAD                       # record it
git diff --stat origin/main...HEAD
git diff origin/main...HEAD -- <path>                 # per file
git log --oneline origin/main..HEAD                   # the commits, in order
```

**Read the changed files in full**, not just the hunks. A hunk hides the function
it sits in, and structure is invisible at hunk granularity - which is the one
thing this skill is for.

## Step 5 - the plain summary

Write this before going near the detail. It is the part the user reads first, and
it is the part that is wrong if you built it from the diff alone rather than from
the diff plus the PR body plus the work item.

Four things, a couple of lines each:

- **What it does**, in the product's own terms - what a user or a caller can now
  do that they could not before, or what stopped happening. Not a restatement of
  the diff.
- **How it does it**, in one or two sentences: the approach the author picked, and
  the alternative it implies they rejected.
- **Where it lands**: the components touched (`src/<component>`), and which of
  them is the centre of the change versus which is a knock-on edit.
- **Does the diff match its stated intent?** Compare against the PR body and the
  linked work item. Anything in the diff the description does not mention is worth
  a line - unexplained scope is the most common real problem with a PR, and it is
  a big-picture point, not a nit.

## Step 6 - the file-by-file walk

Now the detail, so the reader can navigate the change. **Group by component, then
by role within the component** - never a flat alphabetical list, which is what the
GitHub file tree already gives and helps nobody.

Per component:

| File | Change | Why it is here |
|---|---|---|

- `Change` is added / rewritten / edited / deleted / moved, plus the line delta.
- `Why it is here` is one sentence tying the file to the summary in step 5. If you
  cannot write that sentence for a file, say so plainly - a file whose reason for
  being in the PR is unclear is a finding, and one of the few this skill reports
  directly.

Then, in a few lines:

- **The load-bearing files** - the two or three that carry the change. Say what to
  read first and in what order.
- **The mechanical rest** - renames, generated output, catalog updates, lockfiles,
  test-only edits. Name them as a group and move on. Note that `fr.json`/`es.json`/
  `en-XA.json` and the XLIFF memory are pipeline output, so churn there is expected
  and not reviewable.
- **New public surface** - anything the PR added that other components can now
  reach: an interface, a DTO, an endpoint, a proto message, an exported composable,
  a config key. This list is what step 7 needs most.

## Step 7 - the solidify2 pass

Now invoke `solidify2` (`Skill(skill: "solidify2")`), which is the actual review.
It works on "the current branch", and inside `<root>/momentum-pr-<N>` that is the
PR - so hand it the concrete context rather than letting it re-derive any of it:

- the worktree path, and that the session is standing in it
- the merge base from step 4, and that the diff to review is
  `origin/main...HEAD`
- that this is **someone else's PR**: review and plan only, no edits, and no
  "I'll just fix it" on anything
- the new-public-surface list and the load-bearing files from step 6
- that `npm ci` has run, so the LSP resolves - and, if it failed, that it does not
- the `.vue` caveat: if the LSP answers "No LSP server available for file type" on
  a `.vue`, a `findReferences` on a composable is a floor and not the list, so grep
  the `.vue` files too before concluding nothing uses something

Do not restate solidify2's rules here and do not pre-empt its findings. Its bar,
its lenses and its over-engineering veto are its own, and they are why the output
is short.

**Take what it returns at face value only after a sanity check.** For each
finding, confirm the `path:line` sites exist in this PR's tree and that the finding
is caused by *this* PR rather than pre-existing. A pre-existing structural problem
the PR merely sits next to belongs in one line under "pre-existing, not this PR",
not in the ranked list. Everything else passes through as solidify2 wrote it.

## Step 8 - the report

One chat report, in this order. Terse and skimmable - short bullets, no praise, no
restating the diff line by line, no closing summary.

1. **Header** - PR number, title, author, state, `+n/-n across N files`, the URL,
   and the review worktree path.
2. **What this PR does** - step 5.
3. **The change, file by file** - step 6.
4. **Structural review** - solidify2's findings, ranked as it ranked them, plus
   its "Local defects noticed" list left as one flat line-per-item block.
5. **Pre-existing, not this PR** - one line each, or the heading omitted.
6. **Noticed, out of scope** - one line each with the owning skill, or omitted.
7. **Not covered** - say it plainly: no bug hunt, no security pass, no test
   review, nothing built or run. Also name anything that failed (the install, a
   file you could not read, an agent that came back empty). Silence reads as
   "checked and clean".
8. **Cleanup** - the `worktree remove` command from step 2.

Base every claim on code you actually read. Where something could not be
determined - a consumer outside the repo, a runtime behaviour, whether a migration
is reversible - write that it could not be determined. Never guess and never pad.

## Behavioral guidelines

- **Read-only, everywhere.** The review worktree is disposable but it is still not
  yours to edit: no fixes, no formatting, no "I tidied one thing". The default
  worktree at `<root>/momentum` gets `fetch` and `worktree add` and nothing else.
- **Two altitudes, in order.** Summary first, detail second, structure third. The
  detail is navigation, not the review - if the file-by-file section is the longest
  part of the report, the report is upside down.
- **Narrow is the feature.** Every other review angle has a skill that does it
  better. Adding them here produces a report nobody finishes reading, which is how
  the structural findings - the only ones nothing else catches - get skimmed past.
- **Someone wrote this code.** Where a structural point could be a question, ask
  it. "Is the paged path meant to stay separate from the infinite one?" beats an
  assertion when the author knows something you do not.
- **Say what you skipped.** A file you could not read, a component you did not
  reach, an install that failed.
