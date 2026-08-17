---
name: ship-it
description: Commit the current working-tree changes and push them, splitting the work into one commit per logical piece and leaving local-only files uncommitted. Reads the actual diff, groups it, writes short plain-language commit subjects in the repo's own style, commits each group with explicit paths, then pushes the branch. Never commits to main, never stashes or deletes what it skips, and does not run tests or open a PR. Invoke when the user types /ship-it, or asks to "ship it", "commit and push", "commit my changes", "push what I have", or "get this committed".
---

# ship-it: commit the current work and push it

Turn a dirty working tree into a clean push: decide what belongs in the repo,
split it into one commit per logical piece, write a short message for each, and
push the branch.

Committing and pushing a feature branch is cheap and recoverable, so this skill
acts rather than asking at every step. It pauses in exactly three cases: the
branch is `main`, something looks like a secret, or a file's diff is genuinely
ambiguous about whether it is real work or a local tweak.

Out of scope, deliberately: running tests, lint or coverage (that is
`prepare-to-ship`), opening a PR, and amending or rebasing existing commits.

## Invocation

```
/ship-it [hint]
```

`hint` is optional. Use it as context for the split or the message ("this is all
one change", "the config bit is separate"), never as a reason to include a file
step 3 would skip.

## 1. Locate the repo and check the branch

Work in the current worktree. Resolve its root and branch:

```bash
git rev-parse --show-toplevel
git branch --show-current
git log --oneline -20
```

This repo is **jj-colocated**, so `git branch --show-current` can be empty or
stale (detached HEAD). If it is, cross-check before trusting it:

```bash
jj log -r @ --no-graph -T 'bookmarks.join(",") ++ "\n"'
```

- **Never commit to `main`.** If the branch is `main` (or HEAD is detached with
  no bookmark), stop and say so. Offer to run `new-work` to cut a branch first.
  Do not create one silently - the branch name is the user's call.
- The `git log --oneline -20` is not decoration: it is where the commit subject
  style comes from (step 5).

## 2. Inventory the changes

Read what is actually there. Do not commit from `git status` alone.

```bash
git status --porcelain            # tracked changes plus untracked files
git diff                          # unstaged
git diff --cached                 # anything already staged
git diff --stat
```

If something is already staged, do not assume it is the intended split - fold it
into the grouping in step 4 like anything else, and unstage as needed
(`git restore --staged <paths>`) so each commit gets the exact set you chose.

Read the real diff of every file before grouping it. The point of this skill is
the grouping, and a path cannot tell you which piece of work a change belongs to.

## 3. Skip the local-only files

Some changes exist to make the machine work, not to ship. Leave them in the
working tree: **do not commit them, do not stash them, do not revert them, do not
delete them.** They are the user's local state.

| Skip | Why |
|---|---|
| Local dev loop edits (on WSL, anything from `~/m-code/local-server-zellij`, including its `ui-app` changes) | Never belongs in momentum. See the global CLAUDE.md. |
| Local run config: `.env*`, `*.local.*`, `launchSettings.json`, `appsettings.Development.json`, docker-compose overrides, port and connection-string tweaks | Machine-specific. |
| Scratch: temp scripts, notes to self, scratchpad output, one-off repro files, `*.log`, `logs/` | Working state, not a deliverable. |
| Build or tool output that slipped in untracked (`bin/`, `obj/`, `coverage/`, `dist/`, `.nuxt/`) | Should be ignored already; if one shows up, skip it and mention the gitignore gap. |
| Debug leftovers in otherwise real files: a `console.log`, a hardcoded token, a commented-out block, a disabled test | See below - this is a stop, not a skip. |

Two hard stops:

- **Anything that looks like a secret** (key, token, password, connection string
  with credentials, a `.pem`) - stop, name the file and line, commit nothing.
  Secrets go in env vars or the pipeline's secret store.
- **`fr.json`, `es.json`, `en-XA.json`, or the XLIFF memory modified by hand** -
  those are pipeline output. Stop and ask what changed them; only `en.json` is
  edited by a person.

Debug leftovers are different from local files: they sit inside a file that does
belong in the commit. Point them out and ask whether to strip them or ship them,
rather than quietly committing them or excluding the whole file.

Most local junk is already covered by `.gitignore` (this repo ignores `bin/`,
`obj/`, `artifacts/`, `coverage/`, `node_modules/`, `RESUME.md`, `src/ui-app/logs`
and more), so the list above is mainly about **tracked files with local
modifications** and untracked files nobody thought to ignore.

When a file is genuinely ambiguous, ask - but batch every ambiguous file into one
question, and do not ask about anything the table above already settles.

## 4. Group into logical pieces

One commit per logical piece of work. A piece is a change a reviewer would read
as a single decision, not a directory and not a file count.

- **Code plus its tests plus its strings is one piece.** A feature and the tests
  that cover it belong together, along with its `en.json` keys and any doc line
  it makes stale. Splitting them produces a commit that does not build or a commit
  that fails its own suite.
- **Different kinds of work are different pieces**, even in the same file tree:
  a behavior change, a pure rename or refactor, a formatting sweep, a dependency
  bump, a config change, a doc-only edit.
- **A mechanical sweep is its own piece.** A rename touching 40 files buried in a
  feature commit hides the feature. Commit the sweep alone.
- **Order the commits so each one stands on its own.** Put a rename or a shared
  helper before the code that uses it, so no commit in the sequence is broken.
- **Two is not better than one.** If the whole tree is one change, make one
  commit. Do not manufacture a split to look tidy.

If you cannot write a short subject for a group without the word "and", that is
the signal it is two pieces.

**A single file mixing two kinds of work is the awkward case.** Interactive
staging (`git add -p`, `git add -i`) is not available in this environment, so you
cannot split it by hunk. Either edit the file so one piece lands first (only if
that is trivial and safe), or keep it whole in the commit for its dominant change
and say plainly in the report that the commit also carries the other change.
Never reformat or rewrite the file to force a cleaner split.

State the planned split before executing it - one line per commit, with its
files. Then carry on; no confirmation needed unless step 3 raised something.

## 5. Write the message

Short, precise, plain. One subject line, no body unless a reader genuinely cannot
follow the diff without one.

- **Match the repo's existing subject style**, read from `git log --oneline -20`
  in step 1. In momentum that is `[area] Imperative summary`, where area is the
  component folder touched (`[ui-app]`, `[authz]`, `[i18n]`). Follow whatever the
  log actually shows over any preference of your own.
- Imperative mood, one line, aim for 60-70 characters.
- Say what changed in ordinary words. "Fix the toast firing twice on a failed
  load" beats "Enhance error notification handling logic".
- No trailers of any kind. No `Co-authored-by`, no `Generated with`, no issue
  refs the repo does not already use.
- No em dash, no emoji, no arrows, no box-drawing characters.
- Do not restate the diff, do not list the files, do not explain why it is a good
  change.
- Apply the writing rules inline (the `avoid-ai-writing` skill's rules for a short
  fragment): no hedging, no filler, no "comprehensive" or "robust", nothing that
  reads as generated.

## 6. Commit each piece

Stage explicit paths, never `git add -A` or `git add .` - a blanket add is how a
skipped file gets committed.

```bash
git add -- <paths for this piece>
git status --porcelain            # confirm the staged set is exactly what you meant
git commit -m "<subject>"
```

Check the staged set before every commit, not just the first. Repeat per piece,
in the order decided in step 4.

If a commit fails, stop and report it rather than working around it. A pre-commit
hook rejecting the change is a real signal, not an obstacle - never pass
`--no-verify` to get past one.

## 7. Push

```bash
git push                          # upstream already set (new-work publishes it)
git push -u origin HEAD           # only if there is no upstream yet
```

- Push the current branch only. Never `git push origin HEAD:main`, never a push
  to any branch other than the one checked out.
- Use `HEAD` with `-u`, not the branch name, when setting an upstream.
- **A failed push does not undo the commits.** If the push is rejected (behind the
  remote, auth, offline), report the real error and leave the commits in place.
  Do not `git pull --rebase`, force-push, or reset to fix it without being asked -
  a rejected push means the remote moved, and that is the user's decision.

## 8. Report

- each commit: short hash and subject, in order
- what was left uncommitted and why (per file, one line each)
- push result: the branch and that it is on `origin/<branch>`, or the real error
- if any `en.json` changed: the PR needs the **`to-be-translated`** label for
  `pr-i18n-parity` to pass. Mention it; do not try to fix parity locally.
- if a commit carries a mixed file from step 4, say which one and what rode along
- that no checks were run, so `prepare-to-ship` is still worth a pass if it has
  not happened yet

Keep it to a few lines. No praise for the change, no summary of what the code
does.

## Notes

- Only run when asked. Uncommitted changes are the user's review state; this skill
  is the explicit "ship it".
- No amending, no rebasing, no force-pushing, no history rewriting. This skill only
  adds commits on top.
- It does not open a PR. That is a separate step with its own body and work-item
  links (see the global CLAUDE.md).
- In the jj-colocated repo, plain `git commit` and `git push` are fine; jj picks
  up the new commits and the remote bookmark on its next command.
- Nothing to commit is a normal outcome. Say the tree is clean (or that everything
  in it was local-only) and stop.
