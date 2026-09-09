---
name: stamp
description: Commit the current branch's uncommitted work. Reads the working tree, groups clearly unrelated changes into separate commits (one commit when it is all one thing), writes each message in the repo's own style, and commits. Refuses to touch the read-only default momentum worktree, refuses to commit onto a base branch, and never pushes unless asked. Sweeps for things that must not be committed first - secrets, generated translation catalogs, build output, debug leftovers - and reports them instead of quietly including them. Invoke when the user types /stamp, or asks to "commit what I have", "commit this", "stamp my work", "commit the working tree", or "save this off before I keep going".
---

# stamp: commit the working tree

Turn whatever is uncommitted on the current branch into commits. Nothing else:
no tests, no lint, no docs, no refactors, no push. The point is a small, honest
commit that captures the state the user just verified by hand.

## Invocation

```
/stamp [message] [--one] [--push] [--dry-run]
```

- **`message`:** use it as the commit subject, tidied to the style rules below,
  and skip the split. An explicit message means one commit.
- **`--one`:** one commit for everything, message written by stamp.
- **`--push`:** push after committing. Without it, never push - print the command
  instead.
- **`--dry-run`:** show the plan (groups, messages, what got flagged) and stop.

## 1. Refuse to run in the wrong place

Check these before reading a single diff. Each one stops the run with a plain
sentence saying which check failed.

- **The default momentum worktree is read-only.** Resolve
  `git rev-parse --show-toplevel`. If it is `<root>/momentum` (`~/m-code` on
  WSL/Linux, `C:\code2` on Windows), stop. That checkout is for reading. Say so
  and point at making a feature worktree.
- **Not on a base branch.** `main`, `master`, `develop`: stop. Offer the branch
  command from the Git rules (`git fetch origin`, then `git checkout -b
  <veryShortCamelCaseDesc> --no-track origin/main`) and let the user decide.
- **No merge, rebase or cherry-pick in progress.** `git status` says so; a commit
  in the middle of one means something different. Stop.
- **Something to commit.** `git status --porcelain -uall` empty means done -
  say "nothing to commit" and stop. Ignored files do not count; they never show
  up here.

If `.jj/` exists in the worktree, `git branch --show-current` can lie (detached
HEAD). Read the branch from `jj` in that case, or ask.

## 2. Read the change

```bash
git status --porcelain=v1 -uall
git diff                # unstaged
git diff --cached       # already staged
git log --oneline -10   # message style actually in use here
```

Read the actual diff, not just the file list. The commit message has to say what
changed, and a filename does not tell you that.

If the user had already staged a subset, say so in the plan. stamp's contract is
"commit everything uncommitted", so it still takes the lot unless the user says
otherwise, but a deliberate staging is worth naming before it gets swept up.

## 3. Sweep for what must not be committed

Flag these, list them back, and leave them out of the commit unless the user
says to include them. Do not silently commit any of them.

- **Secrets.** Tokens, keys, connection strings, `.env` files, anything that
  looks like a credential in a diff line.
- **Generated translation catalogs.** `fr.json`, `es.json`, `en-XA.json` and the
  XLIFF memory are pipeline output. `en.json` is the only one a human edits. A
  changed `fr.json` means something ran that should not have.
- **Build output and junk.** `bin/`, `obj/`, `node_modules/`, `.nuxt/`,
  `.output/`, coverage reports, `*.log`, editor scratch files. Most are gitignored
  already; anything that got through anyway is a mistake.
- **Debug leftovers.** A stray `console.log`, `.only` on a test, a commented-out
  block, a hardcoded local URL or credential. These are worth a one-line mention
  even when the user wants them committed anyway - they are usually forgotten,
  not intended.

A flagged file that the user does want in stays out of the commit until they say
so. Report and ask; do not decide for them.

## 4. Group

Default is to split. Group the changes into the smallest number of commits where
each one is a single coherent change a reviewer could read on its own. All of it
being one thing is the common case and one commit is the right answer then -
splitting for its own sake makes worse history, not better.

Two hard constraints:

- **Split by file, never by hunk.** Interactive `git add -p` is not available
  here. If one file's changes belong to two groups, they go in one commit
  together and the message covers both. Say that in the plan rather than
  pretending the split was clean.
- **Every commit must stand up on its own.** If group A does not build without
  group B, they are one commit. Do not create a broken intermediate.

`--one` or an explicit message skips this and everything goes in a single commit.

## 5. Write the messages

One imperative fragment per commit. This is the repo's convention and the
writing rules apply in full.

- `<short imperative description>`, no area prefix, no trailing period, roughly
  50 characters. "Fix null check on form submit", not "Fixed the null check that
  was causing the form submit handler to throw".
- **No trailers of any kind.** No `Co-Authored-By`, no `Generated with`, no
  emoji, no em dashes.
- **No body** unless there is a genuine gotcha the diff does not show - why a
  workaround exists, what breaks without it. One or two lines then, not a
  changelog.
- Say what changed, not what file changed. `git log` already has the filenames.

Match the register of the last ten commits. If the repo prefixes with an area,
prefix; if it does not, do not.

## 6. Commit

Show the plan first - each group, its files, its message, plus anything flagged
in step 3 - and get a yes. `--dry-run` stops here.

Then, per group, stage by explicit pathspec and commit:

```bash
git add -- <the files in this group>
git commit -m "<message>"
```

Stage explicitly, never `git add -A`, or a flagged file walks in behind you.

**A failing pre-commit hook is a real failure.** Report what it said and stop.
Never reach for `--no-verify`.

## 7. Report

Short. One line per commit (`<sha> <subject>`), then:

- Anything left uncommitted, and why - flagged files, a file the user held back.
- The push command, when `--push` was not passed:
  `git push -u origin HEAD` for a branch with no upstream, `git push` otherwise.

With `--push`, push and say where it landed. Never push to a base branch.

## Out of scope

stamp commits. It does not run tests, lint, or a build; it does not open a PR or
touch a work item (that is `paperwork`); it does not amend or rewrite existing
commits; it does not merge or pull (that is `merge-main`). If a check ought to
run before this commit, say so in the report and let the user call it.
