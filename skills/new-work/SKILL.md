---
name: new-work
description: Set up the local git environment for a new story or bug fix in the momentum repo. Takes a short description, fetches origin, and either branches in place in the default momentum worktree (when it is clean and on main) or spins up a fresh worktree at <root>/momentum-<shortdesc> so in-progress work is never disturbed. The workspace root is ~/m-code on WSL/Linux and C:\code2 on Windows. Invoke when the user types /new-work, or asks to "start new work", "set up a branch for", "begin a story", or "start a bug fix".
model: sonnet
effort: low
---

# new-work: set up the local env for new work

Prepare a clean starting point for a new story or bug fix: a feature branch cut
fresh from `origin/main`, placed either in the default worktree or in a new one
depending on what the default worktree is currently doing. This is the front half
of the workflow that `teardown` closes out.

Creating a branch or worktree is cheap and reversible, so this skill acts rather
than asking at every step. It only pauses when a name already exists or the
derived branch name looks wrong.

## Invocation

```
/new-work <shortdesc>
```

- `<shortdesc>` describes the work in a few words (e.g. "fix form submit null
  check", "home page widgets"). It is required - if it is missing, ask what the
  work is before doing anything.
- Derive the branch name as `veryShortCamelCaseDesc` per the global git
  conventions (e.g. "fix form submit null check" -> `fixFormSubmitNullCheck`). If
  the user already handed over a camelCase token, use it as-is. Show the derived
  name in the final report so a bad guess is easy to catch.

## 1. Resolve the workspace root

Worktrees live side by side under a single workspace root, which differs by
machine:

- **WSL / Linux** -> `~/m-code` (i.e. `/home/<user>/m-code`)
- **Windows** -> `C:\code2`

Resolve it once, up front, and use the concrete path in every command that
follows - shell state does not carry between commands, so substitute the real
path rather than relying on a variable:

```bash
uname -s   # Linux == WSL root ~/m-code; anything MINGW/MSYS/CYGWIN == C:/code2
```

The rest of this skill writes the root as `<root>`: the default worktree is
`<root>/momentum` and a new one is `<root>/momentum-<shortdesc>`.

## 2. Fetch the latest remote base

Always branch off the freshest `origin/main`, never a stale local ref:

```bash
git -C "<root>/momentum" fetch origin
```

## 3. Decide: branch in place, or new worktree

Inspect the default worktree at `<root>/momentum`. It is safe to reuse **only**
when it is clean and sitting on `main` - anything else is treated as in-progress
work that must not be disturbed.

```bash
git -C "<root>/momentum" status --porcelain          # empty == clean tree
git -C "<root>/momentum" branch --show-current        # expect: main
```

This repo is **jj-colocated**, so `git branch --show-current` can be stale or
detached (see the CI/CD gotchas in the repo CLAUDE.md). If `jj` is present,
cross-check the working-copy state before trusting git:

```bash
jj -R "<root>/momentum" log -r @ --no-graph -T 'bookmarks.join(",") ++ "\n"'
jj -R "<root>/momentum" status
```

- **Clean tree AND on `main`** -> branch in place (step 4a).
- **Anything else** (dirty tree, or on a feature branch, or jj shows an
  in-progress change) -> new worktree (step 4b). Do not stash, reset, or check
  out over the top of whatever is there.

Also check the target names are free before creating:

```bash
git -C "<root>/momentum" branch --list <branch>       # branch must not exist
git -C "<root>/momentum" worktree list                # path must not be taken
```

If the branch already exists or the worktree path is occupied, stop and report it
- do not clobber. Let the user pick a different `<shortdesc>` or confirm reuse.

## 4a. Branch in place (default worktree is clean)

```bash
git -C "<root>/momentum" checkout -b <branch> --no-track origin/main
```

The `--no-track` is required: without it the branch inherits `origin/main` as
upstream and `git push` later fails under `push.default=simple`.

## 4b. New worktree (default worktree is busy)

Create the worktree directly under `<root>`, alongside the primary checkout -
never inside `.claude/worktrees` or under the repo itself:

```bash
git -C "<root>/momentum" worktree add --no-track -b <branch> "<root>/momentum-<shortdesc>" origin/main
```

That single command creates the branch off `origin/main` and checks it out into
the new worktree in one step. `cd` into `<root>/momentum-<shortdesc>` for the
rest of the session's work.

On WSL, keep the worktree on the Linux filesystem under `~/m-code`. Do not put
it on a `/mnt/c` path: the 9p mount is slow enough to break tooling that assumes
local-disk speed (node_modules loads, watchers, dotnet builds).

## 5. Report

State plainly what was set up so the next steps are obvious:

- the branch name (and that it is off fresh `origin/main`)
- whether it was created in place at `<root>/momentum` or in a new worktree at
  `<root>/momentum-<shortdesc>`, and why (default worktree was clean vs. busy) -
  print the resolved absolute path, not the `<root>` placeholder
- the working directory to run subsequent commands from

Do **not** push or create an upstream here - the branch stays local until there
is something to push. When the user is ready, the first push is
`git push -u origin HEAD` (per the global git conventions), which creates
`origin/<branch>` and sets the matching upstream.

## Notes

- Never branch off a stale local `main`; the `fetch` in step 2 is not optional.
- Never push to `main` directly, and never push at setup time.
- One piece of work per invocation - it maps to exactly one branch and, at most,
  one worktree.
- This is setup only. It does not create the TFS work item (that is `create-tfs`)
  or open a PR.
