

# Claude setup source of truth

My skills, this CLAUDE.md, settings.json, statusline.js, and writing corpus are the canonical copies in the git repo at `C:\code2\joey-claude-setup`, symlinked into `~/.claude`. Editing any of these files edits the repo copy directly (that is what the symlink gives me), so to update: change the file in place, then commit and push from `C:\code2\joey-claude-setup`.

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
- Ask before adding a dependency or library.
- Verify before claiming something works — don't assert unchecked success.

# Writing

Any human-facing prose I author or edit — code comments, commit messages, PR
titles/descriptions, TFS work item text, docs, READMEs — must read like a person
wrote it, not an LLM.

- Auto-invoke the **`avoid-ai-writing`** skill on that prose before I present or
  commit it. I don't need to be asked; treat this as standing instruction for the
  writing types above.
- For a short fragment (one comment, a commit subject) apply the skill's rules
  inline rather than spinning up a full pass; for anything longer (a PR body, a
  doc section) run the skill's edit/rewrite pass.
- This reinforces the repo's own style rules (no em dashes, no emoji, sentence-case
  headings) — the skill goes further on AI-isms, hedging, and filler.

# Testing

Match verification to risk; state which level you chose and why.

- **Unit** for pure logic, parsing, calculations, edge cases, clear-IO bug fixes — write a failing test first.
- **Integration** when crossing boundaries (DB, API, services); prefer real integrations over heavy mocking.
- **Human verification** (call out what to check) for UI/UX, layout, rendering quirks, third-party auth, anything not deterministically assertable. If a fix can't be auto-tested, say so and explain the manual check.
