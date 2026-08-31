---
name: new-work
description: Set up the local git environment for a new story or bug fix in the momentum repo. Takes a short description, fetches origin, and always spins up a fresh worktree at <root>/momentum-<shortdesc> with a branch cut off origin/main. The default worktree at <root>/momentum is never branched in and never written to - it stays on main as a read-only reference checkout. Publishes the new branch right away so it tracks origin from the start and unpushed commits show up as outgoing changes in the editor. The workspace root is ~/m-code on WSL/Linux and C:\code2 on Windows. Invoke when the user types /new-work, or asks to "start new work", "set up a branch for", "begin a story", or "start a bug fix".
model: sonnet
effort: low
---

# new-work: set up the local env for new work

Prepare a clean starting point for a new story or bug fix: a feature branch cut
fresh from `origin/main`, checked out in a **new worktree of its own**. This is
the front half of the workflow that `teardown` closes out.

Creating a branch and worktree is cheap and reversible, so this skill acts rather
than asking at every step. It only pauses when a name already exists or the
derived branch name looks wrong.

## The default worktree is read-only

`<root>/momentum` is the reference checkout. It stays on `main`, and the only git
command this skill runs there is `fetch` (a `pull` is the one other thing allowed
to touch it, from `teardown`). Every piece of dev work gets its own worktree, no
matter how clean or idle the default one looks.

Never, in the default worktree: `checkout -b`, `switch -c`, `commit`, `stash`,
`reset`, or an edit to a tracked file. "It was clean, so I branched there" is the
failure this rule exists to prevent - it leaves the agent's read-only view of
`main` sitting on someone's feature branch.

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

The rest of this skill writes the root as `<root>`: the reference checkout is
`<root>/momentum` and the new worktree is `<root>/momentum-<shortdesc>`.

## 2. Fetch the latest remote base

Always branch off the freshest `origin/main`, never a stale local ref:

```bash
git -C "<root>/momentum" fetch origin
```

This is the only command that touches the default worktree. It moves no files and
changes no branch.

## 3. Check the target names are free

```bash
git -C "<root>/momentum" branch --list <branch>       # branch must not exist
git -C "<root>/momentum" worktree list                # path must not be taken
```

If the branch already exists or the worktree path is occupied, stop and report it
- do not clobber. Let the user pick a different `<shortdesc>` or confirm reuse.

Do not inspect the default worktree's status to decide anything. It has no say in
where the work goes; the answer is always a new worktree.

## 4. Create the worktree

Create it directly under `<root>`, alongside the reference checkout - never
inside `.claude/worktrees` or under the repo itself:

```bash
git -C "<root>/momentum" worktree add --no-track -b <branch> "<root>/momentum-<shortdesc>" origin/main
```

That single command creates the branch off `origin/main` and checks it out into
the new worktree in one step, without disturbing the default worktree's checkout.

The `--no-track` is required: without it the branch inherits `origin/main` as
upstream, a bare `git push` fails under `push.default=simple` on the branch name
mismatch, and until step 5 runs the tree reads as "ahead of origin/main" rather
than as a branch of its own.

On WSL, keep the worktree on the Linux filesystem under `~/m-code`. Do not put it
on a `/mnt/c` path: the 9p mount is slow enough to break tooling that assumes
local-disk speed (node_modules loads, watchers, dotnet builds).

## 5. Publish the branch immediately

Push the new branch straight away, from the new worktree:

```bash
git -C "<root>/momentum-<shortdesc>" push -u origin HEAD
```

This is the setup step, not a "push my work" step. The branch is still sitting on
`origin/main`'s commit, so the push transfers no objects and creates no PR; it
only creates `origin/<branch>` and sets the matching upstream.

The upstream is the point. Without one, `@{upstream}` is undefined, so VS Code's
Source Control view hides its incoming/outgoing section entirely and the sync
button reads "Publish Branch" instead of showing the unpushed-commit count.
Setting the tracking ref up front means every commit made from here on shows as
outgoing without having to remember to publish first.

Safe to do at setup in this repo specifically: every workflow under
`.github/workflows/` triggers on `pull_request` or `push` to `main`, so pushing a
feature branch runs no CI.

Two things to get right:

- **Use `HEAD`, not the branch name**, and keep `-u`. Step 4's `--no-track` left
  the branch with no upstream on purpose; this is what sets it.
- **A failed push is not a failed setup.** If the push fails (offline, auth,
  remote rejects the name), the branch and worktree are still good. Report the
  actual error and carry on to step 6 rather than unwinding anything.

## 6. End up in the worktree

The whole point of the setup is to work in the new worktree, so finish there
rather than leaving the human to `cd` by hand and restart Claude.

```
EnterWorktree(path: "<root>/momentum-<shortdesc>")
```

- It needs the session's current directory to be inside a git repo. Launched at
  `<root>` it fails with "the current directory is not in a git repository";
  launched at `<root>/momentum` it works. A failure here is not a setup failure -
  report the path and let the human move.
- It asks to confirm once. If that is declined, carry on to the report.
- Never call `ExitWorktree` after it. Git created this worktree, not the tool, so
  the tool cannot remove it and `keep` would only bounce the session back to
  where it started.

## 7. Report

State plainly what was set up so the next steps are obvious:

- the branch name (and that it is off fresh `origin/main`)
- the resolved absolute path of the new worktree, not the `<root>` placeholder
- the working directory to run subsequent commands from, and whether this session
  already moved there or the human still has to
- that the branch is published and tracking `origin/<branch>`, or, if the push
  failed, that it is local-only and why

## Notes

- Every invocation creates a worktree. There is no in-place branching path, and
  no condition under which the default worktree is a valid place to work.
- Never branch off a stale local `main`; the `fetch` in step 2 is not optional.
- Never push to `main` directly. Publishing the feature branch at setup (step 5)
  is the one push this skill makes, and it carries no commits.
- One piece of work per invocation - it maps to exactly one branch and exactly
  one worktree.
- This is setup only. It creates no TFS work item and opens no PR. Both are
  `paperwork`'s job at the end of the session, once there is a branch worth
  filing paperwork for. The flow is `new-work` -> implement -> `wrap-it-up` ->
  `paperwork`.
