## WI 669863 - description - 05/28/2026 - Joey Lin

As part of the Angular upgrade effort to the latest v21 (2026), a blocker is upgrading Legacy Angular Material to MDC components. MDC was introduced in v15, but PA sites are mostly still using MatLegacy modules. These legacy modules will be fully removed in v18 so this upgrade is a necessary prerequisite.

The changes involve swapping out all low-level UI components (e.g. checkboxes, buttons, dialogs, etc). Details of all changes here:
https://v17.material.angular.dev/guide/mdc-migration

There will be some minor UX changes while we aim to keep styles to be consistent with existing Laserfiche styles. The changes are attached in MDC-Migration-UX-Review.pdf and reviewed by UX.

Impacted libraries/pages to be upgraded:
lib-fileset-runtime
lf-angular-packages

forms-layout

site-app-bpm

site-app-home

site-app-reports

site-app-documents

site-app-bp-designer
site-ops-pa

---

## WI 669863 - description - 05/29/2026 - Joey Lin

As part of the Angular upgrade effort to the latest v21 (2026), a blocker is upgrading Legacy Angular Material to MDC components. MDC was introduced in v15, but PA sites are mostly still using MatLegacy modules. These legacy modules will be fully removed in v18 so this upgrade is a necessary prerequisite.

The changes involve swapping out all low-level UI components (e.g. checkboxes, buttons, dialogs, etc). Details of all changes here:
https://v17.material.angular.dev/guide/mdc-migration

There will be some minor UX changes while we aim to keep styles to be consistent with existing Laserfiche styles. The changes are attached in MDC-Migration-UX-Review.pdf and reviewed by UX.

Impacted libraries/pages to be upgraded:
lib-fileset-runtime
lf-angular-packages

forms-layout

site-app-bpm

site-app-home

site-app-reports

site-app-documents

site-app-bp-designer
site-app-forms
site-ops-pa

---

## WI 667880 - description - 05/26/2026 - Joey Lin

Repro:

https://answers.laserfiche.com/questions/236984/Tasks-Details-Pane-Slightly-Crops-Top-Values

The 'User Task' padding left is cutting into the text
Actual:

Expected:

Variations/Related:

---

## WI 660827 - description - 05/15/2026 - Joey Lin

Repro:

1. In any tenant, create a BP with a single user-task form and an STR service task that saves the form as PDF.
  2. Edit the form's settings → check Enable pagination (leave "Add page breaks on saved forms" at its default of checked).

  3. Add at least 2 pages so the form has 3+ pages total, with any field on each page.

  4. Publish, start the BP, submit the task.

  5. Open the saved document in the repository
Actual:

Expected:

Variations/Related:

---

## WI 660507 - description - 05/14/2026 - Joey Lin

Repro:

- In message start event > on complete completion include large image, e.g. 10mb
- don't enable 'show submitted form
- Submit
-

Actual:
stuck on redirecting with console error

Expected:

Variations/Related:

---

## WI 659571 - description - 05/11/2026 - Joey Lin

Repro:

Issue 659433: Classic form date picker prev/next button is "invisible", is this expected? (1470221584)

Actual:

Expected:

Variations/Related:

---

## WI 658857 - description - 05/07/2026 - Joey Lin

Repro:

Nicole Moulton: Custom Report - Process names no longer alphabetized? | Laserfiche Product Questions and Feedback > General | Microsoft Teams

should be caused by bad encoding in the URL call

/bpm/API/a/Resources/effectiveReferences/Process/monitorProcesses?subtype=0&subtype=1&subtype=3&subtype=4&resourceContext=_global&%24orderby=name%2Basc&%24skip=200&%24top=100

Actual:

Expected:

Variations/Related:

---

## WI 658857 - description - 05/07/2026 - Joey Lin

Repro:

Nicole Moulton: Custom Report - Process names no longer alphabetized? | Laserfiche Product Questions and Feedback > General | Microsoft Teams

should be caused by bad encoding in the URL call

/bpm/API/a/Resources/effectiveReferences/Process/monitorProcesses?subtype=0&subtype=1&subtype=3&subtype=4&resourceContext=_global&%24orderby=name%2Basc&%24skip=200&%24top=100

Actual:

Expected:
- The dropdown listing should also be searchable to be consistent with other resource listing dropdowns

Variations/Related:

---

## WI 658329 - description - 05/05/2026 - Joey Lin

Repro:

- create msgstart -end
- include a large image in the thank you message via file upload
- submit form in iOS mobile safari

Actual:
- sometimes submission fails

Expected:

Variations/Related:

---

## WI 658161 - description - 05/04/2026 - Joey Lin

Repro:

- setup a msgstart-usertask-str-end
- use same from in both msgstart and usertask
- enable direct approval on user task
- configure str to save user task with 'save the submitted form from this process step
- start process and submit msg-start with some data in the shared variables
- submit user task via direct approval from inbox side panel

Actual:
- the str form for user task is empty despite the shared variables being populated via msg-start

Expected:

Variations/Related:

---

## WI 657457 - description - 04/29/2026 - Joey Lin

Description:

  Repro:

  1. Create a Modern form with a table field containing 2 or more columns (e.g. two Single Line fields).

  2. Publish and open the form in fill mode.

  3. Resize the browser viewport to ≤600px wide (or open on a mobile device).

  4. Observe the rendered table rows.

  Actual:

  The column header row is hidden (correct at this width) AND the per-cell field labels are also not visible. Each input in the table appears with no label, leaving the user unable to tell which column a value

   belongs to. A collection field on the same form correctly shows each field's label before its input.

  Expected:

  On screens ≤600px, each cell should show its column label inline before the input — matching the layout that collection fields already use, and matching the rule already declared at noTranslateStrings.ts

  line 7:

  .lf-form .fl-table td.pdc fl-field-label {display: flex; border: none;}

  This rule was added specifically to make per-cell labels visible on small screens; it is being silently overridden.

  Variations/Related:

  - Modern Forms only. Classic Forms not affected.

  - Regression introduced by commit 9283e183 (PR 162864, "Apply sr-only on fl-field-label in tables instead of display: none") which fixed Bug Bug 630667: WCAG Rendered Forms - Fields in table are missing labels . Released in Cloud 2026.03.

  - Root cause: field-label.component.ts line 8 added "[class.sr-only]": "inTable && !inDesigner" as a host binding. The previous mechanism (display: none in table.less) was overridden on small screens because

   the responsive rule in ResponsiveLayoutCSS uses display: flex on the same property. sr-only uses position: absolute; width: 1px; clip: rect(0,0,0,0) — none of which the existing override neutralizes — so

  the label is laid out as flex but clipped to a 1×1 invisible pixel.

  - Collection fields are unaffected because their fields render with isInTable = false, so the sr-only host binding never fires.

  - Related to Bug #630667 (must not regress: screen-reader announcement of table field labels on screens >600px).

---

## WI 657454 - description - 04/29/2026 - Joey Lin

Repro:

Upload the attached process and preview the form 'Planning application'

There is likely a bad field rule configuration causing null error.

Actual:

vendor.js:74 ERROR TypeError: Cannot read properties of undefined (reading 'readOnly')
    at modernForms.bundle.js:2:265051    at modernForms.bundle.js:2:97944    at modernForms.bundle.js:2:123333    at e.processFormulasOnLoad (modernForms.bundle.js:2:263620)
    at Object.postProcess (modernForms.bundle.js:2:278604)
    at main.js:1:68813    at vendor.js:43:43566    at x._next (vendor.js:43:40283)
    at x.next (vendor.js:43:29004)
    at x._next (vendor.js:43:29318)

﻿

Expected:

Variations/Related:

---

## WI 657454 - comment - 06/04/2026 - Joey Lin

Set back to Legacy due to it being very old

  The renderer service has two unguarded fieldIdToSettings[populatedField] dereferences, introduced by two different work items. The one that fires first (and produces the exact isInTable/isInCollection
  TypeError we reproduced) is in initialize().

  Primary crash site — initialize() → the regression

  ┌────────────────────┬──────────────────────────────────────────────────────────────────────────────────────────┐

  │                    │                                                                                          │

  ├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤

  │ Introducing commit │ ec3ea1a26 — "Only run formula for 1 field in repeatable if applicable #426082"           │

  ├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤

  │ Author / date      │ Huong Nguyen, 2023-05-09                                                                 │

  ├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤

  │ Work item          │ Task #426082 — "Improving formula performance" (Area: Forms Frontend, State: Closed)     │

  ├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤

  │ File at the time   │ fl-lib/src/lib/services/formulas.service.ts (later relocated to fl-renderer — see below) │

  └────────────────────┴──────────────────────────────────────────────────────────────────────────────────────────┘

  The exact lines it added (no null guard, then or since):

  const populatedFieldSettings = this.fieldIdToSettings[f.populatedField];

  const populatedFieldInRepeatable = populatedFieldSettings.isInTable || populatedFieldSettings.isInCollection;  // &#128165; NPE on orphaned formula

  This is the line our reverted test failed on: Cannot read properties of undefined (reading 'isInTable'). The commit was a perf change ("only run formula for 1 field in repeatable") that introduced the

  assumption "every formula's populatedField resolves to a live setting" — which an orphaned formula violates.

---

## WI 657448 - description - 04/29/2026 - Joey Lin

Summary

  Relax the IllegalCharacter validation on Forms single-line and multi-line text fields so that values containing <a, &#, and similar character combinations can be submitted. The current validation, introduced

   in 2018 (Bug #98774) as a defense against stored XSS, is overly broad and rejects legitimate user input — most notably passwords, URLs with query fragments, and technical strings.

  Background

  - The validation is enforced both client-side (forms-layout illegalCharacterValidator) and server-side (FormattedSubmissionData.cs) via the regex &#|(<([a-z]|[A-Z]|\/|\?|\!)+).

  - Original intent: block HTML/script injection because several render sites used unsafe [innerHTML] bindings and unencoded email token substitution (ParseTokensDecoded()).

  - Single-line/multi-line form UI rendering is already safe — Angular's {{ }} interpolation auto-encodes HTML, so input rejection is unnecessary for that path.

  - The validation remains a compensating control for: checkbox/radio "Other" [innerHTML] rendering, HTML email token substitution, and monitoring app display.

  Customer Impact

  - US CloudID 424374803 (TFS Issue 657198: Question regarding "This field contains a combination of illegal characters" error ): cannot use a CSS-styled "password" text field because legitimate passwords contain <a, &#, etc.

  - Generally affects: passwords, code snippets, copy-pasted URLs, technical/markup content in any text field.

  Proposed Scope

  1. Per-field opt-out — add a Forms Designer property (e.g., allow_special_characters) that disables the IllegalCharacter validator for that specific field. Lowest-risk, immediate unblock for the customer.

  2. Fix the underlying unsafe render sites so the broad validation is no longer needed:

    - HTML-encode otherChoiceValue in checkbox.component.ts / radio.component.ts before HTML string concatenation.

    - Switch HTML email templates from ParseTokensDecoded() to ParseTokensEncoded() in FormsSubmissionHandler.cs.

    - Apply DOMPurify at remaining [innerHTML] sites (dropdown labels, token field, auto-complete, file-transfer upload prompt).

  3. Once render sites are safe — remove the input-rejection regex entirely for text/longtext fields, retaining it only on the Other field type until the checkbox/radio fix ships.

  Risk

  Low if scoped to (1) only. Medium for (2)/(3) — touches email rendering and shared submission components, requires security review and a stored-XSS test pass.

---

## WI 657160 - description - 04/28/2026 - Joey Lin

Repro:

Actual:
Info+103ms(52)]Eligible for retry with message: Access denied. [9013] and innerException:
[Info+103ms(52)]First attempt to run STR_GET_FOLDERPATH failed, started polly retry max=15 delay-range=0.1-60
[Info+134ms(52)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#1) in 0.094165 seconds
[Info+242ms(29)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#2) in 0.1432231 seconds
[Info+415ms(28)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#3) in 0.0578201 seconds
[Info+507ms(32)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#4) in 0.3926104 seconds
[Info+929ms(10)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#5) in 1.4444235 seconds
[Info+2s 393ms(31)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#6) in 0.725605 seconds
[Info+3s 137ms(31)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#7) in 2.212897 seconds
[Info+5s 378ms(8)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#8) in 10.9867523 seconds
[Info+16s 407ms(30)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#9) in 12.6978614 seconds
[Info+29s 122ms(32)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#10) in 12.6719608 seconds
[Info+41s 817ms(28)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#11) in 34.9161944 seconds
[Info+1m 16s(33)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#12) in 60 seconds
[Info+2m 16s(28)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#13) in 60 seconds
[Info+3m 16s(7)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#14) in 60 seconds
[Info+4m 16s(29)]Giving up on STR_GET_FOLDERPATH, failed after 15 attempt(s)
[ERR+4m 16s(29)][FormsRoutingEngineSaveToLaserficheService::SaveToLF:979][Error: STR: RuntimeStepId=b43900c7-962a-4414-a4c8-3cdf45bfe88b, Error saving to LF. Access denied. [9013]
[ERR+4m 16s(29)]Access denied. [9013]
ACCESS DENIED. [9013]
	-----TRACES----
	Laserfiche.RepositoryAccess.AccessDeniedException: Access denied. [9013]
	   at BPMFormsCommonUtils.PollyRetry.<RetryWithJitter>d__38`1.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at BPMFormsCommonUtils.PollyRetry.<RunAction>d__43`1.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at Laserfiche.RoutingEngine.Manager.Services.Forms.FormsRoutingEngineSaveToLaserficheService.<RunStrGetFilepath>d__39.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at System.Runtime.CompilerServices.ConfiguredTaskAwaitable`1.ConfiguredTaskAwaiter.GetResult()
	   at Laserfiche.RoutingEngine.Manager.Services.Forms.FormsRoutingEngineSaveToLaserficheService.<SaveToLF>d__37.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at Laserfiche.RoutingEngine.Manager.Services.Forms.FormsRoutingEngineSaveToLaserficheService.<SaveToLF>d__37.MoveNext()
	------
	-----DATA-----
		OperationId = b43a012daffb4af1aae1ea924f466940
[Info+4m 16s(29)]Error Logged In Cache, string length 81

Expected:

Variations/Related:

---

## WI 657160 - description - 05/25/2026 - Joey Lin

Repro:

- could not get to this path directly. It seems to be a transient issue that's hard to hit this exact path. Setting ProcessAutomationUser with denied from ACS/webclient will immediately fail/suspend without polly retry.
- Require Dev verify

Actual:
Info+103ms(52)]Eligible for retry with message: Access denied. [9013] and innerException:
[Info+103ms(52)]First attempt to run STR_GET_FOLDERPATH failed, started polly retry max=15 delay-range=0.1-60
[Info+134ms(52)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#1) in 0.094165 seconds
[Info+242ms(29)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#2) in 0.1432231 seconds
[Info+415ms(28)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#3) in 0.0578201 seconds
[Info+507ms(32)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#4) in 0.3926104 seconds
[Info+929ms(10)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#5) in 1.4444235 seconds
[Info+2s 393ms(31)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#6) in 0.725605 seconds
[Info+3s 137ms(31)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#7) in 2.212897 seconds
[Info+5s 378ms(8)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#8) in 10.9867523 seconds
[Info+16s 407ms(30)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#9) in 12.6978614 seconds
[Info+29s 122ms(32)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#10) in 12.6719608 seconds
[Info+41s 817ms(28)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#11) in 34.9161944 seconds
[Info+1m 16s(33)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#12) in 60 seconds
[Info+2m 16s(28)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#13) in 60 seconds
[Info+3m 16s(7)]Previous attempt to run STR_GET_FOLDERPATH failed, retry (#14) in 60 seconds
[Info+4m 16s(29)]Giving up on STR_GET_FOLDERPATH, failed after 15 attempt(s)
[ERR+4m 16s(29)][FormsRoutingEngineSaveToLaserficheService::SaveToLF:979][Error: STR: RuntimeStepId=b43900c7-962a-4414-a4c8-3cdf45bfe88b, Error saving to LF. Access denied. [9013]
[ERR+4m 16s(29)]Access denied. [9013]
ACCESS DENIED. [9013]
	-----TRACES----
	Laserfiche.RepositoryAccess.AccessDeniedException: Access denied. [9013]
	   at BPMFormsCommonUtils.PollyRetry.<RetryWithJitter>d__38`1.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at BPMFormsCommonUtils.PollyRetry.<RunAction>d__43`1.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at Laserfiche.RoutingEngine.Manager.Services.Forms.FormsRoutingEngineSaveToLaserficheService.<RunStrGetFilepath>d__39.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at System.Runtime.CompilerServices.ConfiguredTaskAwaitable`1.ConfiguredTaskAwaiter.GetResult()
	   at Laserfiche.RoutingEngine.Manager.Services.Forms.FormsRoutingEngineSaveToLaserficheService.<SaveToLF>d__37.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at Laserfiche.RoutingEngine.Manager.Services.Forms.FormsRoutingEngineSaveToLaserficheService.<SaveToLF>d__37.MoveNext()
	------
	-----DATA-----
		OperationId = b43a012daffb4af1aae1ea924f466940
[Info+4m 16s(29)]Error Logged In Cache, string length 81

Expected:

Variations/Related:

---

## WI 656816 - description - 04/27/2026 - Joey Lin

Repro:

   1. Have a user account with timezone set to (UTC-06:00) Guadalajara, Mexico City, Monterrey
   2. Create a bp instance with MessageStart->UserTask-End and have the UserTask assigned to the user

   3. Compete the user task

   4. In monitoring, open the task approval page

   5. See the Action history time

   6. Make sure the time is consistent with the current 'Mexico City' time (confirm via google)

   2026-04-27 10:27 am

   Joey Lin completed task User Task

   Should be 9:27 am
Actual:

Expected:

Variations/Related:

---

## WI 656816 - description - 04/27/2026 - Joey Lin

Repro:

During DST, - Sunday, March 8, 2026, at 2:00 A.M. Clocks go forward to 3:00 A.M..
- End (Fall Back): Sunday, November 1, 2026, at 2:00 A.M.

   1. Have a user account with timezone set to (UTC-06:00) Guadalajara, Mexico City, Monterrey
   2. Create a bp instance with MessageStart->UserTask-End and have the UserTask assigned to the user

   3. Compete the user task

   4. In monitoring, open the task approval page

   5. See the Action history time

   6. Make sure the time is consistent with the current 'Mexico City' time (confirm via google)

   2026-04-27 10:27 am

   Joey Lin completed task User Task

   Should be 9:27 am
Actual:

Expected:

Variations/Related:

---

## WI 656100 - description - 04/23/2026 - Joey Lin

- Trigger a 500 response from svc-pa-platform (or any other microservice bpm talks to)
- See Connections to that servicepoint increase during each retry and not released
- This can hit the ConnectionLimit

---

## WI 656100 - comment - 04/23/2026 - Joey Lin

Logs used to verify on dev local:

Sample logs: added in                 onRetry: (response, delay, retryAttempt, context) =>                {
                    context["retrycount"] = retryAttempt;

                    var httpResponse = response.Result;
                    string connectionHeader = httpResponse?.Headers?.Connection != null
                        ? string.Join(",", httpResponse.Headers.Connection)
                        : "none";
                    try
                    {
                        var sp = ServicePointManager.FindServicePoint(request.RequestUri);
                        System.Diagnostics.Trace.TraceWarning(
                            $"[HttpRetryMessageHandler] Retry {retryAttempt}/{MaxRetries} " +
                            $"Host={request.RequestUri.Host}:{request.RequestUri.Port} " +
                            $"Status={(httpResponse != null ? ((int)httpResponse.StatusCode).ToString() : "exception")} " +
                            $"Connection={connectionHeader} " +
                            $"KeepAlive={connectionHeader.IndexOf("close", StringComparison.OrdinalIgnoreCase) < 0} " +
                            $"ConnectionLimit={sp.ConnectionLimit} CurrentConnections={sp.CurrentConnections} " +
                            $"NextDelay={delay.TotalSeconds}s");
                    }
                    catch { }
Before:

Laserfiche.BPMAPI.exe Warning: 0 : [HttpRetryMessageHandler] Retry 5/5 Host=localhost:80 Status=500 Connection= KeepAlive=True ConnectionLimit=10 CurrentConnections=10 NextDelay=16s?

After:
Laserfiche.BPMAPI.exe Warning: 0 : [HttpRetryMessageHandler] Retry 5/5 Host=localhost:80 Status=500 Connection= KeepAlive=True ConnectionLimit=10 CurrentConnections=1 NextDelay=16s

---

## WI 656100 - description - 04/23/2026 - Joey Lin

Issue 654696: CA Production Multiple customers report business process lookup rules are slow
- Trigger a 500 response from svc-pa-platform (or any other microservice bpm talks to)
- See Connections to that servicepoint increase during each retry and not released
- This can hit the ConnectionLimit

---

## WI 656100 - description - 04/23/2026 - Joey Lin

Issue 654696: CA Production Multiple customers report business process lookup rules are slow
- Trigger a 500 response from svc-pa-platform (or any other microservice bpm talks to)
- I hardcoded to throw an exception on the /canaccess api for a particular bp
-             if (callingResourceId == new Guid("b42e0105-03db-4de4-b812-767be7e6bde3")) {
                throw new Exception("Test Exception");

            }

 - See Connections to that servicepoint increase during each retry and not released
- This can hit the ConnectionLimit
 - Trigger lookup rule from another bp, see it significantly slow down

---

## WI 656100 - comment - 05/01/2026 - Joey Lin

Repro steps: - Deploy bad svc-pa-platform branch branch-from-e7a15a5a-incident-branch
- Trigger bug Bug 655435: Business process or Workflow with AI rule cannot be imported to a project
- You can verify in logs, svc-pa-platform has lots of errors:
- DBID: 246\n[Error+3ms]ExceptionFilter: Could not convert string 'AIPromptRule' to dictionary key type 'Laserfiche.Spark.ResourceType'.
- Or import does not work
- While the error is happening, run simple lookup rules in another form, should be fastand not delayed

---

## WI 654719 - comment - 05/12/2026 - Joey Lin

added in https://v-dev-tfs/DefaultCollection/Cloud/_git/bpm/pullrequest/169271
Bug 656100: HttpRetryMessageHandler can leak connections via HttpResponsemessage

---

## WI 651736 - description - 03/31/2026 - Joey Lin

Steps to Reproduce

  Setup:

   1. In the Rules product, optionally prepare a lookup table — OR use the form-only approach described below.

   2. Create a form with one collection field (<collection field>) containing 13 fields:

    - 11 × Single-Line Text fields — set a non-empty Default Value on each (e.g., "text")

    - 2 × Multi-Line Text fields — set a Default Value of several sentences of text on each (e.g., 2–3 lines)

   3. On the same form, add a Formula lookup rule:

    - Trigger: any field change, or Auto Fill on open

    - Formula: splits a string of 600+ space-separated tokens into an array (e.g., the first 600 digits of pi separated by spaces)

    - Output: fills <collection field> → <any one column> → Append rows mode

   4. Create a BP: Message Start Event → attach the form to the start event → User Task 1 → End Event

  Reproduction:

   1. Start a new instance of the BP. Fill the start form and trigger the lookup rule (wait for it to append ~600 rows).

   2. Submit the form to start the BP instance.

   3. Open BP Monitor → locate the new instance (status: In Progress or Completed).

   4. Click the instance → Edit → Update Variable Value.

   5. Observe the time between clicking and the dialog becoming responsive/interactive.

  Actual Result

  The Update Variable Value dialog takes 30–60+ seconds to become interactive after clicking. The browser tab becomes unresponsive during this period. (Data transfer from the server takes < 1 second.)

  Expected Result

  The dialog should open and become interactive within 2–3 seconds at most, regardless of the number of rows in collection variables.

  Variations

   - Severity scales with row count: ~300 rows produces a ~10-second delay; ~600 rows produces a ~30–60-second delay.

   - Including Multi-Line Text fields (longtext) with substantial default values increases the per-row payload size and lowers the row count threshold for observable slowness.

   - Without default values on collection fields, the formula rule only populates one column per row — the dialog loads fast even with hundreds of rows because only one column's data exists in the variable

  store.

   - The issue is in rendering, not data transfer. The VariableDetails API returns all cell objects (including empty ones) and the AngularJS ng-repeat creates one bound form control per cell — all at once,

  with no pagination or virtualization.

---

## WI 651736 - comment - 04/01/2026 - Joey Lin

Yeah, that's true. But with the show more button, it doesn't become a load test anymore since it's very fast even with large data set. Either way, agree the load more button should be tested

---

## WI 650500 - description - 03/25/2026 - Joey Lin

Repro:

- Create a collection with 2 single line fields, trigger and target
- set target to readonly
- Have a simple lookup rule that map trigger -> target
- Add a row
- See that new row gets updated with lookup result
- save draft
- open inbox > open drafts
- save draft again
- open draft again

Actual:
- the newly added rows do not contain lookup target results

Expected:
- drafts contain lookup result for newly added readonly rows

Variations/Related:

---

## WI 649778 - description - 03/20/2026 - Joey Lin

Repro:
Upload the attached process,

Enter 2 dates for time start and time end on mobile safari

Duration with formula is not calculated
Actual:

Expected:

Variations/Related:

---

## WI 647057 - description - 03/05/2026 - Joey Lin

Repro:

For a User Task in Forms the Form selection will give precedence to "Select a form" drop-down selection even though "Forms based on variable" is the selected option.

Steps to reproduce:

Create a User Task, for the Form tab, "Select a form", choose a form from the dropdown.

Reconfigure the User Task to use the "Forms based on variable" option

Observed:
When running the process, the form selected in "Select a form" drop-down loads for the User Task

Expected:
When running the process, the form determined by "Form based on variable" loads for the User Task

Workaround:
Recreate the User Task and leave the "Select a form" drop-down with the default blank value and proceed to configure with the "Form based on variable" option

Reported by CloudID: CA 1284649755
Reproduced on CloudID:  US 190341395

Actual:

Expected:

Variations/Related:

---

## WI 644254 - description - 02/19/2026 - Joey Lin

Problem
The svc-app-pdf-rasterization service fails to rasterize specific PDFs with a NullReferenceException originating inside the O2S PDF4NET library's PDFPageRenderer.ConvertPageToImage method. This causes Forms "Save to Repository" steps to suspend with [LFF716-RasterizationFailed]. The attached PDF (21 pages) fails on page 4; pages 0–3 succeed.
Root Cause
svc-app-pdf-rasterization uses Laserfiche.PDFService.NET.Core (v2026.0109.1514.44, built Jan 9 2026), which uses O2S PDF4NET 15.0.4.1. This version has a confirmed bug where PDFPageRenderer.ConvertPageToImage throws a NullReferenceException when rendering certain PDF pages using the PDFArgbRenderingSurface<int> rendering surface.
Critical code difference:
- Laserfiche.PDFService.NET.Core (svc-app-pdf-rasterization) → uses PDFArgbRenderingSurface<int> → crashes
- Laserfiche.PDFServiceNetCore (RWS) → uses PDFRgbRenderingSurface → avoids the crash for this specific PDF
 Both use PDF4NET 15.0.4.1, but the different rendering surface type triggers the null reference in one code path but not the other for this PDF's page 4 structure.
Stack Trace
System.Exception: PDFPageRenderer.ConvertPageToImage returned GenericError for page 4: Object reference not set to an instance of an object.
   at Laserfiche.PDFService.NET.Core.PDFExtractor.ImportPDFPageImage(PDFFixedDocument pdfDocument, Int32 nPageIndex)
   at Laserfiche.PDFService.NET.Core.PDFExtractor.ImportPDFPagesFromStream(Stream pdfStream)
   at Laserfiche.Sites.SvcAppPdfRasterization.Models.PDFProcessingWorker.StartRasterize(...) in PDFProcessingWorker.cs:line 878Dependency Chain
svc-app-pdf-rasterization
  → Laserfiche.PDFService.NET.Core 2026.0109.1514.44  (Laserfiche.PDFService.NetStandard repo)
    → O2S.Components.PDF4NET.NET 15.0.4.1  ← buggy versionFix
O2 provided a fix in PDF4NET 16.1.1.5, published to NugetShared on Jan 15, 2026 — after the current package build (Jan 9, 2026). The fix needs to be applied to Laserfiche.PDFService.NetStandard → rebuild Laserfiche.PDFService.NET.Core → update the package reference in svc-app-pdf-rasterization.
Related: Bug 635045 - [RWS] Null reference error from PDF4NET generating pages for the attached file (Content Services team, targeted Cloud 2026.03)
Customer Impact
Cloud Account 104689790 — Forms STR step suspends for this specific PDF. Workaround: configure STR to skip page generation, then manually generate pages from the web client. See Cloud Ticket 644240.

---

## WI 644254 - description - 02/20/2026 - Joey Lin

Rasterize with the attached pdf, should pass
Problem
The svc-app-pdf-rasterization service fails to rasterize specific PDFs with a NullReferenceException originating inside the O2S PDF4NET library's PDFPageRenderer.ConvertPageToImage method. This causes Forms "Save to Repository" steps to suspend with [LFF716-RasterizationFailed]. The attached PDF (21 pages) fails on page 4; pages 0–3 succeed.
Root Cause
svc-app-pdf-rasterization uses Laserfiche.PDFService.NET.Core (v2026.0109.1514.44, built Jan 9 2026), which uses O2S PDF4NET 15.0.4.1. This version has a confirmed bug where PDFPageRenderer.ConvertPageToImage throws a NullReferenceException when rendering certain PDF pages using the PDFArgbRenderingSurface<int> rendering surface.
Critical code difference:
- Laserfiche.PDFService.NET.Core (svc-app-pdf-rasterization) → uses PDFArgbRenderingSurface<int> → crashes
- Laserfiche.PDFServiceNetCore (RWS) → uses PDFRgbRenderingSurface → avoids the crash for this specific PDF
 Both use PDF4NET 15.0.4.1, but the different rendering surface type triggers the null reference in one code path but not the other for this PDF's page 4 structure.
Stack Trace
System.Exception: PDFPageRenderer.ConvertPageToImage returned GenericError for page 4: Object reference not set to an instance of an object.
   at Laserfiche.PDFService.NET.Core.PDFExtractor.ImportPDFPageImage(PDFFixedDocument pdfDocument, Int32 nPageIndex)
   at Laserfiche.PDFService.NET.Core.PDFExtractor.ImportPDFPagesFromStream(Stream pdfStream)
   at Laserfiche.Sites.SvcAppPdfRasterization.Models.PDFProcessingWorker.StartRasterize(...) in PDFProcessingWorker.cs:line 878Dependency Chain
svc-app-pdf-rasterization
  → Laserfiche.PDFService.NET.Core 2026.0109.1514.44  (Laserfiche.PDFService.NetStandard repo)
    → O2S.Components.PDF4NET.NET 15.0.4.1  ← buggy versionFix
O2 provided a fix in PDF4NET 16.1.1.5, published to NugetShared on Jan 15, 2026 — after the current package build (Jan 9, 2026). The fix needs to be applied to Laserfiche.PDFService.NetStandard → rebuild Laserfiche.PDFService.NET.Core → update the package reference in svc-app-pdf-rasterization.
Related: Bug 635045 - [RWS] Null reference error from PDF4NET generating pages for the attached file (Content Services team, targeted Cloud 2026.03)
Customer Impact
Cloud Account 104689790 — Forms STR step suspends for this specific PDF. Workaround: configure STR to skip page generation, then manually generate pages from the web client. See Cloud Ticket 644240.

---

## WI 644254 - comment - 03/02/2026 - Joey Lin

v16 regression test has some failures, I confirmed they are false positives form a few sources: old pipelines renaming the expected file name; and manually confirmed the failed cases work in clouddev.

  Test Case Id
  File Name
  pd4netregression v16
  v16 (clouddev)

  Case 86706
  BAD City Council - Redevelopment Agency Agenda Packet 2007-11-13
  19-00.pdf

  TFS 362989,
  TAB 09 A - PP-001230-2021 Redtail Ranch Phase II DR.pdf
  skip > 25mb

  Case 115183,
  REGULAR BOARD MTG Agenda Packet 2009-10-22 12-30.pdf

  Case 233442,
  01072014 BOARD PKT.pdf: Failed Pages 23

  Case 51936,
  walkaboutwrite.pdf: Failed Pages 4

  Case 64473,
  workflow training guide.pdf: Failed Pages
  15,16,17,18,19,20,21,24,27,28,29

  Case 32071 - Star Abroad
  e2502x17xxxxxxxxx.pdf

  Case 46006_raghu_volumes
  00000FC2.pdf,00000FF8.pdf,00000FF9.pdf

  Case 105738,
  20090210.pdf

  Case 199242,
  PERMIT ATTACHMENT - CarlsonJeanRd - ID 5317.pdf

  Case 208780,
  BEARD APPLICATION.pdf

  Case 147946

  Case 238503
  036755810_042924.pdf

  Case 195812
  Agreement sample.pdf

  Case 187028
  Multiple Documents.pdf

  Case 183054
  Fire Roster (40).pdf

  TFS 644240
  Income Lab Financial Plan (1) - 4

---

## WI 643912 - description - 02/17/2026 - Joey Lin

Repro:

Use new outlook and drag and drop a file into a file upload file
Actual:
stuck showing in-progress
Expected:should block invalid files

Variations/Related:

---

## WI 643912 - description - 02/18/2026 - Joey Lin

Repro:

Use new outlook and drag and drop a file into a file upload field
Actual:
stuck showing in-progress
Expected:should block invalid files

Variations/Related:

---

## WI 643654 - description - 02/13/2026 - Joey Lin

https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/discover?_g=(refreshInterval:(pause:!t,value:0),time:(from:now-12h,mode:quick,to:now))&_a=(columns:!(message),filters:!((%27$state%27:(store:appState),meta:(alias:!n,disabled:!f,index:f651ec50-d841-11eb-8c96-47ea7c58f93d,key:kubernetes.container_name.keyword,negate:!f,params:(query:svc-app-renode,type:phrase),type:phrase,value:svc-app-renode),query:(match:(kubernetes.container_name.keyword:(query:svc-app-renode,type:phrase))))),index:f651ec50-d841-11eb-8c96-47ea7c58f93d,interval:auto,query:(language:kuery,query:timeoutError),sort:!(%27@timestamp%27,asc))

---

## WI 643654 - description - 02/18/2026 - Joey Lin

https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/doc/f651ec50-d841-11eb-8c96-47ea7c58f93d/kubernetes-cluster-fbkobdfj9vd9-2026.02.13/fluentd?id=ZDI5ODljZjYtYjY0Zi00ODY4LThjMjgtZGI4MWZiYTkzMmYz&_g=h@5b3f25d

---

## WI 643654 - comment - 03/30/2026 - Joey Lin

This is very likely fixed by Bug 648214: concurrent print jobs can sometimes fail

When a report page do not load successfully, the readyForScreenshot selector never gets populated.
From log evidence, they happen at the same time as another print job.

i.e.
Incident 1:
February 27th 2026, 12:19:16.064	[ReceivedHTTPRequest] TimeoutError: Waiting for selector `#readyForScreenshot
February 27th 2026, 12:19:16.025	[SQSMessage 9fde2048-f80a-4e31-b7b0-57f1e7c5a59e]

Incident 2:
February 27th 2026, 12:20:16.192	[ReceivedHTTPRequest] TimeoutError: Waiting for selector `#readyForScreenshot`
February 27th 2026, 12:20:16.175	[SQSMessage eee57ddf-2dbd-485c-8dcc-0b65b7cb7b7a]

Both suggest that the cookie override caused the report to not load correctly.
The error has also not surfaced since the bug fix deployment since 3/17.

---

## WI 641973 - description - 02/06/2026 - Joey Lin

See Issue 640816: Multivalue DateTime value cleared in WF but Forms retains first value

Currently, it's hard to clear an entire collection\var or table\var by only using WF or rules outputs.

Workaround exist, but it may not be idea.

---

## WI 641440 - description - 02/04/2026 - Joey Lin

Repro:

- Create a lookup rule that returns multiple values
- Map this as a lookup to a single line which creates an auto-suggestion list
- Use developer tool to slow down the lookup request (e.g. enable slow 3G)
- Trigger the lookup rule
- Before the rule completes, type in the target single line field

Actual:
- When the lookup returns, the lookup population is ignored

Expected:
- Should still populate the auto suggestion list

Variations/Related:

---

## WI 641438 - description - 02/04/2026 - Joey Lin

Repro:

sample run
create start-str(with generate LF pages) - end

Create a custom report with status and instance id

Actual:
Sometimes status is not updated

Expected:

Variations/Related:

---

## WI 640964 - description - 02/03/2026 - Joey Lin

Repro:

- Create a WF/Rule that returns empty string variable
- Map it to a datetime or collection/table/datetime that already contains a date
-

Actual:
- Should reset the date to blank

Expected:

Variations/Related:

---

## WI 640964 - description - 02/03/2026 - Joey Lin

Repro:

- Create a WF/Rule that returns empty string variable
- Map it to a datetime outside of collection/table that already contains a date
-

Actual:
- Should reset the date to blank

Expected:

Variations/Related:

---

## WI 640964 - description - 02/03/2026 - Joey Lin

Repro:

- Create a WF/Rule that returns empty string variable
- Map it to a datetime outside of collection/table that already contains a date
-

Actual:

- should not show a warning
-

Expected:

Variations/Related:

---

## WI 640139 - description - 01/29/2026 - Joey Lin

Repro:
Import attached BP
or
- Create start->usertask-end
- set usertask with "Make form read-only for users the task is assigned to"
 - Create form in usertask
- readonly section
- SingleLine1
- SingleLine2 with formula =SingleLine1
 - Field rule to always hide SingleLine1
 - run and submit user task

Actual:Submission fails

Expected:

Variations/Related:

---

## WI 637621 - description - 01/19/2026 - Joey Lin

https://v-dev-tfs/DefaultCollection/Server%20Tools/_build/results?buildId=2016945&view=ms.vss-test-web.build-test-results-tab&runId=2178128&resultId=100000&paneView=debug

Test method BpmWebApiTests.FormsTests.RuntimeTest.Runtime_STRTaskSaveAsPdfPagesFuzzTestingSmallFiles threw exception:
Laserfiche.RepositoryAccess.MultiStatusException: Multistatus response. [9039]
Another operation on which this operation depends failed. [9054]
Entry locked. [9014]

Occurred during both renode + rasterization container deployment. Likely concurrent issue.

---

## WI 637271 - comment - 01/19/2026 - Joey Lin

https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/doc/f651ec50-d841-11eb-8c96-47ea7c58f93d/kubernetes-cluster-fbkobdfj9vd9-2026.01.16/fluentd?id=OTk1OTlkNjgtNjMyMy00MDIyLTlhNTUtNjk4YTE3Mzg4NGFk&_g=h@9066ea7

Memory cgroup out of memory: Killed process 546921 (chromium) total-vm:1459728736kB, anon-rss:3519232kB, file-rss:109160kB, shmem-rss:0kB, UID:100 pgtables:10012kB oom_score_adj:968

Some OOM logs correlate to same time as timeouts.

---

## WI 637090 - description - 01/15/2026 - Joey Lin

Repro:

STR with arabic text

Paste arabic text:"تَتَحَدَّث اَلْأَبْيَات عَنْ لَحْظَة وَدَاع يَسْتَغْرِب فِيهَا اَلشَّاعِر أَنْ لَا يَبْكِي مِنْ أَلَم اَلْفِرَاق، وَيَصِف حَالَة اَلْمُودِعِينَ وَبَعْضهمْ يَتَكَلَّم فِي حِين يَكْتَفِي اَلْمُحِبُّونَ بِالصَّمْتِ، لِأَنَّ حَالهمْ تَظْهَر عِشْقهمْ"

On Classic Form, should work when the following fonts are added (same as customer form):

* {
  font-family: "noto sans arabic" !important;
}

Actual:

Expected:
Should not contain space.

Variations/Related:

---

## WI 637090 - description - 01/15/2026 - Joey Lin

Repro:

STR with arabic text

Paste arabic text:"تَتَحَدَّث اَلْأَبْيَات عَنْ لَحْظَة وَدَاع يَسْتَغْرِب فِيهَا اَلشَّاعِر أَنْ لَا يَبْكِي مِنْ أَلَم اَلْفِرَاق، وَيَصِف حَالَة اَلْمُودِعِينَ وَبَعْضهمْ يَتَكَلَّم فِي حِين يَكْتَفِي اَلْمُحِبُّونَ بِالصَّمْتِ، لِأَنَّ حَالهمْ تَظْهَر عِشْقهمْ"

Actual:

Expected:
Should not contain space.

Variations/Related:

---

## WI 636836 - description - 01/14/2026 - Joey Lin

David Choy: Updating the EKS nodes in development us-west-2 and ca-central-1 to te... | Cloud Operations > Development | Microsoft Teams

---

## WI 634778 - description - 01/05/2026 - Joey Lin

Repro:

STR with arabic text

Paste arabic text:"تَتَحَدَّث اَلْأَبْيَات عَنْ لَحْظَة وَدَاع يَسْتَغْرِب فِيهَا اَلشَّاعِر أَنْ لَا يَبْكِي مِنْ أَلَم اَلْفِرَاق، وَيَصِف حَالَة اَلْمُودِعِينَ وَبَعْضهمْ يَتَكَلَّم فِي حِين يَكْتَفِي اَلْمُحِبُّونَ بِالصَّمْتِ، لِأَنَّ حَالهمْ تَظْهَر عِشْقهمْ"

Actual:

Expected:
Should not contain space.

Variations/Related:

---

## WI 634778 - description - 01/14/2026 - Joey Lin

Repro:

STR with arabic text

Paste arabic text:"تَتَحَدَّث اَلْأَبْيَات عَنْ لَحْظَة وَدَاع يَسْتَغْرِب فِيهَا اَلشَّاعِر أَنْ لَا يَبْكِي مِنْ أَلَم اَلْفِرَاق، وَيَصِف حَالَة اَلْمُودِعِينَ وَبَعْضهمْ يَتَكَلَّم فِي حِين يَكْتَفِي اَلْمُحِبُّونَ بِالصَّمْتِ، لِأَنَّ حَالهمْ تَظْهَر عِشْقهمْ"

On Modern form: should work natively.

On Classic Form, should work when the following fonts are added (same as customer form):

* {
  font-family: "noto sans arabic" !important;
}

Actual:

Expected:
Should not contain space.

Variations/Related:

---

## WI 634778 - description - 01/15/2026 - Joey Lin

Repro:

STR with arabic text

Paste arabic text:"تَتَحَدَّث اَلْأَبْيَات عَنْ لَحْظَة وَدَاع يَسْتَغْرِب فِيهَا اَلشَّاعِر أَنْ لَا يَبْكِي مِنْ أَلَم اَلْفِرَاق، وَيَصِف حَالَة اَلْمُودِعِينَ وَبَعْضهمْ يَتَكَلَّم فِي حِين يَكْتَفِي اَلْمُحِبُّونَ بِالصَّمْتِ، لِأَنَّ حَالهمْ تَظْهَر عِشْقهمْ"

On Classic Form, should work when the following fonts are added (same as customer form):

* {
  font-family: "noto sans arabic" !important;
}

Actual:

Expected:
Should not contain space.

Variations/Related:

---

## WI 634778 - comment - 01/15/2026 - Joey Lin

Split form designer out to here Bug 637090: arabic text in print form contains wrong format with a space - Copy

Keep this one only for Classic Form, (one used by support customer)

---

## WI 632700 - description - 12/18/2025 - Joey Lin

Repro:

From:
Alex Aw: It would be nice if things in an account expiring (certificates, keys, et... | Laserfiche Product Questions and Feedback > General | Microsoft Teams

Create simple formula rule such as

%(input) + 1

Setup 2 single lines, one for input, one for fill result

run live form, not preview

enter an invalid input e.g. 'a'

Actual:
No error is shown
Expected:
Show error like in preview mode

Variations/Related:

---

## WI 632700 - comment - 12/18/2025 - Joey Lin

@Leen Al Lababidi from User Story 512052: As a form submitter I need layout forms to display an error toast when lookup rules error,

I don't see any AC that suggest we should hide errors on live form and only show on preview mode.

In any case, seems odd we don't show any form of error for live form.

@Zac StLouis , please confirm if we want to keep this this behvaior (invalid this bug) or update to show more generic error on live form, or just show same as preview.

---

## WI 632700 - comment - 12/18/2025 - Joey Lin

Some rules require dynamic/live input. How would the designer see that?

In the example of bad input format, the designer would need to update the form to only send valid inputs? Seems it'd be useful for end users to still see some form of error, or at least warning.

---

## WI 631632 - comment - 02/18/2026 - Joey Lin

Confirmed with Robbie this is not actually needed. The hardcoded 'license' was not used for O2s and it's a LF only check. Our binaries from O2s don't need license strings. Confirmed via code this 'm_strLicenseKey' is not passed to o2s at all.

---

## WI 631482 - description - 12/17/2025 - Joey Lin

Repro:

login to cloudtest with account 890302206

username: a
pass: L****fiche1234
Actual:
container sites doesnt work / show
Expected:

Variations/Related:

---

## WI 631482 - description - 12/17/2025 - Joey Lin

Repro:

login to cloudtest with account 890302206

username: a
pass: L****fiche1234
Actual:
container sites doesnt work / show
Expected:

for this bug, verify:

site-app-tasks
site-app-bpm
site-app-bp-designer
site-app-documents
site-app-forms

site-app-forms-monitoring

site-app-reports

Variations/Related:

---

## WI 630899 - comment - 06/30/2026 - Joey Lin

Status: still on hold — active monitoring in place.

Diagnostic story #674021 ([RasterSizeTrace] logging) deployed to production 2026-06-26, confirmed live in prod logs. We are now actively monitoring for a recurrence of the legacy local rasterization path before removing the old BpmServer code here.

Root cause mechanism (confirmed from source): the send-side eligibility check uses the attachment's real file size (filehandle.ContentLength), while the import-side check uses the recorded size (attachment.Item1.ContentLength) — FormsRoutingEngineSaveToLaserficheService.cs, send trace ~L297, import trace ~L943, ShouldRasterizePDF L319–322. When these disagree (recorded under the limit, real size over it), the attachment is excluded from the rasterization microservice (no token) yet still rasterized locally, with no TooLargeForRasterization warning — matching the originally reported symptom.

Conditions that confirm local rasterization is still processing (search es-us-west-2, index vpc-053e08f18c55291ce-windows_file_logs-YYYY.MM.*, sub_type=bpm_server_spark_trace) — ideally all three for the same operation / fileRef:

- [RasterSizeTrace] stage=send … sizeMismatch=True with recordedSize < rasterMaxBytes ≤ realFileSize

- [RasterSizeTrace] stage=import … shouldRasterizeLocally=True, hasToken=false (same fileRef)

- Legacy execution markers DeletePages Started → ImportPDFStream Started with no preceding LoadCompletedRasterization in the same operation

Current findings (as of 2026-06-30): No recurrence since the diagnostic deployed. The true legacy fingerprint (DeletePages Started) appears only 3 times in all of June 2026 (06-04 and 06-11 ×2) — all before the diagnostic shipped, so none captured the size fields. Note: the shouldRasterizeLocally=True count (~11,600) is not an indicator of the legacy path — that branch is the normal no-token import for any non-rasterized attachment.

Decision gate: Keep this story on hold until a recurrence is captured with the diagnostic. Removing the old code now would delete the very path we're trying to catch in the act. Once a recurrence is confirmed, the fix shifts from "remove old code" to "correct the recorded-vs-real size discrepancy" (send and import sides must use the same size source).

---

## WI 629921 - description - 12/09/2025 - Joey Lin

Alert fired for a renode timeout. Investigation points to possible large file that caused memory spike in the svc-app-renode pod causing print timeout.

Load time was manageable at 16s for a 157mb file.

---

## WI 629921 - description - 12/12/2025 - Joey Lin

Alert fired for a renode timeout. Investigation points to possible large file that caused memory spike in the svc-app-renode pod causing print timeout.

Load time was manageable at 16s for a 157mb file.

Renode print can  be slow or timeout when a form has a very large file attachment.
since the form print portion does not actually need the large attachments, especially when preview is off, see if we can just not load the files to optimize print performance.

Otherwise, memory pressure has been seen in renode pods.

---

## WI 629753 - description - 12/08/2025 - Joey Lin

Repro:

https://v-dev-tfs/DefaultCollection/WF/_build?definitionId=5116&_a=summary
should pass
Actual:

Expected:

Variations/Related:

---

## WI 629753 - description - 12/09/2025 - Joey Lin

Repro:

https://v-dev-tfs/DefaultCollection/WF/_build?definitionId=5116&_a=summary
and
https://v-dev-tfs/DefaultCollection/Repository%20Analytics/_build?definitionId=3023
and
https://v-dev-tfs/DefaultCollection/Repository%20Analytics/_build?definitionId=3028

should pass

remove unsupported font-ubuntu package
Actual:

Expected:

Variations/Related:

---

## WI 627803 - comment - 11/27/2025 - Joey Lin

The first 	PFS_17_02-RoutingEngineTasks message ran for 1m+ at 	November 20th 2025, 09:14:30.802
https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/doc/34939b60-0f04-11f0-bc8c-099c5deb183d/vpc-053e08f18c55291ce-windows_file_logs-2025.11.20/doc/?id=MGI3MDk5MTYtOTE3NS00MGZmLTgyZWMtZTcxZDU2Njc3MTY4

which includes triggering the WF.

The WF reply message still got triggered and accepted at 	November 20th 2025, 09:14:55.071
https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/doc/34939b60-0f04-11f0-bc8c-099c5deb183d/vpc-053e08f18c55291ce-windows_file_logs-2025.11.20/doc?id=NjFjZjE5NTctYTUzMS00YzFlLTg1ZmMtZWU1Y2IyNmZkZDMz&_g=h@f7ef4ba

The instance lock was supposed to prevent timing issues like this.

Log did indicate instance was locked successfully in both messages. Expected is failed in second one until first one unlocks.

[INFORMATION+8s 636ms(80)]Locked instance b37d010d-d4ec-426c-bcde-eb156ae02941 LockKey: 896709125:OT:Laserfiche.Reaction.Models.Instances.InstancePersist:b37d010dd4ec426cbcdeeb156ae02941

[INFORMATION+10s 376ms(60)]Locked instance b37d010d-d4ec-426c-bcde-eb156ae02941 LockKey: 896709125:OT:Laserfiche.Reaction.Models.Instances.InstancePersist:b37d010dd4ec426cbcdeeb156ae02941

---

## WI 626980 - description - 11/24/2025 - Joey Lin

renode will receive timeouterror when printing a bad survey report

https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/discover?_g=(refreshInterval:(pause:!t,value:0),time:(from:now%2fd,mode:quick,to:now%2fd))&_a=(columns:!(message),filters:!(('$state':(store:appState),meta:(alias:!n,disabled:!f,index:f651ec50-d841-11eb-8c96-47ea7c58f93d,key:kubernetes.container_name,negate:!f,params:(query:svc-app-renode,type:phrase),type:phrase,value:svc-app-renode),query:(match:(kubernetes.container_name:(query:svc-app-renode,type:phrase))))),index:f651ec50-d841-11eb-8c96-47ea7c58f93d,interval:auto,query:(language:lucene,query:'%22TimeoutError%22+AND+%22ReceivedHTTPRequest%22'),sort:!('@timestamp',asc))

Need to figure out why this is empty:
https://v-dev-tfs/DefaultCollection/WF/_search?action=contents&text=exportParams&type=code&lp=dashboard-Project&filters=ProjectFilters%7BWF%7D&pageSize=25&result=DefaultCollection/WF/site-app-reports/GBdevelop//src/Views/Print/PrintDashboardChart.cshtml

---

## WI 626980 - comment - 11/26/2025 - Joey Lin

In the error cases, the HttpContext.Request.Body is null/empty, which is passed in from renode via request interception.
I suspect there may be a timing issue and that interception did not happen.

https://v-dev-tfs/DefaultCollection/WF/_git/site-app-reports?path=/src/Controllers/PrintController.cs&version=GBdevelop&line=64&lineEnd=65&lineStartColumn=1&lineEndColumn=1&lineStyle=plain&_a=contents

Add additional logs to confirm if this happens again.

---

## WI 621755 - comment - 11/05/2025 - Joey Lin

@Stephen Hughes-Jelen

To give some context. When an STR task is enabled with the 'Generate Laserfiche Pages feature', we generate images from the PDF along with extracting annotations, which can be searched in web access. However, when a PDF is password protected with an empty password, the annotation extraction no longer works. Thus the warning. However, we feel the string 'Annotations were not generated for this PDF.' might not be descriptive enough, since it doesn't say why. We were thinking something along the lines of:

'Annotations were not generated for this PDF because it is password protected with an empty password'  or just '...because i t is password protected'.

---

## WI 620758 - description - 10/21/2025 - Joey Lin

svc-app-renode already scales based on sqs-messages

The cpu based scaling from 80% of requested cpu is causing frequent pod starts and stops, which leads to unnecessary scaling and retrying of messages.

---

## WI 616948 - comment - 10/03/2025 - Joey Lin

We use the chrome-headless-shell option in puppeteer due to past performance superior results. However, alpine stable repository does not contain the chromium-headless-shell package, only on the edge.

I compared performance results using alpine's chromium package to the current chrome-headless-shell, and noticed better results. Test run with different number of large images, the numbers are time in ms, extracted from the logs

alpine chromium is using latest v140 and puppeteer v24 (latest), compared to the old chrom-headless-shell v131 and puppeteer v23

        alpine-chromium       chrome-headless-shell       production (chrome-headless-shell)

10    5094                           8727

20    11002                         17340

40    15758                         28956

70    25822                         41305                                 46952

---

## WI 616614 - description - 09/26/2025 - Joey Lin

Repro:
Upload the attached bp which contain form with invalid characters.

Try to save the form.

Get error:

Actual:
Should be more clear about unable to saving form and the form name, instead of ambiguous resource name.

Expected:
Possible suggestion. "Unable to save form due to invalid characters: \000bStarting Form. The form name must start with a letter or a number"
Variations/Related:

---

## WI 615774 - description - 09/23/2025 - Joey Lin

rasterization-worker hit OOM exception
https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/doc/f651ec50-d841-11eb-8c96-47ea7c58f93d/kubernetes-cluster-fbkobdfj9vd9-2025.09.23/fluentd?id=MDc3MjYwODItYWZjNC00ZDA0LWJkMTQtZjhmZGI0MTExOTU0&_g=h@44136fa

Currently the pod has a 4GiB limit

See if this surge is valid, e.g. is there a type of PDF that requires large memory. Possibly pages with large embedded images.

Then, consider increase memory limit to alleviate memory pressure

---

## WI 615534 - description - 09/22/2025 - Joey Lin

https://v-dev-tfs/DefaultCollection/Server%20Tools/_wiki/wikis/Server-Tools.wiki/70817/PDF-Regression-test-Linux-

Update RWS to use PDFArgbRenderingSurface in the PDF4NET library and run the full regression test.

This is to address Bug 614593: STR rasterization fails for this specific pdf, after O2 Solutions replied that PDFArgbRenderingSurface works instead of PDFRgbRenderingSurface that we were using.

---

## WI 615534 - comment - 09/29/2025 - Joey Lin

Create test enhancement item here: Product Backlog Item 616913: Make it easier to run pdf regression test on O2S PDF4NET changes

---

## WI 614593 - description - 09/17/2025 - Joey Lin

Repro:

With the Flag PA.Forms.UseRasterizationService ON
Use the attached PDF with generated Laserfiche pages ON
Actual:
STR Fails
Expected:
STR Pass
Variations/Related:

---

## WI 613234 - description - 09/09/2025 - Joey Lin

Repro:

- Create process with [msg-start]-usertask-end
- Create form used in both
- make user task readonly
- add datetime field > Advanced, set min date = Today
- Start process
- Before user task, go to monitoring and update the datetime value to be before today
- go to user task, try to submit

Actual:

Unable to submit with error

Expected:
submission works
Variations/Related:

---

## WI 613234 - description - 09/10/2025 - Joey Lin

Repro:

- Create process with [msg-start]-usertask-end
- Create form used in both
- make user task readonly
- add datetime or a time field > Advanced, set min date = Today, or if time field, set min time
- Start process
- Before user task, go to monitoring and update the datetime value to be before today
- go to user task, try to submit

Actual:

Unable to submit with error

Expected:
submission works
Variations/Related:

---

## WI 610639 - description - 08/28/2025 - Joey Lin

Do an exploratory test on rasterization for pdfs with passwords, e.g. user and owner passwords. Compare its behavior, along with error messages, etc. to the when rasterization service is turned OFF. Ensure there are no regression issues.

Passing tests from this story will turn on rasterization service for GA in EU and US.

---

## WI 610639 - comment - 09/03/2025 - Joey Lin

UseRasterizationService = ON
No EncryptionUserPwd = "", OwnerPwd = ""UserPwd = "user", OwnerPwd = ""UserPwd = "", OwnerPwd = "owner"UserPwd = "user", OwnerPwd = "owner"
Extraction AllowedCompletedCompletedCompletedCompletedRasterizationPasswordNeeded
Extraction Not Allowedn/aCompletedCompletedCompletedRasterizationPasswordNeeded

UseRasterizationService = OFF
No EncryptionUserPwd = "", OwnerPwd = ""UserPwd = "user", OwnerPwd = ""UserPwd = "", OwnerPwd = "owner"UserPwd = "user", OwnerPwd = "owner"
Extraction AllowedCompletedCompletedCompletedCompletedThe following image may be corrupted
Extraction Not Allowedn/aCompletedCompletedCompletedThe following image may be corrupted

---

## WI 610164 - description - 08/26/2025 - Joey Lin

Currently errors are thrown as raw exception strings from svc-app-pdf-rasterization.

This is hard for the clients to deal with error handling, such as bpm.

Improve this error messaging by introducing error codes so clients can better deal with them.

Investigate all types of errors that can be thrown by the app, some include corrupt pdf, network issues, other transient issues. And classify them into different error codes.

Maybe 1000x --- user input issues,  4000x --- system issues.

---

## WI 610164 - comment - 09/16/2025 - Joey Lin

https://v-k8s-1.laserfiche.com/elasticsearch/development/us-west-2/_plugin/kibana/app/kibana#/doc/51150690-0e8f-11f0-a79c-4de73b8734e8/vpc-06db0e119d2b45b42-windows_file_logs-2025.09.16/doc?id=YWY5YmM5MjItZWUyMS00NmUwLTk4ODMtYTVlZWU1YzMzMDgx&_g=h@b4a10f5

@Leon Cai there are some assembly binding issues

[ERR+17ms(41)]Routing Engine DoWork Exception
COULD NOT LOAD TYPE 'LASERFICHE.SITES.SVCAPPPDFRASTERIZATION.PDFRASTERIZATIONERRORCODE' FROM ASSEMBLY 'LASERFICHE.SITES.SVCAPPPDFRASTERIZATION.PUBLICCONTRACTS, VERSION=1.0.0.0, CULTURE=NEUTRAL, PUBLICKEYTOKEN=607DD73EE2BD1C00'.
	-----TRACES----
	System.TypeLoadException: Could not load type 'Laserfiche.Sites.SvcAppPdfRasterization.PdfRasterizationErrorCode' from assembly 'Laserfiche.Sites.SvcAppPdfRasterization.PublicContracts, Version=1.0.0.0, Culture=neutral, PublicKeyToken=607dd73ee2bd1c00'.
	   at Laserfiche.Spark.Services.RA.RasterizationService.<AskJobStatus>d__11.MoveNext()
	   at System.Runtime.CompilerServices.AsyncTaskMethodBuilder`1.Start[TStateMachine](TStateMachine& stateMachine)
	   at Laserfiche.Spark.Services.RA.RasterizationService.AskJobStatus(String token, OperationLogger logger)
	   at Laserfiche.RoutingEngine.Manager.Services.Forms.FormsRoutingEngineSaveToLaserficheService.<CheckAndUpdateRasterizationStatus>d__56.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at Laserfiche.RoutingEngine.Manager.Services.Forms.FormsRoutingEngineSaveToLaserficheService.<ResumeRasterization>d__58.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at Laserfiche.Spark.Processors.RoutingEngineProcessorBase.<ProcessServiceMessage>d__23.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at System.Runtime.CompilerServices.ConfiguredTaskAwaitable`1.ConfiguredTaskAwaiter.GetResult()
	   at Laserfiche.Spark.Processors.RoutingEngineProcessorBase.<ProcessRoutingEngineInstanceMessage>d__11.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at Laserfiche.Spark.Processors.RoutingEngineProcessorBase.<ProcessRoutingEngineInstanceMessage>d__11.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at Laserfiche.Spark.Processors.RoutingEngineProcessorBase.<ProcessInstanceMessage>d__10`1.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at Laserfiche.Spark.Processors.RoutingEngineProcessorBase.<DoWork>d__6.MoveNext()
	------
	-----DATA-----
		OperationId = b35a012d557a4e47830a7e43c6273564

---

## WI 609564 - description - 08/21/2025 - Joey Lin

Repro:
- use the attached pdf in an STR with rasterization on
- the pdf has security but empty password, and is able to be opened in adobe reader

Actual:
- get password invalid error

Expected:
- should work for pdf with empty passwords

Variations/Related:

---

## WI 609564 - comment - 08/21/2025 - Joey Lin

Looks like a bug in O2S.Components.PDF4NET.NET, I tested v13.2.0 and seems they've addressed the bug.

We can update it here:
https://v-dev-tfs/DefaultCollection/LF%20Libraries/_git/Laserfiche.PDFService.NetStandard?path=/Laserfiche.PDFService.NET.Core/Laserfiche.PDFService.NET.Core.csproj

---

## WI 608508 - description - 08/14/2025 - Joey Lin

Repro:

- have a simple Formula rule that runs a split(' ')
- have a single line trigger field
- have a collection with 2 readonly single lines
- setup 2 rules as follows:
- When trigger -> fill collection/single_line
- When collection/single_line -> fill collection/single_lin2

 - Fill trigger with "a b" this creates 2 rows, and triggers 2 more lookup
- this fills correctly a a, b b
 - Fill trigger with "a"
- this fills correctly a a
 - Fill trigger with "a b"
- only "a a b" is filled, row 2 is missing value

Actual:

Expected:

Variations/Related:

---

## WI 608006 - description - 08/12/2025 - Joey Lin

This is to support story User Story 606472: Add Retry for image download

When pods shutdown while processing a http download request, the request can unexpectedly fail. This is likely due to the shutdown handler closing the puppeteer browser instance right as SIGTERM is received.

Should not close the browser instance right away and give the full terminationGracePeriodSeconds (30s) for the pod to finish the current http download request.

This should reduce the number of failures.

---

## WI 607426 - description - 08/08/2025 - Joey Lin

Issue 607409: 404 error when viewing repository reports from the Home application - CA and EU regions only

update links here:
https://v-dev-tfs/DefaultCollection/WF/_search?action=contents&text=auditanalytics&type=code&lp=code-Project&filters=ProjectFilters%7BWF%7DRepositoryFilters%7Bsite-app-reports%7D&pageSize=25&result=DefaultCollection/WF/site-app-reports/GBdevelop//src/Controllers/ViewControllerHelpers/RepositoryView.cs

to the app subdomain from auditanalytics.

---

## WI 607426 - description - 08/12/2025 - Joey Lin

Issue 607409: 404 error when viewing repository reports from the Home application - CA and EU regions only

update links here:
https://v-dev-tfs/DefaultCollection/WF/_search?action=contents&text=auditanalytics&type=code&lp=code-Project&filters=ProjectFilters%7BWF%7DRepositoryFilters%7Bsite-app-reports%7D&pageSize=25&result=DefaultCollection/WF/site-app-reports/GBdevelop//src/Controllers/ViewControllerHelpers/RepositoryView.cs

AuditDashboard Backend is also updated here: Pull Request 150148: Updated AuditChartWidgetRequestHandler.cs subdomain from auditanalytics to app. Although, this is currently an incomplete feature, not able to test it.

to the app subdomain from auditanalytics.

---

## WI 606652 - description - 08/05/2025 - Joey Lin

https://v-k8s-1.laserfiche.com/elasticsearch/production/ca-central-1/_plugin/kibana/app/kibana#/discover?_g=(refreshInterval:(pause:!t,value:0),time:(from:now-7d,mode:quick,to:now))&_a=(columns:!(message),filters:!(('$state':(store:appState),meta:(alias:!n,disabled:!f,index:'6e63f550-d51b-11eb-83ab-2531a6eb0dfc',key:kubernetes.container_name,negate:!f,params:(query:svc-app-pdf-rasterization-worker,type:phrase),type:phrase,value:svc-app-pdf-rasterization-worker),query:(match:(kubernetes.container_name:(query:svc-app-pdf-rasterization-worker,type:phrase))))),index:'6e63f550-d51b-11eb-83ab-2531a6eb0dfc',interval:auto,query:(language:lucene,query:%227633e047-de55-449e-9d1c-c44c25bfcdbc%22),sort:!('@timestamp',asc))

There was a failure in Prod CA, log above.

[INFO+170ms(33)]Download from s3 success
[INFO+279ms(40)][PDF rasterization] Job 7633e047-de55-449e-9d1c-c44c25bfcdbc (OperationID 233e47212be341f08de1a7b28851d1f0) [b32f013e-5ad1-4f5a-8b3d-7f9bb619c9a7] finished with result Failed. Current Run Time taken: 279ms. Total Elapsed Time taken: 361ms MilliSpeedOp.

This is not completing the file opening code correctly.

[INFO+280ms(80)]Files and streams opened.

---

## WI 606306 - description - 08/01/2025 - Joey Lin

Repro:

- create a collection/table and setup a lookup rule to fill it
- Ensure the setting 'Append rows to the rows populated by a data source or variable' is selected under Adanced

- Keep clicking on Execute rule (e.g. with Auto fill on).

Actual:
- The execute rule will get slower and slower because the payload repeatableReadOnlySetting gets larger and larger

Expected:

Variations/Related:

---

## WI 606306 - description - 08/07/2025 - Joey Lin

Repro:

- create a collection/table and setup a lookup rule to fill it
- Ensure the setting 'Append rows to the rows populated by a data source or variable' is selected under Adanced
- Ensure lookup is filling a field inside collection that is NOT-readonly

- Keep clicking on Execute rule (e.g. with Auto fill on).

Actual:
- The execute rule will get slower and slower because the payload repeatableReadOnlySetting gets larger and larger

Expected:

Variations/Related:

---

## WI 604220 - description - 07/22/2025 - Joey Lin

Repro:

Create bp with msgstart-usertask-end, user task assigned to

in msg start enable "Automatically load the next user task"

Start bp, and wait for user task to load. The save draft button flash before disappearing
Actual:

Expected:

Variations/Related:

---

## WI 603209 - description - 07/18/2025 - Joey Lin

Repro:

Use an old ipad /simulator running iOS <= 16 and open a form
Actual:
Form does not load
Expected:

Variations/Related:

---

## WI 601436 - description - 07/10/2025 - Joey Lin

remove retired CloudFormation resources from the CI repository

stacks like
Resources52-Brnodesvc
Resources54-FormsSaveToRepository
Resources55-Renodesvc.yaml

Resources71-SiteAppTasks
Resources73-SiteAppForms

---

## WI 601436 - description - 07/24/2025 - Joey Lin

remove retired CloudFormation resources from the CI repository

stacks like

Resources54-FormsSaveToRepository
Resources55-Renodesvc.yaml

Resources71-SiteAppTasks
Resources73-SiteAppForms

---

## WI 601436 - description - 07/24/2025 - Joey Lin

remove retired CloudFormation resources from the CI repository

stacks like
Resources52-Brnodesvc
Resources54-FormsSaveToRepository
Resources55-Renodesvc.yaml

Resources67-SiteAppBpm
Resources71-SiteAppTasks
Resources72-SiteAppReports
Resources73-SiteAppForms
Resources113-SiteAppFormsMonitoring

---

## WI 600244 - description - 07/03/2025 - Joey Lin

Repro:

run npm install and npm run build for site-app-tasks on local

runs into this error:

Error: error:0308010C:digital envelope routines::unsupported

    at new Hash (node:internal/crypto/hash:79:19)

    at Object.createHash (node:crypto:139:10)

    at module.exports (C:\code\site-app-tasks\src\node_modules\webpack\lib\util\createHash.js:135:53)

    at NormalModule._initBuildHash (C:\code\site-app-tasks\src\node_modules\webpack\lib\NormalModule.js:417:16)

    at handleParseError (C:\code\site-app-tasks\src\node_modules\webpack\lib\NormalModule.js:471:10)

    at C:\code\site-app-tasks\src\node_modules\webpack\lib\NormalModule.js:503:5

    at C:\code\site-app-tasks\src\node_modules\webpack\lib\NormalModule.js:358:12

    at C:\code\site-app-tasks\src\node_modules\loader-runner\lib\LoaderRunner.js:373:3

    at iterateNormalLoaders (C:\code\site-app-tasks\src\node_modules\loader-runner\lib\LoaderRunner.js:214:10)

    at iterateNormalLoaders (C:\code\site-app-tasks\src\node_modules\loader-runner\lib\LoaderRunner.js:221:10)

    at C:\code\site-app-tasks\src\node_modules\loader-runner\lib\LoaderRunner.js:236:3

    at context.callback (C:\code\site-app-tasks\src\node_modules\loader-runner\lib\LoaderRunner.js:111:13)

    at C:\code\site-app-tasks\src\node_modules\babel-loader\lib\index.js:59:71 {

  opensslErrorStack: [

    'error:03000086:digital envelope routines::initialization error',

    'error:0308010C:digital envelope routines::unsupported'

  ],

  library: 'digital envelope routines',

  reason: 'unsupported',

  code: 'ERR_OSSL_EVP_UNSUPPORTED'

}

Actual:

Expected:

Variations/Related:

---

## WI 599131 - description - 06/27/2025 - Joey Lin

Repro:

Set a user to the system or account default timezone in ACS,
e.g. in CA region, set user's timezone to Account Default [EST]

Actual:
Tasks page timezones are fall back to PST
Expected:
Use the cookie value Timezone which matches the configured System or Account Default

Variations/Related:

---

## WI 599131 - description - 07/03/2025 - Joey Lin

Repro:

Set a user to the system or account default timezone in ACS which is different than the default timezone,
e.g. in CA region, set user's timezone to Account Default [EST]

Actual:
Tasks page timezones are fall back to PST
Expected:
Use the cookie value Timezone which matches the configured System or Account Default

Variations/Related:

---

## WI 599131 - description - 07/03/2025 - Joey Lin

Repro:

Set a user to the system or account default timezone in ACS which is different than the fallback pst timezone,
e.g. in CA region, set user's timezone to Account Default [EST]

Actual:
Tasks page timezones are fall back to PST
Expected:
Use the cookie value Timezone which matches the configured System or Account Default

Variations/Related:

---

## WI 597812 - description - 06/20/2025 - Joey Lin

From Issue 597684: [AT] BPMAppFrontendServer CA - CPU alert PA General

From the dump file, inputData on calculate formula exceed 1000.
Investigate if this situation causes maxed CPU cases

---

## WI 597812 - comment - 09/22/2025 - Joey Lin

@Catherine Wang @Sherry Tan the 500 CalculateFormula calls is not a good indicator for high CPU since they're fast, and likely due to invalid formulas.

What's more concerning is the large amounts of very slow calls that's taking over the CPU at that time, even calls that's not CalculateFormulas. Without a mini-dump, it'd be hard to pinpoint who caused this surge.

https://v-k8s-1.laserfiche.com/elasticsearch/production/ca-central-1/_plugin/kibana/app/kibana#/discover?_g=(refreshInterval:(pause:!t,value:0),time:(from:'2025-09-15T17:54:42.843Z',mode:absolute,to:'2025-09-15T19:23:59.085Z'))&_a=(columns:!(message),filters:!(('$state':(store:appState),meta:(alias:!n,disabled:!f,index:'37078190-0f04-11f0-98bd-3b16b86f61a2',key:Role,negate:!f,params:(query:BpmFrontendServer,type:phrase),type:phrase,value:BpmFrontendServer),query:(match:(Role:(query:BpmFrontendServer,type:phrase))))),index:'37078190-0f04-11f0-98bd-3b16b86f61a2',interval:auto,query:(language:lucene,query:'(%22VeryHighSecondOp%22+OR+%22HighSecondOp%22)+AND+NOT+%22CalculateFormula+%22'),sort:!('@timestamp',asc))

---

## WI 597507 - description - 06/18/2025 - Joey Lin

From Issue 597483: BP instances show start date/time column different values than when opening the instances under history "start" step. th207029809, r-3870a6c8

Set user time to different than local browser time zone, e.g. UTC, when I'm in EST

Start a new bp instances.
Enable date fields in the monitoring page

They are not using User timezones. Opening each instances show correct timezones.

---

## WI 596992 - description - 06/17/2025 - Joey Lin

NOT READY YET. This story will be ready once Chris finalized the approved list below.

For security compliance, update container base and intermediate images used in Dockerfile to an approved version.

The list is here:
https://app.laserfiche.com/laserfiche/DocView.aspx?repo=r-795d76da&customerId=343353773&docid=367161#?openmode=OFFICE

Containers list:
site-app-bpm
site-app-bp-designer

site-app-forms

site-app-forms-monitoring

site-app-home

site-app-reports

site-app-tasks

site-app-documents

svc-app-renode

svc-app-direct-approval

svc-app-pdf-rasterization

---

## WI 595035 - description - 06/04/2025 - Joey Lin

Test process is attached.

Form contains values with special characters (apostrophe and ampersand)

These values are used in a STR task as tokens to create the path for storage.

A second STR task uses the token "{/dataset/_saved_form_folder_path}" to store to the same path

Observed:
The task using  "{/dataset/_saved_form_folder_path}" token does not recognize the apostrophe or the ampersand and ends up creating a new folder without the special characters.

Expected:
Using the "{/dataset/_saved_form_folder_path}" token should include the same path with the special characters

---


