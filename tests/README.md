# CymBuild automated testing

This folder contains the shared conventions and repository-level test infrastructure for CymBuild.

## Mandatory boundaries

Automated tests must preserve the production flow:

```text
Blazor PWA -> FormHelper/API.Client -> gRPC API -> EF -> SQL Server
```

Tests must not introduce direct UI-to-API, UI-to-EF, or UI-to-SQL dependencies. Business decisions remain outside Razor components. Database tests must deploy source-controlled SQL to disposable databases; they must never write to shared DEV, QA, UAT, or LIVE databases.

## Test levels

Use xUnit traits so tests can be selected consistently:

```csharp
[Trait("Level", "Unit")]
[Trait("Area", "Finance")]
```

Supported levels are `Unit`, `Component`, `Architecture`, `Integration`, `Database`, and `EndToEnd`. Area values should use stable subsystem names such as `Finance`, `Workflow`, `Outbox`, `SchemaMigration`, `MetadataMigration`, `Outlook`, `PostCode`, and `Sage`.

## Determinism

Tests must not depend on wall-clock time, random ordering, developer machine settings, live credentials, or shared mutable data. Use controlled clocks, explicit ordering, stable identifiers, fake external clients, and isolated SQL Server databases as appropriate.

## Commands

Run the current fast test portfolio with coverage:

```powershell
.\tools\Testing\Invoke-CymBuildFastTests.ps1 -Configuration Release
```

List the discovered fast projects without executing them:

```powershell
.\tools\Testing\Invoke-CymBuildFastTests.ps1 -ListOnly
```

Generate a repository test baseline report:

```powershell
.\tools\Testing\Get-CymBuildTestBaseline.ps1
```

Results are written below the ignored root `TestResults` directory. R0 records coverage but deliberately sets no global percentage threshold. Coverage gating will be introduced as a project-specific ratchet after the first substantive test projects are established.

## R1 foundational projects

R1 adds the first grouped fast-test projects:

- `CymBuild.Architecture.Tests`
- `Concursus.Common.Shared.Tests`
- `Concursus.EF.Tests`

It also expands `Concursus.API.Tests` with finance eligibility and exact outbound payload serialization tests. These remain fast tests and are discovered automatically by `Invoke-CymBuildFastTests.ps1`.

Architecture tests intentionally lock currently compliant project and persistence boundaries. Existing legacy PWA HTTP usage is documented technical debt and is not silently approved as the target architecture; it will be characterised and migrated behind FormHelper/API.Client in later tranches without behaviour loss.

## R2 FormHelper and metadata-driven UI projects

R2 adds:

- `Concursus.API.Client.Tests` for controlled gRPC request/reply mapping, validation, error handling, and deterministic client helpers;
- `Concursus.Components.Shared.Tests` for `ViewDefinitionBuilder`, `V2DropdownLoader`, `V2FormRenderer`, and `V2FieldEditor`.

The API Client suite uses an in-process `CallInvoker` test double. It does not call a live API, bypass FormHelper, or introduce UI-to-API coupling. The component suite uses bUnit for rendered component assertions and continues to treat EntityType/EntityProperty metadata and `DataObject` values as the source of truth.

## R3 API orchestration and workers

R3 expands `Concursus.API.Tests` with deterministic coverage for transaction-to-Sage orchestration, inbound payment synchronization, submission administration, hosted-worker disabled paths, Sage configuration validation, invoice automation guards, and outbox payload contracts.

External boundaries are mocked at their existing interfaces. The tests do not call live Sage, Kafka, SQL Server, or shared environments. Database atomicity, stored procedures, DataObjects, workflow transitions, outbox persistence, and application-lock behaviour remain reserved for the dedicated SQL Server integration tranche.

## R4 SQL Server integration tests

R4 adds `CymBuild.Database.IntegrationTests`. It is deliberately excluded from the fast-test runner and must run against a dedicated disposable SQL Server database.

The database name must start with `CymBuild_Test_` unless the runner is given an exact explicit allow-list name. The runner rejects system databases and does not print or persist the supplied connection string.

For an empty dedicated database, provision the source-derived R4 contract schema and run the suite in one command:

```powershell
.\tools\Testing\Invoke-CymBuildSqlIntegrationTests.ps1 `
    -ConnectionString 'Server=(localdb)\MSSQLLocalDB;Database=CymBuild_Test_R4;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=10' `
    -ProvisionDatabase
```

The provisioner adds empty test-only compatibility tables for deferred legacy procedure references, then reads the reviewed table and procedure definitions directly from `Database\CymBuild_DB\Schema`, validates their normalized hashes, applies only missing objects transactionally, and seeds deterministic DataObjects-compliant fixture rows. It does not create, drop, restore, truncate, or delete a database.

Subsequent runs may omit `-ProvisionDatabase`; the runner performs a fail-fast provisioning check before starting xUnit.

The suite executes the real SQL Server procedures and repository SQL for DataObjects, workflow transitions, active-row filters, stored-procedure idempotency, outbox lease ownership, retry recording, and concurrent claims. Transaction-scoped entity/workflow fixtures are rolled back; outbox rows are identified by generated GUIDs and removed in `finally` blocks.

Never point this runner at `CymBuild_Dev`, QA, UAT, LIVE, or another shared database.
