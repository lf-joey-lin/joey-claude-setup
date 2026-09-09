

# Claude setup source of truth

My skills, agents, this CLAUDE.md, settings.json, and statusline.js are the canonical copies in the git repo at `C:\code2\joey-claude-setup`, symlinked into `~/.claude`. Editing any of these files edits the repo copy directly (that is what the symlink gives me), so to update: change the file in place, then commit and push from `C:\code2\joey-claude-setup`.

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

- **The default worktree is read-only.** `C:\code2\momentum` is a reference checkout that stays on `main`, for reading code and answering questions. Never branch, commit, stash, reset, or edit a tracked file there — not even when it is clean. The only git commands allowed against it are `fetch` and `pull`.
- **All dev work happens in its own worktree.** Every story, bug fix or experiment gets a fresh one at `C:\code2\momentum-<feature>`, with the branch cut off freshly fetched `origin/main` (see Git above — `git fetch origin`, then `git -C C:\code2\momentum worktree add --no-track -b <branch> C:\code2\momentum-<feature> origin/main`). Don't start editing until the session is in that worktree.
- **Localized strings: edit `en.json` and nothing else.** `fr.json`, `es.json`, `en-XA.json` and the XLIFF memory are pipeline output. Never hand-edit them, never hand-prune keys a change removed, and never reach for `translate.ts --pseudo` to quiet a check — that writes fake accented text into real catalogs.
- **`pr-i18n-parity` is cleared by a label, never by editing catalogs.** It fails on any branch that changed an `en.json`, which is the point: the **`to-be-translated`** label goes on the PR and the pipeline commits the regenerated catalogs back to the branch. It needs `MTRANS_*` credentials, so it cannot run locally anyway. Don't run `check-parity.ts` in a pre-push check, don't report it as a failure, and don't let it block a "ready to push" verdict.
  - The one place that label gets added for me is `paperwork --pr`, when it opens a ready-for-review PR and the branch changed an `en.json`. Everywhere else, including a draft PR, just remind me the label is still needed and give me the command. A pre-push check earns its keep on unit tests, the 100% coverage gates, lint, build and a11y.
- **On creating a PR, link it to the work item in the PR body**: a `## Related` hyperlink to the TFS work item, written per Writing below. The reverse link is automatic - `pr-metadata.yaml` adds the PR as a Hyperlink relation on each linked work item and keeps its comment in step with the PR's state, so don't add one by hand.

# Coding

- Smallest useful diff; tightly scoped to the request.
- Match the repo's existing style over my personal preference.
- Comments: add only for very non-obvious code (the "why", not the "what"); keep as short as possible. Don't comment self-explanatory code. When I do write one, apply the writing rules below (see Writing).
- Comment wording: write for someone opening the file for the first time who does
  not yet know what it does. Plain, simple, direct. Short words, short sentences,
  ordinary grammar. Leave out the deep technical detail, the background story, and
  the hedging. Name the things in the code - the function, the prop, the piece of
  state - instead of alluding to them, and say the concrete thing that breaks
  without this code, in the words you would use out loud. No literary register: no
  sentence whose subject is an abstraction, no rhetorical contrast, no phrase that
  needs a re-read to work out what it points at. One line; two if the "why"
  genuinely needs it. A block comment over five lines is a smell - if it takes that
  much, the code needs the work, not the comment. See `joey-writing-style.md` for a
  worked before/after.
- "Match the repo's existing style" above does not extend to comment prose. Dense
  comments already sitting in a file are not a licence to add more.
- Ask before adding a dependency or library.
- Verify before claiming something works — don't assert unchecked success. What
  "verify" means per edit is compile/lint, not the test suite (see Testing).

# Code intelligence

The `typescript-lsp` plugin covers `.ts`/`.tsx`/`.js`/`.jsx`/`.mts`/`.cts`/`.mjs`/`.cjs`.
`.vue` needs a **separate** Vue language server, which is a per-machine install (set
up on WSL, see the local `~/.claude/CLAUDE.md`). Either way the LSP is a deferred
tool: load it with `ToolSearch("select:LSP")` before the first call, or it looks
unavailable.

**Check before trusting a reference count in `ui-app`.** If `.vue` comes back "No LSP
server available for file type", then a `findReferences` on a composable or util
export cannot see usage inside any `.vue` file, and the result is a floor rather than
the list. In that case grep the `.vue` files too, and never conclude "nothing uses
this any more" from the LSP alone. Where the Vue server is running, the list is whole.

Where it is genuinely better than grep:

- `findReferences` before changing a shared export. Grep on a common name (`value`,
  `update`, `props`) is noise; this is the real binding sites.
- `goToDefinition` to get through `index.ts` barrels in one hop.
- `hover` for a resolved type, including inference and generics, which grep cannot
  reach at all.
- `incomingCalls` for the blast radius of a change to a shared function.

Grep stays right for text, config, `en.json` keys, `data-testid`, and every non-code
file. The LSP is a lookup tool, not a checker: `tsc` and lint still verify an edit.
It does nothing for C#.

Setup, the version pins and why they matter, and the failure modes are in
[`language-servers/README.md`](language-servers/README.md). Short version: both
servers are global npm installs bound to the active nvm node version, and both are
pinned (`typescript@6`, `@vue/language-server@2`) because the current majors do not
work here. If the LSP tool starts answering "No LSP server available", re-run
`language-servers/setup.sh` rather than debugging it.

# Browser automation

The `chrome-devtools` MCP is the way to drive a browser. On WSL, if every call fails
with `Protocol error (Target.setDiscoverTargets): Target closed`, it is pointed at a
Chrome that is not installed: re-run `chrome-devtools-mcp/setup.sh` and restart, rather
than debugging it. A plugin update undoes the fix, so expect this to recur.

For a one-off page load without restarting the session, momentum has playwright at
`src/ui-app/node_modules/playwright`; `chromium.launch` from a script in that directory
works.

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

# Ad-hoc implementation

Implementation with me in the loop is iterative: many rounds of edit, look, rework. Most
of what an edit touches gets reworked or thrown away, so anything written around the code
is wasted at that point.

**Default for ad-hoc implementation work: code only.** After each edit run the cheap
checks on what you touched — compile / typecheck / lint — then stop and hand back. Don't
volunteer the next step.

Until I ask for it by name, don't:

- write or update tests, or run the test suite
- update docs, READMEs, changelogs, storybook stories, or comments elsewhere in the repo
- chase coverage gates or run the a11y suite
- refactor or tidy code the request didn't ask about

`loom-finish` is where all of that lands. It runs once at the end, after I've verified the
behavior, and it covers the whole session. Leaving that gap is correct, not sloppy. Say
what's still outstanding if it's worth knowing, but don't fill it in.

# Testing

Testing is its own phase, not part of every edit (see Ad-hoc implementation above). Start
the pass when I ask for it ("add tests", "cover this", "run the tests"), when I say I'm
ready to commit or open a PR, or as part of `loom-finish`. Cover everything the session
changed in one pass at that point.

When the testing pass does run, match verification to risk and say which level you chose
and why:

- **Unit** for pure logic, parsing, calculations, edge cases, clear-IO bug fixes. For a
  bug fix, start from a test that reproduces the bug and fails.
- **Integration** when crossing boundaries (DB, API, services); prefer real integrations over heavy mocking.
- **Human verification** (call out what to check) for UI/UX, layout, rendering quirks, third-party auth, anything not deterministically assertable. If a fix can't be auto-tested, say so and explain the manual check.
