---
name: api-integrator
description: Attach an existing backend API to momentum through a realm BFF - read the upstream contract from its own source (ACS at C:\code\AccountControlSystem, BPM/PA at C:\code\bpm), design the narrowed browser-facing contract, and build the wire/mapper/bridge/endpoint slice in acs-bff or app-bff plus the openapi.yaml entry. Optionally continues into the matching ui-app service composable. Invoke when the user asks to "expose", "attach", "wire up", "hook up", "surface", "proxy", or "add a BFF endpoint for" an existing ACS/BPM/legacy API, names an upstream route (for example trustee/getcurrentuser or a/widgets/data) and wants it reachable from ui-app, or asks how an existing backend call should reach the browser.
---

# api-integrator Skill

You are adding a **browser-facing route to an existing realm BFF** in the momentum
monorepo, backed by an API that already exists in a legacy backend. The deliverable is
a vertical slice on the BFF side: wire types, mapper, bridge method, endpoint,
`contract/openapi.yaml`, and the `specs/design.md` entry, plus the tests that the
separate `update-tests` pass will extend.

A BFF route is not a proxy. Its whole job is to be the place where the legacy contract
stops and the browser contract starts: the tenant comes off the session instead of the
query string, 92 upstream fields become the 8 a page reads, a legacy POST becomes a
GET, and an `IsError: true` inside a 200 becomes a real 502. If your design ends up
forwarding the upstream shape unchanged, you have almost certainly missed something -
go back to step 4.

**Hard boundary: no new realm.** This skill adds routes to `acs-bff` or `app-bff`. A
backend that is neither the ACS realm nor the app realm needs a new realm in `sso-auth`,
a new BFF component, a chart, an ingress path, and a new `BffTarget` in ui-app. That is
a spec-driven feature (root `CLAUDE.md`, "Specs"), not this skill. Detect it at step 3,
say so, and stop.

## Step 0 - Ground yourself in the as-built code

Do not design from memory or from the specs alone. Several of these components carry
"as-built" notes precisely because earlier spec revisions describe things that were
deliberately never built (`IBackendAdapter`, `AcsRealmAdapter`, `WarmUpAsync`, incoming
anti-forgery). The code wins.

Read, in this order:

1. `CLAUDE.md` at the repo root, then `src/bff-platform/CLAUDE.md`.
2. The BFF you are extending: `src/acs-bff/CLAUDE.md` and `src/acs-bff/specs/design.md`
   (or the `app-bff` pair). `acs-bff` is the richer reference instance; `app-bff` is
   almost pure forwarding.
3. The closest existing route to the one you are adding, end to end. For a tenant-scoped
   ACS read that is `GET /bff/acs/customer`:
   - `src/acs-bff/Laserfiche.AcsBff/Services/AcsCustomerWire.cs` (upstream shape and paths)
   - `src/acs-bff/Laserfiche.AcsBff/Services/CustomerMapper.cs` (classification and projection)
   - `src/acs-bff/Laserfiche.AcsBff/Contracts/Customer.cs` (browser DTO, outcome, result)
   - `src/acs-bff/Laserfiche.AcsBff/Services/AcsBridge.cs` (orchestration)
   - `src/acs-bff/Laserfiche.AcsBff/Endpoints/AccountEndpoints.cs` (route and status mapping)
   - `src/acs-bff/tests/Laserfiche.AcsBff.Tests/CustomerTests.cs` and `AcsTestHarness.cs`

Name the route you chose as your model when you present the plan. Copying one existing
slice faithfully is the goal; inventing a fifth way to classify a 403 is the failure.

## Step 1 - Pin down the ask

Restate as a short numbered list, and record assumptions rather than blocking:

- Which upstream route(s), by verb and path (`POST api/trustee/GetPagedUserListing`).
- What the browser actually needs from the response. Ask for the consuming page or
  component if it exists; a field with no reader does not get forwarded.
- Read or write. A write brings anti-forgery, idempotency, and verb-normalization
  questions a read does not.
- Whether one browser call should compose several upstream calls (the `/consents`
  pattern) or stay one-to-one.

If the request names a feature rather than a route ("show the account's SAML settings"),
find the upstream route yourself in step 2 and confirm it in the step 5 gate.

## Step 2 - Read the upstream contract from its own source

Never guess an upstream shape. Both backends are on this machine.

| Backend | Windows path | WSL path |
|---|---|---|
| ACS | `C:\code\AccountControlSystem` | `/mnt/c/code/AccountControlSystem` |
| BPM / PA | `C:\code\bpm` | `/mnt/c/code/bpm` |

Exclude `bin/` and `obj/` from every search there; both trees carry build output, and on
WSL the 9p mount makes a wide search slow.

### ACS

Two server-side surfaces, and they authenticate differently:

- **Customer Portal MVC** (`Source/CustomerPortalMVC/Controllers/`) - the `ACSAuth`
  cookie surface, which is what nearly every `/bff/acs` route calls. `TrusteeController`,
  `CustomerController`, `OAuthController`, `SessionController`. The class carries
  `[XsrfValidation]`, which is why writes need the derived `x-xsrf-token`.
- **Web API** (`Source/AccountControlSystem.WebApi/Controllers/`) - the
  `X-Lf-Acs-SessionKey` surface. Used today only for the liveness probe.

For a chosen action, extract:

- The route as the BFF must call it (`api/` + controller + action, plus query
  parameters). Confirm which parameters ACS actually requires: `getcustomerbyid` 400s
  when a `need*` flag is omitted rather than defaulting it.
- The parameter binding. `GetPagedUserListing(ListingOptions listingOptions, Int64
  customerID)` binds the options from the body and the id from the query string.
- The response type. Actions return `ApiResponse`, the `{ IsError, Message, Value }`
  envelope that momentum binds as `AcsValueResponse<T>` (in `AcsUserListingWire.cs`).
  Follow `Value`'s type into `Source/AccountControlSystem.Core/Implementations/Contracts/`
  (for example `TrusteeListingDC.cs`) and read the real field names and casing.
- Any awkward spelling. ACS ships `SPEntityId`, `ID`, and mixed casing; those get pinned
  with `[JsonPropertyName]` rather than left to case-insensitive luck.

### BPM / PA

Start from `C:\code\bpm\CLAUDE.md` and the nested per-project guides; the repo has ~180
projects and the root guide maps them. The browser-facing surface is
`Src/Websites/Laserfiche.Spark.WebAPI/Controllers/` (`Laserfiche.BPMAPI.exe`, the
cookie-authenticated REST surface that `app-bff` already calls at `a/widgets/data`).
Request and response types are usually in `Src/Websites/Laserfiche.Spark.WebAPI/ViewModels/`
or the `*.Contracts` project for the owning domain under `Src/Domain/`. The
`bpm-mcp-server` MCP server can exercise a live BPM environment when reading the code
leaves a real ambiguity about runtime behavior; prefer it over guessing, and say in the
plan which answers came from it.

### Record what you found

Write down, per upstream route: verb, exact path, parameter binding, envelope, payload
type and its real field names, and the failure modes (non-2xx, `IsError` inside a 200,
an absent `Value`, an empty collection). You need all of it in step 4, and the plan is
not reviewable without it.

## Step 3 - Pick the BFF

| Upstream | BFF | Route group | Realm cookie |
|---|---|---|---|
| ACS Customer Portal or ACS Web API | `acs-bff` | `/bff/acs` | `ACSAuth*` plus the `X-Lf-Acs-SessionKey` projection |
| BPM API / the PA fleet | `app-bff` | `/bff/app` | `appsts`, `apikey`, `apiid` |
| anything else | none yet | - | stop, see the hard boundary above |

The realms are configured in `src/sso-auth/Laserfiche.SsoAuth/appsettings.json` under
`SsoAuth:Realms`. If the upstream you need is not served by one of those two cookie
families, it is a new realm - stop and say so.

If the upstream is reached at a base URL the chosen BFF does not already hold, that is a
new option on `AcsBffOptions` / `AppBffOptions` plus `appsettings.json`, the local-dev
AppHost, and `deploy/<bff>/values.yaml` and its deployment template. Flag it in the plan;
it is the one part of this work that touches deployment.

## Step 4 - Design the browser-facing contract

This is where the skill earns its keep. Every rule below is already load-bearing in the
repo, and each one exists because the alternative failed quietly rather than loudly.

### Narrow the payload, structurally

Bind only the fields the browser reads, in a dedicated `internal sealed record` in
`Services/` (the `Acs*Wire` naming). ACS's `CustomerInfo` has 92 members including
payment data and operator comments; `AcsCustomerInfo` binds 8. A field that never enters
the process cannot be forwarded by accident, so the exclusion is structural rather than
a filter someone can forget. Then project onto a separate DTO in `Contracts/`, which is
what ships to the browser.

Translate enums and numeric codes to stable names (`CustomerTypeName`: `0` becomes
`"solutionProvider"`), so the front end keys a localization string off a fixed token and
no upstream enum reaches the wire.

### Never take a tenant, account, or repository from the browser

Read it from `IRealmSessionClient.GetFactsAsync(sid)` (`SessionFacts.CustomerId`,
`RepositoryIds`, `DefaultRepositoryId`). ACS returns any account whose id you can name,
so a client-supplied `customerid` is a cross-tenant read. Where the browser legitimately
supplies one (app-bff's widget query names a repository), validate it against the granted
set and 403 on a miss - do not rewrite the body, which is silent mutation.

Escape anything that reaches a query string with `Uri.EscapeDataString`, even a
server-supplied claim.

### Normalize the legacy verb

The browser gets the verb that matches the meaning, not the one the legacy API happens to
use. A listing that is `POST` upstream is a `GET` here, so the client gets reactive
refetch and paging as URL state. A revoke that is `POST oauth/revokeconsentedapp` is a
`DELETE` on the grant, so a repeat call is harmless. This is what a BFF is for.

### Real HTTP status codes

The go-forward convention (`src/acs-bff/specs/design.md`, `GET /users`). Do not add
another `ok: false` inside a 200; the two old My Account routes are grandfathered and
follow when their client is next touched. The mapping:

| Situation | Status |
|---|---|
| Bad parameter, rejected before any upstream call | 400 |
| Session ended (`ForwardResult.SessionEnded`) | 401 |
| Upstream refused this request | 403 |
| Live session whose facts carry no tenant id | 500 |
| Every upstream failure: non-2xx, unparseable body, `IsError`, missing `Value` | 502 |

The `switch` fallthrough goes to 502, so a failure mode added later fails safe instead of
reporting success. 500 rather than 502 for the missing tenant id because no upstream call
happened, and 502 would point triage at the wrong service. Never 401 for either of the
last two: the session is live, so signing in again cannot fix it, and a 401 bounces a
signed-in user into a login loop.

A 403 is not a sign-out. `RealmForwarder` re-mints and retries once, and its
`IsSessionConfirmedEnded` deliberately excludes 403, so `SessionEnded` means expiry and
the status check for 403 comes after it.

### Reuse the result types, do not fork them

If the upstream answers ACS's `Value` envelope, reuse `CustomerOutcome` and
`CustomerResult<TPayload>` (`Contracts/Customer.cs`) and add a case to
`CustomerMapper.ToResult<TWire, TPayload>` rather than writing a fourth guard chain. One
chain and one status map is what stops two routes disagreeing about what a 403 means. A
session-scoped route inherits a `NoCustomerId` it cannot reach; that is the accepted cost.
`ConsentsOutcome` is a standing exception forked before this was settled, not a pattern
to copy.

### `Cache-Control: no-store` on every response

Set it as the first line of the handler, before the validation branch, so the rejection
notes are covered too. Everything behind a session cookie is somebody's private data. The
unauthenticated refusal is already covered in `bff-platform`'s `ApiCookieBehavior`.

### Log the outcome, never the payload

One warning per failure carrying the operation, the outcome, the upstream status, and the
note. The note is a fixed string per guard for exactly this reason: it is both logged and
returned, so the upstream's own `Message` is never carried into it (`AcsValueResponse`
does not even bind that field). No row, name, email, tenant id, client id, or response
body is ever logged. A success logs nothing.

The one exception worth copying is `AcsBridge.LogBindGaps`: when a wire-shape drift would
answer `ok: true` with an empty list, byte-identical to a legitimately empty answer, log
the counts. Nothing else can see that failure.

### Composing several upstream calls

Sequential, not concurrent. Either call can find the realm credential stale, and
`RealmForwarder` heals that by asking sso-auth for a forced re-mint; issuing both at once
races two mints for the same session. Short-circuit once the first has failed at the
transport level. Decide explicitly whether a partial result is renderable: `/consents`
fails the whole read because applications without their permission catalog would
understate the access the page exists to disclose.

### Preview propagation

Add `AddPreviewPropagation()` only to a momentum-to-momentum hop (the sso-auth gRPC
session client). A client calling ACS or BPM must not carry `X-Preview-Pr`: nothing on
the far end honors it, and it leaks which PR a developer is previewing to a third party.

## Step 5 - Gate the plan with the human

Present, and stop for approval before writing code:

1. The upstream route(s): verb, path, parameters, envelope, payload fields, failure modes,
   and where in the legacy source you read each.
2. The BFF and the browser-facing route(s), with the verb you chose and why it differs
   from upstream if it does.
3. The DTO: field by field, with what you are deliberately not forwarding.
4. The status mapping, including which existing outcome enum you are reusing.
5. The files you will add or touch (step 6's list), and whether any config or chart change
   is needed.
6. Open questions and assumptions.

## Step 6 - Build the slice

Order matters: pure and testable first, wiring last.

| File | What goes in it |
|---|---|
| `Services/<Feature>Wire.cs` | The upstream shape: the bound subset record(s), the path builders, and any pure enum-to-name translation. No I/O. |
| `Contracts/<Feature>.cs` | The browser DTO, and the outcome or result type if you are genuinely adding one rather than reusing `CustomerResult<T>`. |
| `Services/<Feature>Mapper.cs` | `ForwardResult` in, result out: the guard chain and the projection. All the JSON knowledge lives here, so `Contracts/` stays shapes and the bridge stays orchestration. Extend `CustomerMapper` instead where the envelope matches. |
| `Services/AcsBridge.cs` (or `PaBridge.cs`) | One method: read the session facts if the route needs a tenant, call the client, hand the result to the mapper, log a failure. |
| `Services/AcsClient.cs` | Only if the call needs an outbound behavior that does not exist yet. Most routes need nothing here. |
| `Endpoints/AccountEndpoints.cs` (or `AppEndpoints.cs`) | The `MapGet`/`MapPost`/`MapDelete` on the existing `MapGroup`, a named handler method, `no-store`, and the outcome-to-status `switch`. |
| `Program.cs` | Only for a new option, a new named `HttpClient`, or a new DI registration. |
| `contract/openapi.yaml` | The route, its parameters, its response schema, and the security scheme. Required, not optional. |
| `specs/design.md` | Add the route to section 3, with the decisions that are not obvious from the code. |

Conventions that are non-negotiable here (root `CLAUDE.md`): `net10.0`, `Nullable enable`,
no `var` anywhere, 4-space indent, `internal` by default with tests reaching in through
`InternalsVisibleTo`, S.O.L.I.D., managed-only, and no em dash, emoji, arrows, or
box-drawing characters in code or comments. Handlers are named methods, not inline
lambdas, so tests can call them directly.

Comment density: match the surrounding files. These components comment the *why* heavily
and the *what* not at all - the reason a 403 is not a 401, the reason two calls are
sequential, the reason a field is absent. That is house style here, not over-commenting.

## Step 7 - Verify what you touched

Per the standing testing rule, this is the cheap check only, not the test pass:

```bash
dotnet build src/acs-bff/acs-bff.slnx -c Release   # or src/app-bff/app-bff.slnx
```

Then stop and hand back. Do not run or write the full suite here. When the user is ready
to commit or open a PR, the `update-tests` skill covers everything the branch changed in
one pass, against this repo's 100% line and branch coverage gate.

If you do sketch tests as you go, follow the weighting the existing ones use: pin what
this service alone can get wrong *inside a 200* - a field quietly bound to its default, a
shifted timestamp, an off-by-one page, an upstream rejection read as an empty tenant, a
permission denial misread as expiry. The upstream's own correctness is the upstream's to
test. `AcsTestHarness` gives you the real bridge over a fake session authority and a
scripted upstream; use it rather than a new harness.

## Step 8 - The ui-app client slice (optional, ask first)

A BFF route with no caller is a legitimate deliverable here (the contract is the unit of
work). Offer the client slice; build it only if the user says yes, and keep it thin -
anything with real UI belongs to `design-ui` / `implement-ui`.

The established shape, one folder per service under `src/ui-app/app/composables/`:

- `<name>.model.ts` - the DTO interfaces mirroring the BFF's `Contracts/` field for field,
  the `Service` interface pages program against, and the `InjectionKey`.
- `acs-<name>-service.ts` - the real implementation over `BffFetch`. It takes the fetch as
  a parameter rather than calling the composable itself, and it throws rather than
  substituting a blank payload on a missing response.
- `mock-<name>-service.ts` - the default the composable injects when no plugin provides one.
- `use<Name>Service.ts` - the injection wrapper.
- `src/ui-app/app/plugins/<name>-service.ts` - provides the real implementation, gated on
  `hasAppShellSession(...)` so the standalone `npm run dev` loop keeps the mock.

Call it through `useBffFetch('acs')` (or `'app'`), which owns the SSR base URL, the cookie
allowlist, the CSRF echo, and the `X-Preview-Pr` header. Never hand-roll a `$fetch` to a
BFF. Use `useBffData` for a read that should server-render. Local dev routes `/bff/acs/*`
and `/bff/app/*` through `app/nuxt-config/dev-proxy.ts`, so nothing new is needed there.

Verification for this half is the cheap pair, run from `src/ui-app` (there is no
`typecheck` npm script; `npx nuxt typecheck` is the working invocation):

```bash
npx nuxt typecheck
npm run lint
```

The specs come in the same `update-tests` pass.

## Step 9 - Hand back

Report:

- The routes added, with their verbs and status mappings.
- Every file added or changed, grouped BFF / contract / ui-app / config.
- What you deliberately did not forward, and why.
- Any config or chart change required before this works in a deployed environment.
- What is not yet tested, so the `update-tests` pass has a starting point.
- Anything you could not determine from the legacy source, stated as unknown rather than
  guessed.

## Invariant checklist

Run this before handing back. Every line is a real failure this repo has already paid for.

- [ ] No tenant, account, or repository id is accepted from the browser.
- [ ] A client-supplied identifier that is legitimate is validated against the session's
      granted set, not rewritten.
- [ ] Only the fields the browser reads are bound from the upstream response.
- [ ] `Cache-Control: no-store` is set on every branch, validation rejections included.
- [ ] The status `switch` falls through to 502.
- [ ] `SessionEnded` is checked before the 403 branch.
- [ ] `IsError` is checked before the missing-`Value` branch.
- [ ] No upstream `Message`, response body, or PII reaches a log line or a `note`.
- [ ] An existing outcome or result type is reused unless the envelope genuinely differs.
- [ ] Composed upstream calls are sequential.
- [ ] No `AddPreviewPropagation` on a client that leaves momentum.
- [ ] `contract/openapi.yaml` and `specs/design.md` are updated.
- [ ] No `var`, no em dash, no emoji, no arrows; `internal` by default.
