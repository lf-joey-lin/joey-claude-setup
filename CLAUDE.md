

# Claude setup source of truth

My skills, this CLAUDE.md, settings.json, and statusline.js are the canonical copies in the git repo at `C:\code2\joey-claude-setup`, symlinked into `~/.claude`. Editing any of these files edits the repo copy directly (that is what the symlink gives me), so to update: change the file in place, then commit and push from `C:\code2\joey-claude-setup`.

- Don't drop a real file into `~/.claude` for a path the repo owns; that replaces the symlink and breaks the sync. If it happens, re-run `bootstrap.ps1` from the repo.
- New machine: clone the repo and run `bootstrap.ps1` to recreate the links.

# Git

- Branch new work off the latest remote base: `git fetch origin` then `git checkout -b <branch> --no-track origin/main` (or `origin/develop`) — never off a stale local checkout. The `--no-track` matters: without it the new branch inherits `origin/develop` as upstream, and `git push` then fails with an upstream/branch name mismatch under `push.default=simple`.
- Branch name: `veryShortCamelCaseDesc` (e.g. `fixFormSubmitNullCheck`).
- First push sets the matching upstream: `git push -u origin HEAD` (creates `origin/<branch>`). Never push to the base branch directly (no `HEAD:main`).
- Commit message: `<short imperative description>`. No other trailers. Apply the writing rules below (see Writing).
- Don't commit or push unless asked — uncommitted changes are my review state.

# Momentum project

Workflow for the `momentum` GitHub repo (org `Laserfiche`).

- **Session start, before modifying any code:** confirm the working tree is clean and on a branch pulled fresh from `origin/main` (see Git above — `git fetch origin` then a new `--no-track` branch off `origin/main`). Don't start editing on a stale or dirty checkout.
- **Concurrent work / dirty default worktree:** if the default worktree at `C:\code2\momentum` has modified content or another branch's in-progress work, don't disturb it — create a new worktree under `C:\code2` (i.e. `C:\code2\momentum-<feature>`) and work there instead.
- **Localized strings: edit `en.json` and nothing else.** `fr.json`, `es.json`, `en-XA.json` and the XLIFF memory are pipeline output. Never hand-edit them, never hand-prune keys a change removed, and never reach for `translate.ts --pseudo` to quiet a check — that writes fake accented text into real catalogs.
- **`pr-i18n-parity` is mine to clear, not yours.** It fails on any branch that changed an `en.json`, which is the point: I add the **`to-be-translated`** label to the PR and the pipeline commits the regenerated catalogs back to the branch. It needs `MTRANS_*` credentials, so it cannot run locally anyway. Don't run `check-parity.ts` in a pre-push check, don't report it as a failure, and don't let it block a "ready to push" verdict — just remind me the label is still needed. A pre-push check earns its keep on unit tests, the 100% coverage gates, lint, build and a11y.
- **On creating a PR — link both directions:** (write the PR title/body per Writing below)
  - PR -> work item: the PR body carries a `## Related` hyperlink to the TFS work item.
  - work item -> PR: add the GitHub PR as a **Hyperlink relation in the work item's Links tab** — not a comment. The ADO `wit_link_work_item_to_pull_request` MCP tool only links ADO-hosted PRs, so it can't be used for a GitHub PR. The `wit_update_work_item` MCP tool can't add it either (it only accepts string field values, not a relation object). Add it via the TFS REST API with Windows integrated auth:
    ```powershell
    Invoke-RestMethod -Uri "https://v-dev-tfs.laserfiche.com/DefaultCollection/Cloud/_apis/wit/workitems/<id>?api-version=5.0" `
      -Method Patch -ContentType "application/json-patch+json" -UseDefaultCredentials `
      -Body '[{"op":"add","path":"/relations/-","value":{"rel":"Hyperlink","url":"<pr-url>","attributes":{"comment":"<desc>"}}}]'
    ```

# Coding

- Smallest useful diff; tightly scoped to the request.
- Match the repo's existing style over my personal preference.
- Comments: add only for very non-obvious code (the "why", not the "what"); keep as short as possible. Don't comment self-explanatory code. When I do write one, apply the writing rules below (see Writing).
- Comment wording: plain, simple, direct. Short words, short sentences, ordinary
  grammar. Say what a reader needs to know and stop. Leave out the deep technical
  detail, the background story, and the hedging.
- Ask before adding a dependency or library.
- Verify before claiming something works — don't assert unchecked success. What
  "verify" means per edit is compile/lint, not the test suite (see Testing).

# Writing

Any outward-facing prose I author or edit — code comments, commit messages, PR
titles/descriptions, TFS work item text — must read like a person wrote it, not
an LLM. Internal skill, doc, and config files are out of scope.

- **Compact by default, in every genre.** PR bodies, code comments, TFS story and
  bug descriptions, acceptance criteria, commit messages, review replies, status
  updates. Write the shortest version that still carries the point: what changed,
  plus whatever a reader would not guess from the diff. Then stop. Long is a
  failure mode, not thoroughness — a dense description gets skimmed and nothing
  lands. Rules of thumb: cut anything the diff, a CI check, or the linked work
  item already says; if a paragraph and a bullet cover the same ground, keep the
  bullet; drop a line rather than defend a decision the code comment already
  carries. Short sentences, short words, plain grammar.
- **Avoid AI writing.** No em dashes, no emoji, no arrows or box-drawing
  characters, sentence-case headings. Cut hedging and filler. Nothing that reads
  as generated: no "comprehensive", "robust", "seamless", "delve", "it's not just
  X, it's Y", no closing summary that restates what was already said. Read it back
  and cut whatever a person would not have written.
- `joey-writing-style.md` carries the per-genre length targets and the TFS work
  item rules. Read it when writing something longer than a commit subject.

# Testing

Testing is its own phase, not part of every edit. **Default: edit only.** Don't write
or run the test suite after each change. A session is usually edit + edit + edit, then
test once at the end — many of those edits are experimental and get reworked or thrown
away, so tests written per-edit are wasted and get rewritten anyway.

Start the testing pass when I ask for it ("add tests", "cover this", "run the tests"),
or when I say I'm ready to commit or open a PR. Cover everything the session changed in
one pass at that point.

After an individual edit, do the cheap checks only: compile / typecheck / lint on what
you touched, so the code I'm reading is known to build. Those are not tests. Then stop
and hand back — don't volunteer the next step.

When the testing pass does run, match verification to risk and say which level you chose
and why:

- **Unit** for pure logic, parsing, calculations, edge cases, clear-IO bug fixes. For a
  bug fix, start from a test that reproduces the bug and fails.
- **Integration** when crossing boundaries (DB, API, services); prefer real integrations over heavy mocking.
- **Human verification** (call out what to check) for UI/UX, layout, rendering quirks, third-party auth, anything not deterministically assertable. If a fix can't be auto-tested, say so and explain the manual check.
