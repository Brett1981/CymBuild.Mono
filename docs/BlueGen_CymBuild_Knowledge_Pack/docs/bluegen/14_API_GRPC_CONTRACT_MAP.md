# API and gRPC Contract Map

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

Generated from the 26.3 source-of-truth repository after applying CYB361 R22–R27.

## Mandatory flow

```text
PWA component → FormHelper partial → core.proto RPC
→ CoreService partial → EF/repository/SQL
```

## FormHelper partials

| File | Main surface |
|---|---|
| `FormHelper.cs` | General data objects, grids, dropdowns, documents, finance, Sage orchestration, schedules and shared operations. |
| `FormHelper.SchemaMigration.cs` | Schema run create/list/get, compare, objects/detail, lightweight selection save/clear, validate, plan, review and deployment outcome. |
| `FormHelper.MetadataMigration.cs` | Run, stage, validate, identity map review/details/candidates/override, selection, ignore, preview, apply and dashboard. |
| `FormHelper.OnboardingMigration.cs` | OnBoarding stage, scope, selections, validate, apply, report and audit. |
| `FormHelper.AIAssistant.cs` | Conversations, messages, knowledge search, bookmarks and feedback. |
| `FormHelper.AIAssistant.Uploads.cs` | Upload presign/complete/list. |
| `FormHelper.AIAssistantKnowledgeImport.cs` | Knowledge import. |
| `FormHelper.DeveloperInspector.cs` | Developer inspector. |
| `FormHelper.UniversalSearch.cs` | Universal search. |

## Schema Migration contracts

FormHelper methods:

- `SchemaMigrationRunCreateAsync`
- `SchemaMigrationRunsAsync`
- `SchemaMigrationRunGetAsync`
- `SchemaMigrationCompareAsync`
- `SchemaMigrationValidateAsync`
- `SchemaMigrationDashboardAsync`
- `SchemaMigrationObjectsAsync`
- `SchemaMigrationObjectDetailAsync`
- `SchemaMigrationSelectionSaveAsync`
- `SchemaMigrationSelectionClearAsync`
- `SchemaMigrationDeploymentPlanAsync`
- `SchemaMigrationReviewSetAsync`
- `SchemaMigrationDeploymentOutcomeAsync`

Corresponding `core.proto` RPCs use the same operation names without `Async`. Comparison/object list responses are lightweight; full source/target SQL is loaded only for one selected object detail. Selection save sends selected comparison GUIDs, not full SQL definitions.

## Metadata Migration contracts

FormHelper methods include:

- `MetadataMigrationRunCreateAsync`, `MetadataMigrationRunsAsync`, `MetadataMigrationRunGetAsync`
- `MetadataMigrationStageAsync`, `MetadataMigrationValidateAsync`
- `MetadataMigrationBuildIdentityMapAsync`
- `MetadataMigrationIdentityMapReviewSetAsync`
- `MetadataMigrationIdentityMapDetailsAsync`
- `MetadataMigrationIdentityMapIssueUpsertAsync`
- `MetadataMigrationIdentityMapCandidatesAsync`
- `MetadataMigrationIdentityMapOverrideUpsertAsync`
- `MetadataMigrationSelectionUpsertAsync`, `MetadataMigrationSelectionClearAsync`
- `MetadataMigrationIgnoreUpsertAsync`, `MetadataMigrationIgnoredRecordsAsync`
- `MetadataMigrationApplyPreviewAsync`, `MetadataMigrationApplyAsync`, `MetadataMigrationApplySelectedAsync`
- `MetadataMigrationEntityTypeScopeListAsync`, `MetadataMigrationEntityTypeScopeSaveAsync`
- `MetadataMigrationDashboardAsync`, `MetadataMigrationStagedRowsAsync`, `MetadataMigrationDiffAsync`

## OnBoarding contracts

`FormHelper.OnboardingMigration.cs` exposes run reservation/listing, source stage, business-unit groups, entity/stage selections, validate, apply, report, staged data, diff and audit dashboard methods.

## Proto inventory

- `services/Concursus.API/Protos/core.proto`: 177 RPC declarations in the supplied 26.3 source, including schema, metadata and OnBoarding migration surfaces.
- `services/Concursus.API/Protos/assistant_v1.proto`: 52 assistant RPC declarations.
- `services/Concursus.API/Protos/dms.proto`: 15 document/mail RPC declarations.
- `services/Concursus.API/Protos/translation.proto`: `TranslateText`.

## Service implementation files

- `services/Concursus.API/Services/CoreService.SchemaMigration.cs`
- `services/Concursus.API/Services/CoreService.MetadataMigration.cs`
- `services/Concursus.API/Services/CoreService.OnboardingMigration.cs`
- `services/Concursus.API/Services/CoreService.Finance.cs`
- `services/Concursus.API/Services/CoreService.Sage.cs`
- `services/Concursus.API/Services/CoreService.Documents.cs`
- `services/Concursus.API/Services/UiService.cs`

## Contract-change rule

A new PWA operation must be implemented end to end: UI → FormHelper → proto → service → EF/SQL. Preserve existing proto behavior and message-size controls; do not return large SQL definitions in list/filter calls.
