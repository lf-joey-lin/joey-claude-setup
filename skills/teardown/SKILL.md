---
name: teardown
description: Tear down the local git branch and worktree created for a piece of work once its PR is merged. Resolves the target from the <shortdesc> argument or from what was created earlier in the session, verifies the PR is merged and the tree is clean before deleting anything, and never touches main or the worktree you are standing in. Invoke when the user types /teardown, or asks to "clean up the branch", "delete the worktree", "tidy up after the merge", or "post-merge cleanup".
---

# teardown: post-merge branch and worktree teardown

Delete the throwaway git artifacts created for a task - the feature branch and,
if one was made, its worktree - **after the PR has merged**. This is a manual,
opt-in cleanup: only run it when the user asks.

Deleting branches and worktrees is hard to undo, so this skill verifies before it
destroys. Never delete something you cannot re-derive (unmerged commits,
uncommitted review state) without stopping to confirm. When anything is
ambiguous, ask - do not guess and delete.

## Invocation

```
/git-clean [shortdesc]
```

- `shortdesc` is optional. It names the work whose artifacts to remove and maps
  to a branch name (`veryShortCamelCaseDesc`, per the global git conventions)
  and/or a worktree at `C:\code2\momentum-<shortdesc>`.
- If omitted, resolve the target from session context (see below).

## 1. Resolve the target branch and worktree

Resolve in this order; stop at the first that yields a concrete target, then
confirm it back to the user before touching anything:

1. **`shortdesc` argument.** Match it against existing branches and worktrees -
   it may be the exact branch name, a camelCase-ization of the words, or the
   `momentum-<shortdesc>` worktree suffix. Do not assume the literal string is
   the branch name; look it up (step below) and match.
2. **Session context.** If this conversation created a branch or worktree (the
   branch it started work on, a `C:\code2\momentum-<feature>` worktree it made),
   use that.
3. **Current checkout.** Fall back to the branch/worktree currently checked out -
   but treat this with extra care (see the "standing in it" guard in step 3).

Enumerate what actually exists so the match is grounded, not guessed:

```bash
git worktree list
git branch --list
git for-each-ref --format='%(refname:short) <- %(upstream:short)' refs/heads
```

This repo is **jj-colocated**, so `git branch --show-current` / `git rev-parse
HEAD` can be stale or detached (see the CI/CD gotchas in the repo CLAUDE.md). If
`jj` is present, cross-check with:

```bash
jj bookmark list
jj log -r @ --no-graph -T 'bookmarks.join(",") ++ "\n"'
```

State the resolved target (branch name, worktree path if any, and how you
resolved it) and get a yes before proceeding.

## 2. Verify it is safe to delete

All of these are hard gates. If any fails, stop and report - do not delete.

- **Never `main`.** Refuse if the resolved branch is `main` (or the worktree is
  the primary checkout at `C:\code2\momentum`). This skill only removes
  throwaway feature artifacts.
- **PR is merged.** Confirm the PR for this branch actually merged - the whole
  premise of the cleanup:

  ```bash
  gh pr list --head <branch> --state all --json number,state,mergedAt,title
  ```

  Proceed only on `state: MERGED`. If it is `OPEN`, still in review, or `CLOSED`
  without merge, stop and say so - deleting now would lose the work. The user can
  override explicitly ("delete it anyway, it was abandoned"), but never assume.
- **No uncommitted changes.** The user's review state lives in the working tree.
  Check the target worktree (or the current one if there is no separate
  worktree):

  ```bash
  git -C <worktree-path> status --porcelain
  ```

  If it is non-empty, stop and show what is dirty. Do not stash-and-delete.
- **No unpushed commits.** Make sure nothing local is missing from the remote:

  ```bash
  git -C <worktree-path> log --oneline @{upstream}..HEAD
  ```

  (In the jj-colocated repo, prefer `jj log -r 'remote_bookmarks()..@'` to see
  work not yet on any remote.) If there are unpushed commits, stop - the merged
  PR may not include them.

## 3. Remove the worktree (if there is one)

- **Do not delete the worktree you are standing in.** If the current working
  directory is inside the target worktree, `cd` back to the primary checkout
  (`C:\code2\momentum`) first, then remove it. Removing the cwd out from under
  the session breaks subsequent commands.

```bash
git worktree remove <worktree-path>       # refuses if dirty/locked - good
git worktree prune                          # clean up stale admin entries
```

- If `git worktree remove` refuses because of leftover state and the safety gates
  in step 2 all passed, report the exact refusal and ask before using `--force`.
  Never `--force` silently.

## 4. Delete the branch

Prefer the safe delete so git double-checks the merge; only escalate on explicit
confirmation.

```bash
git branch -d <branch>        # refuses if not merged into its upstream - keep it that way
```

- If `-d` refuses (git thinks it is unmerged - common when the PR was
  squash/rebase-merged so the SHAs differ), do not reflexively `-D`. Re-confirm
  the PR really merged (step 2), tell the user why `-d` refused, and use
  `git branch -D <branch>` only after they say go.
- **jj-colocated repo:** in a colocated repo the git branch and the jj bookmark
  are two views of one ref. After deleting the git branch, drop the bookmark too
  so jj does not re-import it:

  ```bash
  jj bookmark forget <branch>
  ```

  (Use `jj bookmark delete <branch>` instead if you also intend to propagate the
  deletion to the remote on the next `jj git push`.)

## 5. Remote branch (optional, confirm first)

GitHub usually auto-deletes the PR's head branch on merge. Only if the remote
branch still exists and the user wants it gone:

```bash
git fetch --prune origin         # drops stale remote-tracking refs locally
git push origin --delete <branch>   # only with explicit confirmation
```

Deleting a remote branch is outward-facing - always confirm, never assume.

## 6. Report

Summarize exactly what was removed and what was left alone, e.g.:

- worktree `C:\code2\momentum-homePageWidgets` removed
- local branch `homePageWidgets` deleted (jj bookmark forgotten)
- remote branch already gone (auto-deleted on merge)

If any gate stopped the cleanup, say which one and what the user needs to do
(push first, commit or discard review changes, merge the PR) rather than
reporting partial success.

## Notes

- Manual only. Do not run this automatically after a merge, and do not chain it
  onto a PR-creation flow.
- One target per invocation. If the user has several stale branches, clean them
  one at a time so each merge check and dirty check is explicit.
- If the resolved branch has no PR at all (never pushed, purely local
  experiment), that is not a "merged" cleanup - tell the user and let them decide
  whether to force-delete.
