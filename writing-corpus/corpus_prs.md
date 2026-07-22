## PR 163852 - pdf4net-regression-test - 2026-02-20
### Title: allow test filter for single test debugging
allow test filter for single test debugging
update readme for better instructions on adding new test file

---

## PR 163863 - Laserfiche.PDFService.NetStandard - 2026-02-20
### Title: update pdf4net to v16
update pdf4net to v16
Version 16.1.1.5 for O2S.Components.PDF4NET.Render.NET has been tested already.
No need to run regression test, marking step successful.

Regression test for v16 already passed awhile back. But will re-run again tonight as well. 

https://v-dev-tfs.laserfiche.com/DefaultCollection/WF/_build/results?buildId=2057222&view=logs&j=98292372-9688-5a3c-bdbe-a39c10cd532b&t=9ba5b10b-b50a-5e80-a8b7-bf17e8bab40c

---

## PR 163877 - Laserfiche.PDFService.NetStandard - 2026-02-20
### Title: update nuget publish script to use https sources
update nuget publish script to use https sources
update nuget package to use v16 of pdf4net

---

## PR 164571 - pdf4net-regression-test - 2026-02-27
### Title: pdf4net regression test pipeline enhancements
allow running single test in the pipeline instead of all
fix bug: don't modify expected image name when test fails
support testing specific version of the library at pipeline run

---

## PR 164734 - ai-shared - 2026-03-02
### Title: update sli drop
update sli drop skill with ACS deployment known issue

---

## PR 165798 - pdf4net-regression-test - 2026-03-12
### Title: default empty for testcase filters for all cases
default empty for testcase filters for all cases
SO UI can leave empty

---

## PR 165800 - pdf4net-regression-test - 2026-03-12
### Title: use empty as default
use empty as default

Cherry-picked from commit `06322088`.

---

## PR 166182 - Laserfiche.PDFService.NetStandard - 2026-03-17
### Title: add tests to ignore xobject error
- add tests to ignore xobject error
- setup test project

---

## PR 168003 - bpm - 2026-04-07
### Title: add UI test for see more button
- add UI test for see more button
- init copilot instructions for ui test project

---

## PR 168560 - svc-app-renode - 2026-04-14
### Title: Merge WF changes Cloud repo
Merge WF/develop changes to this Cloud repo

---

## PR 168690 - svc-app-renode - 2026-04-15
### Title: Migrate new pipelines 
build & deploy pass in dev ca + test ca
https://v-dev-tfs/DefaultCollection/Cloud/_build/results?buildId=2122859&view=results

smoke test: 
https://v-dev-tfs/DefaultCollection/Cloud/_build/results?buildId=2122295&view=results

veracode: 
https://v-dev-tfs/DefaultCollection/Cloud/_build/results?buildId=2122811&view=results

build+test for prs: 
https://v-dev-tfs/DefaultCollection/Cloud/_build/results?buildId=2125187&view=logs&j=70f23758-ad7d-57fc-863a-b626cd8e6918&t=544c8ac2-66f6-5763-010b-c1ac878ba837

---

## PR 168763 - bpm - 2026-04-16
### Title: read recaptcha keys from vpc=all
read recaptcha keys from vpc=all since it's the same key for all envs

Accompanied by 'Save Password' runs:

https://v-dev-tfs/DefaultCollection/Cloud%20Infrastructure/_releaseProgress?releaseId=81424&_a=release-pipeline-progress

https://v-dev-tfs/DefaultCollection/Cloud%20Infrastructure/_releaseProgress?releaseId=81425&_a=release-pipeline-progress

Verified in dev us using new key: 6LcWPLksAAAAAN6kcrymB2acPoLi0n8PRC556YeS

![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/454803aa-26ff-4fae-afac-14f97e0370ab/pullRequests/168763/attachments/image.png)

---

## PR 168921 - disaster-recovery - 2026-04-20
### Title: Updated 40_pa_apps.yaml with svc-app-renode
Updated 40_pa_apps.yaml with svc-app-renode build pipeline

---

## PR 169038 - bpm - 2026-04-21
### Title: Update pollyretry to optimistic, Update connectionLimit to 10
- Update PollyRetry to optimistic, this avoids an additional background thread. Optimistic requires cancellation token to pass all the way down, during timeouts, the requests is canceled and can recycle the Connection
- Update DefaultConnectionLimit to 10. This is the limit for concurrent requests to a single address (e.g. pa-platform). 10 is the default for IIS hosted web apps. Our OWIN defaults to 2. Increasing to 10 should give more buffer room to handle the retries. 
- Dispose HttpResponseMessage to avoid connection hogging so doesn't need to wait for GC

---

## PR 169132 - svc-app-renode - 2026-04-22
### Title: Sync WF/production to Cloud/Production
Sync WF/production to Cloud/Production
Merge develop to production for 2026.4.4

---

## PR 169155 - bpm - 2026-04-22
### Title: read recaptcha keys from vpc=all
read recaptcha keys from vpc=all since it's the same key for all envs

Accompanied by 'Save Password' runs:

https://v-dev-tfs/DefaultCollection/Cloud%20Infrastructure/_releaseProgress?releaseId=81424&_a=release-pipeline-progress

https://v-dev-tfs/DefaultCollection/Cloud%20Infrastructure/_releaseProgress?releaseId=81425&_a=release-pipeline-progress

Verified in dev us using new key: 6LcWPLksAAAAAN6kcrymB2acPoLi0n8PRC556YeS

![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/454803aa-26ff-4fae-afac-14f97e0370ab/pullRequests/168763/attachments/image.png) 

Cherry picked from !168763

---

## PR 169271 - bpm - 2026-04-23
### Title: dispose HttpResponseMessage after each retry attempts
dispose HttpResponseMessage after each retry attempts.
Otherwise a connection is tied up and unable to be used within this internal retry cycle, which is ~31s for 6x retries. 

Polly v7 Policy syntax does not auto dispose the HttpResponseMessage. This won't be needed after we upgrade to Polly v8 and use Strategies. 

Before: 
Laserfiche.BPMAPI.exe Warning: 0 : [HttpRetryMessageHandler] Retry 5/5 Host=localhost:80 Status=500 Connection= KeepAlive=True ConnectionLimit=10 CurrentConnections=**10** NextDelay=16s
After:
Laserfiche.BPMAPI.exe Warning: 0 : [HttpRetryMessageHandler] Retry 5/5 Host=localhost:80 Status=500 Connection= KeepAlive=True ConnectionLimit=10 CurrentConnections=**1** NextDelay=16s

Also verified on local, ExecuteRule will get very slow when ConnectionLimit is hit

---

## PR 169526 - site-app-tasks - 2026-04-27
### Title: upgrade moment-timezone to 0.6.2; move moment install to package.json
- upgrade moment-timezone to 0.6.2
- move moment install to package.json
- remove hardcoded moment libraries 

Mexico timezone issue fixed in newer moment-timezone package

---

## PR 169529 - site-app-tasks - 2026-04-27
### Title: upgrade moment-timezone to 0.6.2; move moment install to package.json
upgrade moment-timezone to 0.6.2
move moment install to package.json
remove hardcoded moment libraries
Mexico timezone issue fixed in newer moment-timezone package

---

## PR 169604 - Laserfiche.PDFService.NetStandard - 2026-04-28
### Title: add null check for quadpoints in AnnotationConverter
- add null check for quadpoints in AnnotationConverter
- setup unit test project for Laserfiche.PDFService.NET.Consumer

Verified on local rasterization/annoation import pass for the troublesome pdf
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/ed8db710-80e8-4cfb-8434-986aface21f0/pullRequests/169604/attachments/image.png) 
#656054

---

## PR 169862 - forms-layout - 2026-04-30
### Title: fix [Modern Forms] Table cells are missing field labels on small screens (≤60...
fix [Modern Forms] Table cells are missing field labels on small screens (≤600px)
- override the sr-only properties which cause it to not display 
- add mobile environment tests
- ensure axe issue do not regress
![faa8ad7b-2839-4612-a039-05032caf5374.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/c3c63e69-ef6e-490c-9c4f-826a63d1fe95/pullRequests/169862/attachments/faa8ad7b-2839-4612-a039-05032caf5374.png) 
#657457

---

## PR 169889 - site-app-bp-designer - 2026-04-30
### Title: remove unused signalr package
- remove unused signalr package
- confirmed bell notification still works, done via site-app-bpm

---

## PR 169976 - forms-layout - 2026-05-01
### Title: bump version + patch
bump version + patch

Previous version forms-layout@2.32.75 deleted, now gitversion wont publish
Do a simple bump to get pipelin working

---

## PR 169982 - forms-layout - 2026-05-01
### Title: update to node 24
- build + publish: https://v-dev-tfs/DefaultCollection/Cloud/_build/results?buildId=2140715&view=logs&j=275f1d19-1bd8-5591-b06b-07d489ea915a&t=a3ae15c5-5010-54a4-a139-b84fe08b9ca3
- build and lint: https://v-dev-tfs/DefaultCollection/Cloud/_build/results?buildId=2140718&view=logs&j=fd490c07-0b22-5182-fac9-6d67fe1e939b
- veracode: https://v-dev-tfs/DefaultCollection/Cloud/_build/results?buildId=2140724&view=results

---

## PR 170022 - forms-layout - 2026-05-01
### Title: use node 24 in publish step
use node 24 in publish step

reapply commit, overwritten by https://v-dev-tfs/DefaultCollection/Cloud/_git/forms-layout/pullrequest/169998

---

## PR 170042 - site-app-bp-designer - 2026-05-02
### Title: sync package.json to fix npm ci
sync package.json to fix npm ci

https://v-dev-tfs/DefaultCollection/Cloud/_build/results?buildId=2141125&view=results

---

## PR 170442 - site-app-forms - 2026-05-07
### Title: guard against signalr front-end redirect
After submission, for 'fast redirect' options, e.g. ones without show submitted form, the formssubmission API also sends back an signalr 'frontendredirect'. There is a timing issue where when signalr returns first before the formssubmission api returns fully, and we redirect away, the call gets canceled. In this case, ignore the error.

---

## PR 170648 - site-app-forms - 2026-05-11
### Title: upload /wwwroot/styles files to cdn
upload /wwwroot/styles files to cdn as it's still used in classic forms. 

Confirm datepicker icons now show:
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/937064e0-f618-4073-904d-deb9a336dcbf/pullRequests/170648/attachments/image.png)

---

## PR 170699 - azure_devops_pipelines - 2026-05-11
### Title: Npm Audit pipeline  template
- Runs npm audit for an input path
- Runs optional npm audit fix
- Creates optional PR for audit fix

Sample: https://v-dev-tfs/DefaultCollection/Cloud/_git/svc-app-renode/pullrequest/170685

---

## PR 170785 - svc-app-renode - 2026-05-12
### Title: setup npm audit pipeline
- setup npm audit pipeline
- autorun to apply 'npm audit fix'
- run npm audit daily at 7am mon-fri

---

## PR 170807 - bpm - 2026-05-12
### Title: Add test for classic form icons
Add test for classic form icons
- pass in dev
- fail in cloud test (expected without fix)

---

## PR 171251 - bpm - 2026-05-16
### Title: Bug: STR 'save' by this process step does not show existing variable values for user task completed by direct approval
- Make sure submission id is passed correctly for Direct Approval
- Previously it was using task.id which was resumeid and so it couldn't find the correct submission during STR step 
- Add webapi auto test.

---

## PR 171436 - forms-layout - 2026-05-19
### Title: dont apply page break on last page
dont apply page break on last page which creates extra empty page in print
#660827

![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/c3c63e69-ef6e-490c-9c4f-826a63d1fe95/pullRequests/171436/attachments/image.png)

---

## PR 171897 - bpm - 2026-05-25
### Title: Bug: STR 'save' by this process step does not show existing variable values for user task completed by direct approval
- Make sure submission id is passed correctly for Direct Approval
- Previously it was using task.id which was resumeid and so it couldn't find the correct submission during STR step 
- Add webapi auto test. 

Cherry picked from !171251

---

## PR 171904 - svc-app-renode - 2026-05-25
### Title: Update to use internal npm registry
- Update to use internal npm registry
- smoke test pass in dev ca https://v-dev-tfs/DefaultCollection/Cloud/_build/results?buildId=2163036&view=results
- fix updated variable name PUPPETEER_SKIP_DOWNLOAD

---

## PR 171978 - svc-app-renode - 2026-05-26
### Title: update uuid to v17
update uuid to v17 to fix npm audit

---

## PR 172009 - site-app-tasks - 2026-05-26
### Title: update right collapse button background to transparent
update right collapse button background to transparent
#667880
Before: 
![image (2).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/e708882b-d367-4606-ac1d-49b9a058cb84/pullRequests/172009/attachments/image%20%282%29.png) 
After:
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/e708882b-d367-4606-ac1d-49b9a058cb84/pullRequests/172009/attachments/image.png)

---

## PR 172162 - bpm - 2026-05-27
### Title: deprecate the need to remove exif data in print
- deprecate the need to remove exif data in print
- renode now is more performant than before

Test results with 91 mobile images with exif, I don't see significant performance difference. We can also consider increasing renode timeout of 120s

**Dev EU with this change (KEEP exif):** 
https://v-k8s-1.laserfiche.com/elasticsearch/development/eu-west-1/_dashboards/app/discover#/doc/8309af60-dfa5-11eb-9c47-fdb5c1e002e6/kubernetes-cluster-jm0yk9snfbgj-2026.05.27?id=ZmE2NDc0OTQtMjQwYS00NDNjLWI1MzEtZWQyYTdjNzUwNDEz
[1m 15s 937ms] Form load took 1m 15s 816ms - HighSecondOpFormLoad
[1m 26s 708ms] Form first print took 10s 769ms - MidSecondOpPrint

**Dev US without this change (REMOVE exif):**
https://v-k8s-1.laserfiche.com/elasticsearch/development/us-west-2/_dashboards/app/discover#/doc/1f307dc0-0cce-11eb-9593-f3cf4fed61dc/kubernetes-cluster-muls31lzojfx-2026.05.27?id=MDg2YTMwZGMtMDE2My00YTljLTk4ZjQtNWQ1NmU4NTFkZTlj
[1m 7s 927ms] Form load took 1m 7s 808ms - HighSecondOpFormLoad
[1m 23s 89ms] Form first print took 15s 161ms - MidSecondOpPrint

---

## PR 172579 - lib-fileset-runtime-js - 2026-06-03
### Title: migrate dialogs to mdc 
- remove legacy mdc dialogs
- add basic vs code run setting
- add basic mocks for local folder import dialog
- fill in unit tests for dialogs
- add new integration unit test from fileset-shell to ensure all dialogs open correctly

All dialogs open as expected
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/571f22ae-0cbd-4e64-975d-5f88baf7b413/pullRequests/172579/attachments/image.png) 
![image (2).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/571f22ae-0cbd-4e64-975d-5f88baf7b413/pullRequests/172579/attachments/image%20%282%29.png)

---

## PR 172603 - forms-layout - 2026-06-03
### Title: update label for to first item in checkbox and radio
- update label for to first item in checkbox and radio
- future fix should be fieldset, but that will cause breaking changes to custom CSS defer to later
- clicking on label will click the first item
#653017

---

## PR 172705 - forms-layout - 2026-06-04
### Title: add null check for orphaned formulas
add null check for orphaned formulas
remove unsupported always-auth from npmrc 

#657454

---

## PR 172708 - site-app-forms - 2026-06-04
### Title: add null check for populatedField in orphaned formula
add null check for populatedField in orphaned formula
#657454

---

## PR 172713 - site-app-forms - 2026-06-04
### Title: add unit test for orphaned formulas
add unit test for orphaned formulas

Cherry-picked from commit `17d602e3`.

---

## PR 172867 - site-app-bpm - 2026-06-08
### Title: Update forms-layout to 2.32.81
Update forms-layout to 2.32.81: - update label for to first item in checkbox and radio

Cherry picked from !172678

---

## PR 172868 - site-app-bpm - 2026-06-08
### Title: Update forms-layout to 2.32.82
Update forms-layout to 2.32.82: add null check for orphaned formulas

Cherry picked from !172711

---

## PR 172881 - bpm - 2026-06-08
### Title: retry serviceunavailable when talking to rasterization service
retry serviceunavailable when talking to rasterization service
-  Retry on System.Exception with ServiceUnavailable string
#672414

---

## PR 172972 - svc-app-pdf-rasterization - 2026-06-09
### Title: tweak svc-app-pdf-rasterization pod scaling up and down behavior
tweak svc-app-pdf-rasterization pod scaling up and down behavior

svc-app-pdf-rasterization scales up too aggressively on 50% CPU, which gets tripped by only 50m. Overall cpu usage is low.  
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/0ee370ad-991d-49af-8020-579859b7a986/pullRequests/172972/attachments/image.png) 

On termination the process stops accepting connections almost
  immediately, before the Istio sidecar / load balancer has deregistered the pod's endpoint. Clients routed to the dying pod get 503s:

Jun 9, 2026 @ 16:02:08.797	QED exit
	Jun 9, 2026 @ 16:02:08.506	LifecycleNotifier OnStopped
	Jun 9, 2026 @ 16:02:08.501	All shutdown guards satisfied after 0s, proceeding with shutdown
	Jun 9, 2026 @ 16:02:08.500	LifecycleNotifier OnStopping

  ▎ upstream connect error or disconnect/reset before headers... reset reason: remote connection failure, transport failure reason: delayed connect error: Connection refused.

  The existing LifecycleNotifier graceful-drain only protects the worker pod — its single shutdown guard checks for in-flight SQS jobs (jobTaken == 0 && finishedJobs.Count == 0), which is always true on the
  HTTP pod since it never consumes the queue (ConsumeUntilEmpty() is gated on LONGOP_MODE=worker). So the HTTP pod exits the drain loop at t=0 and shuts down with no delay.

  Change

  Added a preStop hook with a 15s sleep to the HTTP/non-worker container (cloud/helm/templates/deployment.yaml):

---

## PR 173182 - site-app-forms - 2026-06-11
### Title: catch sessiontStorage.setItem exception to allow proper fallback
catch sessiontStorage.setItem exception to allow proper fallback

Wrap the sessionStorage.setItem in the fast-redirect branch of redirectThankyouPage in a try/catch (wwwroot/js/app/signalr.config.js). On quota failure we skip the client-side cache and still redirect to
  ?pvid=&iid=; the ThankYou page's existing fallback (ThankYou.cshtml) then fetches the message from the server via /ThankYouMsg — the same render path used when "Show submitted form" is enabled. No server
  change required.

  Added Jest unit test wwwroot/__tests__/signalrConfig.spec.ts:
  - caches the message and redirects when storage has room;
  - still redirects (no throw) when setItem throws QuotaExceededError — regression guard for this bug.

#660507

---

## PR 173310 - bpm - 2026-06-12
### Title: add log for ShouldRasterizePDF check using different contentlength
add log for different Contentlength to see why some attachment files are still being rasterized locally in bpmserver. 

Log the 2 sources of file size to see if there are discrepancies. Likely yes for the few production cases. 

Likely what happened is the real file size is > the 25mb limit, so shouldrasterize = false in the first check. Then later it reads the attachment.Item1.ContentLength which might be 0 or < the 25mb limit causing a fallback to local rasterization.

Those are supposed to be the same, but not sure how it can be different. If confirmed in production, we can adjust code to both use one source of truth, i.e. the real file size.

---

## PR 173412 - bpm - 2026-06-15
### Title: retry serviceunavailable when talking to rasterization service
retry serviceunavailable when talking to rasterization service
-  Retry on System.Exception with ServiceUnavailable string
#672414

Cherry picked from !172881

---

## PR 173424 - site-app-forms - 2026-06-15
### Title: remove legacy mdc references
- remove unneeded ~/css/indigo-pink.css. Previous commit was for the feedback module. Confirmed works without this outdated/hardcoded css. 
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/937064e0-f618-4073-904d-deb9a336dcbf/pullRequests/173424/attachments/image.png) 

updated fileset and forms layout, ensure work in both modern and classic form
![image (2).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/937064e0-f618-4073-904d-deb9a336dcbf/pullRequests/173424/attachments/image%20%282%29.png)

---

## PR 173530 - site-app-bpm - 2026-06-16
### Title: migrate mdc buttons
migrate mdc buttons

Highest risk are mat-button upgrades. 

**Rules**
- Toolbar 
before: ![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173530/attachments/image.png) 
after: 
![image (2).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173530/attachments/image%20%282%29.png) 
New changes, a hover state. 

- New Rules dialog popout icons buttons
before: ![image (3).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173530/attachments/image%20%283%29.png) 
after: 
![image (4).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173530/attachments/image%20%284%29.png) 
No change

**lf-resource-dialog**
From work schedules: Add holidays
before: 
![image (5).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173530/attachments/image%20%285%29.png) 
Now (temp): 
![image (6).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173530/attachments/image%20%286%29.png) 

*** fix is in lf-angular-packages, the scroll bar will be fixed once we migrate the dialogs 

Most buttons are lf-buttons with no change

---

## PR 173642 - site-app-bpm - 2026-06-17
### Title: Migration mdc card
**- PA Landing Page**
before:
![image (5).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image%20%285%29.png) 
after:
![image (6).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image%20%286%29.png) 
**- Welcome Page**
before:
![image (3).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image%20%283%29.png) 
after:
![image (4).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image%20%284%29.png) 
**- Rules Version dialog**
before:
![image (7).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image%20%287%29.png) 
after:
![image (8).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image%20%288%29.png) 
**- Workflow instance tab stats card**
before:
![image (10).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image%20%2810%29.png) 
after:
![image (11).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image%20%2811%29.png) 
**- Application connection api usage stats card**
before:
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image.png) 
after:
![image (2).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image%20%282%29.png) 
**- lookup table creation dialog step 2 loading**
before:
* Too fast to capture screenshot, but looks same as after, just centered loading text.
after:
![image (9).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173642/attachments/image%20%289%29.png)

---

## PR 173663 - site-app-bpm - 2026-06-17
### Title: migrate legacy menu to mdc
migrate legacy menu to mdc

- Overflow menu: 
before: 
![image (4).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173663/attachments/image%20%284%29.png) 
after: 
![image (3).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173663/attachments/image%20%283%29.png) 
- Starting events conditions menus
before: 
![image (6).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173663/attachments/image%20%286%29.png) 
after: 
![image (5).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173663/attachments/image%20%285%29.png)

---

## PR 173686 - site-app-bpm - 2026-06-18
### Title: update slide toggle 
update legacy slide toggle. Really should be using lf-toggle to be consistent with the rest of app, but upgrade anyway. 

before: 
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173686/attachments/image.png) 

after: 
![image (2).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173686/attachments/image%20%282%29.png)

---

## PR 173775 - site-app-bpm - 2026-06-18
### Title: migrate legacy checkbox to mdc
migrate legacy checkbox to mdc

before: 
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173775/attachments/image.png) 
![image (4).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173775/attachments/image%20%284%29.png) 
after: 
![image (3).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173775/attachments/image%20%283%29.png) 
![image (2).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173775/attachments/image%20%282%29.png)

---

## PR 173838 - site-app-bpm - 2026-06-19
### Title: migrate legacy tabs to mdc
migrate legacy tabs to mdc

- Details Tab
before:
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173838/attachments/image.png)  
after: 
![image (2).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173838/attachments/image%20%282%29.png) 
- Fileset 
before: 
![image (4).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173838/attachments/image%20%284%29.png) 
after: 
![image (3).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173838/attachments/image%20%283%29.png) 
- Team editor
before: 
![image (6).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173838/attachments/image%20%286%29.png) 
after: 
![image (5).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173838/attachments/image%20%285%29.png)

---

## PR 173850 - site-app-bpm - 2026-06-19
### Title: restore some previous styles
restore some previous styles
- tab dashboard separator
- application connection toggle checkmark style

Cherry-picked from commit `c16853c8`.

---

## PR 173853 - site-app-bpm - 2026-06-19
### Title: migrate legacy table
- Rules import dialog
before: 
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173853/attachments/image.png) 
after:
![image (6).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173853/attachments/image%20%286%29.png) 
- bp instance version upgrade table
before: 
![image (2).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173853/attachments/image%20%282%29.png) 
after:
![image (5).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173853/attachments/image%20%285%29.png) 
- application connections object mapper
before: 
![image (3).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173853/attachments/image%20%283%29.png) 
after: 
![image (4).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173853/attachments/image%20%284%29.png)

---

## PR 173957 - site-app-bpm - 2026-06-22
### Title: migrate legacy autocomplete
migrate legacy autocomplete

- team add users
before: 
after: 
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173957/attachments/image.png) 
- team assignment roles
before: 
after: 
![image (2).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173957/attachments/image%20%282%29.png) 

- team picker
before: ![image (4).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173957/attachments/image%20%284%29.png) 
after: ![image (3).png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/8354e1a5-307e-4100-b0a3-9fc0ef43581d/pullRequests/173957/attachments/image%20%283%29.png)

---

## PR 174024 - bpm - 2026-06-23
### Title: add log for ShouldRasterizePDF check using different contentlength
add log for different Contentlength to see why some attachment files are still being rasterized locally in bpmserver. 

Log the 2 sources of file size to see if there are discrepancies. Likely yes for the few production cases. 

Likely what happened is the real file size is > the 25mb limit, so shouldrasterize = false in the first check. Then later it reads the attachment.Item1.ContentLength which might be 0 or < the 25mb limit causing a fallback to local rasterization.

Those are supposed to be the same, but not sure how it can be different. If confirmed in production, we can adjust code to both use one source of truth, i.e. the real file size. 

Cherry picked from !173310

---

## PR 174066 - svc-app-renode - 2026-06-23
### Title: Override js-yaml to 4.2.0 to resolve GHSA-h67p-54hq-rp68
Override js-yaml to 4.2.0 to resolve GHSA-h67p-54hq-rp68

Override is required for now. Risk is low due to it being used by jest. Confirm unit tests still pass. 

Reason: the moderate quadratic-DoS advisory is fixed only in js-yaml
4.2.0; no patched 3.x release exists. The vulnerable js-yaml@3.14.2 is
pulled transitively by Jest coverage tooling (@jest/transform ->
babel-plugin-istanbul -> @istanbuljs/load-nyc-config), which pins
js-yaml ^3.13.1, so no dependency upgrade clears it. The upstream fix is
committed but unreleased (istanbuljs/load-nyc-config#26), making a
temporary override the only available remediation. 4.2.0 also satisfies
the ^4.1.0 consumers (eslint, @eslint/eslintrc, cosmiconfig).

Verification: npm audit no longer reports the js-yaml advisory and all
js-yaml copies resolve to 4.2.0. build (tsc) and lint (eslint) pass; the
test suite passes against committed sources (load-nyc-config calls
js-yaml .load(), present in both 3.x and 4.x, so the bump is API-safe).
Pre-existing rendering-engine.test.ts failures stem from an unrelated
working-tree edit, not this change.

#675381

---

## PR 174071 - svc-app-renode - 2026-06-23
### Title: Scope js-yaml 4.2.0 override to @istanbuljs/load-nyc-config
Scope js-yaml 4.2.0 override to @istanbuljs/load-nyc-config

Reason: GHSA-h67p-54hq-rp68 (moderate quadratic-DoS) is fixed only in
js-yaml 4.2.0; no patched 3.x release exists. The vulnerable js-yaml@3.14.2
is pulled solely via Jest coverage tooling (@jest/transform ->
babel-plugin-istanbul -> @istanbuljs/load-nyc-config, pinned ^3.13.1),
which cannot reach a fixed version on its own. The eslint/@eslint/eslintrc/
cosmiconfig copies already accept ^4.1.0 and float to 4.2.0 via
npm update, so the override is scoped to load-nyc-config alone rather than
a blunt global js-yaml pin (avoids masking future js-yaml updates for
other consumers).

Verification: all js-yaml copies resolve to 4.2.0 (npm ls) and the
moderate advisory clears (npm audit); build (tsc) and lint (eslint) pass.
load-nyc-config calls js-yaml .load(), present in both 3.x and 4.x, so the
bump is API-safe.

#675381

---

## PR 174079 - site-app-bp-designer - 2026-06-23
### Title: Bump form-data to 4.0.6 to resolve CVE-2026-12143
Bump form-data to 4.0.6 to resolve CVE-2026-12143
#675385

---

## PR 174088 - forms-layout - 2026-06-23
### Title: Bump dompurify to 3.4.11 to resolve CVE-2026-49459
Bump dompurify to 3.4.11 to resolve CVE-2026-49459

#675373

---

## PR 174119 - svc-app-renode - 2026-06-24
### Title: Bump js-yaml to 4.2.0 to fix CVE-2026-53550 (#675381)
## Finding

- **Advisory:** CVE-2026-53550 / GHSA-h67p-54hq-rp68 — js-yaml quadratic-complexity DoS in merge-key (` Formal gate: confirmation lands when Veracode re-scans on the platform `ReviewResultsSCA` page; the pipeline SCA log above is strong corroboration.

Confirmed js-yaml scan pass on Veracode
![image.png](https://v-dev-tfs/DefaultCollection/d0e7f4b8-3615-4fc9-ba0a-fa3bf48f3150/_apis/git/repositories/e73a257f-27aa-46db-bfbe-143b9ffd7f08/pullRequests/174119/attachments/image.png)

---

## PR 174123 - svc-app-renode - 2026-06-24
### Title: Bump form-data to 4.0.6 to fix CVE-2026-12143
Fixes **CVE-2026-12143** (CWE-93 CRLF injection) in `form-data` — High severity, flagged by Veracode SCA on *Forms PA Svc-App-Renode*.

### Fix
`form-data` is a **transitive** dependency via `axios@1.16.1 → form-data ^4.0.5`. That range already admits the patched **4.0.6**, so a lock-only update dedupes to it:

```sh
npm update form-data --package-lock-only
```

**`package-lock.json` only** — no `package.json` change and no `overrides` (per review feedback on the earlier abandoned PR !173897). Diff is two patch-level leaf bumps, all on the internal LFNPMPackages feed:
- `form-data` 4.0.5 → 4.0.6
- `hasown` 2.0.3 → 2.0.4 (form-data 4.0.6 requires `hasown ^2.0.4`)

### Risk
Low. The app's only multipart usage (`bpm-updater.ts`) uses fixed/trusted `printTypes` enum values as field names, so it was never exploitable by this CVE's vector; 4.0.6 only escapes `\r`/`\n`/`"`, leaving those values byte-identical.

### Verification
| Step | Result |
|---|---|
| `npm ci` | ✅ 636 packages from lockfile |
| `npm run build` (tsc) | ✅ |
| `npm test` (jest) | ✅ 141/141 |
| `npm audit` | ✅ high: 0; form-data no longer flagged |
| Veracode SCA pipeline 7963 (build 2189010) | ✅ Vulnerable Libraries: **0**; form-data absent; 0 vulns all severities |

The platform SCA re-scan (build 70451640, submitted in the same run) is the formal sign-off once it finishes processing.

---

## PR 174267 - lib-user-service-js - 2026-06-25
### Title: Bump form-data to 4.0.6 to clear CVE-2026-12143
Bug 675382: `form-data@4.0.5` flagged for CVE-2026-12143 (CRLF injection via unescaped multipart field names, GHSA-hmw2-7cc7-3qxx; vulnerable range 4.0.0–4.0.5).

**Fix:** lock-only bump of `form-data` 4.0.5 → 4.0.6. It's a transitive dep via `axios@1.15.2 → form-data`; axios already declares `^4.0.5`, which admits the patched 4.0.6, so no package.json change is needed. CI runs `npm ci`, so the lockfile bump is sufficient.

**Diff:** `package-lock.json` only — form-data 4.0.5→4.0.6 plus the nested `hasown@2.0.4` that 4.0.6 requires.

**Verification:**
- `npm ci` / `npm run build` / `npm test` (23/23) all pass
- Production `npm audit` no longer reports form-data
- Veracode SCA pipeline (build 2189690, this branch): 0 vulnerable libraries — form-data absent from Vulnerable Libraries / Issues

---

## PR 174356 - svc-app-renode - 2026-06-26
### Title: Add --disable-gpu-sandbox to fix Chromium 149 browser-disconnect during print
## Problem
svc-app-renode pods in clouddev began throwing `Puppeteer Browser disconnected` during print/screenshot (~Jun 23, 2026). The Chromium GPU process was dying mid-screenshot, taking the whole browser down and forcing pod restarts (the `Disconnected` handler intentionally throws to recycle the pod).

## Root cause
Piping Chromium's stdout/stderr to the pod logs (dumpio) captured the real failure:
```
GPU process exited unexpectedly: exit_code=139      (= killed by signal 11)
**CRASHING**:seccomp-bpf failure in syscall nr=0x148
... (GPU process retried, crashed each time) ...
FATAL: GPU process isn't usable. Goodbye.
Puppeteer Browser disconnected. ShuttingDown: false
```
- `0x148` = syscall **328 = `pwritev2`** (x86_64).
- The crash is in Chromium's **own GPU-process seccomp-bpf sandbox** (`sandbox/linux/seccomp-bpf-helpers/sigsys_handlers.cc`) — **not** the container/k8s seccomp profile.
- Chromium's GPU seccomp allowlist (`baseline_policy.cc`) does not permit `pwritev2`. These nodes have no GPU, so Chromium uses the **SwiftShader** software rasterizer (inside the GPU process) for screenshots; on **Alpine/musl + Chromium 149** that path calls `pwritev2`, the sandbox traps it → SIGSYS → GPU process killed → browser exits → Puppeteer disconnects.
- Trigger: the Alpine Chromium **148 → 149** bump (Jun 07, 2026). Known Alpine/musl bug class (aports #10257, void-linux #11149).

## Fix
Add `--disable-gpu-sandbox` to the Puppeteer launch args. This stops Chromium installing the seccomp-bpf filter on the GPU process. SwiftShader still renders exactly as before, but `pwritev2` is no longer trapped, so screenshots complete.

## Tests performed
| Test | Result |
|---|---|
| Deploy prod branch (worked Jun 1) to clouddev | FAILED — rules out app code (same code, new image) |
| Bump puppeteer 25.1 / 25.2 | FAILED — rules out puppeteer (system Chromium via `PUPPETEER_EXECUTABLE_PATH`) |
| Deploy `develop` to cloudtest ca | FAILED |
| helm rollback to old image (Chromium 148) | WORKS — confirms the image/Chromium version |
| dumpio diagnostic deploy | Captured the seccomp SIGSYS root cause above |
| `--disable-gpu` alone | FAILED — GPU process still launches for SwiftShader; seccomp filter still applied → same crash |
| `--disable-gpu-sandbox` (this PR) | **WORKS** — screenshots complete, no seccomp / "GPU isn't usable" lines |

## Security note
- This disables Chromium's **internal** GPU-process sandbox (one defense-in-depth layer) — **not** the container's. The GPU process still runs **non-root** (`pptruser`) inside the locked-down k8s container, which remains the primary isolation boundary.
- Scope is limited to the GPU process; renderer-process sandboxes are unaffected. The service only processes internal Forms print jobs.
- This is a standard, accepted mitigation for containerized Chromium on Alpine.
- Alternative `--disable-gpu --disable-software-rasterizer` (removes the GPU process entirely) was rejected: it drops the software renderer screenshots depend on, risking blank/broken output.

---

## PR 174387 - forms-layout - 2026-06-26
### Title: Bump dompurify to 3.4.11 to resolve CVE-2026-49459
Resolves the Veracode SCA finding **CVE-2026-49459** (XSS — CWE-79) on **dompurify 3.4.1** for the Forms PA Forms-Layout application.

Bumps dompurify **3.4.1 → 3.4.11** (lock-only; patched version is within the existing `^3.2.4` range, so `package.json` is unchanged).

Work item: #675373

### Why this version
The advisory affects DOMPurify ≤ 3.4.5. 3.4.11 is the latest release within the current semver range and clears the finding. Same major version — no breaking API changes.

### Risk
Low. The only consumer is `HtmlSanitizerService` (`projects/fl-lib/src/lib/services/html-sanitizer.service.ts`), which calls `DOMPurify.sanitize(content)` with **string input** — the path the advisory explicitly lists as *not affected* (the CVE only triggers in `IN_PLACE` mode on a form root). API used (`setConfig`, `addHook`, `sanitize`, `removed`, `UponSanitizeAttributeHookEvent`) is unchanged across 3.4.x.

### Changes
- `package-lock.json` — dompurify 3.4.1 → 3.4.11
- `html-sanitizer.service.spec.ts` — added 2 behavioral lock-in tests (strips disallowed elements; event-handler rewrite hook still fires)

### Verification
- `npm ci` clean; `npm ls dompurify` → 3.4.11; `npm audit` no longer flags dompurify
- fl-lib unit tests pass incl. the 2 new tests; the one unrelated pre-existing failure is the `FieldLabelComponent` responsive-layout test (requires ≤600px viewport, fails in headless desktop runs — not affected by this change)
- **Veracode SCA scan on this branch (build 2191496) confirms CVE-2026-49459 / dompurify is cleared** — absent from Vulnerable Libraries and Issues. Remaining findings (`ws`, `markdown-it`, `js-yaml`) are unrelated and pre-existing.

---

## PR 174420 - svc-app-renode - 2026-06-26
### Title: Update svc-app-renode to Puppeteer 25
Updates the `puppeteer` dependency from `^24.22.3` to `^25.2.1` (resolves to 25.2.1).

## Notes
- Puppeteer 25 is **ESM-only** with a Node floor of `>=22.12.0`. The Docker runtime and CI both run **Node 24**, where `require(esm)` is unflagged, so the compiled CommonJS (`require('puppeteer')`) loads it without converting the project to ESM. `PageEvent`/`BrowserEvent` are `const enum`s — `tsc` inlines them to literal event strings, so nothing looks them up at runtime.
- Diff is `package.json` (1 line) + regenerated `package-lock.json` (CI uses `npm ci`).

## Verification
- `npm run build`, `npm test` (141/141 pass), `npm run lint` — all clean locally.
- Pipeline 7575 run on this branch, deployed to **dev ca-central-1**: image build + helm deploy succeeded; post-deployment Version Check smoke test passed; **Run_Api_Tests 211/211 passed**. Confirms the ESM-only v25 loads under the real Node 24 Alpine / system-Chromium runtime.

#677088

---

## PR 174422 - svc-app-renode - 2026-06-26
### Title: Add CLAUDE.md
Adds a `CLAUDE.md` to give Claude Code (and new developers) fast context on svc-app-renode.

Covers:
- Common commands (build/test/lint, single-test).
- Runtime & Puppeteer constraints — unbundled + unpinned Alpine Chromium (debug-Chromium-version-first, per Bug 676184), ESM-only Puppeteer 25 under CommonJS via `require(esm)`, const-enum event wiring.
- Architecture — server modes, render flow, printer hierarchy, result delivery.
- Operational invariants — browser-disconnect crash-to-recycle, SIGTERM/Helm grace-period coupling.
- Build & deploy pipeline (definition 7575) — single-region CloudDev deploy and post-deployment test checks.

Docs only; no code or build changes.

#677097

---

## PR 174444 - forms-layout - 2026-06-26
### Title: Bump markdown-it to 14.2.0 to resolve CVE-2026-48988
Resolves Veracode SCA finding CVE-2026-48988 (bug #675372): markdown-it is vulnerable to Denial of Service via quadratic-time processing in the smartquotes rule when `typographer: true`.

## Fix
- Bump `markdown-it` 14.1.1 -> 14.2.0 (lockfile-only; the existing `^14.1.1` range in package.json already admits the patched version, so `package.json` is unchanged).
- Sibling sub-dependency `linkify-it` 5.0.0 -> 5.0.1 (patch) pulled in by markdown-it's updated range.

CI installs strictly from the lockfile (`npm ci`), so a lockfile-only bump is the cleanest change.

## Risk
Low. markdown-it is used in exactly one place — `ask-us-modal.component.ts`, instantiated as `md()` with default options (`typographer: false`), so the vulnerable smartquotes path is never exercised. The `md()` / `.render()` API is unchanged in this minor bump, so no code changes were needed.

## Verification
- `npm ci` clean install passes
- `npm audit` — markdown-it advisory cleared; `npm ls markdown-it` -> 14.2.0
- Production build of all three projects (fl-lib / fl-designer / fl-renderer) passes
- Veracode pipeline 7962 (build 2191666) succeeded and submitted the platform SCA scan

## Links
- CVE-2026-48988: https://nvd.nist.gov/vuln/detail/CVE-2026-48988
- Veracode component: https://analysiscenter.veracode.com/auth/index.jsp#ReviewResultsSCA:91401:1762951:70020804:69978769:69831387::::::1092a1f4-c42e-42d9-a9ca-8552227d98bf

---

## PR 174459 - forms-layout - 2026-06-26
### Title: Bump ws to 8.21.0 to resolve CVE-2026-48779
Resolves CVE-2026-48779 / GHSA-96hv-2xvq-fx4p — ws memory-exhaustion DoS (High, CVSS 7.5), affecting ws >=8.0.0 <8.21.0, patched in 8.21.0.

**Fix:** Lock-only transitive bump (`npm update ws --package-lock-only`). The production-reaching copy `puppeteer → puppeteer-core → ws` floats from 8.20.1 to 8.21.0 within the existing `^8` range — no package.json change or override needed. Also bumped the dev-only `webpack-dev-server` ws (8.20.1→8.21.0) and top-level jsdom ws (7.5.10→7.5.11).

**Scope:** package-lock.json only, 9 insertions / 9 deletions. `ws` is never imported in app code — it backs dev/automation tooling (puppeteer CDP, webpack-dev-server, karma) and is not in the shipped Angular bundles. Two dev-only copies (engine.io, socket.io-adapter via karma's socket.io) remain at 8.20.1 because their parents pin `~8.20.1`; they are dev-only and excluded from the production-scope SCA scan.

**Verification:** `npm ci` passes; prod-only `npm audit` reports no ws finding; no new advisories. Veracode SCA pipeline 7962 (build 2191740) confirms ws is absent from Vulnerable Libraries/Issues.

#675374

---

## PR 174468 - forms-layout - 2026-06-27
### Title: Bump transitive js-yaml 4.1.1 -> 4.3.0 to resolve CVE-2026-53550 #675375
## Finding
Veracode SCA bug #675375 flags component **js-yaml 4.1.1** (CVE-2026-53550) in the **Forms PA Forms-Layout** application. A crafted YAML document can trigger algorithmic CPU exhaustion in js-yaml merge-key (` cosmiconfig`, so Veracode's prod-only agent scan sees it.
- The vulnerable merge code is present in 4.1.1; **4.2.0 fixes it** (dedupes repeated alias sources + adds a `maxMergeSeqLength` guard). `^4.1.0` already permits the 4.x line, so this stays in-range and in-policy (no 5.0.0 major).

## Change
- `package-lock.json` only: `npm update js-yaml --package-lock-only` resolved the top-level `node_modules/js-yaml` from `4.1.1` to **4.3.0** (latest 4.x; resolved + integrity regenerated by npm). All four 4.1.1 instances now dedupe to 4.3.0; no `4.1.1` remains in the lockfile.
- No `package.json` `overrides` added: a broad `js-yaml` override would force the dev-only nested `js-yaml@3.14.x` copies (under `istanbul`/`tslint`) onto the 4.x major and break them. The lockfile resolution is sufficient since CI runs `npm ci`.

## Tested
- `npm ci` — clean install from the lockfile (exit 0); `npm ls js-yaml` confirms `4.3.0` across the tree.
- `npm run build-prod-hm` — full production build of fl-lib + fl-designer + fl-renderer succeeded. This exercises the `postcss-loader -> cosmiconfig -> js-yaml` config-load path that actually consumes the bumped package.
- Karma unit suite not run: js-yaml is consumed only by build/lint config loaders, not application or test runtime code, and the production build validated that path. Minor in-major version bump, no app code imports js-yaml.

---

## PR 174528 - ai-shared - 2026-06-29
### Title: Add npm-security-fix skill
Adds the **npm-security-fix** skill to `process-automation/skills/` plus a README index row.

The skill autonomously remediates Veracode / npm SCA findings: it normalizes the finding (CVE/GHSA, package+version, Veracode SCA report, or ADO Advanced Security alert), confirms it against the dependency tree, applies the smallest safe fix (preferring a package-lock-only update since CI runs `npm ci`), runs a risk-scoped test plan, and flags anything needing human verification.

### Changes
- `process-automation/skills/npm-security-fix/SKILL.md` (new)
- `process-automation/README.md` — skills-index row

### Validation
This PR only adds documentation, so there is no build/test to run on the change itself. The skill's procedure has instead been exercised on **real Veracode CVE findings**, each driven from a work item, landed as a PR, and independently confirmed by a Veracode re-scan (state → Verified):

| Work item | Finding | Fix | Veracode re-scan |
|---|---|---|---|
| #675373 | dompurify 3.4.1 — CVE-2026-49459 (forms-layout) | PR !173891: `^3.2.4 → ^3.4.11` + lockfile | Verified, scan 20260626.4 |
| #675374 | ws 8.20.1 — CVE-2026-48779 (forms-layout) | PR !173892: overrides `ws ^8.21.0` / jsdom `ws ^7.5.11` + lockfile | Verified, scan 20260627.1 |
| #675380 | form-data 4.0.5 — CVE-2026-12143 (svc-app-renode) | lock-only `npm update form-data` → 4.0.6 (no overrides) | Verified, scan 20260626.1 |

Highlights from those runs that show the workflow end to end:
- **Transitive-dependency tracing** — #675373/#675374 correctly located the fix in the internal `forms-layout` library rather than the scanned app.
- **Smallest-safe-fix iteration** — #675380 was reworked from an `overrides` approach to a clean lockfile-only `npm update` after review feedback ("should try to fix without overrides"), with real verification output: `npm ci` (636 pkgs), `npm ls form-data` → 4.0.6, `tsc` exit 0, jest **141/141**.
- **Human gates respected** — every run opened a PR and left merge/approval and final work-item state to a human, and noted that local `npm audit` is not authoritative until the Veracode pipeline re-scans.

Note: #675375 (js-yaml, forms-layout) is still in progress and is not counted as evidence.

---

## PR 174549 - svc-app-renode - 2026-06-29
### Title: [svc-app-renode] Log in-flight requests when a print navigation times out
## What

On a `networkidle0` navigation timeout in `PagePrinter.visit()`, log the requests still in flight (URL, method, ms since issued) so RCAs can tell a **hung sub-resource fetch** from a **pure client-side render stall** — previously only completed requests were logged (via `ResponseLogs`), so whatever held `networkidle0` open was invisible.

## How

- Track issued-at time per request in `inFlightRequests`, keyed by the request object.
- Drain on **`RequestFinished`** (body complete) + `RequestFailed` — **not** `Response` (headers only). `networkidle0` keeps a request active until its body finishes, so a slow/streaming body (SSE, chunked, large download) must stay tracked.
- On `TimeoutError`, emit the pending set (oldest first, capped at 20). Empty set logs `0 network requests in flight (pure client-side render stall)`.
- Clear the map at the start of each `visit()` attempt so the retry doesn't double-count a prior attempt's hung request.

WebSockets are intentionally not tracked — they arrive via CDP `webSocketCreated` (not the `request` event) and don't gate `networkidle0`.

## Tests

5 new unit tests in `page-printer.test.ts`: hung sub-resource, render stall (0 in flight), streaming-body still reported (drains only on `RequestFinished`), `RequestFinished` drains, and no double-count across retries. All 55 suite tests pass; lint + build clean.

## Test evidence (dev ca-central-1)

Hung request injected via a form's custom JS (`fetch(origin + "/forms/print/hang?seconds=300", { mode: "no-cors" })`), then printed. renode log:

```
[77ms] Loading url:https://app.a.clouddev.laserfiche.ca/forms/print/PrintModernForm?...
[45s 78ms] Navigation timeout: 1 request(s) still in flight (showing 1):
GET https://app.a.clouddev.laserfiche.ca/forms/print/hang?seconds=300 (in flight 43s 792ms)
[45s 78ms] First attempt failed with TimeoutError: Navigation timeout of 45000 ms exceeded. Running second attempt:
[1m 30s 79ms] Navigation timeout: 1 request(s) still in flight (showing 1):
GET https://app.a.clouddev.laserfiche.ca/forms/print/hang?seconds=300 (in flight 44s 670ms)
```

Confirms: the hung request is surfaced with its URL + elapsed time, and each retry attempt reports **1** in flight (not 2) — the per-attempt clear works. Satisfies acceptance criteria 1–3.

---

## PR 174699 - ai-shared - 2026-06-30
### Title: Refine npm-security-fix skill: Veracode-before-PR flow, audit gate, invasive-fix justification, Angular mitigation
Refinements to the `npm-security-fix` skill (the baseline was merged separately in PR 174528). This PR layers four improvements on top of it:

- **Veracode → PR ordering.** Reworked Steps 5–8 so the flow is commit/push → trigger the Veracode SCA pipeline → summarize → and only on a **clean scan** open the PR. The summary is reused as the PR description and carries the scan result + the triggered pipeline link.
- **`npm audit` verify gate.** When the finding was originally confirmed by `npm audit` (Step 1.4), a clean `npm audit` is now part of the minimum verification bar (with the `npm ls` fallback for Veracode-only findings).
- **Invasive-fix justification.** Before taking any invasive option (range bump / parent bump / override / replace), the less-invasive options above it must be ruled out one by one, recorded in the summary and PR.
- **Angular mitigation-by-design.** Major upgrades are attempted when feasible — except Angular, where the skill first checks whether the vulnerable code path is used; if it isn't, it documents a *Mitigation by Design* and posts the report to the original TFS ticket instead of forcing a cross-cutting major upgrade.

Net diff vs `main`: SKILL.md only (+48 / −14).

---

## PR 174705 - svc-app-renode - 2026-06-30
### Title: [svc-app-renode] Extend SQS visibility via heartbeat to prevent duplicate concurrent renders
### What & why
A long STR render can run several times its Puppeteer timeout (`visit()` and `print()` each retry once per file). The SQS message used a static 330s visibility timeout, so a render exceeding that would have its message redelivered **mid-render** to another pod — a duplicate concurrent render of the same job, plus wasted receive-count toward the DLQ.

This enables `sqs-consumer`'s heartbeat: while `handleMessage` runs it calls `ChangeMessageVisibility` every 60s to keep extending the window, so an in-progress render is never redelivered out from under itself. The 330s timeout is kept as the per-delivery floor.

### Changes
- **`queue-consumer.ts`** — add `heartbeatInterval: 60`; rename the timeout constant to `VISIBILITY_TIMEOUT_IN_SEC`; guard the consumer `error` handler so per-message `SQSError`s (which carry `messageIds`, e.g. a transient heartbeat failure) don't restart the consumer mid-render — only consumer-level failures do.
- **`cloud/helm/templates/iam-role.yaml`** — grant `sqs:ChangeMessageVisibility` on the BPM-RenderingEngine queue (the heartbeat's API call; without it every tick is AccessDenied).
- **`queue-consumer.test.ts`** — coverage for the new wiring.

### Test evidence (dev eu-west-1)
Hardcoded a form fetching `/forms/print/hang?seconds=200` to force render timeouts; traced one STR job end-to-end in ES logs.

| | Before IAM grant (`4e4c51b7…`) | After (`3cde29c2…`) |
|---|---|---|
| Heartbeat `ChangeMessageVisibility` errors | 11 × AccessDenied (one per 60s tick) | **0** (on fixed pod) |
| Redelivery cadence | ~330s (static window, no extension) | ~570s ×8 (window re-extended through render) |
| Concurrent duplicate renders | — | none — all receives strictly sequential |

The post-fix job failed all 10 attempts and correctly dead-lettered (queue `maxReceiveCount=10`, unchanged). The 330s→570s cadence shift is the direct fingerprint of the heartbeat extending visibility.

**CI:** deploy run 2194581 (build of `96fbf51`) — unit tests + dev-EU deploy passed.

---

