## WI 643662 - Description - 2026-02-13 - author Joey Lin

Deploy k8s secret PDF4NET_LICENSE_KEY to production

Creating this ticket for new cloud pipeline:
https://v-dev-tfs/DefaultCollection/Cloud/_build?definitionId=7162

---

## WI 643662 - Description - 2026-02-13 - author Joey Lin

Deploy k8s secret o2s-pdf4net-license to production

Creating this ticket for new cloud pipeline:
https://v-dev-tfs/DefaultCollection/Cloud/_build?definitionId=7162

---

## WI 634460 - Description - 2025-12-31 - author Joey Lin

Customer 705049016 started a large import activity via STR (Save to repository) tasks. This caused all BPMServers to spike in CPU due to processing large amounts of files. Impact to other customers may have include slightly delayed processing of BP/PA tasks.

https://v-k8s-1.laserfiche.com/grafana/d/R97lBCYGz/repository?orgId=1&from=now-3h&to=now&var-datasource=VFm1C7Z7k&var-repository=r-a691c530&refresh=1m

https://v-k8s-1.laserfiche.com/grafana/d/jJMax7d7k/bpm-cpu-utilization?orgId=1&from=now-6h&to=now&refresh=1m

https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/discover?_g=h@b4a10f5&_a=h@7bf76b0

[Info+1s 126ms(124)]OwnershipToken extended LockKey: 705049016:OT:Laserfiche.Reaction.Models.Instances.InstancePersist:b35100f28ef84b41ba6aa5372e037abb seconds: 1200

[Info+1s 469ms(124)]Create doc 317738 after 0 retries
[Info+22s 984ms(81)]OwnershipToken extended LockKey: 705049016:OT:Laserfiche.Reaction.Models.Instances.InstancePersist:b35100f28ef84b41ba6aa5372e037abb seconds: 22.0133271

[Info+23s 117ms(81)]Inserting attachment Started

From the logs, there seems to be significant delays (20s+) when dealing with importing files. Currently not sure if it's from interacting with S3, or the server, or when setting template/fields, etc. Will improve logs on that area: User Story 634455: add additional logs in STR to identify slowness

A mini dump file of bpmserver was taken when the CPU was high. https://v-dev-tfs/DefaultCollection/Cloud%20Infrastructure/_build/results?buildId=2002635&view=results
However, the slow threads seems to error-ed and not show the call stack:
0:000> !runaway
 User Mode Time
  Thread       Time
   30:ec4      0 days 0:43:17.468
   31:122c     0 days 0:40:10.218OS Thread Id: 0xec4 (30)
        Child SP               IP Call Site
GetFrameContext failed: 1

---

## WI 618499 - Description - 2025-10-10 - author Joey Lin

Dashboard is showing some 503 responses starting around midnight PT

https://v-k8s-1.laserfiche.com/grafana/d/f7c52305-e485-4a73-89df-15bf21d8e15b/rules-container-performance?orgId=1&viewPanel=panel-20&from=now-24h&to=now&var-NewCloud=BjmH76Z7k&refresh=10s

This is causing BPM to use fallback, which cause very slow rule requests.
https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/discover?_g=(refreshInterval:(pause:!t,value:0),time:(from:now-4h,mode:quick,to:now))&_a=(columns:!(message),index:'34939b60-0f04-11f0-bc8c-099c5deb183d',interval:auto,query:(language:lucene,query:%22Svc-Rules-Engine-Reroute%22),sort:!('@timestamp',desc))
[ERR+22s 799ms(155)]upstream connect error or disconnect/reset before headers. retried and the latest reset reason: connection timeout
UPSTREAM CONNECT ERROR OR DISCONNECT/RESET BEFORE HEADERS. RETRIED AND THE LATEST RESET REASON: CONNECTION TIMEOUT
	-----TRACES----
	System.Exception: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: connection timeout
	------
	-----DATA-----
		StatusCode = ServiceUnavailable
		OperationId = b37200ed1baa4a46a40011325555ab68
[ERR+22s 799ms(155)]!Svc-Rules-Engine-Reroute! Received ServiceUnavailable response from svc-rules-engine.
UPSTREAM CONNECT ERROR OR DISCONNECT/RESET BEFORE HEADERS. RETRIED AND THE LATEST RESET REASON: CONNECTION TIMEOUT
		UPSTREAM CONNECT ERROR OR DISCONNECT/RESET BEFORE HEADERS. RETRIED AND THE LATEST RESET REASON: CONNECTION TIMEOUT
	-----TRACES----
	Laserfiche.BusinessRules.Exceptions.ExternalServerErrorException: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: connection timeout ---> System.Exception: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: connection timeout
	   --- End of inner exception stack trace ---
	   at Laserfiche.BusinessRules.Handlers.Independent.RulesEngineClient.<Execute>d__26.MoveNext()
	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()
	   at Laserfiche.BusinessRules.Handlers.Independent.BusinessRuleExternalExecuteHandler`9.<ProcessExternalExecuteCommand>d__10`1.MoveNext()
	------
	-----DATA-----
		OperationId = b37200ed1baa4a46a40011325555ab68
		StatusCode = ServiceUnavailable

---

## WI 598131 - Description - 2025-06-23 - author Joey Lin

This is affecting 2 different users. SP grab a har file while logged in as each user separately, and viewing the task list -  which shows the time being incorrect, and appears to be reverting to pst, when it is set to est.  i have the har log files collected and a video showing the issue.

username: Skhan and Klivinskaattached har files - Skhan - Shakila2.harKlivinska - kat3.harScreenshot of Klivinska profile settings.png
Screenshot of Skhan profile settings.png
video located here \\laserfiche.com\fileserver\Eng\Support\Case Files\240000-249999\245646\Incorrect DATE AND TIME.mp4

---

## WI 589051 - Description - 2025-05-01 - author Joey Lin

This issue was reported in case 244772.

Customer has a business process which performs a lookup against a table to fill a repository username in order to perform a usertask. This lookup intermittently fails, leaving the field blank, causing the bp to suspend, and preventing the user task from starting successfully.

Example suspended bp: https://app.laserfiche.com/bpm/home/_global/bp/monitor#/instances/detail/b2420150-b7b8-4878-b8ca-c28060d153e5/b2bf0108-1713-43ed-9962-4a951e781bbf/variable

The issue was intermittent and wasn't immediately reproducible, but reoccurred several times today (4/29) and yesterday (4/28).

Checking Kibana logs for cloud account ID 762449155 reveals the following unhandled exception during the lookup operation due to a value which isn't globally unique:

API Request started at 2025-04-28T14:50:23.8519855Z.
[INFO+0ms(52)]Initializing request...

[INFO+0ms(52)][GET] http://bpm1.old.svc.cluster.local/bpm/api/a/FormsTask/b1f70140-82e0-4f65-b0f6-c1a7e53e09e5 NGINX:

[Verbose+0ms(52)]Entering TryGetLanguageByParam method.

[Verbose+0ms(52)]Entering TryGetLanguageByCookie method.

[Debug+0ms(52)]Language cookie was not found.

[Verbose+0ms(52)]Entering TryGetLanguageByHeader method.

[INFO+0ms(52)]Processing cookie...

----- COOKIEHANDLER -----

Cookie BPMSTS not found.

[INFO+20ms(52)]Processing cookie claims...

[Debug+20ms(52)]Decoding base 64 authorization

[INFO+20ms(52)]Processing basic login...

[Debug+26ms(7)]AuthorizeApplication: RunningInCloud: True

[Info+26ms(7)]Authorizing business_process_forms_designer

[Debug+26ms(7)]Retrieving business_process_forms_designer from password store.

[Debug+26ms(7)]Finished password store.

[INFO+27ms(7)]Coverting cookie.

[INFO+27ms(7)]BPMSTS  token read fast

[Verbose+27ms(7)]Basic Authentication Identity: Claims: 45. HasSamleToken: True

[INFO+27ms(7)]Validating cookie BPMSTS.

[INFO+27ms(7)]Cookie BPMSTS validated.

[INFO+27ms(7)]CSRF Antiforgery token cookie not present http://bpm1.old.svc.cluster.local/bpm/api/a/FormsTask/b1f70140-82e0-4f65-b0f6-c1a7e53e09e5

[INFO+27ms(7)]Before Account Authorization

[Info+27ms(7)]AsyncRefreshCache: Creating refresh task for Tenancy

[Debug+29ms(7)]Logger set for tenant: 762449155 [f7624491-5500-0000-0000-000000000000]

[INFO+29ms(7)]3 settings. Plan: EndUser_ProcessAutomation_Tier2_2018-07-11

[INFO+29ms(7)]Tenant Authorization

[INFO+29ms(7)]Account: f7624491-5500-0000-0000-000000000000 User Id: f7624491-5500-00ff-0000-000000000414

[INFO+29ms(7)]Before handler

[Info+32ms(7)]Created DbConnection: Core (50) -> ReadOnly [b2cd00f4-8e1e-4af9-8ca5-4a0c9c0f1e03] 89µs

[INFO+32ms(7)]Entering GetById method.

[Info+32ms(7)]Created DbConnection: Instances (1) -> Full [b2cd00f4-8e1e-47cf-a7f0-5c9d73b68d83] 52µs

[Info+32ms(7)]Created InstanceDbContext with DBAccess

[Info+33ms(7)]VaultWindowRepository: Find is querying for InstanceStepToResume.

[Verbose+37ms(52)]DB: Instances[bpmserverinstance.database.server.lfcinternal : b2cd00f4-8e1e-47cf-a7f0-5c9d73b68d83 : False]: -- Completed in 1 ms with result: NpgsqlDefaultDataReader

[Debug+38ms(52)]Find result is not null.

[Verbose+38ms(52)]Accessed b1f70140-82e0-4f65-b0f6-c1a7e53e09e5 from database. Found = True InstanceStepToResume.

[Verbose+38ms(52)]GetFromInstanceStepAndForm: Task Instance Id: b1ed00fb-ec0c-4a92-b671-517917d3862d, Task Version: 145:b1f0016e-520a-4bd6-983a-29edf508fb3a, Task status: Processing, Task Submission Id: b20200fe-d158-49c8-b931-534b332161f7.

[Verbose+38ms(52)]General type: user task. Try to retrieve InstanceTracking with instance Id: b1ed00fb-ec0c-4a92-b671-517917d3862d.

[Verbose+40ms(52)]DB: Instances[bpmserverinstance.database.server.lfcinternal : b2cd00f4-8e1e-47cf-a7f0-5c9d73b68d83 : False]: -- Completed in 0 ms with result: NpgsqlDefaultDataReader

[Verbose+40ms(52)]Retrieved InstanceTracking. InstanceTracking version: 145:b1f0016e-520a-4bd6-983a-29edf508fb3a, InstanceTracking status: Completed.

[Info+40ms(52)]AccountRepository: Find is querying for UserAccount.

[Verbose+42ms(54)]DB: Core[bpmservergeneral.database.server.lfcinternal : b2cd00f4-8e1e-4af9-8ca5-4a0c9c0f1e03 : False]: -- Completed in 1 ms with result: NpgsqlDefaultDataReader

[Debug+59ms(54)]Find result is not null.

[Info+59ms(54)]FormsTaskController: GetFromInstanceStepAndForm is querying for ProcessVersionResource.

[Verbose+62ms(54)]DB: Core[bpmservergeneral.database.server.lfcinternal : b2cd00f4-8e1e-4af9-8ca5-4a0c9c0f1e03 : False]: -- Completed in 1 ms with result: NpgsqlDefaultDataReader

[Debug+64ms(54)]GetFromInstanceStepAndForm result is b1f0016e-520a-4bd6-983a-29edf508fb3a.

[Verbose+64ms(54)]ProcessResource loaded with Id: b0fb017c-79f0-45a2-924f-75fde2e3553a.

[Info+64ms(54)]FormsTaskController: GetFromInstanceStepAndForm is querying for ProcessResource.

[Verbose+68ms(54)]DB: Core[bpmservergeneral.database.server.lfcinternal : b2cd00f4-8e1e-4af9-8ca5-4a0c9c0f1e03 : False]: -- Completed in 1 ms with result: NpgsqlDefaultDataReader

[Debug+68ms(54)]GetFromInstanceStepAndForm result is b0fb017c-79f0-45a2-924f-75fde2e3553a.

[Info+69ms(54)]Querying "ProcessModelerLayout" setting for ProcessVersionResource.

[Info+70ms(54)]ExecuteReaderList before execute action

[Verbose+74ms(54)]DB: Core[bpmservergeneral.database.server.lfcinternal : b2cd00f4-8e1e-4af9-8ca5-4a0c9c0f1e03 : False]: -- Completed in 3 ms with result: NpgsqlDefaultDataReader

[Info+75ms(54)]ExecuteReaderList after execute action

[Debug+75ms(54)]Found 1 settings for "ProcessModelerLayout".

[Info+75ms(54)]Querying "ProcessOptionsInfo" setting for ProcessVersionResource.

[Info+75ms(54)]ExecuteReaderList before execute action

[Verbose+77ms(54)]DB: Core[bpmservergeneral.database.server.lfcinternal : b2cd00f4-8e1e-4af9-8ca5-4a0c9c0f1e03 : False]: -- Completed in 0 ms with result: NpgsqlDefaultDataReader

[Info+77ms(54)]ExecuteReaderList after execute action

[Debug+77ms(54)]Found 1 settings for "ProcessOptionsInfo".

[Info+78ms(54)]Created DbConnection: Core (51) -> Full [b2cd00f4-8e2e-4ca0-9418-96c5c0ff6979] 67µs

[Info+82ms(54)]FormsTaskController: CheckTaskAvailability is querying for FormVersionResource.

[Verbose+85ms(54)]DB: Core[bpmservergeneral.database.server.lfcinternal : b2cd00f4-8e1e-4af9-8ca5-4a0c9c0f1e03 : False]: -- Completed in 1 ms with result: NpgsqlDefaultDataReader

[Debug+86ms(54)]CheckTaskAvailability result is b1f0016e-5220-4c33-9e72-5f49fb02e5d7.

[Info+86ms(54)]Querying "FormDC" setting for FormVersionResource.

[Info+86ms(54)]ExecuteReaderList before execute action

[Verbose+88ms(54)]DB: Core[bpmservergeneral.database.server.lfcinternal : b2cd00f4-8e1e-4af9-8ca5-4a0c9c0f1e03 : False]: -- Completed in 1 ms with result: NpgsqlDefaultDataReader

[Info+89ms(54)]ExecuteReaderList after execute action

[Debug+89ms(54)]Found 1 settings for "FormDC".

[Info+90ms(54)]Querying "FormVariableInfo" setting for FormVersionResource.

[Info+90ms(54)]ExecuteReaderList before execute action

[Verbose+92ms(54)]DB: Core[bpmservergeneral.database.server.lfcinternal : b2cd00f4-8e1e-4af9-8ca5-4a0c9c0f1e03 : False]: -- Completed in 1 ms with result: NpgsqlDefaultDataReader

[Info+92ms(54)]ExecuteReaderList after execute action

[Debug+92ms(54)]Found 1 settings for "FormVariableInfo".

[Verbose+93ms(54)]FormDC and FormVariableInfo loaded. ThemeId: .

[Verbose+93ms(54)]ProcessVersionResource loaded with Id: b1f0016e-520a-4bd6-983a-29edf508fb3a.

[Info+93ms(54)]ResourceRepository: Get is querying for Resource.

[Verbose+95ms(54)]DB: Core[bpmservergeneral.database.server.lfcinternal : b2cd00f4-8e1e-4af9-8ca5-4a0c9c0f1e03 : False]: -- Completed in 1 ms with result: NpgsqlDefaultDataReader

[Debug+95ms(54)]Get result is not null.

[Debug+128ms(52)]Try to update InstanceStepToResume as Terminate due to status conflict ( Instance Status: Completed / Task Status: Processing ) and insert history with Id: b2cd00f4-8e37-4a87-a80b-31781e782424.

[Verbose+165ms(52)]DB: Instances[bpmserverinstance.database.server.lfcinternal : b2cd00f4-8e1e-47cf-a7f0-5c9d73b68d83 : False]: -- Completed in 7 ms with result: 1

[ERR+188ms(52)][SparkLogging::LogSystemOperationFailed:70][Error: [http://bpm1.old.svc.cluster.local/bpm/api/a/FormsTask/b1f70140-82e0-4f65-b0f6-c1a7e53e09e5]An error occurred while updating the entries. See the inner exception for details.[b2cd00f48e1542ccb411abf8394a6059]

[ERR+188ms(52)][http://bpm1.old.svc.cluster.local/bpm/api/a/FormsTask/b1f70140-82e0-4f65-b0f6-c1a7e53e09e5]An error occurred while updating the entries. See the inner exception for details.[b2cd00f48e1542ccb411abf8394a6059]

[HTTP://BPM1.OLD.SVC.CLUSTER.LOCAL/BPM/API/A/FORMSTASK/B1F70140-82E0-4F65-B0F6-C1A7E53E09E5]AN ERROR OCCURRED WHILE UPDATING THE ENTRIES. SEE THE INNER EXCEPTION FOR DETAILS.[B2CD00F48E1542CCB411ABF8394A6059]

	-----TRACES----

	System.Exception: [http://bpm1.old.svc.cluster.local/bpm/api/a/FormsTask/b1f70140-82e0-4f65-b0f6-c1a7e53e09e5]An error occurred while updating the entries. See the inner exception for details.[b2cd00f48e1542ccb411abf8394a6059]

	------

	-----DATA-----

		OperationId = b2cd00f48e1542ccb411abf8394a6059

[INFO+284ms(36)]Finalizing Response

[INFO+284ms(36)]Entering WriteToStreamAsync method.

[INFO+285ms(36)]Preparing response

[INFO+285ms(36)]	ConvertToJsonAPI

[INFO+285ms(36)]JSON API Conversion

[INFO+285ms(36)]Leaving WriteToStreamAsync method.

[INFO+285ms(36)]Response: 500 Internal%20Server%20Error authorization_not_checked

[ERR+285ms(36)][SparkLogging::SetResult:632][Error: An error occurred while updating the entries. See the inner exception for details.

[ERR+285ms(36)]An error occurred while updating the entries. See the inner exception for details.

23505: DUPLICATE KEY VALUE VIOLATES UNIQUE CONSTRAINT "INSTANCE_FORM_PK"

	-----TRACES----

	Npgsql.PostgresException (0x80004005): 23505: duplicate key value violates unique constraint "instance_form_pk"

	   at Npgsql.NpgsqlConnector.<>c__DisplayClass161_0.<<ReadMessage>g__ReadMessageLong|0>d.MoveNext()

	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()

	   at Npgsql.NpgsqlConnector.<>c__DisplayClass161_0.<<ReadMessage>g__ReadMessageLong|0>d.MoveNext()

	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()

	   at Npgsql.NpgsqlDataReader.<NextResult>d__46.MoveNext()

	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()

	   at Npgsql.NpgsqlDataReader.NextResult()

	   at Npgsql.NpgsqlCommand.<ExecuteDbDataReader>d__100.MoveNext()

	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()

	   at Npgsql.NpgsqlCommand.<ExecuteNonQuery>d__92.MoveNext()

	   at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()

	   at Npgsql.NpgsqlCommand.ExecuteNonQuery()

	   at System.Data.Entity.Infrastructure.Interception.InternalDispatcher`1.Dispatch[TTarget,TInterceptionContext,TResult](TTarget target, Func`3 operation, TInterceptionContext interceptionContext, Action`3 executing, Action`3 executed)

	   at System.Data.Entity.Infrastructure.Interception.DbCommandDispatcher.NonQuery(DbCommand command, DbCommandInterceptionContext interceptionContext)

	   at System.Data.Entity.Core.Mapping.Update.Internal.DynamicUpdateCommand.Execute(Dictionary`2 identifierValues, List`1 generatedValues)

	   at System.Data.Entity.Core.Mapping.Update.Internal.UpdateTranslator.Update()

	------

	-----DATA-----

		Severity = ERROR

		SqlState = 23505

		Code = 23505

		MessageText = duplicate key value violates unique constraint "instance_form_pk"

		Detail = Key (form_version_id)=(b1f0016e-5220-4c33-9e72-5f49fb02e5d7) already exists.

		SchemaName = public

		TableName = instance_form

		ConstraintName = instance_form_pk

		File = nbtinsert.c

		Line = 666

		Routine = _bt_check_unique

[INFO+285ms(36)]Completed at 2025-04-28T14:50:24.1457673Z MilliSpeedOp. Tags: formstask_getbyid_get,review_security

[API Request]Internal Server Error An error occurred while updating the entries. See the inner exception for details.[b2cd00f48e1542ccb411abf8394a6059][2!0](285ms)<f7624491550000000000000000000000>

This causes the lookup to fail, which in turn causes the subsequent email action to fail since there's no username to run the action against. The process retries a few times, inevitably fails, and suspends the bp. The sequence of events is pretty clear from the logs by searching "DUPLICATE KEY VALUE VIOLATES UNIQUE CONSTRAINT "INSTANCE_FORM_PK"" and following the resultant errors chronologically.

I believe the issue here isn't so much that there's a duplicate value in an SQL table, but that Cloud is experiencing an unhandled exception as a result, rather than generating a user-facing friendly error.

Support is requesting the following:

Please determine whether this error is an internal Cloud error or due to user-entered data in the customer bp/lookup tables.

Investigate whether the resulting unhandled exception is expected behavior.

---

## WI 586695 - Description - 2025-04-15 - author Joey Lin

A completed Forms task is showing as in progress, took a close look at the case and can confirm all the steps have completed successfully. We suspect this might be a bug. Customer is requesting that this gets investigated as they rely on our reporting for their operations. Getting wrong information is going to have a detrimental to their monitoring.

This is on the EMEA cloud
Customer ID: 2277857380
Case URL: Business Process - Monitor

---

## WI 586695 - Description - 2025-04-15 - author Joey Lin

A completed Forms instance is showing as in progress, took a close look at the case and can confirm all the steps have completed successfully. We suspect this might be a bug. Customer is requesting that this gets investigated as they rely on our reporting for their operations. Getting wrong information is going to have a detrimental to their monitoring.

This is on the EMEA cloud
Customer ID: 2277857380
Case URL: Business Process - Monitor

---

## WI 586530 - Description - 2025-04-14 - author Joey Lin

https://v-k8s-1.laserfiche.com/grafana/d/d78b5f78-e888-4d64-8db9-cc742cfea71e/bpm-memory-utilization?orgId=1&refresh=30s&from=now-3h&to=now&timezone=browser&viewPanel=panel-2

Currently at 8GiB free Memory. This is usually large rasterization job related in STR tasks

---

## WI 582179 - Description - 2025-03-20 - author Joey Lin

Received alert of TimeoutError in renode

PA Platform Prod - US: [FIRING:1] RenodeTimeoutError US Forms [FIRING:1] RenodeTim...
posted in Process Automation Product Area / Grafana Alerts - Prod US on Wednesday, March 19, 2025 7:40 PM

This is from customer: 745196189 Bp Instance ID: b2a3010d-2f25-4239-a70e-0b6319b13870

Log:
https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/discover?_g=(refreshInterval:(pause:!t,value:0),time:(from:now-1h,mode:quick,to:now))&_a=(columns:!(log),index:f651ec50-d841-11eb-8c96-47ea7c58f93d,interval:auto,query:(language:lucene,query:%22e09f03fa-a33b-48de-8639-831c36f7226d%22),sort:!('@timestamp',desc))

This is due to memory pressure on  the svc-app-renode pod. Increasing the memory limit to 3Gig should address the issue, and we'll working on deploying it.

---

## WI 580587 - ImpactAssessment - 2025-03-10 - author Joey Lin

BP instances can submit but instances do not show up in monitoring, all queued processing (STR, usertasks, etc.) were delayed
WF completions and scheduled rules were delayed

---

## WI 573470 - Description - 2025-01-23 - author Joey Lin

Unable to access process automation site in production CA after the release of 2025.1.4

Chat records:
David Choy via Workflows: Card - access it on https://go.skype.com/cards.unsupport...
posted in Cloud Operations / Production on Thursday, January 23, 2025 4:40 PM

The deployment of bpm failed for CA and the CPU spiked for BpmAppFrontEndServer
https://v-k8s-1.laserfiche.com/grafana/d/jJMax7d7k/bpm-cpu-utilization?orgId=1&from=now-1h&to=now&refresh=1m&viewPanel=panel-21

---

## WI 554234 - RootCauseAnalysis - 2024-11-12 - author Joey Lin

Product Backlog Item 554010: try and reproduce timeout issue for renode in 2024.11

We suspect CPU throttling of the pod may have contributed to the timeout. When CPU units usage is closer to the limit, the time correlates with more timeout errors.

We also suspect it's related to the updated puppeteer v22. Despite all our auto test and load test passed in cloudtest with v22, we suspect it may be the new chromeless shell that's still having performance issues. https://pptr.dev/guides/headless-modes

---

## WI 554234 - Description - 2024-11-12 - author Joey Lin

svc-app-renode was rolled back in 2024.11 release.
Issue 553605: Rollback renode to previous version as described in CPCR

Right after release, we were still seeing smalls amounts of TimeoutError. 8 fails/ ~1.1k success in US, 0 failure in CA and EU.

sample error: https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west-2/_plugin/kibana/app/kibana#/discover?_g=(refreshInterval:(pause:!t,value:0),time:(from:now%2fw,mode:quick,to:now%2fw))&_a=(columns:!(_source),filters:!(('$state':(store:appState),meta:(alias:!n,disabled:!f,index:f651ec50-d841-11eb-8c96-47ea7c58f93d,key:kubernetes.container_name,negate:!f,params:(query:svc-app-renode,type:phrase),type:phrase,value:svc-app-renode),query:(match:(kubernetes.container_name:(query:svc-app-renode,type:phrase))))),index:f651ec50-d841-11eb-8c96-47ea7c58f93d,interval:auto,query:(language:lucene,query:%22TimeoutError%22),sort:!('@timestamp',asc))

---

## WI 554234 - ImpactAssessment - 2024-11-12 - author Joey Lin

Detailed instances outlined here: Issue 553605: Rollback renode to previous version as described in CPCR, but in summary, about 6 customers and 8 instances had the save to respository tasks suspended.

---

## WI 540204 - Description - 2024-08-27 - author Joey Lin

CPU at around 80%
https://v-k8s-1.laserfiche.com/grafana/d/jJMax7d7k/bpm-cpu-utilization?orgId=1&refresh=1m&from=now-1h&to=now&viewPanel=24

We suspect a message might be stuck processing.

---

## WI 524471 - Description - 2024-05-24 - author Joey Lin

We noticed an issue when testing Save to repository task on LFQA production US.

The setup on forms side is a message start -> Save to repository Task -> end with the following settings:
[X] Generate Laserfiche pages when importing PDFs

Save options: Save as: PDF

The expected behavior is PDFs are saved to the repository with both the electronic file and the generated Laserfiche pages. This is verified by seeing the file is saved with a .pdf extension, and the 'File View' toggle on the top left corner to toggle between pdf and image view.

On production US LFQA, account ID: 491263275, only the images are generated, and the pdf efile is not.
This is a sample bp instance:

https://app.laserfiche.com/bpm/home/_global/bp/monitor#/instances/detail/b17a00fd-069e-4144-8a99-34578865c1c5/b17a0104-50a1-48a2-9073-b69e9a0d9072/pm

Where entry id: 1583746 is saved without the electronic file:
File path
 (Document has no electronic file)

We could not reproduce this bug in other prod accounts such as other US, prod CA, nor prod EU, nor cloud test accounts.

Prod US:
491263275 BROKEN

325447701 WORKS

Prod CA:

1443767787 WORKS

Cloud Test US:

642614842 	WORKS

From the logs on forms side, it seems to succeed without errors. Looking for help from other teams to identify if related to Aurora migration or other configuration issues for this specific account.

---

## WI 512734 - RootCauseAnalysis - 2024-03-13 - author Joey Lin

An AMQ maintenance window at roughly 3/09/2024 1:00AM UTC caused new rabbit nodes with new ips to come up. This caused an connection issue with BPMServer talking to rabbmitMQ. Subsequently, all RoutingEngineTasks and RoutingEngineHighPriorityTasks queued items were building up unable to be processed. A restart of the BpmServer service resolved the connection issue.

---

## WI 502254 - Description - 2023-12-22 - author Joey Lin

BpmServer CPU reached 100%
https://v-k8s-1.laserfiche.com/grafana/d/jJMax7d7k/bpm-cpu-utilization?orgId=1&refresh=1m&from=now-3h&to=now&viewPanel=9

From logs there are exceptions for "StackExchange.Redis.RedisTimeoutException" which correlated with the CPU spike timeline
https://v-k8s-1.laserfiche.com/elasticsearch/production/us-west- 2/_plugin/kibana/app/kibana#/discover?_g=(refreshInterval:(pause:!t,value:0),time:(from:now-4h,mode:quick,to:now))&_a=(columns:!(_source),index:'vpc-01c245c7e403ca77d-windows_file_logs-*',interval:auto,query:(language:lucene,query:%22StackExchange.Redis.RedisTimeoutException%22),sort:!('@timestamp',asc))

Incident bundle before the restart: https://tfs/DefaultCollection/Cloud%20Infrastructure/_build/results?buildId=1288301&view=logs&j=275f1d19-1bd8-5591-b06b-07d489ea915a&t=5fd232ee-0bcd-5c4f-9e6b-7e96853085e6

---

## WI 473979 - Description - 2023-07-24 - author Joey Lin

Below are the two instances that show process remain in progress even though instances has completed:

https://app.laserfiche.com/bpm/home/Employee%20Performance%20Appraisals/bp/monitor#/instances/detail/b02f014a-f080-433d-90ae-44dfeb6650ed/b00000d2-8885-417d-be18-0226c3b56e00/pmhttps://app.laserfiche.com/bpm/home/Employee%20Performance%20Appraisals/bp/monitor#/instances/detail/b02f014a-f080-433d-90ae-44dfeb6650ed/afff0137-9483-4ea8-b833-634ab69a224d/pm

---


