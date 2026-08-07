# R4 — SQL Server integration foundation

## Purpose

R4 establishes the first real SQL Server test suite for CymBuild's persistence invariants. It does not use EF InMemory or SQLite and it does not call DEV, QA, UAT, or LIVE.

## New project

`tests/CymBuild.Database.IntegrationTests`

The project is part of the root solution but is excluded from `Invoke-CymBuildFastTests.ps1` by its `IntegrationTests` suffix. It is executed separately by `tools/Testing/Invoke-CymBuildSqlIntegrationTests.ps1`.

## Safety boundary

The runner requires a dedicated database whose name starts with `CymBuild_Test_`. An alternative exact name can be allowed only through the explicit `-AllowedDatabaseName` parameter.

The test database must be provisioned through the controlled schema and metadata deployment process. No test creates or promotes schema manually, and no connection string is written to source control or result summaries.

## Coverage

R4 adds 22 executed SQL Server cases:

| Area | Cases |
|---|---:|
| Database safety and schema contracts | 6 |
| DataObject identity and entity upsert invariants | 4 |
| Workflow transition and latest-state invariants | 5 |
| IntegrationOutbox persistence, leases, active-row filtering, and concurrency | 7 |
| **Total** | **22** |

### DataObjects

The suite verifies that a production entity upsert creates exactly one entity row and one `SCore.DataObjects` row with the same GUID, active RowStatus, non-null rowversion, and the correct EntityTypeId resolved from `SCore.EntityHobts`.

Repeated upserts must update the existing row rather than duplicate identity. Caller-managed rollback must remove both the entity and DataObject. `SCore.UpsertDataObject` must reject an existing DataObject whose entity row is missing.

### Workflow

The suite invokes `SCore.DataObjectTransitionUpsert` directly and verifies:

- every transition has its own matching DataObject;
- latest active transition is the current state;
- reuse of a transition GUID updates one transition rather than duplicating it;
- an invalid record GUID rolls back transition identity;
- workflow transitions do not directly change `SCore.DataObjects.RowStatus`.

### Outbox

The suite invokes the production `WorkflowOutboxRepository` SQL against SQL Server and verifies:

- claims assign a lease token and increment attempts;
- concurrent claims do not return the same rows;
- RowStatus 0 and 254 rows are not claimed;
- publish completion requires the owning token;
- failure recording truncates errors and releases the lease;
- expired leases can be reclaimed.

## Running

```powershell
.\tools\Testing\Invoke-CymBuildSqlIntegrationTests.ps1 `
    -ConnectionString 'Server=<DEV SQL instance>;Database=CymBuild_Test_R4;Integrated Security=True;TrustServerCertificate=True'
```

The runner requires exactly 22 passed, 0 failed, and 0 skipped, and writes TRX, Cobertura, and `sql-integration-test-run.json` beneath `TestResults/sql-integration`.

## Deliberate exclusions

R4 does not yet cover the schema/metadata migration lifecycle, migration exclusions, constraint replacement, invoice trigger-ledger application locks, or full hosted API/gRPC behaviour. Those remain R5 and later tranches.
