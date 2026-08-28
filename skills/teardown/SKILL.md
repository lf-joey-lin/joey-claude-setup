---
name: teardown
description: Sweep away the throwaway momentum worktrees and branches left behind by merged work, then put the workspace back on a fresh main. Removes only <root>/momentum-<desc> worktrees, never the default momentum worktree, manta, gnhf, or anything else under the root, and ends by putting momentum's default worktree on a freshly pulled main and pulling manta's main. Default mode gates every removal on merged PR, clean tree and no unpushed commits; --yes keeps the gates but skips the confirmation question; --force skips all checks and resets. Invoke when the user types /teardown, or asks to "clean up the branch", "delete the worktree", "clean up my worktrees", "tidy up after the merge", or "post-merge cleanup".
---

# teardown: post-merge worktree sweep

Delete the throwaway git artifacts left over from finished work - the
`momentum-<desc>` worktrees and their feature branches - then leave the
workspace on a clean, freshly pulled `main`. Manual and opt-in: only run it when
the user asks.

Deleting worktrees and branches is hard to undo, so the default mode verifies
before it destroys and skips anything it cannot prove is safe. `--force` throws
those checks away by explicit request.

## Invocation

```
/teardown [shortdesc] [--yes] [--force]
```

- **No argument:** sweep every `momentum-*` worktree under the workspace root.
- **`shortdesc`:** narrow the sweep to one target - the branch name
  (`veryShortCamelCaseDesc`), or the `momentum-<shortdesc>` worktree suffix. Look
  it up against what actually exists rather than assuming the literal string.
- **`--yes`:** the list has already been confirmed, so do not ask again - resolve
  it, print it, and go. Every gate in step 1 still runs; that is what makes
  skipping the question safe. The `m-teardown` shell wrapper passes it, since
  typing the command is the confirmation and there is no human to answer a
  question in a headless run.
- **`--force`:** no safety checks at all. Remove every `momentum-*` worktree,
  delete every local branch but `main`, hard-reset and clean both default
  worktrees, pull. Uncommitted and unpushed work is destroyed. See step 6.

The final pull in step 5 always runs, in both modes, even when nothing was
removed.

## Scope: what may be touched

Resolve the workspace root first - `~/m-code` on WSL/Linux, `C:\code2` on
Windows (`uname -s`: Linux means the WSL root). Substitute the concrete path into
every command; shell state does not carry between commands.

**Removable:** direct children of the root named `momentum-<desc>` that git
reports as worktrees of the momentum repo.

**Never touched, in either mode:**

- `<root>/momentum` - the default worktree. It gets reset and pulled, never removed.
- `<root>/manta` - separate repo, never worked in. Its main gets pulled (step
  5), nothing else, not even in force mode.
- `<root>/gnhf` - nightly state, including the momentum worktrees it keeps at
  `gnhf/stack/momentum-gnhf` and `gnhf/runs/*/work/*`. Those are real momentum
  worktrees but they are gnhf's to manage, not this skill's. Path filter, not a
  name filter: match only one level below the root.
- Anything else under the root (`azure-devops-mcp`, loose notes and md files, any
  directory that is not a momentum worktree).

Enumerate before matching so the target list is grounded:

```bash
git -C "<root>/momentum" worktree list --porcelain | grep '^worktree ' | cut -d' ' -f2-
git -C "<root>/momentum" branch --list
git -C "<root>/momentum" for-each-ref --format='%(refname:short) <- %(upstream:short)' refs/heads
```

Keep only paths matching `<root>/momentum-*` with no further `/` after that.
State the resolved list back to the user - each worktree, its branch, and what
was excluded - and get a yes before deleting anything. With `--yes` or `--force`,
still print the list, then go without asking.

## 1. Safety gates, per worktree (skipped by `--force`)

Run these for each candidate. A worktree that fails any gate is **skipped, not
deleted** - keep sweeping the rest and report the skips at the end.

- **PR is merged.** The premise of the cleanup:

  ```bash
  gh pr list --head <branch> --state all --json number,state,mergedAt,title
  ```

  Only `state: MERGED` clears the gate. `OPEN`, in review, or `CLOSED` unmerged
  means skip and say so. No PR at all (never pushed, local experiment) is also a
  skip - tell the user and let them decide.
- **No uncommitted changes.** The working tree is the user's review state.

  ```bash
  git -C <worktree-path> status --porcelain
  ```

  Non-empty means skip, and show what is dirty. Never stash-and-delete.
- **No unpushed commits.**

  ```bash
  git -C <worktree-path> log --oneline @{upstream}..HEAD
  ```

  Anything listed means the merged PR may not cover it. Skip.

## 2. Remove the worktrees

Do not delete the worktree you are standing in. If the cwd is inside a target,
`cd "<root>/momentum"` first - pulling the cwd out from under the session breaks
every command after it.

```bash
git -C "<root>/momentum" worktree remove <worktree-path>
git -C "<root>/momentum" worktree prune
```

`worktree remove` refuses on leftover state, which is the point. If it refuses
after the gates passed, report the exact refusal and ask before `--force`ing that
one. Never `--force` a single removal silently in default mode.

## 3. Delete the branches

```bash
git -C "<root>/momentum" branch -d <branch>
```

`-d` refuses when git cannot see the merge, which is normal for a squash or
rebase merge since the SHAs differ. Do not reflexively `-D`: re-state that the PR
merged (step 1 already proved it), say why `-d` refused, and use
`git branch -D <branch>` once the user says go.

## 4. Remote branches

GitHub auto-deletes the PR head branch on merge, so usually there is nothing to
do. Drop stale tracking refs locally:

```bash
git -C "<root>/momentum" fetch --prune origin
```

Deleting a live remote branch is outward-facing. Only on explicit confirmation:

```bash
git -C "<root>/momentum" push origin --delete <branch>
```

## 5. Land momentum on a fresh main, pull manta

Always run, both modes, even when every candidate was skipped.

For momentum, the default worktree may still be sitting on a feature branch that
`new-work` created in place. Move it to `main` only when that is safe: clean tree,
and the branch either merged or already pushed. If it is dirty or carries
unpushed commits, leave it where it is, pull nothing, and report why.

```bash
git -C "<root>/momentum" status --porcelain     # must be empty to switch
git -C "<root>/momentum" checkout main
git -C "<root>/momentum" pull --ff-only origin main
```

`--ff-only` on purpose: if momentum's main has diverged locally, the pull fails
loudly instead of building a merge commit. Report the failure, do not fix it.

Manta is read-only here - no work is ever authored in it - so it just needs its
local main brought up to date. No gates, no reset, same in both modes:

```bash
git -C "<root>/manta" checkout main
git -C "<root>/manta" pull origin main
```

If that pull ever reports anything but a fast-forward or already-up-to-date, say
so and stop. It means manta is not the clean read-only checkout this assumes.

## 6. `--force`

Only when the user passed `--force`. It skips every gate in steps 1 and 5 and
destroys uncommitted and unpushed work in the momentum worktrees **and in the
default momentum worktree**. Say that in one line before running, and list what
is about to go, but do not ask for a confirmation the flag already gave.

Manta is untouched by force. It gets the same plain pull as step 5.

The scope rules in "What may be touched" still hold. `--force` means no checks,
not a wider blast radius: gnhf, manta, and everything else under the root are
still off limits.

```bash
cd "<root>/momentum"                                     # never stand in a target

# every momentum-* worktree under the root
git -C "<root>/momentum" worktree remove --force <worktree-path>
git -C "<root>/momentum" worktree prune

# every local branch but main
git -C "<root>/momentum" branch -D <branch>

# reset the default momentum worktree to the remote
git -C "<root>/momentum" fetch --prune origin
git -C "<root>/momentum" checkout --force main
git -C "<root>/momentum" reset --hard origin/main
git -C "<root>/momentum" clean -fd

# manta: plain pull, exactly as in step 5
git -C "<root>/manta" checkout main
git -C "<root>/manta" pull origin main
```

`clean -fd` without `-x` on purpose: it clears stray files but leaves
`node_modules` and other gitignored build state alone, so the next run does not
start with a full reinstall.

Force mode still does not delete remote branches. That stays step 4, confirmation
only.

## 7. Report

Say what went and what stayed:

- worktrees removed, with their branches
- branches deleted, and any that needed `-D`
- **skipped**, one line each with the gate that stopped it (PR still open, dirty
  tree, unpushed commits) and what the user has to do
- momentum: on `main` and pulled, or the reason it is not
- manta: main pulled, and what it moved (already up to date is worth a word)
- anything deliberately left alone that the user might expect to be gone (gnhf's
  worktrees, a manta branch)

Do not report partial success as success. If a gate stopped a removal, that is
the headline for that entry.

## Notes

- Manual only. Never chain it onto a merge or a PR flow.
- The gates are per worktree, so one dirty leftover does not block the rest of
  the sweep. Only `--force` bypasses them.
- If the user names a target that does not resolve to an existing
  `momentum-<desc>` worktree or branch, say what you did find instead of guessing.
