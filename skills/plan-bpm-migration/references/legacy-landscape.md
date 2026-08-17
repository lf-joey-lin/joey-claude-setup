# Legacy landscape: verified starting map

The facts below were read out of the real repos on 2026-08-05 so that no planning
session has to re-derive them. Every row cites where it came from. Treat this as a
starting map, not gospel: if a session finds it stale, correct it here in the same
session and note the correction.

Sources cited as `bpm:<path>` (`C:\code\bpm`, WSL `/mnt/c/code/bpm`),
`kb:<path>` (`C:\code\forms_agent_kb`), and `momentum:<path>` (this repo).

## What the legacy platform is

BPM Server is the platform that Laserfiche's process automation products
(Workflow, Forms, Reporting and Analytics) are built on. It runs as several
independently deployed executables on EC2 Windows instances, partitioning work
through internal queues (MSMQ, RabbitMQ, SQS) against per-tenant SQL Server or
PostgreSQL databases. Source: `bpm:CLAUDE.md`.

Codenames that appear throughout the source, and are needed to read it:

| Codename | Namespace | What it is |
|---|---|---|
| Catalyst | - | Original codename for the platform |
| Spark | `Laserfiche.Spark.*` | The core BPM platform |
| Reaction | `Laserfiche.Reaction.*` | The newer routing and workflow engine |
| WorkflowEngine83 | `Laserfiche.Workflow.*` | The older WWF-based engine, under `Src/WorkflowEngine83` |

Source: `bpm:CLAUDE.md`. Both engines are live. Reaction did not replace
WorkflowEngine83; they coexist.

Scale: roughly 180 projects in the repo. No solution at the repo root; solutions
live under `Src/`, with `Src/CoreServices.sln` (about 177 projects) as the
everything view. Source: `bpm:CLAUDE.md`.

## Executables

| Executable | Path | Role |
|---|---|---|
| `Laserfiche.BPMAPI.exe` | `Src/Websites/Laserfiche.Spark.WebAPI/` | Public and internal stateless REST HTTP API, OWIN/Katana self-hosted, plus SignalR. The outward-facing aggregation layer, widest dependency footprint of the four. |
| `Laserfiche.Spark.exe` | `Src/Processors/Laserfiche.SparkServer.Host/` | Windows Service hosting the core BPM cluster's System Queue processors, plus an internal short-lived-token HTTP API. |
| `Laserfiche.Workflow.EngineHost.83.exe` | `Src/Services/LaserficheWorkflowEngineHost/` | Queue-driven Windows Service that creates and runs legacy WWF workflow instances and processes workflow activity tasks. Has its own `README.md`, read that first. |
| `LaserficheWorkflowSubscriber` | `Src/Services/LaserficheWorkflowSubscriber/` | Windows Service that watches repositories and turns repository events into workflow triggers. |

Source: `bpm:CLAUDE.md`. Other executables exist under `Src/Services`,
`Src/Websites`, `Src/Processors` (`Laserfiche.Workflow.WebDesigner`,
`WorkflowCompiler`, `ProcessAutomation.LocalAgent`) and had no agent
documentation as of the read; they are unmapped, not absent.

## Deployment roles

The deploy pipeline builds one `BpmServer` package and deploys it to five EC2
autoscaling groups, each running a different role:

`BpmServer`, `BpmFrontendServer`, `BpmAppFrontendServer`, `WorkflowServer`,
`WorkflowSubscriber`. Source: `bpm:Pipelines/deploy.yaml:122-138`.

The two named as the epic's biggest offenders, `BpmAppFrontendServer` and
`BpmServer`, are deployment roles, not projects. An early discovery task is to
pin down exactly which executables, sites, and processors each role actually
hosts (start from `bpm:Install/cloud/packagescripts/RunOnce.ps1` and
`bpm:Pipelines/deploy.yaml`). Do not assume the mapping is one role to one
executable.

## Shared hub libraries

| Hub | Path | Contents |
|---|---|---|
| Domain and contracts | `Src/Domain/` | `Laserfiche.BPMServer.*`, `Laserfiche.SparkServer.*`, `Laserfiche.Subscriber.*` Contracts, Manager, WebApi assemblies. The core domain model, used by all four executables. |
| Spark Core infra | `Src/Core/` | `Laserfiche.Spark.Core.*`: queueing (MSMQ, RabbitMQ, AWS), Redis, RepositoryAccess, FileStore, Unity DI, Api.Core and Owin. |
| Legacy workflow engine | `Src/WorkflowEngine83/` | `Laserfiche.Workflow.*` activities, runtime, conditions, connection. Used by Spark.exe, EngineHost, Subscriber, not by BPMAPI. |

Source: `bpm:CLAUDE.md`. Each has its own `CLAUDE.md`; read it before the raw
source.

Other `Src/` areas by functional domain: `Services`, `Websites`, `Processors`,
`Reaction`, `Forms`, `BusinessRules`, `RoutingEngine`, `RPA`, `Analytics`,
`Integrations`, `BusinessEntities`, `AppServices` (DataSources, Scripting,
WebRequests, Imap, TrusteeDirectories), `Web`, `Desktop`, `Setup`, `SDK`.
Plus `Tests/` (Selenium, WebAPI, regression, load), `Tools/`, `SQL/`, `Build/`,
`Pipelines/`, `Install/`. Source: `bpm:CLAUDE.md`.

## Data model

Multi-tenant. A **cluster database** holds cluster-wide settings and the tenancy
directory. Each **customer database** holds one tenant's data, split into schemas:
`Core`, `Instances`, `Diagnostics`, `CaseInstances`, `BusinessInstances`,
`DiscussionInstances`.

PostgreSQL is the only fully implemented DBMS; MSSQL and Oracle exist in config
but are not live. Customer data is reached through `I*Database` and
`I*DatabaseView` interfaces off `IContainTenantContext` (the `View` variant is
read-only against a read replica); cluster data through `IClusterApplication` and
`IClusterOperation`. Schema documentation lives in `bpm:SQL/`
(`DATABASE_DOCUMENTATION.md`, `DATABASE_ERD.md`, `Using Databases In BPM.md`).

Source: `bpm:CLAUDE.md`.

This is the single most important constraint on slicing: read `bpm:SQL/` docs
before proposing that any component owns its own data.

## Candidate discovery subsystems

A starting decomposition for phase 1, drawn from the knowledge base's feature map
(`kb:domain-knowledge/feature-map.md`). Refine it as discovery proceeds; the point
is coverage, not fidelity to this list.

| Subsystem | Legacy anchor |
|---|---|
| Form submission (HTTP entry) | `bpm:Src/Domain/Laserfiche.BPMServer.WebApi/Controllers/Forms/FormsSubmissionController.cs` |
| Process instance lifecycle and CRUD | `bpm:Src/Domain/Laserfiche.BPMServer.WebApi/Controllers/Forms/Processes/ProcessInstanceController.cs` |
| BP routing engine (Reaction) | `bpm:Src/Reaction/`, `bpm:Src/RoutingEngine/` |
| Tasks and inbox | `bpm:Src/Domain/Laserfiche.BPMServer.Manager/Handlers/TaskHandler.cs` |
| BP draft and publish | `bpm:Src/Domain/Laserfiche.BPMServer.Manager/Handlers/WorkflowDraftHandler.cs` |
| Business rules and rules engine | `bpm:Src/BusinessRules/` |
| Save to Repository (STR) | `bpm:Src/RoutingEngine/Laserfiche.RoutingEngine.Manager/Services/Forms/FormsRoutingEngineSaveToLaserficheService.cs` |
| Analytics and custom reports | `bpm:Src/Analytics/`, `Controllers/Reports/` |
| Scheduled report processors | `bpm:Src/Processors/Laserfiche.SparkServer.Host/Processors/AnalyticsScheduleReportProcessor.cs` |
| Repository event subscriber | `bpm:Src/Reaction/Laserfiche.Reaction.Manager/Processors/RepositoryEventProcessor.cs`, `Src/Services/LaserficheWorkflowSubscriber/` |
| Legacy WWF workflow engine | `bpm:Src/WorkflowEngine83/`, `Src/Services/LaserficheWorkflowEngineHost/` |
| Repository access | `bpm:Src/Core/Laserfiche.Spark.Core.RepositoryAccess/` |
| Queueing and core infra | `bpm:Src/Core/` |
| Integrations, data sources, scripting, IMAP | `bpm:Src/AppServices/`, `Src/Integrations/` |
| Forms designer and renderer frontend | `kb:architecture/forms-layout-architecture.md` (fl-designer, fl-renderer, fl-lib) |
| Rendering and rasterization | `svc-app-renode`, `svc-app-pdf-rasterization` (separate repos, already off Windows) |
| Monitoring page | `kb:architecture/monitoring-architecture.md` |
| Direct approval | `kb:architecture/direct-approval-architecture.md` |

Note that rendering and rasterization already run as Kubernetes services in
separate repos. They are prior art for how this organization moves a capability
off the Windows platform, and worth reading as precedent rather than re-planning.

## Momentum components as of 2026-08-05

From `momentum:src/`: `acs-bff`, `app-bff`, `authz`, `bff-platform`, `db-auth`,
`db-migration-runner`, `db-user-provider`, `goodbye-app`, `hello-app`, `imaging`,
`instants`, `local-dev`, `preview-routing`, `queue-resilience`, `repository`,
`repository-mover`, `repository-service-reaper`, `rules-engine`, `sso-auth`,
`ui-app`, `valkey`, `value-sets`, `workflow-engine`,
`workflow-subscriber-trace`.

Several of these already occupy legacy BPM territory: `workflow-engine`,
`workflow-subscriber-trace`, `rules-engine`, `repository`, `instants`,
`value-sets`. Before planning any slice, read the relevant component's
`CLAUDE.md` and `README.md` and find out what is already built. Discovery output
that skips this check is not accepted (see SKILL.md section 2).

## Knowledge base entry points

`kb:index.md` is the index; load it first, then pull only the architecture files
the session's area needs. Highest value for this epic:

- `architecture/system-architecture.md`: cross-service behavior, routing, topology
- `architecture/bp-runtime-architecture.md`: BP routing, gateways, events, tasks,
  process variables
- `architecture/bp-definition-xml-structure.md`: the BP definition contract, which
  is customer data and therefore a contract to preserve
- `architecture/rules-architecture.md`, `fields-architecture.md`,
  `str-architecture.md`, `rtf-architecture.md`, `monitoring-architecture.md`,
  `direct-approval-architecture.md`, `forms-layout-architecture.md`
- `architecture/server-logs/*.md`: log schemas that support depends on today, and
  therefore an observability contract
- `domain-knowledge/overview.md` and `feature-map.md`

## Live-system tooling

The `bpm-mcp-server` MCP server can drive a live BPM environment (login, environment
selection, list/get/create/update/delete across workflows, workflow instances,
Forms processes, business rules, teams, plus a raw `bpm_api_request` escape
hatch). Source: `bpm:CLAUDE.md`. Useful for confirming an actual contract shape
instead of inferring it from code. Availability in a given session is not
guaranteed; check before relying on it.
