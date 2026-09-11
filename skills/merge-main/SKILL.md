---
name: merge-main
description: Bring the current branch up to date with the latest origin/main and resolve every conflict the merge produces. Always pulls origin/main first so the merge is never against a stale ref, checks whether there is anything to merge, commits or works around a dirty tree rather than stashing it, merges (never rebases, so published history is safe), then triages the conflicts: simple ones where the union of both sides is the only sensible answer get resolved outright, one subagent per file, while diverging changes and anything where a refactor is on the table stop and ask the human instead of guessing. Knows the momentum repo's special cases: generated translation catalogs and lockfiles take main's side and get regenerated, never hand-stitched. Finishes with a build of the components the merge touched, because a merge can conflict nowhere and still be broken. Invoke when the user types /merge-main, or asks to "merge main", "pull main", "merge origin/main into this branch", "catch up with main", "update from main", or "rebase on main" (they get a merge, and are told why).
---

# merge-main: catch the branch up with main

One job: the current branch ends up containing the latest `origin/main`, with every
conflict resolved properly and the code still building. Nothing else. No reviews,
no tests, no commits of unrelated work, no push, no PR.

This is the merge phase of `loom-land` on its own, for the times a branch needs to
catch up mid-session rather than at the end.

## Invocation

```
/merge-main
/merge-main --no-build      # skip the post-merge build check
```

Say the resolved shape in your first line of output, before any tool call:
`Branch: <branch>  Worktree: <absolute path>`.

## Merge, never rebase

`git merge origin/main`, always. The branch is usually already pushed, and a
rebase rewrites published history. If the user asked
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

## 2. Pull main first

Every run starts by pulling main from the remote, before anything reads
`origin/main`. No skipping it because a fetch ran earlier in the session: a merge
against a stale `origin/main` succeeds, looks clean, and leaves the branch behind
without saying so.

```bash
git -C "<worktree>" fetch origin main
```

Then advance the local `main` branch too, so it is not left stale either. Which
command applies depends on where `main` is checked out (`git worktree list`):

```bash
# main is not checked out anywhere: fast-forward the ref, no checkout needed
git -C "<worktree>" fetch origin main:main

# main is checked out in the default momentum worktree: pull it there
git -C ~/m-code/momentum pull --ff-only origin main
```

Both are inside the read-only rule for the default worktree, which allows `fetch`
and `pull` and nothing else. This step is best-effort: the merge itself reads
`origin/main`, so a refused ref update is a line in the report, not a stop.

## 3. Is there anything to merge

```bash
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

## 4. Can the merge start

Uncommitted work is normal mid-session, and `git merge` refuses to start when a
dirty file is one the merge also touches:

```bash
comm -12 \
  <(git -C "<worktree>" diff --name-only HEAD...origin/main | sort) \
  <(git -C "<worktree>" status --porcelain | cut -c4- | sort)
```

- **No overlap** - merge now. The dirty files ride along untouched.
- **Overlap** - the working tree has to land in commits first. Commit the
  overlapping files yourself, with explicit paths and a short subject, then merge.
  Do not push.

Never `git stash`. A stash is easy to lose and the working tree is the human's
review state.

## 5. The merge

```bash
git -C "<worktree>" merge --no-edit origin/main
git -C "<worktree>" diff --name-only --diff-filter=U     # conflicted files
```

A clean merge: record the merge commit SHA and go to step 7.

## 6. Resolve the conflicts

Three kinds of file are **not** hand-merged:

- **Generated translation catalogs** - `fr.json`, `es.json`, `en-XA.json`, the
  XLIFF memory. Take main's side (`git checkout --theirs <file>`) and let the
  pipeline regenerate them. `en.json` is a normal hand-resolved conflict, because
  it is the source.
- **Lockfiles** - take main's side and re-run the install so the lockfile is
  regenerated. Never hand-stitch one.
- **Anything else generated from a source file** - resolve the source, then
  regenerate the output.

Every other conflicted file gets triaged before a single line is edited, because
the two classes get very different treatment. Triage from the conflict hunks plus
both sides' history for that file:

```bash
git -C "<worktree>" log --oneline HEAD..origin/main -- <file>   # main's side
git -C "<worktree>" log --oneline origin/main..HEAD -- <file>   # the branch's side
```

### Simple: merge it, do not ask

The union of the two sides is the answer and there is only one sensible way to
write it:

- the two sides touched different things that happened to land in one hunk: an
  import block, a registry or list each side appended to, separate new members
- one side added, the other added elsewhere, nothing actually overlaps
- both sides made the same change, so the resolution is to keep it once
- formatting or whitespace churn on one side over a real change on the other

### Diverging, or a refactor is on the table: ask the human

These are decisions, not merge resolutions:

- both sides changed the same behavior and the two answers contradict each other
- main renamed, moved, extracted or reshaped the code the branch edited, so
  keeping the branch's intent means re-applying it onto a shape that did not exist
  when it was written
- the resolution needs edits outside the conflict region: a new call site, a
  changed signature, a caller adapted to an API main moved
- delete/modify: one side deleted the file the other changed
- there is more than one defensible resolution and they differ in behavior or in
  structure

Ask with `AskUserQuestion`, and:

- **ask once**, covering every file in this class, one question per file. If there
  are more files than the tool takes, ask about the ones that block the others
  first and say the rest are waiting.
- **leave the merge in progress while asking.** Do not abort first. Aborting
  throws away the resolutions already done, and the answer is often "resolve it
  this way" rather than "stop".
- each question names the file, says in one line what each side did, and offers
  the concrete resolutions with your recommendation first.
- always include a last option that stops: leave the tree as it was.
- **never guess past a no-answer.** If the prompt cannot be answered, `git merge
  --abort` and report the file, what each side does, and the options in the same
  detail.

### Doing the simple ones

**One subagent per conflicted file.** One file each, so they cannot collide, so
they all run concurrently: send them in a single message.

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
>
> If the file turns out not to be a simple union after all - the two sides
> contradict each other, or main reshaped the code this branch edited, or the fix
> reaches outside the conflict region - make no edits at all. Report back what each
> side did and what the options are. A human decides that one, and you cannot ask
> them from here.

An escalation coming back from a subagent joins the ask class: prompt for it the
same way, with the merge still in progress.

Once every file is resolved, stage them and close the merge:

```bash
git -C "<worktree>" add <the resolved files>
git -C "<worktree>" diff --check                  # no leftover markers
git -C "<worktree>" commit --no-edit
```

Grep the resolved files for `<<<<<<<`, `=======` and `>>>>>>>` before committing.
A conflict marker that reaches a commit is worse than an unfinished merge.

## 7. Build what the merge touched

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
`loom-gate`.

Skip this step on `--no-build`, and say in the report that it was skipped.

## 8. Report

Short. What a person needs to know and nothing else:

- how many commits came in from main, or that the branch was already up to date
- the merge commit SHA
- each conflicted file, one line each, saying what the two sides wanted and how
  the resolution kept both
- which files were resolved by rule rather than by hand (catalogs, lockfiles) and
  what has to regenerate them
- every file the human was asked about, and which way they went
- the build result, or that it was skipped
- anything left for the human: a stop, a regenerated lockfile to look at, an
  `en.json` change that still needs the `to-be-translated` label on the PR

## Notes

- Never push. The branch is left local-ahead; `loom-land` pushes it.
- Never open a PR or touch a work item. That is `paperwork`.
- Never commit unrelated working-tree changes. The only commit this skill makes is
  the merge commit, plus the step 4 commit when a dirty file blocks the merge.
- Never resolve a diverging conflict by picking a side to keep the run moving, and
  never take a refactor main invites without being told to. Ask.
- Never `git stash`, never `git rebase`, never `git reset --hard`.
- If anything goes wrong mid-merge, `git merge --abort` puts the tree back. Prefer
  that over a half-resolved tree.
