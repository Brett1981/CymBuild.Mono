# CymBuild Integration Guide

CymBuild integrations must be idempotent, diagnosable, and server-controlled.

## Core integration rule

Use `SCore.IntegrationOutbox` or the approved module-specific outbox pattern.

Do not make external integration calls directly from the UI.

## Sage integration

Relevant areas in the supplied snapshot include:

- `services/Concursus.API/Services/CoreService.Sage.cs`
- `services/Concursus.API/Services/Finance/SageInboundPaymentSyncService.cs`
- `services/Concursus.API/Services/Finance/SageInboundPaymentSyncWorker.cs`
- `services/Concursus.API/Services/Finance/SageTransactionSubmissionWorker.cs`
- `services/Concursus.API/Services/Finance/TransactionToSageIdempotencyService.cs`
- `libs/Concursus.EF/Finance/*Sage*Repository.cs`
- `services/SageAPI`
- `services/Sage200Microservice`
- `Database/CymBuild_DB/Schema/Tables/SCore.IntegrationOutbox.sql`

## Integration principles

- Use an idempotency key.
- Store enough payload/context to diagnose failures.
- Avoid duplicate external effects.
- Track status and retry state.
- Keep failed records visible for diagnostics.
- Requeue/replay only through approved mechanisms.

## Outlook/SharePoint integration

Relevant areas include:

- `apps/CymBuild_Outlook_Addin`
- `services/CymBuild_Outlook_API`
- `services/CymBuild_Outlook_Service`
- `libs/CymBuild_Outlook_Common`
- `services/Concursus.API/Services/SharepointService.cs`
- `services/Concursus.API/Services/CoreService.Documents.cs`
- `services/Concursus.API/Services/CoreService.Documents.Email.cs`

## Background processing

Workers should be safe to restart and should not create duplicate external effects.

Relevant patterns include:

- Worker options classes.
- Repository/service split.
- Idempotency repository/service.
- Diagnostic/requeue API methods.

## BlueGen troubleshooting route

For integration problems, trace:

```text
Source record → DataObject → Outbox/integration table → Worker/service → External API → Diagnostics/retry state
```
