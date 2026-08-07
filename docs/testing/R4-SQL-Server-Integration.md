# R4 — SQL Server integration foundation and controlled provisioning

## Purpose

R4 establishes the first real SQL Server test suite for CymBuild's persistence invariants. It does not use EF InMemory or SQLite, and it must never target DEV, QA, UAT, LIVE, or another shared database.

R4D completes the foundation by adding a controlled bootstrap path for an empty dedicated SQL Server database. The bootstrap is deliberately limited to the schema and deterministic reference data required by the 22 R4 cases.

## Projects and tools

- `tests/CymBuild.Database.IntegrationTests`
- `tools/Testing/Invoke-CymBuildSqlIntegrationTests.ps1`
- `tools/Testing/Initialize-CymBuildSqlTestDatabase.ps1`
- `tools/Testing/R4-Sql-Test-Schema.json`
- `tests/CymBuild.Database.IntegrationTests/Database/R4-Test-Compatibility.sql`
- `tests/CymBuild.Database.IntegrationTests/Database/R4-Test-Fixtures.sql`

The test project is part of the root solution but is excluded from `Invoke-CymBuildFastTests.ps1` by its `IntegrationTests` suffix.

## Safety boundary

The runner and provisioner require a dedicated database whose name starts with `CymBuild_Test_`. An alternative exact name can be used only through the explicit `-AllowedDatabaseName` parameter.

Neither tool creates, drops, restores, truncates, or deletes a database. The database must already exist and be accessible to the Windows or SQL identity executing the command.

The provisioner:

1. validates the database-name safety boundary;
2. validates normalized SHA-256 hashes for every canonical source SQL file;
3. acquires a transaction-owned SQL application lock;
4. creates only missing R4 schema objects;
5. applies current canonical procedures using `CREATE OR ALTER`;
6. seeds deterministic fixture rows idempotently;
7. creates the matching `SCore.DataObjects` identities;
8. verifies all schema and fixture contracts;
9. commits only when every verification passes.

Any failure rolls back the transaction.

## Source-of-truth model

Table and procedure definitions are read directly from:

```text
Database/CymBuild_DB/Schema
```

The manifest identifies the exact source files and batches required by R4 and locks them by normalized SHA-256. A source change therefore cannot be applied silently; the manifest must be reviewed and updated deliberately.

The dedicated test database uses `PRIMARY` in place of the production `METADATA` filegroup because LocalDB and disposable test databases normally contain only `PRIMARY`. This is a physical-storage substitution only; logical columns, keys, indexes, filtered predicates, and procedure bodies remain source-derived.

Seven empty compatibility tables are installed for deferred references in the unchanged canonical DataObject/workflow procedures. They contain no business fixtures and their branches are not exercised by R4.

Audit and notification triggers are not installed by the minimal R4 bootstrap because the R4 suite disables those side effects and does not test their behaviour. A test-only `SCore.GetCurrentUserDefaultGroup` compatibility function is created only when the canonical function is absent. It returns `-1`; the exercised upsert path passes `@IncludeDefaultSecurity = 0`, so this compatibility dependency is never used for a business decision.

## Deterministic fixture data

R4D seeds stable test-only rows for:

- EntityTypes;
- EntityHobts;
- one Group;
- one active Identity;
- two WorkflowStatus rows;
- one NonActivityType.

All fixture inserts use explicit column lists. Every seeded entity and metadata row receives a matching active `SCore.DataObjects` row with the correct `EntityTypeId`.

The fixture script is idempotent by stable GUID. It never uses `MERGE`, `DELETE`, `TRUNCATE`, or `DROP`, and it does not directly update RowStatus.

## Coverage

R4 contains 22 executed SQL Server cases:

| Area | Cases |
|---|---:|
| Database safety and schema contracts | 6 |
| DataObject identity and entity upsert invariants | 4 |
| Workflow transition and latest-state invariants | 5 |
| IntegrationOutbox persistence, leases, active-row filtering, and concurrency | 7 |
| **Total** | **22** |

## First run against an empty LocalDB database

Run PowerShell under the same normal Windows identity that owns the LocalDB instance. Where the workstation has `AllSigned` at LocalMachine scope, use a process-only bypass:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

Then provision and execute:

```powershell
.\tools\Testing\Invoke-CymBuildSqlIntegrationTests.ps1 `
    -ConnectionString 'Server=(localdb)\MSSQLLocalDB;Database=CymBuild_Test_R4;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=10' `
    -ProvisionDatabase
```

Provision without executing tests:

```powershell
.\tools\Testing\Invoke-CymBuildSqlIntegrationTests.ps1 `
    -ConnectionString 'Server=(localdb)\MSSQLLocalDB;Database=CymBuild_Test_R4;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=10' `
    -ProvisionDatabase `
    -ProvisionOnly
```

Verify an already provisioned database:

```powershell
.\tools\Testing\Initialize-CymBuildSqlTestDatabase.ps1 `
    -ConnectionString 'Server=(localdb)\MSSQLLocalDB;Database=CymBuild_Test_R4;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=10' `
    -VerifyOnly
```

Run without `-ProvisionDatabase` only after verification succeeds:

```powershell
.\tools\Testing\Invoke-CymBuildSqlIntegrationTests.ps1 `
    -ConnectionString 'Server=(localdb)\MSSQLLocalDB;Database=CymBuild_Test_R4;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=10'
```

The runner requires exactly 22 passed, 0 failed, and 0 skipped, and writes TRX, Cobertura, and `sql-integration-test-run.json` beneath `TestResults/sql-integration`.

## Deliberate exclusions

R4D is a minimal contract database, not a complete CymBuild application database. It does not deploy UI metadata, onboarding data, all business tables, audit triggers, notification triggers, or integration services.

Schema/metadata migration lifecycle testing, constraint replacement, persistent exclusions, full migration-plan execution, invoice trigger-ledger application locks, and hosted API/gRPC tests remain later tranches.
