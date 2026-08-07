# CymBuild Integration Guide

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

CymBuild integrations are server-controlled, idempotent, auditable and retry-safe.

## Mandatory boundary

```text
PWA → FormHelper → gRPC/API → business transaction/outbox
→ worker/microservice → external system
```

Use `SCore.IntegrationOutbox` for integration events. Do not call external systems directly from UI, and CymBuild must never call Sage directly.

## Sage

Active 26.3 areas include:

- `services/Concursus.API/Services/CoreService.Sage.cs`
- `services/Concursus.API/Services/Finance/SageInboundPaymentSyncService.cs`
- `services/Concursus.API/Services/Finance/SageInboundPaymentSyncWorker.cs`
- `services/Concursus.API/Services/Finance/SageTransactionSubmissionWorker.cs`
- `services/Concursus.API/Services/Finance/TransactionToSageIdempotencyService.cs`
- `libs/Concursus.EF/Finance`
- `services/Sage200Microservice`
- `Database/CymBuild_DB/Schema/Tables/SCore.IntegrationOutbox.sql`

`services/SageAPI_TEMP_DISABLED` must not be documented or used as the active integration route.

## Outlook and SharePoint

- `apps/CymBuild_Outlook_Addin`
- `services/CymBuild_Outlook_API`
- `services/CymBuild_Outlook_Service`
- `libs/CymBuild_Outlook_Common`
- `services/Concursus.API/Services/SharepointService.cs`
- `services/Concursus.API/Services/CoreService.Documents.cs`
- `services/Concursus.API/Services/CoreService.Documents.Email.cs`

Use current Microsoft Graph through controlled server services where Graph is relevant. Keep SharePoint path/permission logic server-controlled.

## Implementation rules

- Use stable idempotency keys and execution ledgers.
- Create outbox records atomically with the business event where possible.
- Store source GUID, event type, payload and diagnostic context.
- Workers must tolerate restart and duplicate delivery.
- Do not mark integration complete merely because the PWA request succeeded.
- Keep failed records visible; requeue only through approved APIs/procedures.
- Use microservices for external SOAP/REST systems; no direct UI/API coupling.

## Troubleshooting route

```text
Source row → DataObject → latest transition → outbox/module ledger
→ worker logs → microservice request/response → external result
→ retry/requeue audit
```
