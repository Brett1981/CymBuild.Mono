# Repository Inventory

Generated from the uploaded `CymBuild-Telerik.zip` snapshot.

## Solution and projects

- `CymBuild.Monorepo.sln`
- `apps/Concursus.Metadata.Tools/Concursus.Metadata.Tools.csproj`
- `apps/Concursus.PWA/Concursus.PWA.csproj`
- `apps/CymBuild_Outlook_Addin/CymBuild_Outlook_Addin.csproj`
- `libs/Concursus.API.Client/Concursus.API.Client.csproj`
- `libs/Concursus.API.Client/Concursus.API.Client.sln`
- `libs/Concursus.Common.Shared/Concursus.Common.Shared.csproj`
- `libs/Concursus.Common.Shared/Concursus.Common.Shared.sln`
- `libs/Concursus.Components.Shared/Concursus.Components.Shared.csproj`
- `libs/Concursus.Components.Shared/Concursus.Components.Shared.sln`
- `libs/Concursus.EF/Concursus.EF.csproj`
- `libs/CymBuild_Outlook Manifest/CymBuild_Outlook.csproj`
- `libs/CymBuild_Outlook_Common/CymBuild_Outlook_Common.csproj`
- `services/Concursus.API/Concursus.API.csproj`
- `services/Concursus.API/Concursus.API.sln`
- `services/CymBuild_AIErrorServiceAPI/CymBuild_AIErrorServiceAPI.csproj`
- `services/CymBuild_AIErrorServiceAPI/CymBuild_AIErrorServiceAPI.sln`
- `services/CymBuild_Outlook_API/CymBuild_Outlook_API.csproj`
- `services/CymBuild_Outlook_Service/CymBuild_Outlook_Service.csproj`
- `services/PostCodeLookup/PostCodeLookup.csproj`
- `services/Sage200Microservice/Sage200Microservice.API/Sage200Microservice.API.csproj`
- `services/Sage200Microservice/Sage200Microservice.Data/Sage200Microservice.Data.csproj`
- `services/Sage200Microservice/Sage200Microservice.Services/Sage200Microservice.Services.csproj`

## Key project areas

| Area | Path | Notes |
|---|---|---|
| PWA | `apps/Concursus.PWA` | Blazor WebAssembly UI; Pages, Shared components, css, modals, dynamic grids. |
| API client | `libs/Concursus.API.Client` | FormHelper and client-facing wrappers. |
| API | `services/Concursus.API` | CoreService, UiService, Finance, Sage, MetadataMigration, Assistant, Outbox, SharePoint. |
| EF | `libs/Concursus.EF` | Core/UserInterface metadata building, QueryBuilder, repositories, Finance, MetadataManifests. |
| Shared components | `libs/Concursus.Components.Shared` | Reusable controls and non-Telerik component candidates. |
| Database | `Database/CymBuild_DB` | Schema, procedures, functions, views, static data, upgrade scripts. |
| Metadata tools | `apps/Concursus.Metadata.Tools` | Metadata validation tooling. |
| Outlook add-in | `apps/CymBuild_Outlook_Addin` | Outlook/Office JS filing UI. |
| Outlook API/service | `services/CymBuild_Outlook_API and services/CymBuild_Outlook_Service` | Outlook/SharePoint filing backend/support services. |
| Sage API/microservice | `services/SageAPI and services/Sage200Microservice` | Sage integration services. |
| Assistant | `services/Concursus.API/Services/Assistant and SAi SQL schema` | BlueGen/CymBuild assistant service surface. |

## Confirmed high-value files

- `apps/Concursus.PWA/Shared/DynamicBatchGridViewV2.razor`
- `apps/Concursus.PWA/Shared/DynamicBatchGridViewV2.razor.cs`
- `apps/Concursus.PWA/Shared/DynamicBatchGridViewV2.razor.css`
- `apps/Concursus.PWA/Shared/Diagnostics/SageInboundDiagnosticsV2.razor`
- `apps/Concursus.PWA/Pages/Admin/MetadataMigration.razor`
- `apps/Concursus.PWA/Pages/Admin/OnboardingMigration.razor`
- `libs/Concursus.API.Client/FormHelper.cs`
- `services/Concursus.API/Services/CoreService.cs`
- `services/Concursus.API/Services/UiService.cs`
- `services/Concursus.API/Services/CoreService.Sage.cs`
- `services/Concursus.API/Services/CoreService.MetadataMigration.cs`
- `services/Concursus.API/Services/InvoiceAutomation/InvoiceAutomationScheduledWorker.cs`
- `services/Concursus.API/Services/InvoiceAutomation/InvoiceAutomationRepository.cs`
- `services/Concursus.API/Services/Finance/SageTransactionSubmissionWorker.cs`
- `services/Concursus.API/Services/Finance/SageInboundPaymentSyncWorker.cs`
- `services/Concursus.API/Services/Outbox/WorkflowOutboxRepository.cs`
- `libs/Concursus.EF/Core.cs`
- `libs/Concursus.EF/UserInterface.cs`
- `libs/Concursus.EF/QueryBuilder.cs`
- `libs/Concursus.EF/MetadataManifests/ValidateOnly/README.md`
- `Database/CymBuild_DB/Schema/Programmability/Procedures/SCore.DataObjectTransitionUpsert.sql`
- `Database/CymBuild_DB/Schema/Tables/SCore.DataObjects.sql`
- `Database/CymBuild_DB/Schema/Tables/SCore.IntegrationOutbox.sql`
- `Database/CymBuild_DB/Schema/Tables/SCore.DataClassifications.sql`
- `Database/CymBuild_DB/Schema/Tables/SCore.SecurityClassifications.sql`
- `Database/CymBuild_DB/Schema/Programmability/Procedures/SMigration.MetadataValidate_Run.sql`
- `Database/CymBuild_DB/Schema/Programmability/Procedures/SMigration.MetadataApply_Run.sql`
