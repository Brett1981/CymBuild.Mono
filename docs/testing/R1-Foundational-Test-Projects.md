# R1 foundational test projects

## Purpose

R1 creates the first substantive automated safety net on top of the R0 test foundation. It adds fast, deterministic tests only and does not alter CymBuild production behaviour.

## Implemented projects

### CymBuild.Architecture.Tests

Locks the current compliant dependency path:

```text
Concursus.PWA -> Concursus.Components.Shared -> Concursus.API.Client/FormHelper
Concursus.API -> Concursus.EF -> SQL Server
```

The tests verify project-reference direction, prevent direct EF/SQL persistence code in the PWA, require FormHelper to remain in API.Client, and ensure all fast test projects are present in the root solution and import the shared R0 test configuration.

Known legacy direct HTTP usage in the PWA is not declared compliant. R1 avoids creating a permanently approved exception list before those call sites have been characterised. Later work must move business/API access behind FormHelper without behaviour loss.

### Concursus.Common.Shared.Tests

Covers deterministic utilities and finance contracts, including:

- batching and distinct-by behaviour;
- numeric clamping and value comparison;
- string truncation and full-text search preparation;
- active-row rules (`RowStatus` 0 and 254 excluded);
- Sage read-model line usability and reference selection;
- transaction usability and preferred date/reference selection;
- eligibility and process-result factory consistency.

### Concursus.EF.Tests

Tests the existing pure ValidateOnly metadata comparison engine without using EF InMemory or SQLite. Coverage includes:

- QA/UAT/LIVE unmanaged-drift severity rules;
- null versus explicitly empty managed arrays;
- missing, different and unresolvable-reference drift;
- optional-property comparison semantics;
- deterministic issue ordering;
- CI summaries, per-view rollups and exit codes.

No database behaviour is simulated. DataObjects, transitions, SQL constraints, locking and migration execution remain reserved for isolated SQL Server integration projects.

### Concursus.API.Tests expansion

Adds tests for every major `TransactionToSageEligibilityValidator` decision and verifies that `ApprovedTransactionForSagePayloadFactory` serializes the exact wrapper property names while omitting null optional values.

## Acceptance criteria

R1 is accepted when:

1. The root solution builds in Release configuration.
2. The fast runner discovers five test projects.
3. All five projects pass.
4. Each project produces a TRX file and Cobertura attachment.
5. The generated baseline reports five test projects.
6. No production, SQL, metadata, workflow, DataObjects, outbox or integration file is changed.
