# CymBuild Troubleshooting Playbooks

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

## Workflow/status issue

Trace `UI → FormHelper → API → EF/SQL → DataObjects → latest DataObjectTransition`. Confirm the correct `EntityTypeId`, workflow/status/transition metadata, and use `SCore.DataObjectTransitionUpsert` for correction. Never update status directly.

## Grid or dropdown issue

1. Confirm the SQL source returns the expected alias with explicit columns.
2. Confirm parent metadata and active filters use `RowStatus <> 0 AND RowStatus <> 254`.
3. Check Grid → View → Column ordering, labels, formats, query parameters and duplicate active definitions.
4. Check the metadata run, identity map, ignored/selected rows, Apply Preview and execution log.
5. Trace the UI call through FormHelper; clear only appropriate client metadata caches after server state is verified.

## Missing DataObject

A missing identity row can break workflow, security, automation and integration. Confirm the business record GUID and `EntityTypeId`. Remediate through an approved idempotent procedure, then correct the insert path so the business row and `DataObjects` row are created atomically. Do not adopt insert-then-update identity repair as normal behavior.

## Metadata migration failure

1. Read `SMigration.Metadata_Run` and `SMigration.Metadata_ExecutionLog`.
2. Review staged counts and validation issues.
3. Build/rebuild identity map only through the workbench/API flow.
4. Inspect unresolved, ignored and overridden issues.
5. Confirm selection and Apply Preview represent the intended rows.
6. Do not edit target metadata directly.
7. Treat manifests as ValidateOnly/governance evidence, not a substitute for the run.

## Schema migration failure

1. Inspect the accepted plan from `SMigration.SchemaDeploymentPlan_Get`.
2. Review `unsupported-items.csv`, `manual-preview-deployment.sql`, and `SMigration.Schema_ExecutionLog`.
3. Confirm the selected object maps to canonical SQL under `Database/CymBuild_DB/Schema`.
4. Use `-WhatIf`; it must not write deployment/audit state.
5. Do not use `-AllowPartial` when the full accepted plan is required.
6. For a failed reviewed run, use `-RetryFailedDeployment` only after the source-controlled correction is reviewed.
7. If failure occurs after `PreDeploymentScript`, confirm R27 recovery or the subsequent successful `PostDeploymentScript` result.
8. Recompare after a successful deployment rather than rewriting the historical run.

## Sage/integration failure

Trace:

```text
Source record → DataObject → IntegrationOutbox/module ledger
→ worker → Sage200Microservice → external response → diagnostics/retry
```

Check idempotency, batch/transaction state, worker logs and approved requeue. Do not add a direct Sage call from PWA or Concursus API business paths.

## Invoice automation issue

Check `InvoiceSchedule` intent, schedule configuration, `InvoiceScheduleTriggerInstances` idempotent execution ledger, generated InvoiceRequest/Items, RIBA attribution, transaction state and worker audit. Re-running must not duplicate requests.

## Non-Telerik regression

Compare old/new feature inventories; confirm FormHelper flow, metadata rendering, search/filter/sort/page/export, actions, modals, dropdowns, validation, loading/empty/error states and shared CSS. No behavior loss is acceptable.
