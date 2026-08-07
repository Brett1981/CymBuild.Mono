# CymBuild 26.3 Runtime Deployment & Worker Decomposition Matrix

**Status:** WP2 source analysis / proposed runtime decomposition  
**Date:** 7 August 2026  
**Repository:** `https://bitbucket.org/esgdevelopers/cymbuild_monorepo.git`  
**Branch:** `feature/SB_Kubenetes`  
**Baseline commit:** `d57a5965` (`docs(cicd): reconcile 26.3 baseline with R40 and Sage Wrapper`)  
**Runtime source basis:** the supplied 26.3 source archive is the runtime source immediately before the documentation-only R1 commit. R1 changed documentation only, so the runtime findings below apply to `d57a5965`.

## 1. Purpose

This document closes the analysis part of WP2 before production Dockerfiles or Kubernetes manifests are created. It identifies:

- which projects are deployable runtimes versus libraries/tools;
- which hosted workers currently run inside `Concursus.API`;
- whether those workers are safe to run in multiple Kubernetes replicas;
- which components should be containerised in the first CymBuild Kubernetes release;
- which existing source dependencies must be removed or isolated before scaling;
- which components remain external, retained-only, or require a separate remediation workstream.

The mandatory CymBuild application boundary remains:

`Blazor PWA -> Concursus.API.Client/FormHelper -> Concursus gRPC API -> EF -> SQL Server`

No new direct browser-to-business-API or browser-to-integration coupling is permitted.

---

## 2. Executive runtime decisions

1. **Do not scale the current `Concursus.API` process as-is.** It registers five `BackgroundService` workers in the API process. Scaling the API would therefore scale all five workers automatically.
2. **Separate API replica count from worker replica count before Kubernetes rollout.** The least-risk first implementation is a runtime-role switch in the existing API binary/image: API Pods run with hosted workers disabled; dedicated worker Deployments use the same tested image but enable one named worker role each. This preserves current default behaviour outside Kubernetes while removing the scaling coupling.
3. **Initial worker replica count is one for every worker role.** Some workers contain strong database concurrency controls, but not all do. Horizontal scaling is enabled only after the role-specific concurrency gate in this document is satisfied.
4. **The Sage Wrapper service is the active Sage boundary.** The older `Sage200Microservice.*` projects and `SageAPI_TEMP_DISABLED` remain in source but are excluded from current build/container/deployment scope.
5. **PostCodeLookup remains separately delivered.** It already has its own pipeline and is treated as an external CymBuild dependency rather than being absorbed into the CymBuild image set.
6. **`CymBuild_Outlook_API` is not Linux-container-ready unchanged.** Its Data Protection keys are persisted to SQL but protected with Windows DPAPI. A cross-platform key-protection decision is required before Linux RKE2 deployment.
7. **`CymBuild_Outlook_Service` is not a Kubernetes worker candidate in its current form.** It is explicitly configured as a Windows Service and its worker polls a hard-coded localhost example URL. Its current operational purpose must be confirmed before it is included in deployment scope.
8. **`CymBuild_AIErrorServiceAPI` needs a separate remediation gate before Kubernetes.** It uses Windows-Service hosting, writes startup files to the application directory, currently has authentication commented out, contains two non-leased background schedulers, and is called directly from the PWA in existing code.
9. **The PWA still carries a legacy Sage gRPC dependency that is no longer used by `FormHelper`.** It should be removed before containerisation, with tests proving no behaviour loss.
10. **Several existing PWA direct-HTTP paths conflict with the mandatory architecture.** These are existing-source debts and must not be reproduced in the new Kubernetes design.

---

## 3. Core deployable component matrix

| Component | Current project/source | Target deployment | First-release replicas | Current decision |
|---|---|---|---:|---|
| CymBuild PWA | `apps/Concursus.PWA` | Containerised static web host + Kubernetes `Deployment`, `Service`, `Ingress` | 2 after smoke validation | **IN SCOPE** |
| Concursus gRPC/API | `services/Concursus.API` | Kubernetes `Deployment` + internal `Service`; external route through approved Ingress/KEMP path | 2+ only after hosted workers are disabled in API role | **IN SCOPE** |
| CymBuild worker runtime | Initially the same tested Concursus API runtime image with an explicit worker role; later extract a dedicated host if justified | No public `Service`; one Kubernetes `Deployment` per worker role | 1 per role initially | **IN SCOPE** |
| Schema deployment | `tools/SchemaDeployment` R39/R40 process | Bitbucket controlled pipeline step initially; Kubernetes Job remains an option after PowerShell/SQL connectivity is proven | one-shot | **IN SCOPE** |
| Metadata validation/apply | `apps/Concursus.Metadata.Tools` plus the run-based `SMigration` API/process | Controlled pipeline step/Job according to the active run lifecycle | one-shot | **IN SCOPE** |
| Outlook API | `services/CymBuild_Outlook_API` | Separate web Deployment only after cross-platform Data Protection/security work | TBD | **DEFERRED GATE** |
| Outlook Service | `services/CymBuild_Outlook_Service` | No Kubernetes deployment until current business purpose is confirmed and Windows-Service/localhost assumptions are removed | 0 | **EXCLUDE FOR NOW** |
| AI Error service | `services/CymBuild_AIErrorServiceAPI` | Separate service after security, scheduling and UI-boundary remediation | 0 initially | **DEFERRED GATE** |
| PostCodeLookup | `services/PostCodeLookup` | Existing separately pipelined service | externally managed | **EXTERNAL DEPENDENCY** |
| Sage Wrapper | external approved Wrapper service | External controlled integration boundary | externally managed | **EXTERNAL DEPENDENCY** |
| Sage200Microservice | `services/Sage200Microservice/*` | none | 0 | **RETAIN, DO NOT DEPLOY** |
| SageAPI_TEMP_DISABLED | `services/SageAPI_TEMP_DISABLED` | none | 0 | **RETAIN, DO NOT DEPLOY** |

---

## 4. Hosted workers currently coupled to Concursus.API

`services/Concursus.API/Program.cs` currently registers all of the following with `AddHostedService`:

1. `SageInboundPaymentSyncWorker`
2. `WorkflowOutboxKafkaPublisherWorker`
3. `InvoiceAutomationScheduledWorker`
4. `SharePointStructureRepairWorker`
5. `SageTransactionSubmissionWorker`

If an unchanged API image runs three replicas, each of those workers also runs three times. The API therefore cannot be horizontally scaled safely until runtime roles are introduced.

### 4.1 Proposed Kubernetes worker roles

Use one worker role per Deployment even if the first implementation shares one binary/image:

| Worker role | Class | Proposed Deployment name | Initial replicas |
|---|---|---|---:|
| `InvoiceAutomation` | `InvoiceAutomationScheduledWorker` | `cymbuild-worker-invoice` | 1 |
| `WorkflowOutbox` | `WorkflowOutboxKafkaPublisherWorker` | `cymbuild-worker-outbox` | 1 |
| `SharePointRepair` | `SharePointStructureRepairWorker` | `cymbuild-worker-sharepoint-repair` | 1 |
| `SageSubmission` | `SageTransactionSubmissionWorker` | `cymbuild-worker-sage-submit` | 1 |
| `SageInbound` | `SageInboundPaymentSyncWorker` | `cymbuild-worker-sage-inbound` | 1 |

No worker Deployment receives a public Ingress. NetworkPolicy should permit only the exact SQL, Kafka, Wrapper and SharePoint/Graph routes required by that role.

---

## 5. Worker concurrency analysis

### 5.1 InvoiceAutomationScheduledWorker

**Source evidence**

- Uses `InvoiceAutomationRepository.WithExclusiveAppLockAsync`.
- Lock is implemented with SQL Server `sp_getapplock` in `SqlDistributedAppLock`.
- Lock owner is the SQL session and lock mode is `Exclusive`.
- The worker executes materialisation, nudge dequeue and Phase 4-to-6 orchestration while holding that lock.
- Configuration uses the stable lock name `SFin.InvoiceAutomation.ScheduledWorker`.

**Assessment:** **multi-instance protected**, but multiple replicas offer little throughput because only one can own the global lock at a time.

**Initial decision:** dedicated Deployment, `replicas: 1`.

**Future scale gate:** multiple replicas can be used for failover only after a Kubernetes termination/restart test proves the session lock is released predictably and that the SQL procedures remain idempotent after interrupted execution.

### 5.2 SageTransactionSubmissionWorker

**Source evidence**

- Claims `SCore.IntegrationOutbox` using `READCOMMITTEDLOCK`, `UPDLOCK`, `READPAST`, `ROWLOCK` and a unique `PublishingToken`.
- Completion/failure updates require the same `PublishingToken`.
- A second transaction-level claim exists through `SFin.TransactionSageSubmissionStatus_TryClaim`, protected by `UPDLOCK/HOLDLOCK`.
- Successfully submitted transactions are recorded in `TransactionSageSubmissionStatus`.
- The actual external call is the **Sage REST Wrapper** through `SageSalesOrderGateway` (`POST api/sales-orders`).

**Assessment:** **strongest multi-instance design of the five workers, but only conditionally safe for horizontal scale**.

There is still an at-least-once failure window: if the Wrapper creates the Sage order but the CymBuild success record cannot be committed, a later stale-claim retry can repeat the Wrapper call. No external idempotency header/key is added by `SageSalesOrderGateway` in the inspected source.

**Initial decision:** dedicated Deployment, `replicas: 1`.

**Future scale gate:** confirm/implement Wrapper-side idempotency using a stable CymBuild transaction/event identifier, then execute crash-after-Wrapper-success tests and claim-timeout tests before raising replicas.

### 5.3 SageInboundPaymentSyncWorker

**Source evidence**

- `SFin.SageInboundPaymentSync_Worklist` atomically selects and marks rows `IsInProgress = 1` using row locks and `READPAST`.
- Stale work may be reclaimed after `ClaimStaleAfterMinutes`.
- The worker calls `SageInboundPaymentSyncService.SyncAsync` for each claimed document.
- Success/failure clears the in-progress state through the status procedures.
- The inspected service currently treats the worklist claim as authoritative; it does not carry a claim-owner token into completion updates.

**Assessment:** **safe from immediate duplicate claims, but not ownership-safe after stale-claim expiry**. A slow first worker and a second worker can overlap after the stale threshold, and completion updates are not bound to a claim token.

**Initial decision:** dedicated Deployment, `replicas: 1`.

**Future scale gate:** add a claim token/owner to `SageInboundDocumentStatus`, require it on completion/failure, and test processing that intentionally exceeds the stale threshold.

### 5.4 WorkflowOutboxKafkaPublisherWorker

**Source evidence**

- Outbox publish claims use a unique `PublishingToken`, row locking, a lease timeout and token-bound completion. This part is suitable for multiple publishers.
- Kafka messages use stable business keys, e.g. `TransitionGuid` for workflow notifications.
- The same worker first drains `SCore.WorkflowNotificationQueue` into the outbox.
- `DequeueNotificationQueueAsync` increments `AttemptCount` but does **not** persist a lease/claim token or in-progress owner before returning rows.
- `IntegrationOutbox_EnqueueWorkflowStatusNotification` has an idempotency existence check for transition Guid, but the inspected SQL does not provide a unique database constraint/serialized claim around that check-and-insert race.
- Normal outbox semantics also permit a duplicate Kafka publish if the broker accepts a message and the subsequent `MarkPublishedAsync` fails; consumers must therefore remain idempotent.

**Assessment:** **publisher claim is multi-instance capable; the combined notification-queue stage is not proven multi-instance safe**.

**Initial decision:** dedicated Deployment, `replicas: 1`.

**Future scale gate:** either split queue-materialisation from publishing or add queue lease tokens/ownership and a database-enforced outbox uniqueness invariant for the transition/event identity. Then test broker-success/database-failure replay behaviour.

### 5.5 SharePointStructureRepairWorker

**Source evidence**

- Claims a `SharePointStructureRepairRequested` outbox row with row locks and increments `PublishAttempts`.
- The claim does **not** set `PublishingToken`, `PublishingStartedOnUtc` or another in-progress owner.
- The transaction commits immediately after the attempt count is incremented while `PublishedOnUtc` remains null.
- A second worker can therefore select the same row before the first has finished SharePoint repair.
- Completion/failure updates are by outbox ID only, with no ownership token.

**Assessment:** **not safe for multiple worker instances**.

**Initial decision:** dedicated Deployment, **strictly `replicas: 1`**.

**Future scale gate:** change the claim to token/lease semantics and make mark-published/failed conditional on the same token. Add concurrent-worker integration tests before any replica increase.

---

## 6. Recommended first runtime implementation pattern

To minimise behaviour change, do **not** immediately move worker classes across projects or duplicate large sections of API DI setup.

Introduce an explicit runtime role in `Concursus.API` with backward-compatible defaults:

- `Combined` — existing behaviour; API endpoints + all currently registered hosted workers. This remains the default initially so local/current non-Kubernetes behaviour does not silently change.
- `ApiOnly` — API/gRPC endpoints with all five hosted workers disabled.
- `Worker` — exactly one named worker role enabled; HTTP endpoints may still start in the first implementation but the Pod receives no Kubernetes Service/Ingress and is constrained by NetworkPolicy.

Proposed configuration shape:

```json
{
  "CymBuildRuntime": {
    "Mode": "Combined",
    "WorkerRole": ""
  }
}
```

Kubernetes would use:

```text
API Deployment                 Mode=ApiOnly
invoice worker Deployment      Mode=Worker  WorkerRole=InvoiceAutomation
outbox worker Deployment       Mode=Worker  WorkerRole=WorkflowOutbox
SharePoint repair Deployment   Mode=Worker  WorkerRole=SharePointRepair
Sage submission Deployment     Mode=Worker  WorkerRole=SageSubmission
Sage inbound Deployment        Mode=Worker  WorkerRole=SageInbound
```

This immediately allows API horizontal scaling without duplicating workers, while preserving a straightforward rollback to current combined hosting.

A dedicated worker host project can be extracted later if operating the shared web runtime in worker Pods creates a material security/resource issue. That extraction is not required to achieve safe first deployment and should not be allowed to become a broad rewrite.

---

## 7. Existing PWA dependencies that must be corrected before final container manifests

### 7.1 Legacy Sage200Microservice gRPC client — remove

The PWA registers:

- `Sage200Microservice.API.Protos.Invoice.InvoiceService.InvoiceServiceClient`
- a named HTTP client `SageIntegrationAPI` using `Grpc:SageApi`

`Concursus.API.Client/FormHelper` accepts and stores the Sage gRPC client, but the inspected current source contains **no use of `_sageClient` beyond constructor assignment**. No calls to the generated `CreateCustomer`, `CheckInvoiceStatus` or `CreateSalesOrderInvoice` client methods were found outside generated output.

This is dead architectural coupling to the retired Sage microservice and should be removed with a compile/test-protected patch.

`Pages/KafkaTest.razor` separately uses the `SageIntegrationAPI` named HTTP client to call `api/kafka/publish`. That development path must either be removed or routed through `FormHelper -> Concursus gRPC API`; it must not retain browser-to-Sage-service coupling.

### 7.2 Direct REST call to Concursus.API — migrate to FormHelper/gRPC

`Shared/DynamicGridView.razor.cs` creates the named `ShoreApiHttp` client and directly posts to:

`api/invoice-schedules/{guid}/month-configurations/generate`

This bypasses FormHelper/gRPC and should be migrated to a gRPC operation exposed through `FormHelper` before the new deployment is declared architecture-compliant.

### 7.3 AI Error service direct browser calls — separate remediation

`AiErrorReporter`, `AiErrorAdmin` and `JiraTickets` directly call `AiErrorService:BaseUrl` from the PWA. This is an existing exception to the mandatory PWA boundary.

The target design should be:

`PWA -> FormHelper -> Concursus gRPC API -> controlled AI Error service layer`

or a governed outbox-based equivalent where asynchronous reporting is appropriate.

Do not expose the AI Error service as a new browser-facing Kubernetes dependency simply to preserve this shortcut.

### 7.4 Postcode legacy/developer UI path

The primary `PostcodeLookupButton` already uses `FormHelper.AddressLookupSearchAsync/ResolveAsync`, which correctly flows through Concursus gRPC and the API-side lookup service.

`PostcodeLookupTab.razor` still contains direct HTTP developer/test paths. These should be removed or converted to the existing FormHelper methods; they are not the model for the production deployment.

### 7.5 Presigned AI Assistant upload

The AI Assistant obtains a presigned upload URL through FormHelper/gRPC and then performs the actual file PUT from the browser. This is a data-plane transfer rather than direct business-API orchestration. Keep it as an **explicit documented exception** only if the storage security review confirms that the URL is short-lived, scoped to one object/operation, and contains no reusable credential.

---

## 8. Outlook subsystem classification

### 8.1 CymBuild_Outlook_API

Current positives for Kubernetes:

- ASP.NET Core web service.
- OBO token cache is persisted in SQL (`SOffice.OutlookMsalTokenCache`), which avoids in-memory-only token state.
- Data Protection keys are persisted to SQL.
- No `Database.Migrate()`/`EnsureCreated()` runtime call was found in the inspected startup path.

Current blocker:

```csharp
.PersistKeysToDbContext<DataProtectionKeyContext>()
.ProtectKeysWithDpapi();
```

DPAPI is Windows-specific. Do not choose a Linux image until key protection is replaced with an approved cross-platform mechanism (for example an enterprise certificate/key store or approved secret-management integration). The exact SOCOTEC key-custody standard is an open infrastructure/security decision.

### 8.2 CymBuild_Outlook_Service

Current code:

- uses `.UseWindowsService()`;
- hosts a single `Worker`;
- repeatedly calls a hard-coded `https://localhost:7256/api/Message` example URL every ten seconds.

This is not suitable to translate directly into Kubernetes. Confirm whether this service is genuinely part of the current live Outlook workflow. Until confirmed, keep the project in source but exclude it from the first deployment matrix.

---

## 9. AI Error service classification

`CymBuild_AIErrorServiceAPI` should not be copied into Kubernetes unchanged.

Observed gates:

- `.UseWindowsService()` is enabled.
- startup writes `before-startup.txt` and error files under `AppContext.BaseDirectory`.
- Azure AD authentication/authorization registration is currently commented out in `Program.cs` while `UseAuthentication/UseAuthorization` remains in the pipeline.
- CORS is hard-coded to a localhost origin.
- `JiraSyncRetryService` selects unsynced rows without a database claim/lease; multiple replicas can create duplicate Jira tickets.
- `JiraSyncSchedulerService` uses an in-process `Timer`, `async void`, no distributed leader/claim, and calls the service's own HTTPS endpoint using configuration/local defaults. Every replica would run the same schedule.

**Initial decision:** do not make this a dependency of the first core PWA/API Kubernetes cutover. Keep existing hosting until an explicit remediation work package is completed, unless the service owner confirms it is unused and can remain disabled.

---

## 10. Health, readiness and shutdown requirements before Kubernetes

The inspected core services do not currently expose a standard ASP.NET Core health-check surface suitable for Kubernetes probes.

Before production manifests are written:

1. Add separate liveness/readiness endpoints to the core API runtime.
2. Liveness must not fail just because SQL/Kafka/Wrapper is temporarily unavailable.
3. Readiness should prove the process is ready to serve requests; dependency checks must be chosen carefully to avoid cluster-wide restart/traffic oscillation during external outages.
4. Worker roles require a process liveness endpoint and role-identification telemetry.
5. Background workers must honour cancellation and not begin new work after termination starts.
6. Kubernetes `terminationGracePeriodSeconds` must exceed the normal bounded shutdown time for each role.
7. Long-running external calls must have explicit timeouts shorter than stale-claim/lease windows, or the lease must be renewable.

---

## 11. Initial Kubernetes scaling policy

| Deployment | Initial replicas | May scale immediately? | Reason |
|---|---:|---|---|
| PWA | 2 | Yes, after service-worker/Ingress smoke tests | static/stateless browser assets |
| API | 2 | Yes **only in ApiOnly mode** | current worker coupling otherwise duplicates background processing |
| Invoice worker | 1 | No operational need | SQL application lock serialises work globally |
| Workflow outbox worker | 1 | No | notification queue materialisation lacks ownership lease |
| SharePoint repair worker | 1 | **No** | outbox claim has no ownership token |
| Sage submission worker | 1 | Not yet | needs Wrapper-side idempotency/crash-window proof |
| Sage inbound worker | 1 | Not yet | stale claim has no owner token on completion |
| Outlook API | 0 initially | No | Linux DPAPI/security decision outstanding |
| Outlook Service | 0 | No | current purpose/implementation unresolved |
| AI Error service | 0 initially | No | security and multi-instance scheduler defects |

---

## 12. Required code work before production Dockerfiles

### R2A — Runtime-role foundation (no default behaviour change)

- Add strongly typed `CymBuildRuntimeOptions`.
- Preserve default `Combined` behaviour.
- Register hosted services through one deterministic worker-role registration path.
- Add startup validation for invalid mode/worker combinations.
- Add tests proving `Combined`, `ApiOnly`, and each `WorkerRole` registers exactly the expected hosted services.
- Add role information to startup logging.

### R2B — Remove retired Sage UI dependency

- Remove the generated Sage200 gRPC client requirement from `FormHelper`.
- Remove Sage client injections that exist only to construct FormHelper.
- Remove `Grpc:SageApi` and `SageIntegrationAPI` registration from the PWA where no longer required.
- Keep the legacy Sage microservice source projects intact but outside build/deployment scope.
- Add an architecture test preventing future PWA/API.Client references to `Sage200Microservice`.

### R2C — Correct direct UI business API bypasses

- Move monthly invoice-series generation behind FormHelper/gRPC.
- Remove/rework the direct `KafkaTest` integration call.
- Convert legacy postcode developer direct calls to the existing FormHelper lookup methods.
- Define the migration path for AI Error reporting/admin traffic.

### R2D — Probe and shutdown foundation

- Add API liveness/readiness endpoints.
- Add worker-role liveness/diagnostic endpoint or equivalent process probe.
- Add deterministic shutdown tests for claimed work.

Only after R2A-R2D should the production Dockerfile/Kubernetes manifest work package begin.

---

## 13. Tests required before raising any worker above one replica

1. Two worker processes race to claim the same work item.
2. First worker crashes immediately after claim.
3. First worker crashes after external side effect but before database success mark.
4. Processing exceeds the stale-claim/lease timeout.
5. SQL connection is lost while completion is being marked.
6. Kafka publish succeeds but database mark-published fails.
7. Pod receives SIGTERM while work is active.
8. A replacement Pod starts before the old Pod's termination grace period ends.

Expected result: no lost work, no uncontrolled duplicate business side effect, retry is bounded/audited, and ownership is enforced by SQL claim identity rather than Pod identity.

---

## 14. Information still requiring owner confirmation

These confirmations do not block R2A/R2B, but they are required before final deployment scope is frozen:

1. Is `CymBuild_AIErrorServiceAPI` currently used in QA/UAT/LIVE, or is it effectively disabled/experimental?
2. Is `CymBuild_Outlook_Service` currently installed/running anywhere, and what live business function does it perform? The inspected worker appears to be example/placeholder logic.
3. Who owns deployment and availability of the Sage Wrapper service, and is Wrapper-side idempotency available for `CreateSalesOrder`?
4. What SOCOTEC-approved cross-platform key-protection/secret-management mechanism should replace Outlook API DPAPI when moved to Linux RKE2?

---

## 15. WP2 analysis conclusion

The source is suitable to proceed, but **safe Kubernetes scaling requires a runtime-role separation before containerisation**. The five API-hosted workers do not share the same concurrency guarantees, so the first deployment must isolate them at one replica each rather than relying on API replica count.

The recommended next engineering change is **R2A Runtime-role foundation**, followed by **R2B removal of the retired Sage PWA client dependency**. Both can be implemented with backward-compatible defaults and covered by the existing fast test suite before any Docker/Kubernetes behaviour is introduced.
