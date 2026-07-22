---
name: forms-repro
description: Reproduce PA Forms / BPM bugs in a target environment using Chrome DevTools MCP. Drives the browser to set up the repro scenario, captures evidence, and at the end of every session produces a step summary, screenshot audit, and reusable script proposals. Invoke when the user says "repro", "reproduce", "verify", or "confirm" a PA Forms bug, or asks to set up a test scenario in an environment.
---

# forms-pa-repro Skill

You drive the browser via Chrome DevTools MCP to reproduce PA Forms bugs.

## KB to load

`C:\code\forms_agent_kb\` is the knowledge base.

- `index.md` — load first.
- `repro-tooling/chrome-mcp-repro.md` — load before driving the browser (iframe, drag, viewport, navigation, common pitfalls).
- `repro-tooling/scripts/config/environments.json` — environment URLs and credentials.
- `repro-tooling/bp-library/README.md` — owned BP starting points; load before creating any BP.
- `architecture/<area>.md` — only if you need to understand internals to design the repro.

---

## Operating principles

**1. Glob the snippets directory at session start.** Run `Glob C:/code/forms_agent_kb/repro-tooling/scripts/snippets/**/*.js` before writing JS or planning API calls. Open file headers of anything that looks relevant. The index can lag the filesystem.

**2. UI first, API once you know the pattern.** Each properties pane runs live API calls on render to fetch tenant/user state and pre-populate fields. Direct `PUT /EditProcessModeler` bypasses that init logic — the BP publishes but fails at runtime, often with cryptic errors like `LFBad Request`. For any unfamiliar config:

1. Drive the UI; observe network calls via `list_network_requests` + `get_network_request`.
2. Read the matching `*-pane.component.ts` in `C:/code/site-app-bp-designer/src/SiteContent/bp-designer/src/app/panes/`.
3. Replicate those calls in your snippet.

Confirmed exemplar: `str-pane.component.ts:174-179` calls `GET /BPM/API/a/Assets/ContentRepositoryProfiles/` to auto-pick `repo_stl`. Skipping it produces an unrunnable BP. Other panes follow the same shape.

**3. Use the BP library, never fork another user's BP.** Repros must be idempotent (same starting BP every session) and independent (re-verify against current build, don't trust `Verified` state). Source from `repro-tooling/bp-library/`; never clone BPs owned by Yiding, Catherine, Tong, etc. — they may modify or delete those at any time. Naming, workflow, and catalog: `bp-library/README.md`.

**4. Stuck or seeing errors? Stop and ask.** If three consecutive tool calls are diagnostic (DOM probing, listing endpoints, retrying the same call) without forward progress, stop. Summarize what you tried (commands, response snippets, screen state) and ask the user what to click or call instead.

**5. Plan before executing.** Before driving the browser, write three lines:
- **Source:** `_lfkb_<shape>` library BP (existing or upload).
- **Modification:** what changes for this bug.
- **Verification:** how you'll independently observe success.

If you can't fill these in, ask the user for context first.

---

## Step 1 — Understand the bug

Establish: expected vs actual behavior, features involved (BP routing, User Task, STR, DA, Rules, RTF, form layout), target environment (local / clouddev us / cloudtest us / cloud us / etc.). For TFS work items, fetch with `mcp__tfs__wit_get_work_item` (`expand: "all"`) and `mcp__tfs__wit_list_work_item_comments`.

---

## Step 2 — Authenticate

Read `repro-tooling/scripts/config/environments.json` for `baseUrl` and credentials. If either is empty for the target env, prompt the user. Call `list_pages` to check current tenant; if not authenticated, run `repro-tooling/scripts/snippets/auth/login.js` (note: clouddev US is a two-stage login — account ID, then username/password).

---

## Step 3 — Source the BP from the library

Per Operating Principle #3, BPs come from `bp-library/`, not from scratch:

1. Identify the shape needed (`msgStart_str_end`, `msgStart_userTask_end`, etc.).
2. Search the tenant for `_lfkb_<shape>`. If it exists, use it.
3. If not, upload `bp-library/_lfkb_<shape>.xml` via `intercept-import-upload-response.js` + `import-process-continue.js`. If the XML is missing too, build it once (`bp-build-kit.js`), export, save to `bp-library/`, update its README catalog, then proceed.
4. Derive a per-session BP named `{bug_id}_{shortdesc}` (e.g., `123456_rtf-blank-on-submit`); leave the library BP untouched.

Before creating, check tenant hasn't hit the 4000-process limit. If it has, ask the user before running `delete-formsautotest-processes.js` — it is destructive.

---

## Step 4 — Known-safe API shortcuts

For these specific actions, the API call sequence is already verified — no UI exploration needed:

| Action | Snippet / endpoint |
|---|---|
| Import a BP `.xml` file | `intercept-import-upload-response.js` + `import-process-continue.js` |
| Get form preview URL after import | `get-form-preview-url.js` (`GET .../LinkedForms`) |
| Publish a BP | `publish-bp.js` (`POST .../Publish`) |
| Build a BP from spec | `bp-build-kit.js` (primary) |
| Full import → preview | workflow: `import-and-preview-bp.md` |

For any action not listed, follow Operating Principle #2 (UI first) and propose a snippet at session end if you confirm a working API call.

---

## Step 5 — Run the repro

### URLs

- BP designer: `{baseUrl}/bpm/home/_global/bp/draftdesign/{bpDefinitionId}`
- Form fill: `{baseUrl}/forms/Form/NewInstance/?processId={publishedProcessId}`
- Task fill: `{baseUrl}/forms/Form/FillForm/?taskId={taskId}`
- Tasks inbox: `{baseUrl}/tasks`
- Monitor: `{baseUrl}/bpm/home/_global/bp/monitor`

### Tool priority

| Goal | Tool |
|---|---|
| Read DOM state, computed styles, field values | `evaluate_script` → JSON |
| Verify form submission or API response | `evaluate_script` with `fetch()` |
| Fill Angular inputs | `evaluate_script` dispatching `input`+`change` events (not direct `.value`) |
| Confirm visual state (layout, overlap, rendering) | `take_screenshot` |
| Click standard buttons | `click` via `uid` from `take_snapshot` |

Take a screenshot only when the bug is inherently visual. For data/state bugs, return JSON.

### Iframe + Angular

```js
// iframe DOM access
const iDoc = document.querySelector('iframe').contentWindow.document;

// Angular input fill (never assign .value directly)
const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
setter.call(el, 'value');
el.dispatchEvent(new Event('input', { bubbles: true }));
el.dispatchEvent(new Event('change', { bubbles: true }));
```

For deeper patterns (PLD drag, viewport emulation, double-click for DETAILS panel, repo-profile API fallback), see `chrome-mcp-repro.md`.

### Find STR output

Monitor → instance detail → **History** tab → click the link on the STR row.

---

## Step 6 — Capture evidence

Capture the minimum needed to confirm or deny the bug:

- **Data bugs** — JSON from `evaluate_script`.
- **Visual bugs** — `take_screenshot`, labeled.
- **API/network bugs** — `evaluate_script` with `fetch()` or `list_network_requests` + `get_network_request`.
- **Routing bugs** — Monitor instance detail (History, Variables, Process Modeler) as JSON.

State clearly: **Bug confirmed** or **Bug not reproduced** and why.

---

## Step 7 — Post-session output (always required)

Never write any of the proposed changes below without user approval. If something didn't work mid-session, you already stopped and asked (Operating Principle #4) — don't relitigate it now by self-fixing in this report.

### Steps Taken (with method tags)

Numbered list of every meaningful action. Tag each with its method so future runs can see what mix of UI vs automation was actually used:

- `[ui]` — clicked through the designer / form / monitor
- `[api]` — known-safe API shortcut from Step 4
- `[kit]` — `bp-build-kit.js` primitive or `build(spec)`
- `[lib]` — sourced/uploaded a `_lfkb_<shape>` BP from the library
- `[custom]` — one-off `evaluate_script` written this session

Example:
1. `[ui]` Authenticated (clouddev US two-stage login).
2. `[lib]` Uploaded `_lfkb_msgStart_str_end.xml`.
3. `[ui]` Derived per-session BP, attached test PDF to start form.
4. `[api]` Published via `publish-bp.js`.
5. `[ui]` Submitted form, opened Monitor.
6. `[custom]` Inspected `/ExecuteRule` response via patched fetch.

### Screenshot Audit
For each screenshot, one row: step number, why it was needed. If a screenshot could have been replaced by `evaluate_script` reading a selector, say so.

### Result
- Bug reproduced: Yes / No / Partial
- Evidence: 1–2 sentences.

### Self-improvement notes

- **Total tool calls / approx. time:** N calls / X minutes (your best estimate).
- **Method mix:** count of `[ui]` / `[api]` / `[kit]` / `[lib]` / `[custom]` from Steps Taken. A high `[ui]` or `[custom]` count is a signal — those are candidates for automation.
- **Most time spent on:** which phase (auth / BP setup / form fill / monitor lookup / debugging) and why.
- **Friction points:** specific things that slowed you down — empty dropdowns, unexpected errors, things that "should have been one click."
- **What worked well:** patterns to repeat — surface them so they get reinforced in the kit/skill.

### Improvement proposals

For each friction point, propose **one** concrete fix, categorized:

- **Kit change** — `bp-build-kit.js` should add/change X (specific function or option).
- **Snippet** — a new `<area>/<file>.js` would automate Y.
- **BP library** — add `bp-library/_lfkb_<shape>.xml` (this shape was needed today).
- **Skill rule** — Operating Principle should add W.
- **KB doc** — `<file>.md` should document Z.
- **Tenant config** — something the user needs to set up outside the agent (e.g., a missing repo profile).

For "what worked well" items that aren't yet reinforced anywhere, propose where to encode them.

For each proposal: show the file path + the change, wait for approval, then write. Decomposition + placement rules for snippets: see `forms_agent_kb/AGENTS.md`.

---

## Behavioral notes

- Never run `delete-formsautotest-processes.js` without explicit user approval.
- If you discover a missing/wrong URL or credential, propose updating `environments.json`.
- Never self-fix mid-session by tangenting through unrelated UI/code — Operating Principle #4 is non-negotiable. Save findings for the Step 7 improvement proposals; the user resolves blockers faster than you guess them.
