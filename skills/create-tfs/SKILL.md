---
name: create-tfs
description: Create a new work item (story or bug) on Joey's Momentum board in TFS, assigned to him in the new/backlog state with the required fields filled in. Invoke when the user types /create-tfs, or asks to "create a TFS item / story / bug", "make a work item", or "add this to my board" for the Momentum project.
---

# Create a TFS work item on the Momentum board

Creates a work item on the Momentum board
(`https://v-dev-tfs/DefaultCollection/Cloud/_boards/board/t/Momentum/Stories`)
via the `azure-devops` MCP server, assigned to Joey in the **new/backlog** state
(not in progress), with the fields the board expects already filled in.

## Invocation

```
/create-tfs <story|bug> <short description>
```

- First token is the type: `story` or `bug` (case-insensitive). If it is missing
  or unclear, default to `story` and note the assumption.
- The rest is the short description used to build the title and seed the
  description / acceptance criteria.
- If the description implies a research or investigation task ("spike",
  "investigate", "evaluate", "compare", "POC", "figure out"), treat it as a
  **spike** (title marker + `Spike` tag). Otherwise a normal story.

## Fixed context (verified against the live board)

- **Server**: `https://v-dev-tfs.laserfiche.com/DefaultCollection` (the
  `azure-devops` MCP server is already configured for it).
- **Project**: `Cloud`  **Team**: `Momentum`
- **Create tool**: `mcp__azure-devops__wit_create_work_item` (load its schema
  with `ToolSearch("select:mcp__azure-devops__wit_create_work_item")` first).
- **Type mapping**: `story` -> `User Story`, `bug` -> `Bug`. (There is no type
  literally named "Story"; using it returns null.)
- **Assignee**: `LASERFICHE\joey.lin`. Do not use the email form
  `joey.lin@laserfiche.com` - this on-prem TFS rejects it as an unknown identity.
  The identity-lookup endpoint (`core_get_identity_ids`) also 401s here, so do
  not rely on it.
- **Initial state**: a new item is not in progress unless the request says so.
  Use the work-item-type's first state: `New` for a User Story, `Open` for a Bug.
  The board column follows state automatically. Only set `Active` (or a later
  state) if the user explicitly says the work is already underway.
- **Area path**: `Cloud\Projects\Momentum`.

## Steps

### 1. Resolve the current sprint iteration (do not hardcode)

Sprints roll over weekly, so look it up every time:

```
mcp__azure-devops__work_list_team_iterations  project=Cloud team=Momentum timeframe=current
```

Use the returned `path` (e.g. `Cloud\Projects\Momentum\Sprint 3`) as
`System.IterationPath`. If none comes back, fall back to the area path root
(`Cloud\Projects\Momentum`) and say so.

### 2. Build the title

- Normal ui-app story: `[ui-app] <description>`
- Research spike: `[spike, ui-app] <description>`

Keep the description in sentence case, no trailing period, no em dashes. Only use
the `ui-app` area tag; if the request is clearly about a different Momentum
component, use `[<component>]` instead and mention it.

### 3. Write the description and acceptance criteria

Both are HTML fields (`format: Html`). Write them the way a person on this team
writes them - see existing items like 678773 for tone. Apply the standing
`avoid-ai-writing` rules inline (no em dashes, no emoji, no "populated with" /
"seamless" filler, sentence-case). Keep it short:

- **Description** (`System.Description`): 1-3 short sentences on what and why.
- **Acceptance criteria** (`Microsoft.VSTS.Common.AcceptanceCriteria`): a short
  `<ul>` of concrete, checkable bullets. For a spike, frame them as the questions
  answered / artifact produced rather than shipped behavior.

### 4. Assemble the fields per type

**User Story** (the common case):

| Field | Value |
| --- | --- |
| `System.Title` | title from step 2 |
| `System.AssignedTo` | `LASERFICHE\joey.lin` |
| `System.State` | `New` (not in progress unless the request says so) |
| `System.AreaPath` | `Cloud\Projects\Momentum` |
| `System.IterationPath` | current sprint from step 1 |
| `Microsoft.VSTS.Scheduling.StoryPoints` | scope estimate: `1`-`2` trivial, `3` typical (default), `5`-`8` large |
| `Microsoft.VSTS.Common.Priority` | `2` (default) |
| `Laserfiche.Catalyst.TFS.Fields.Product` | `Momentum` |
| `Laserfiche.Target` | current release train, `Cloud 2026.08` as of 2026-07. Confirm by copying the `Laserfiche.Target` off a recent Momentum item (`search_workitem searchText=ui-app project=[Cloud]`) rather than trusting this date. |
| `Laserfiche.Module` | `Momentum Architecture` |
| `System.Description` | HTML from step 3 |
| `Microsoft.VSTS.Common.AcceptanceCriteria` | HTML from step 3 |
| `System.Tags` | `Spike` for a spike; omit otherwise |

**Bug** differences from the above:

- `System.State` is `Open` (the Bug type's first state), not `New`/`Active`.
- No `StoryPoints`. Add `Microsoft.VSTS.Common.Severity` (default `3 - Medium`)
  and `Microsoft.VSTS.Common.ValueArea` (`Business`).
- `Microsoft.VSTS.Build.FoundIn` is **required** on a Bug (creation fails with
  `TF401320 ... field Found In ... Required` without it). Default it to `<None>`;
  set an actual build/version only if the user gives one.
- `System.Description` holds the repro / observed-vs-expected (this template does
  not use a separate repro-steps field).
- Title marker is still `[ui-app]` (no `spike` on a bug).

Escape backslashes in JSON path values (`Cloud\\Projects\\Momentum`).

### 5. Create and report

Call `wit_create_work_item` with `project=Cloud`, the mapped `workItemType`, and
the fields array. On success, confirm to the user with the id and a clickable
board link:

```
https://v-dev-tfs/DefaultCollection/Cloud/_workitems/edit/<id>
```

State plainly what you set (type, state/column, sprint, story points) so Joey can
adjust anything you guessed. Do not claim it worked without the returned id.

## Notes

- This creates a real item on a shared board. Create exactly one per invocation;
  do not retry blindly on a non-identity error (a duplicate may already exist -
  check with `search_workitem` before re-creating).
- If `System.AssignedTo` errors as an unknown identity, the domain form is wrong
  for the environment - stop and ask rather than guessing other forms.
- Linking a PR to the item later is a separate flow (see the Momentum section of
  the global CLAUDE.md - GitHub PRs attach as a Hyperlink relation via the TFS
  REST API, not through the MCP link tools).
