---
name: ship-it
description: Commit the current working-tree changes and push them, splitting the work into one commit per logical piece and leaving local-only files uncommitted. Reads the actual diff, groups it, writes short plain-language commit subjects in the repo's own style, commits each group with explicit paths, then pushes the branch. With --pr or --draft-pr it first merges the latest origin/main into the branch and runs the prepare-to-ship gate, then resolves the TFS work item (asking, searching the board, or creating one assigned to Joey), checks the PR bullets against the item's acceptance criteria, opens the pull request from the repo's own template, and links the item back to it. Never commits to main, never stashes or deletes what it skips. Invoke when the user types /ship-it, or asks to "ship it", "commit and push", "commit my changes", "push what I have", "get this committed", or "commit, push and open the PR".
---

# ship-it: commit the current work and push it

Turn a dirty working tree into a clean push: decide what belongs in the repo,
split it into one commit per logical piece, write a short message for each, and
push the branch. With `--pr` or `--draft-pr`, carry on into the pull request.

Committing and pushing a feature branch is cheap and recoverable, so this skill
acts rather than asking at every step. It pauses in exactly three cases: the
branch is `main`, something looks like a secret, or a file's diff is genuinely
ambiguous about whether it is real work or a local tweak. PR mode adds three
more: a merge conflict it cannot resolve safely (step 3), and the two work-item
questions (steps 11 and 12).

Out of scope, deliberately: amending or rebasing existing commits, and running
the checks yourself (PR mode delegates that to `prepare-to-ship` rather than
reimplementing it).

## Invocation

```
/ship-it [hint]                      # commit and push only (default)
/ship-it --pr [hint]                 # ... plus merge main, gate, work item, PR
/ship-it --draft-pr [hint]           # ... same, but the PR opens as a draft
/ship-it --pr --work-item 698997     # skip work-item resolution, use this id
```

`hint` is optional. Use it as context for the split, the message or the PR body
("this is all one change", "the config bit is separate"), never as a reason to
include a file step 6 would skip.

`--pr` and `--draft-pr` are the same flow; they differ only in the flag passed to
`gh pr create` and in what step 12 does on a mismatch. Both open a real PR against
`main` on a shared repo, so PR mode is gated on the branch being up to date with
`origin/main` and green on the local checks first, in that order.

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
  style comes from (step 8).

## 2. Resolve the mode

Read the flags, then say the resolved shape in one line before any further tool
call: `Mode: commit+push | commit+push+PR | commit+push+draft PR   Branch: <branch>`.

In PR mode, two things change before anything else happens:

- **`origin/main` is merged in and the gate runs, in that order** (steps 3 and 4),
  before any commit. The gate's job is to predict CI, and CI tests the merge
  result, so gating the pre-merge branch answers the wrong question.
- **An empty working tree is not a stop.** Plain ship-it ends when there is
  nothing to commit; PR mode carries on as long as the branch has commits
  `origin/main` does not:

  ```bash
  git fetch origin
  git log --oneline origin/main..HEAD
  ```

  Nothing there and a clean tree means there is no change to open a PR for. Stop
  and say so.

## 3. PR mode: merge origin/main first, always

A PR that has not seen the latest `main` is a PR whose checks mean less than they
look like they do, and the conflict shows up on the reviewer's screen instead of
yours. So this happens on every PR-mode run, with no "probably fine" exception.

```bash
git fetch origin
git log --oneline HEAD..origin/main        # what is coming in; empty means up to date
git merge origin/main
```

Merge, never rebase. This skill does not rewrite history, and a merge keeps the
commits the human already reviewed exactly where they were.

**If the tree is dirty**, git refuses the merge when an incoming file is also
modified locally. Check before running it:

```bash
git diff --name-only HEAD...origin/main    # incoming
git status --porcelain                      # local
```

- No overlap, or a clean tree: merge now.
- Overlap: run steps 5 through 9 first (inventory, skip, group, commit), then come
  back here and merge. Never stash to get around it - a stash is how local-only
  state gets lost, and step 6 exists precisely to keep it in the tree.

**Already up to date** is the common case. Say so in one line and carry on.

**Conflicts** split two ways:

- **Unambiguous and mechanical** - both sides added a key to the same `en.json`
  block, a lock file that regenerates, an import list. Resolve it, say in the
  report which file and how.
- **Anything where both sides changed the same logic** - stop. Leave the
  conflicted state in place (do not `git merge --abort`; that just makes the
  human redo the merge), name the files, and hand back. Resolving someone else's
  change against yours is a code decision, not bookkeeping. `wrap-it-up` owns
  that pass if the branch needs it.

The merge commit is a commit on the branch. Take git's default message for it,
and note it in the report so nobody wonders where it came from.

## 4. PR mode: run the gate

Run `prepare-to-ship` on the merged tree, before committing, so the tests and lint
fixes it writes are part of the commits rather than a stray dirty tree afterwards.

- Follow that skill's own dispatch rule: if this context already carries tool
  output, hand the whole run to a fresh `general-purpose` subagent and relay only
  its scorecard and verdict.
- Reuse an earlier green run **only** if it ran in this session, nothing has been
  edited since, and step 3 merged nothing. A merge invalidates it: that is the
  combination CI is about to test and nothing has tested yet.

**READY TO PUSH** -> carry on to step 5.

**NOT READY** -> commit and push anyway (steps 5 through 10), then **stop without
opening the PR**. The work is saved and the branch is where the human works from;
what is not safe is a PR against `main` that fails its own checks. Report the real
scorecard, name the failing check, and say that re-running `/ship-it --pr` after
the fix picks up from here. This holds for `--draft-pr` too: a draft still runs
CI and still asks reviewers for their attention.

## 5. Inventory the changes

Read what is actually there. Do not commit from `git status` alone.

```bash
git status --porcelain            # tracked changes plus untracked files
git diff                          # unstaged
git diff --cached                 # anything already staged
git diff --stat
```

If something is already staged, do not assume it is the intended split - fold it
into the grouping in step 7 like anything else, and unstage as needed
(`git restore --staged <paths>`) so each commit gets the exact set you chose.

Read the real diff of every file before grouping it. The point of this skill is
the grouping, and a path cannot tell you which piece of work a change belongs to.

## 6. Skip the local-only files

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
  edited by a person. A file the step 3 merge brought in is not a hand edit -
  check the merge before raising this.

Debug leftovers are different from local files: they sit inside a file that does
belong in the commit. Point them out and ask whether to strip them or ship them,
rather than quietly committing them or excluding the whole file.

Most local junk is already covered by `.gitignore` (this repo ignores `bin/`,
`obj/`, `artifacts/`, `coverage/`, `node_modules/`, `RESUME.md`, `src/ui-app/logs`
and more), so the list above is mainly about **tracked files with local
modifications** and untracked files nobody thought to ignore.

When a file is genuinely ambiguous, ask - but batch every ambiguous file into one
question, and do not ask about anything the table above already settles.

## 7. Group into logical pieces

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
- **In PR mode, the gate's own edits are a piece.** Tests `prepare-to-ship` wrote
  go with the code they cover; a pure lint autofix sweep is its own commit.

If you cannot write a short subject for a group without the word "and", that is
the signal it is two pieces.

**A single file mixing two kinds of work is the awkward case.** Interactive
staging (`git add -p`, `git add -i`) is not available in this environment, so you
cannot split it by hunk. Either edit the file so one piece lands first (only if
that is trivial and safe), or keep it whole in the commit for its dominant change
and say plainly in the report that the commit also carries the other change.
Never reformat or rewrite the file to force a cleaner split.

State the planned split before executing it - one line per commit, with its
files. Then carry on; no confirmation needed unless step 6 raised something.

In PR mode this grouping is also the PR's bullet list, so it does double duty:
the pieces a reviewer reads as one decision are the bullets step 12 checks
against the acceptance criteria. Do not re-derive a different list later.

## 8. Write the message

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
- Apply the writing rules inline: no hedging, no filler, no "comprehensive" or
  "robust", nothing that reads as generated.

## 9. Commit each piece

Stage explicit paths, never `git add -A` or `git add .` - a blanket add is how a
skipped file gets committed.

```bash
git add -- <paths for this piece>
git status --porcelain            # confirm the staged set is exactly what you meant
git commit -m "<subject>"
```

Check the staged set before every commit, not just the first. Repeat per piece,
in the order decided in step 7.

If a commit fails, stop and report it rather than working around it. A pre-commit
hook rejecting the change is a real signal, not an obstacle - never pass
`--no-verify` to get past one.

## 10. Push

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
  a rejected push means the remote moved, and that is the user's decision. In PR
  mode a failed push ends the run: there is nothing on the remote to open a PR
  against.

Default mode ends here. Go to step 15.

## 11. PR mode: resolve the work item

Every momentum PR has to link at least one TFS work item - `pr-metadata` reads the
body and fails without one. So the item is resolved before the PR is written, not
after.

**A PR may already exist for this branch.** Check first, and if one is open, do
not create a second:

```bash
gh pr view --json number,url,state,isDraft,body
```

An open PR means the push in step 10 already updated it, and the step 3 merge is
now on it too. Report its URL and stop there, unless the user asked for the body
to be rewritten.

Work through these sources in order and take the first that answers:

1. **`--work-item <id>`**, or an id the user gave in the conversation.
2. **The branch's own paper trail**: `artifacts/wrap-it-up/<branch>.md`, a
   `src/ui-app/logs/*` handoff for this feature, a spec under
   `src/<component>/specs/`, digits in the branch name, or an id already in a
   commit message.
3. **The board.** Search rather than guess, with both tools, since they answer
   differently:

   ```
   mcp__azure-devops__wit_my_work_items          project=Cloud type=assignedtome
   mcp__azure-devops__search_work_items_semantic query=<what the branch does, in a sentence>
                                                 project=["Cloud"]
                                                 areaPath=["Cloud\\Projects\\Momentum"]
   ```

   Rank candidates on whether the item's title and acceptance criteria describe
   **this** change - the same component, the same behavior - not on keyword
   overlap. A story about the same page that asks for something else is not a
   match.
4. **Nothing plausible** -> create one with the `create-tfs` skill (story or bug
   per the change), assigned to `LASERFICHE\joey.lin`, its acceptance criteria
   written from what the branch actually does. Then use the returned id.

Then read the chosen item before trusting it:

```
mcp__azure-devops__wit_get_work_item id=<id> project=Cloud expand=relations
    fields=["System.Title","System.State","System.AssignedTo","System.AreaPath",
            "Microsoft.VSTS.Common.AcceptanceCriteria"]
```

- **Interactive**: put the top three candidates, "create a new one", and "none of
  these, I will give you the id" to the human with `AskUserQuestion`, each
  candidate as id, title and state. Ask once; do not walk the list one at a time.
- **Auto mode** (see the autonomous section): take the top candidate only when it
  clearly describes this change. Anything short of that, create a new item - a
  wrong link is worse than an extra story, because it silently attributes the work
  to someone else's scope.
- **Assigned to someone else** is a signal, not a detail. Say so and confirm
  before linking; do not reassign it.

## 12. PR mode: check the bullets against the acceptance criteria

The PR bullets come from step 7's grouping. The acceptance criteria come from the
item's `Microsoft.VSTS.Common.AcceptanceCriteria` (HTML, usually a `<ul>`). Line
them up one to one and classify every entry on both sides:

- **A criterion with no bullet delivering it** - the branch does not finish the
  item. This is the mismatch that matters.
- **A bullet no criterion asks for** - the branch does more than the item says.
  Worth reporting, but it does not block on its own unless it is a whole feature.
- A bug with no acceptance criteria at all: compare the bullets against its
  repro / observed-versus-expected description instead, and say that is what you
  compared.

Judge on substance. Different wording for the same behavior is a match; a
criterion the branch half-does is not.

**Everything lines up** -> carry on to step 13, and say so in one line.

**Mismatch** -> stop and ask, with the gaps listed concretely (which criterion,
which bullet). `AskUserQuestion`, two options:

1. **Open it as a draft and note the gap** - the PR body carries a short line
   saying which criteria are not delivered yet. Nothing on the board changes.
2. **Trim the item to match** - remove the undelivered criteria from the work
   item (`wit_update_work_item` on the acceptance-criteria field) and open a
   normal PR. Show the exact criteria you would remove before touching the board,
   and say plainly that anything still wanted needs its own item; do not create
   that follow-up here.

If the mismatch is the other direction (a bullet no criterion covers), the same
question applies, with option 2 reading "add it to the item's criteria" instead.
Only offer that for a real feature a person can check in front of the app. A
bullet about tests, coverage, lint or build, or about an error path like a 403
message, is not a missing criterion - it is deliberately not AC (see the "TFS
work items" section of `joey-writing-style.md`). Drop it from the comparison
instead of pushing it onto the board.

**Auto mode default is option 1**: draft, with the gap noted in the body. Never
edit a shared board item's acceptance criteria unattended - a criterion the
run cannot see the value of is exactly the one someone else is waiting on.

`--draft-pr` is already a draft, so option 1 there is just the note.

## 13. PR mode: open the PR

**Read the template from the repo, do not write one from memory.**

```bash
cat docs/pull_request_template.md
```

It changes (the impact and risk sections were removed on 2026-08-19). Fill every
section it actually has, replacing each `TODO`. If a checkout still carries the
impact and risk sections, fill them properly per the global CLAUDE.md rather than
dropping them.

- **Title**: `[area] Imperative summary`, area being the component folders
  touched. More than one is written `[repository, repository-mover]`.
- **Description of changes**: the step 7 bullets. Short, factual, skimmable; what
  changed, not a line-by-line reading of the diff, no praise. The `origin/main`
  merge is not a bullet - it is not part of what this branch changes.
- **Work item links**: one bullet per item, in the shape the board's own PRs use,
  which is also the shape `pr-metadata`'s regex accepts:

  ```
    * [User Story 698997](https://v-dev-tfs/DefaultCollection/Cloud/_workitems/edit/698997): <title>
  ```

- Every claim comes from code you read. Where you could not determine something
  (a consumer you cannot see, a migration you cannot verify), write that you could
  not determine it. Never guess and never pad.
- Read the body back before it goes up and cut the AI tells: hedging, filler,
  em dashes, a closing paragraph that restates the bullets. This is outward-facing
  prose on a shared repo.

Write the body to a file in the scratchpad and pass it by path, so nothing gets
mangled by shell quoting:

```bash
gh pr create --base main --head "$(git branch --show-current)" \
  --title "<title>" --body-file <scratchpad>/pr-body.md [--draft]
```

Use `--draft` for `--draft-pr`, and for the step 12 mismatch default. Report the
URL `gh` returns; do not claim it opened without one.

## 14. PR mode: link the work item back to the PR

The PR body points at the item; the item has to point back, as a **Hyperlink
relation on its Links tab** - not a comment. The `wit_*` MCP tools cannot add one
for a GitHub PR (`wit_link_work_item_to_pull_request` only handles ADO-hosted
PRs, and `wit_update_work_item` takes string fields, not relation objects), so
this goes through the TFS REST API with Windows integrated auth.

Skip it if the relation is already there - the `expand=relations` read in step 11
shows the existing hyperlinks, and re-running would add a duplicate.

On WSL, integrated auth needs the Windows PowerShell interop:

```bash
powershell.exe -NoProfile -Command "Invoke-RestMethod -Uri 'https://v-dev-tfs.laserfiche.com/DefaultCollection/Cloud/_apis/wit/workitems/<id>?api-version=5.0' -Method Patch -ContentType 'application/json-patch+json' -UseDefaultCredentials -Body '[{\"op\":\"add\",\"path\":\"/relations/-\",\"value\":{\"rel\":\"Hyperlink\",\"url\":\"<pr-url>\",\"attributes\":{\"comment\":\"<short desc>\"}}}]'"
```

If it fails, say so with the real error and leave the PR open. The link back is
bookkeeping; a failed patch is not a reason to close or redo anything.

## 15. Report

- each commit: short hash and subject, in order
- what was left uncommitted and why (per file, one line each)
- push result: the branch and that it is on `origin/<branch>`, or the real error
- if any `en.json` changed: the PR needs the **`to-be-translated`** label for
  `pr-i18n-parity` to pass. That label is Joey's to add, so give him the command
  and move on: `gh pr edit <n> --add-label to-be-translated`. Do not try to fix
  parity locally.
- if a commit carries a mixed file from step 7, say which one and what rode along

In PR mode, add:

- the `origin/main` merge: the sha merged and how many commits came in, or that
  it was already up to date, plus every conflict and how it was resolved
- the gate verdict and its scorecard, or that a same-session green run was reused
  (only valid when the merge brought nothing in)
- the work item: id, title, and how it was resolved (given, found on the board,
  or created)
- the acceptance-criteria check: matched, or the gaps and which option was taken
- the PR: URL, and whether it is a draft and why
- the link back: added, already present, or the error
- what CI still owns that the local gate does not cover: the container builds,
  the migration apply, and the contract breaking-change check. A green scorecard
  is not a promise that CI is green.

Keep it to a few lines. No praise for the change, no summary of what the code
does.

## Autonomous mode

See [`../shared/autonomous-pipeline.md`](../shared/autonomous-pipeline.md). The
gate replacements specific to this skill:

| Interactive gate | Headless default |
|---|---|
| Step 3 merge conflict | resolve only the mechanical ones; a logic conflict is a stop, reported with the file list and the tree left conflicted |
| Step 6 ambiguous file question | commit only what is unambiguously real work; leave anything ambiguous in the tree and list it |
| Step 11 work-item choice | take the top board candidate only on a clear match, otherwise create one via `create-tfs` assigned to Joey |
| Step 12 mismatch question | open as a **draft** with the gap noted in the body; never edit the item's acceptance criteria unattended |

The hard stops do not soften: a secret, a hand-edited translation catalog, the
branch being `main`, and a NOT READY gate all still stop the run, and a stop is
reported rather than worked around.

## Notes

- Only run when asked. Uncommitted changes are the user's review state; this skill
  is the explicit "ship it".
- No amending, no rebasing, no force-pushing, no history rewriting. This skill only
  adds commits on top, the step 3 merge included.
- **Without `--pr` or `--draft-pr` it merges nothing, opens nothing and touches no
  board.** That is what an orchestrator calling ship-it as a phase gets by default,
  so `wrap-it-up` and `joey-bot` keep their own merge and housekeeping rules unless
  they pass the flag.
- In the jj-colocated repo, plain `git commit`, `git merge` and `git push` are
  fine; jj picks up the new commits and the remote bookmark on its next command.
- Nothing to commit is a normal outcome in default mode. Say the tree is clean (or
  that everything in it was local-only) and stop. In PR mode see step 2.
