# State files: layout and skeletons

Everything durable this skill produces lives under
`<momentum-root>/artifacts/bpm-migration/`. `artifacts/` is git-ignored by the
repo-root `.gitignore`, so this is working memory, not a repo deliverable. When
something in it becomes a real commitment (a spec, an ADR, an epic), it graduates
out of `artifacts/` through a separate skill and a normal PR.

## Layout

```
artifacts/bpm-migration/
  MISSION.md            # north star: goal, non-goals, principles, current phase
  PROGRESS.md           # append-only session log, newest first
  TODO.md               # ordered backlog of planning work
  questions.md          # open questions needing a human
  inventory/
    README.md           # index table: subsystem, status, owner file
    <subsystem>.md      # one discovery file per legacy subsystem
  decisions/
    README.md           # index table: id, title, status, date
    NNN-<slug>.md       # one planning decision each
  plan/
    seams.md            # coupling and data-ownership analysis
    target-architecture.md
    data-contracts.md   # contract inventory: preserve / adapt / break
    designs/
      README.md         # index table: id, question, status, recommendation
      NNN-<slug>.md     # design brief: options, pros and cons, diagrams
    evaluations/
      README.md         # index table: id, capability, candidates, recommendation
      NNN-<slug>.md     # build-versus-adopt evaluation
    slices.md           # ranked slice index
    slice-<id>.md       # one card per slice under active planning
    risks.md            # risk register
    epic-draft.md       # the reviewable epic text
```

Create a file when the session first needs it, not all at bootstrap. Bootstrap
creates `MISSION.md`, `PROGRESS.md`, `TODO.md`, and `questions.md` only.

Each artifact carries a status line: `Draft`, `Reviewed` (a human has read it), or
`Accepted` (a human has agreed to it). Default `Draft`. Never promote a status on
your own initiative.

## MISSION.md

```markdown
# BPM to momentum migration: mission

Status: Draft
Last updated: <YYYY-MM-DD>
Current phase: 1 (discovery)

## Goal

Move Laserfiche's legacy process automation platform (the `bpm` repo, Windows and
EC2, above all the `BpmServer` and `BpmAppFrontendServer` roles) into momentum as
cloud-native Linux microservices on Kubernetes.

## Non-goals

- A lift and shift port. The target is a design that is right for k8s.
- Breaking legacy customer data. Data contracts are preserved by default.
- Any implementation during the planning phase.
- Committing to dates or headcount.

## Principles

1. Preserve data contracts; use adapters where the new model must diverge, and
   record every divergence as a decision.
2. Ship in independently deployable, independently reversible slices.
3. Legacy and momentum coexist for a long time. Every slice has a coexistence and
   rollback story before it is considered plannable.
4. Reuse what momentum already has before proposing a new component, and ask
   honestly whether a third party should carry a capability instead of us.
5. Evidence over recall. Unverified means `UNKNOWN`, not omitted.
6. No single-option proposals. Competing options, real pros and cons, a
   recommendation, and a case against it. The reviewable artifact is a design
   brief with the diagrams that explain it.

## Constraints known up front

- Long-lived in-flight process instances. Cutover cannot assume an empty system.
- Multi-tenant: one cluster database plus one database per customer.
- Two live workflow engines (WWF-era `WorkflowEngine83` and the newer Reaction).
- On-prem as well as cloud delivery for parts of this platform.
- Momentum's managed-first, memory-safe, FIPS-base-image compliance posture.

## Pointers

- Legacy source: `C:\code\bpm` (WSL `/mnt/c/code/bpm`)
- Knowledge base: `C:\code\forms_agent_kb` (WSL `/mnt/c/code/forms_agent_kb`)
- Verified starting map: the skill's `references/legacy-landscape.md`
```

## PROGRESS.md

Newest entry first, so a session reads the top and stops.

```markdown
# Progress log

## <YYYY-MM-DD> - <item worked>

- Phase: <n>
- Did: <one or two lines>
- Findings that matter: <bullets, with anchors>
- Files changed: <paths>
- Opened: <new questions or to-dos>
- Next: <the proposed next item>
```

## TODO.md

Ordered, with status. Keep closed items in a `Done` section at the bottom for one
month, then drop them; `PROGRESS.md` is the permanent record.

```markdown
# Backlog

Status values: Todo, In progress, Blocked, Done.

| # | Phase | Item | Status | Notes |
|---|---|---|---|---|
| 1 | 1 | Pin down what `BpmAppFrontendServer` and `BpmServer` roles actually host | Todo | Start from `Pipelines/deploy.yaml`, `Install/cloud/packagescripts/RunOnce.ps1` |
| 2 | 1 | Audit what momentum already built in this domain (`workflow-engine`, `rules-engine`, `repository`, `instants`, `value-sets`) | Todo | Mandatory before any slicing |
| 3 | 1 | Read `bpm:SQL/` schema docs; write the data-ownership picture | Todo | Binding constraint on slicing |
| 4 | 1 | Discovery: form submission HTTP entry | Todo | |
| 5 | 1 | Discovery: process instance lifecycle | Todo | |
| 6 | 1 | Discovery: tasks and inbox | Todo | |
| 7 | 1 | Discovery: BP routing engine (Reaction) | Todo | |
| 8 | 1 | Discovery: legacy WWF engine and EngineHost | Todo | Expect this to be the hardest slice |
| 9 | 1 | Discovery: queueing and core infra (`Src/Core`) | Todo | MSMQ, RabbitMQ, SQS, Redis |
| 10 | 1 | Inventory the public and semi-public API surface and who consumes it | Todo | Includes customer scripts and integrations |
| 11 | 1 | Read the rendering and rasterization services as prior art for moving off Windows | Todo | `svc-app-renode`, `svc-app-pdf-rasterization` |
| 12 | 2 | Build `plan/seams.md` once discovery covers the core paths | Blocked | Needs 3 through 9 |
| 13 | 3b | Evaluate: routing engine, Elsa versus momentum's `workflow-engine` versus a durable-execution service | Todo | Headline question. Deciding factor is likely contract fit against the existing BP definition XML. Also ask which legacy engine the target replaces first |
| 14 | 3b | Evaluate: durable execution for month-long instances (Temporal, Dapr Workflows, our own queue plus state machine) | Todo | |
| 15 | 3b | Evaluate: rules and expression evaluation, what `rules-engine` already covers versus a library versus a scripting sandbox | Todo | |
| 16 | 3b | Evaluate: scheduling and recurring work, KEDA and CronJob versus Quartz or Hangfire | Todo | Replaces the legacy scheduled processors |
| 17 | 3b | Evaluate: form definition and rendering runtime, reuse the existing frontend versus rebuild in `ui-app` | Todo | |
| 18 | 3b | Evaluate: reporting and analytics query layer | Todo | |
| 19 | 3b | Evaluate: messaging semantics, MassTransit patterns versus raw SQS against the MSMQ behavior being replaced | Todo | Ordering, idempotency, poison handling |
| 20 | 3b | Confirm document generation and rasterization is already solved off-platform before re-planning it | Todo | `svc-app-renode`, `svc-app-pdf-rasterization` |
| 21 | 3a | Design brief: where the strangler switch sits (BFF, ingress, or inside a legacy service) | Todo | Needs seams; affects every slice |
| 22 | 3a | Design brief: tenancy and per-tenant rollout model for the target components | Todo | |
| 23 | 3a | Design brief: how in-flight instances survive a cutover | Todo | The constraint most likely to reshape the whole plan |

## Done
```

Seed the backlog with exactly this list at bootstrap. Items 1 through 3 come
first deliberately: role mapping, momentum overlap, and data ownership each have
the power to invalidate a plan built without them. Items 13 onward are the
build-versus-adopt and design questions already visible from the outside; they sit
below discovery because answering them cold, before the inventory exists, produces
confident nonsense. Each is written as a self-contained sub-task so a later
session can pick one up without reading the rest of the backlog, and every session
that uncovers a new question adds it here in the same shape.

## questions.md

```markdown
# Open questions

| # | Question | Why it matters | Asked | Answer |
|---|---|---|---|---|
```

## inventory/<subsystem>.md

One file per subsystem, using the discovery checklist in SKILL.md section 2 as
its headings, in that order. Head the file with:

```markdown
# <Subsystem>

Status: Draft
Last updated: <YYYY-MM-DD>
Legacy anchors: <paths>
Knowledge base: <kb files read>
```

Keep `UNKNOWN:` lines in place rather than deleting them. They are the phase 1
exit checklist.

## decisions/NNN-<slug>.md

Numbered sequentially from 001. Same spirit as `momentum:docs/adr/`, but these are
planning decisions in working memory; one becomes a real ADR only when it
graduates into the repo.

```markdown
# NNN. <Title>

Status: Proposed | Accepted | Superseded by NNN
Date: <YYYY-MM-DD>

## Context

<what forced a decision, with anchors>

## Decision

<what was decided, in the active voice>

## Consequences

<what this makes easy, what it makes hard, what it commits us to>

## Alternatives considered

<and why they lost>
```

## plan/designs/NNN-\<slug\>.md

The design brief. This is the artifact a human reviews, so it stands alone and it
carries its diagrams. Required sections are in SKILL.md section 5. The skeleton
below is fenced with four backticks so the mermaid blocks inside it survive:

````markdown
# NNN. <Design question>

Status: Draft
Date: <YYYY-MM-DD>
Decides: <the one thing this brief settles>
Depends on: <inventory files, other briefs>
Mode: <human | auto>

## Problem

<what has to be decided and what depends on it, with anchors>

## Constraints

<the non-negotiables: preserved contracts, tenancy, in-flight instances, on-prem
parity, managed-first and FIPS, k8s scaling>

## Context today

```mermaid
flowchart LR
```
_Caption: how this works on the legacy platform now, and what to notice._

## Options

### Option A: <name>

How it works. Diagram if its shape differs from the others.

- Pros: <concrete consequences>
- Cons and risks: <concrete>
- Cost to reverse once shipped:
- Legacy data and in-flight instances:

### Option B: <name>

<same shape>

### Option C: <name, or the honest baseline: port as-is / leave on legacy for now>

<same shape>

## Criteria and comparison

Criteria, stated before scoring, weighted if unequal: <list>

| Criterion | Weight | A | B | C |
|---|---|---|---|---|

<the reasoning the table summarizes>

## Recommendation

<option>, confidence <low | medium | high>.

Flips to <runner-up> if: <explicit conditions>

## Case against the recommendation

<the strongest real argument that this is wrong>

## Target design

```mermaid
flowchart LR
```
_Caption._

```mermaid
sequenceDiagram
```
_Caption: the primary flow end to end, including the failure path._

## Coexistence and cutover

```mermaid
flowchart LR
```
_Caption: where the switch sits while both run, and how rollback works._

## Open questions and sub-tasks spawned

<each also written into TODO.md>
````

Diagram set and rules are in SKILL.md section 5. Keep node labels short, caption
every diagram, and never let a diagram carry an argument the prose does not make.

## plan/evaluations/NNN-\<slug\>.md

Build versus adopt. Same review discipline as a design brief, different axes.

```markdown
# NNN. <Capability>: build or adopt

Status: Draft
Date: <YYYY-MM-DD>
Question: <for example, should Elsa carry the routing engine?>
Mode: <human | auto>

## The capability

<what it must do, drawn from the inventory with anchors, not imagined>

## Candidates

### Build it ourselves

- Pros / Cons / What it costs us:

### <Third-party candidate>

| Axis | Finding |
|---|---|
| License and shipping to customers | |
| Maturity and release cadence | |
| Maintainer base health | |
| .NET 10 and Linux fit | |
| Managed-only (no new native dependency) | |
| Extensibility where we need it | |
| Operational fit on k8s | |

- Contract fit: <can it read and persist the existing legacy schema and
  definition formats, or does it impose its own model? adapter cost?>
- Lock-in and exit cost two years in:
- Pros / Cons:

## What we lose by adopting

<control over semantics, debuggability, fixing a customer-blocking bug on our
own timeline>

## What we lose by building

<the edge cases someone else already paid for>

## Comparison

| Criterion | Weight | Build | <candidate> | <candidate> |
|---|---|---|---|---|

## Recommendation

<recommendation>, confidence <low | medium | high>. Flips if: <conditions>

This is a recommendation only. Adding a dependency needs a human to agree first.

## Case against the recommendation

## Open questions and sub-tasks spawned
```

## plan/designs/README.md and plan/evaluations/README.md

One index table each, so a session can see what is settled without opening every
file. Keep the recommendation column short enough to scan.

```markdown
# Design briefs

| Id | Question | Status | Recommendation | Confidence |
|---|---|---|---|---|
```

```markdown
# Build-versus-adopt evaluations

| Id | Capability | Candidates | Status | Recommendation | Confidence |
|---|---|---|---|---|---|
```

## plan/slices.md

```markdown
# Migration slices

Status: Draft
Last updated: <YYYY-MM-DD>

Scores are 1 to 5, 5 easier or safer. See SKILL.md section 7 for the rubric.
Total orders the backlog; the rationale, not the number, is the argument.

| Id | Slice | Target component | Fan-in | Data | Windows | Contract | Test | Blast | Reuse | Total | Card |
|---|---|---|---|---|---|---|---|---|---|---|---|
```

## plan/slice-<id>.md

```markdown
# Slice <id>: <name>

Status: Draft
Score: <total> (see slices.md)

- Legacy owner: <service and paths>
- Target momentum component: <existing or proposed>
- In scope:
- Explicitly out of scope:
- Contracts touched: <with preserve / adapt / break per contract>
- Data ownership plan:
- Depends on slices:
- Coexistence strategy: <routing switch, dual write, read-through adapter, shadow mode>
- In-flight state handling:
- Rollback plan:
- Verification plan: <including the legacy behavior oracle>
- Effort: <XS | S | M | L | XL>
- Score rationale:
- Open questions:
```

## plan/risks.md

```markdown
# Risk register

Status: Draft

| # | Risk | Trigger | Blast radius | Likelihood | Mitigation | Owner |
|---|---|---|---|---|---|---|
```

Blast radius is stated concretely: one feature, one tenant, one service, or the
cluster. No boilerplate risks; every row ties to something read in the code or
the knowledge base.
