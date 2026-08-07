# Repository Inventory

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

Generated from the current source-of-truth repository, with CYB361 R22–R27 overlaid to represent the verified 26.3 schema deployment baseline.

## Solution and projects

- `CymBuild.Monorepo.sln`
- `Concursus.Metadata.Tools.csproj`
- `apps/Concursus.Metadata.Tools/Concursus.Metadata.Tools.csproj`
- `apps/Concursus.PWA/Concursus.PWA.csproj`
- `apps/Concursus.PWA.Tests/Concursus.PWA.Tests.csproj`
- `apps/CymBuild_Outlook_Addin/CymBuild_Outlook_Addin.csproj`
- `libs/Concursus.API.Client/Concursus.API.Client.csproj`
- `libs/Concursus.Common.Shared/Concursus.Common.Shared.csproj`
- `libs/Concursus.Components.Shared/Concursus.Components.Shared.csproj`
- `libs/Concursus.EF/Concursus.EF.csproj`
- `libs/CymBuild_Outlook Manifest/CymBuild_Outlook.csproj`
- `libs/CymBuild_Outlook_Common/CymBuild_Outlook_Common.csproj`
- `services/Concursus.API/Concursus.API.csproj`
- `services/CymBuild_AIErrorServiceAPI/CymBuild_AIErrorServiceAPI.csproj`
- `services/CymBuild_Outlook_API/CymBuild_Outlook_API.csproj`
- `services/CymBuild_Outlook_Service/CymBuild_Outlook_Service.csproj`
- `services/PostCodeLookup/PostCodeLookup.csproj`
- `services/Sage200Microservice/Sage200Microservice.API/Sage200Microservice.API.csproj`
- `services/Sage200Microservice/Sage200Microservice.Data/Sage200Microservice.Data.csproj`
- `services/Sage200Microservice/Sage200Microservice.Services/Sage200Microservice.Services.csproj`
- `tests/Concursus.API.Tests/Concursus.API.Tests.csproj`

## Key project areas

| Area | Path | 26.3 responsibility |
|---|---|---|
| Blazor PWA | `apps/Concursus.PWA` | Pages, shared components, metadata-driven forms/grids, admin migration workbenches. |
| API client | `libs/Concursus.API.Client` | `FormHelper` and partial wrappers; mandatory PWA entry point to gRPC. |
| gRPC API | `services/Concursus.API` | Core, UI, finance, Sage orchestration, documents, schema/metadata/onboarding migration, assistant and worker services. |
| EF/repositories | `libs/Concursus.EF` | SQL access, query building, repositories, metadata readers and ValidateOnly manifest tooling. |
| Shared UI | `libs/Concursus.Components.Shared` | Reusable controls including `V2FormRenderer`, `V2FieldEditor`, and shared non-Telerik styling. |
| Source-controlled schema | `Database/CymBuild_DB/Schema` | Tables, views, functions, procedures, triggers and guarded migrations. |
| Metadata migration SQL | `SQL_CI_Packs_Metadata/database` | SMigration metadata schema, stage/validate/preview/apply scripts. |
| Metadata governance | `metadata-manifests/v1` and `apps/Concursus.Metadata.Tools` | ValidateOnly/governance manifests and tooling; not the complete migration mechanism. |
| Schema deployment | `tools/SchemaDeployment` | R27 external controlled runner and runbook. |
| Outlook add-in | `apps/CymBuild_Outlook_Addin` | Office/Graph-assisted filing UI. |
| Outlook services | `services/CymBuild_Outlook_API`, `services/CymBuild_Outlook_Service` | Server-controlled Outlook/SharePoint support. |
| Sage microservice | `services/Sage200Microservice` | Controlled external Sage boundary. `services/SageAPI_TEMP_DISABLED` is not an active integration target. |
| Tests | `tests/Concursus.API.Tests`, `apps/Concursus.PWA.Tests` | API and PWA regression tests. |

## High-value 26.3 files

### Schema Migration

- `apps/Concursus.PWA/Pages/Admin/SchemaMigration.razor`
- `libs/Concursus.API.Client/FormHelper.SchemaMigration.cs`
- `services/Concursus.API/Services/CoreService.SchemaMigration.cs`
- `services/Concursus.API/Protos/core.proto`
- `Database/CymBuild_DB/Schema/Programmability/Procedures/SMigration.SchemaDeploymentPlan_Get.sql`
- `Database/CymBuild_DB/Schema/Tables/SMigration.Schema_Run.sql`
- `Database/CymBuild_DB/Schema/Tables/SMigration.Schema_RunSelections.sql`
- `Database/CymBuild_DB/Schema/Tables/SMigration.Schema_ObjectComparisons.sql`
- `Database/CymBuild_DB/Schema/Tables/SMigration.Schema_ValidationIssues.sql`
- `Database/CymBuild_DB/Schema/Tables/SMigration.Schema_ExecutionLog.sql`
- `tools/SchemaDeployment/Invoke-CymBuildSchemaDeployment.ps1`
- `tools/SchemaDeployment/README.md`
- `Database/CymBuild_DB/Schema/Migrations/_Shared/SMigration.AlterColumnNullabilityWithDependencies.sql`

### Metadata Migration

- `apps/Concursus.PWA/Pages/Admin/MetadataMigration.razor`
- `libs/Concursus.API.Client/FormHelper.MetadataMigration.cs`
- `services/Concursus.API/Services/CoreService.MetadataMigration.cs`
- `SQL_CI_Packs_Metadata/database/smigration/SMigration.Metadata.Schema.sql`
- `SQL_CI_Packs_Metadata/database/metadata/10_metadata_stage_validate_preview.sql`
- `SQL_CI_Packs_Metadata/database/metadata/20_metadata_apply_existing_validated_run.sql`
- `SQL_CI_Packs_Metadata/database/metadata/21_metadata_stage_validate_apply.sql`
- `SQL_CI_Packs_Metadata/database/metadata/30_metadata_post_apply_verify.sql`
- `metadata-manifests/v1/families/grids/grids.json`
- `metadata-manifests/v1/policies/allowlist.grids.json`
- `libs/Concursus.EF/MetadataManifests/ValidateOnly/README.md`

### Metadata-driven/non-Telerik UI

- `libs/Concursus.Components.Shared/Controls/V2FormRenderer.razor`
- `libs/Concursus.Components.Shared/Controls/V2FieldEditor.razor`
- `apps/Concursus.PWA/Shared/FilteredDynamicGridViewV2.razor`
- `apps/Concursus.PWA/Shared/DynamicBatchGridViewV2.razor`
- `apps/Concursus.PWA/Shared/Diagnostics/SageInboundDiagnosticsV2.razor`
- `libs/Concursus.Components.Shared/wwwroot/css/cymbuild-v2.css`

### Platform identity, workflow and integration

- `Database/CymBuild_DB/Schema/Tables/SCore.DataObjects.sql`
- `Database/CymBuild_DB/Schema/Tables/SCore.DataObjectTransition.sql`
- `Database/CymBuild_DB/Schema/Programmability/Procedures/SCore.DataObjectTransitionUpsert.sql`
- `Database/CymBuild_DB/Schema/Tables/SCore.IntegrationOutbox.sql`
- `services/Concursus.API/Services/Finance/SageTransactionSubmissionWorker.cs`
- `services/Concursus.API/Services/Finance/SageInboundPaymentSyncWorker.cs`
