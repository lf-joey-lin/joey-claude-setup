---
name: merge-main
description: Bring the current branch up to date with the latest origin/main and resolve every conflict the merge produces. Fetches origin, checks whether there is anything to merge, commits or works around a dirty tree rather than stashing it, merges (never rebases, so published history is safe), then resolves conflicts one subagent per conflicted file so both sides' intent survives. Knows the momentum repo's special cases: generated translation catalogs and lockfiles take main's side and get regenerated, never hand-stitched. Stops instead of guessing when the two sides genuinely disagree about behavior. Finishes with a build of the components the merge touched, because a merge can conflict nowhere and still be broken. Invoke when the user types /merge-main, or asks to "merge main", "pull main", "merge origin/main into this branch", "catch up with main", "update from main", or "rebase on main" (they get a merge, and are told why).
---

# merge-main: catch the branch up with main

One job: the current branch ends up containing the latest `origin/main`, with every
conflict resolved properly and the code still building. Nothing else. No reviews,
no tests, no commits of unrelated work, no push, no PR.

This is the merge phase of `wrap-it-up` on its own, for the times a branch needs to
catch up mid-session rather than at the end.

## Invocation

```
/merge-main
/merge-main --no-build      # skip the post-merge build check
```

Say the resolved shape in your first line of output, before any tool call:
`Branch: <branch>  Worktree: <absolute path>`.

## Merge, never rebase

`git merge origin/main`, always. The branch is usually already pushed (`new-work`
publishes it at setup), and a rebase rewrites published history. If the user asked
for a rebase, do the merge and say in one line that a merge was used because the
branch is published.

Use `git fetch` then `git merge` rather than a bare `git pull origin main`. Same
result, but it lets you look at what is coming before it lands, and it leaves
`origin/main` as a real ref you can diff against in later steps.

## 1. Preconditions

Work out the worktree first and use its absolute path in every command
(`git -C "<worktree>" ...`). Shell state does not carry between commands.

```bash
git rev-parse --show-toplevel
git branch --show-current
```

- **On `main`** - there is nothing to merge into. A plain `git pull --ff-only
  origin main` is all that is wanted; do that, report it, and stop.
- **Detached HEAD** - stop and report. Name what you saw.
- **A merge already in progress** (`.git/MERGE_HEAD` exists) - stop. Report the
  conflicted files and let the human say whether to finish it or abort it. Never
  start a second merge over the top of one.

## 2. Is there anything to merge

```bash
git -C "<worktree>" fetch origin
git -C "<worktree>" merge-base --is-ancestor origin/main HEAD && echo up-to-date
```

`up-to-date` means the branch already contains main. Report that and stop: no
merge commit, no build, nothing.

Otherwise show what is arriving before merging it, so the report has something to
say about scope:

```bash
git -C "<worktree>" log --oneline HEAD..origin/main | wc -l
git -C "<worktree>" diff --name-only HEAD...origin/main
```

## 3. Can the merge start

Uncommitted work is normal mid-session, and `git merge` refuses to start when a
dirty file is one the merge also touches:

```bash
comm -12 \
  <(git -C "<worktree>" diff --name-only HEAD...origin/main | sort) \
  <(git -C "<worktree>" status --porcelain | cut -c4- | sort)
```

- **No overlap** - merge now. The dirty files ride along untouched.
- **Overlap** - the working tree has to land in commits first. Run `ship-it` in
  commit-only mode (`--no-push`), then merge.

Never `git stash`. A stash is easy to lose and the working tree is the human's
review state.

## 4. The merge

```bash
git -C "<worktree>" merge --no-edit origin/main
git -C "<worktree>" diff --name-only --diff-filter=U     # conflicted files
```

A clean merge: record the merge commit SHA and go to step 6.

## 5. Resolve the conflicts

Three kinds of file are **not** hand-merged:

- **Generated translation catalogs** - `fr.json`, `es.json`, `en-XA.json`, the
  XLIFF memory. Take main's side (`git checkout --theirs <file>`) and let the
  pipeline regenerate them. `en.json` is a normal hand-resolved conflict, because
  it is the source.
- **Lockfiles** - take main's side and re-run the install so the lockfile is
  regenerated. Never hand-stitch one.
- **Anything else generated from a source file** - resolve the source, then
  regenerate the output.

Everything else gets **one subagent per conflicted file**. One file each, so they
cannot collide, so they all run concurrently: send them in a single message.

Seed each with the absolute worktree path, the one file it owns, what the branch is
trying to do, and this bar:

> Resolve this file's conflicts so both sides' intent survives. Read enough of both
> histories to know what each side was doing:
> `git log --oneline HEAD..origin/main -- <file>` for main's side,
> `git log --oneline origin/main..HEAD -- <file>` for the branch's. Never take one
> side wholesale because it is shorter or easier. Never delete someone else's
> change to make the markers go away. Leave no conflict markers and no
> commented-out losing side. Return the resolved hunks, and one line per hunk
> saying what each side wanted and how both survived.

**Stop, do not guess**, when the two sides genuinely disagree about behavior: main
changed the same thing the branch changed and keeping both is not possible. Run
`git merge --abort`, leave the tree exactly as it was, and report the file, what
each side does, and the options. That is the human's call, not a merge resolution.

Once every file is resolved, stage them and close the merge:

```bash
git -C "<worktree>" add <the resolved files>
git -C "<worktree>" diff --check                  # no leftover markers
git -C "<worktree>" commit --no-edit
```

Grep the resolved files for `<<<<<<<`, `=======` and `>>>>>>>` before committing.
A conflict marker that reaches a commit is worse than an unfinished merge.

## 6. Build what the merge touched

A merge can conflict nowhere and still be broken: main renamed something the branch
calls, or changed a contract it relies on. So work out which components the merge
touched and build them. A failure here is a stop with the real error, not a fix
attempt - the fix may be a code change the human wants to make themselves.

Delegate the build to one subagent and give it **absolute** paths, e.g.
`dotnet build <worktree>/src/<component>/<component>.slnx -c Release`, not a
relative path against a cwd it never states. Auto mode judges the command text it
is handed, and a bare relative build from a subagent stalls on a permission prompt
no subagent can answer.

Tests, coverage, lint and the full gate are not this skill's job. That is
`prepare-to-ship`.

Skip this step on `--no-build`, and say in the report that it was skipped.

## 7. Report

Short. What a person needs to know and nothing else:

- how many commits came in from main, or that the branch was already up to date
- the merge commit SHA
- each conflicted file, one line each, saying what the two sides wanted and how
  the resolution kept both
- which files were resolved by rule rather than by hand (catalogs, lockfiles) and
  what has to regenerate them
- the build result, or that it was skipped
- anything left for the human: a stop, a regenerated lockfile to look at, an
  `en.json` change that still needs the `to-be-translated` label on the PR

## Notes

- Never push. The branch is left local-ahead; `ship-it` or `wrap-it-up` pushes it.
- Never open a PR or touch a work item. That is `paperwork`.
- Never commit unrelated working-tree changes. The only commit this skill makes is
  the merge commit, plus the `ship-it --no-push` call in step 3 when a dirty file
  blocks the merge.
- Never `git stash`, never `git rebase`, never `git reset --hard`.
- If anything goes wrong mid-merge, `git merge --abort` puts the tree back. Prefer
  that over a half-resolved tree.
