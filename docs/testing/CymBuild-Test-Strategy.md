# CymBuild Test Strategy and Test Project Plan

**Source analysed:** `CymBuild.Monorepo(11).zip`  
**Analysis date:** 5 August 2026  
**Purpose:** establish a production-ready automated test architecture before CymBuild CI/CD and container promotion are implemented.

## 1. Executive conclusion

CymBuild has a very small automated test baseline relative to its current size and risk profile. The repository contains approximately **191,348 lines of non-generated C#/Razor production source** across **17 intended production projects**, but only **two test projects**, **32 test methods**, and approximately **48 executed test cases**.

The existing tests are useful regression seeds, but they do not yet protect the mandatory CymBuild flow:

`Blazor PWA -> FormHelper -> gRPC API -> EF -> SQL Server`

They also do not protect the platform invariants around `SCore.DataObjects`, workflow transitions, `SCore.IntegrationOutbox`, migration idempotency, or controlled external integrations.

The recommended approach is not to create one test project for every production assembly immediately. Instead, create a layered test portfolio organised by architectural boundary and subsystem, with fast tests first and real SQL Server integration tests for behaviour that cannot be represented accurately by mocks or EF in-memory providers.

## 2. Current repository baseline

### Production projects

There are 20 `.csproj` files in the archive:

- 17 intended production projects;
- 2 existing test projects;
- 1 duplicate root-level `Concursus.Metadata.Tools.csproj` outside the canonical `apps/Concursus.Metadata.Tools` location.

The main solution currently omits these four active production projects:

- `services/PostCodeLookup/PostCodeLookup.csproj`
- `services/Sage200Microservice/Sage200Microservice.API/Sage200Microservice.API.csproj`
- `services/Sage200Microservice/Sage200Microservice.Data/Sage200Microservice.Data.csproj`
- `services/Sage200Microservice/Sage200Microservice.Services/Sage200Microservice.Services.csproj`

This must be resolved before a repository-wide build/test pipeline is treated as authoritative.

### Existing test projects

#### `apps/Concursus.PWA.Tests`

- Target: `net10.0`
- Framework: xUnit v3
- Mocking: Moq
- Approximate executed cases: 41
- Coverage areas:
  - selected `PWAFunctions` helpers;
  - selected `ShoreInput` value bindings;
  - basic JavaScript invocation and navigation behaviour.

Limitations:

- no bUnit rendered-component tests;
- no tests for `V2FormRenderer`, `V2FieldEditor`, or `FilteredDynamicGridViewV2`;
- no authentication/token-expiry tests;
- no FormHelper boundary tests;
- three tests only assert that methods do not throw;
- the project duplicates a large set of production package references;
- it directly references `Concursus.EF`, although the test source does not use EF;
- no coverage collector is configured.

#### `tests/Concursus.API.Tests`

- Target: `net10.0`
- Framework: xUnit v3
- Approximate executed cases: 7
- Coverage area:
  - `SageSalesOrderRequestMapper` purchase order and tax code mapping.

Limitations:

- no mocking package or shared test fixtures;
- no gRPC service tests;
- no hosted API integration tests;
- no tests for workflow, outbox, invoice automation, idempotency, metadata migration, or schema migration;
- no coverage collector is configured.

### Current CI/test infrastructure

The repository has no root Bitbucket pipeline and no repository-level `dotnet test` or coverage workflow. Existing pipeline files are limited to SQL packs and the inactive Sage API area, while the AI error service still contains a Jenkinsfile.

No evidence was found for:

- bUnit;
- Playwright;
- `Microsoft.AspNetCore.Mvc.Testing`;
- SQL Server Testcontainers;
- Pester tests for the schema deployment scripts;
- architecture tests;
- contract/snapshot tests;
- mutation testing;
- a `.runsettings` file;
- coverage thresholds or coverage exclusions.

## 3. Risk-based priority

### Priority 0: architectural and platform invariants

These tests must be introduced first because a failure can corrupt platform behaviour across every business module.

1. UI project-reference boundary remains `PWA -> Components.Shared -> API.Client`.
2. No new direct UI-to-API, UI-to-EF, or UI-to-SQL path is introduced.
3. Every major entity insert creates its `SCore.DataObjects` row atomically with the correct `EntityTypeId`.
4. Workflow state changes use `SCore.DataObjectTransitionUpsert`; latest active transition is current state.
5. Integration events are written through `SCore.IntegrationOutbox` with retry-safe idempotency.
6. Schema and metadata migration remain idempotent, controlled, auditable, and source-authoritative.
7. No test writes to shared DEV, QA, UAT, or LIVE databases.

### Priority 1: current high-risk business and operational services

- schema migration R39 exclusions and R40 autonomous constraints;
- metadata migration run lifecycle and identity mapping;
- finance approval to Sage submission;
- transaction-to-Sage idempotency and retry classification;
- Sage inbound payment synchronisation;
- invoice automation phases 4-6 and trigger-instance idempotency;
- workflow outbox claiming, publication, failure, and retry;
- authorisation decisions and transitions;
- SharePoint structure repair worker;
- token expiry/re-authentication behaviour;
- V2 metadata-driven form and grid controls.

### Priority 2: subsystem integrations

- Outlook add-in/API/service and Microsoft Graph wrappers;
- PostCodeLookup external provider and cache;
- AI error service, Jira, and AI client wrappers;
- Sage200 microservice API/services/data layers;
- document generation and conversion.

## 4. Proposed test project portfolio

The proposed structure deliberately groups related production projects where that reduces duplication without weakening ownership.

### Fast test projects

| Proposed project | Target | Scope | First test targets |
|---|---:|---|---|
| `tests/CymBuild.Architecture.Tests` | net10.0 | Repository and assembly boundary rules | project references, forbidden dependencies, solution completeness, source guardrails |
| `tests/Concursus.Common.Shared.Tests` | net10.0 | Pure shared models/helpers | finance model calculations, active-line filtering, reference selection, converters, SQL reader helpers |
| `tests/Concursus.API.Client.Tests` | net10.0 | FormHelper and client mapping | gRPC request construction, reply mapping, cancellation, error propagation, cache keys/coalescing |
| `tests/Concursus.Components.Shared.Tests` | net10.0 | Shared Razor components and helpers | `V2FormRenderer`, `V2FieldEditor`, dropdown loading, view-definition building, offline sync |
| existing `apps/Concursus.PWA.Tests` | net10.0 | PWA-specific components and helpers | token expiry, navigation, state restoration, `FilteredDynamicGridViewV2`, migration page state |
| `tests/Concursus.EF.Tests` | net10.0 | Pure EF-layer logic without database I/O | filter/query construction, metadata comparer, converters, deterministic mapping |
| existing `tests/Concursus.API.Tests` | net10.0 | API application services | eligibility, payload factory, submission orchestration, outbox parsing, worker decisions |
| `tests/CymBuild.Outlook.Tests` | net10.0 | Outlook common/add-in/API/service | string/path parsing, token handling, Graph request mapping, filing decisions |
| `tests/CymBuild.AIErrorService.Tests` | net10.0 | AI/Jira service | Markdown-to-ADF, request mapping, retry/error handling, controller validation |
| `tests/PostCodeLookup.Tests` | net9.0 | postcode service | normalisation, cache hit/miss, provider mapping, not-found behaviour, controller validation |
| `tests/Sage200Microservice.Tests` | net9.0 | Sage API/services/data | authentication caching, API client retries, invoice/customer services, repository queries, validation |

### Integration and release test projects

| Proposed project/suite | Target | Scope |
|---|---:|---|
| `tests/Concursus.API.IntegrationTests` | net10.0 | in-process REST/gRPC host, authentication overrides, DI wiring, serialization and status mapping |
| `tests/CymBuild.Database.IntegrationTests` | net10.0 | real SQL Server schema, stored procedures, DataObjects, transitions, outbox and repository behaviour |
| `tests/CymBuild.Migration.IntegrationTests` | net10.0 | isolated source/target SQL databases, schema/metadata run lifecycle, exclusions, constraints, idempotency |
| `tests/SchemaDeployment.Pester` | PowerShell/Pester | initializer/runner safety, WhatIf/Apply, LIVE guard, selection, immutable files and constraint order |
| `tests/CymBuild.EndToEnd.Tests` | net10.0 | Playwright browser tests against a complete disposable environment |

A separate test project is not recommended for the 25-line metadata CLI wrapper. Its meaningful behaviour should be tested through EF metadata validation tests and migration integration tests.

## 5. Test technology standards

Retain the repository's existing xUnit v3 baseline initially. Do not combine a package upgrade with test expansion.

Recommended additions:

- `coverlet.collector` for coverage collection;
- Moq or small hand-written fakes for service collaborators;
- bUnit for Razor component tests;
- `Microsoft.AspNetCore.Mvc.Testing` for hosted REST/gRPC integration tests;
- SQL Server Testcontainers, or a pipeline-created disposable SQL Server, for SQL integration tests;
- Pester for PowerShell deployment scripts;
- Playwright for browser-level release tests.

Do not use EF InMemory or SQLite as substitutes for CymBuild SQL behaviour. They cannot accurately exercise SQL Server stored procedures, `SESSION_CONTEXT`, `rowversion`, constraints, `WITH NOCHECK`, filtered indexes, locking, or transition/outbox semantics.

## 6. Test conventions

Every test should be classifiable by both level and area.

Suggested traits:

- `Level=Unit`
- `Level=Component`
- `Level=Architecture`
- `Level=Integration`
- `Level=Database`
- `Level=EndToEnd`
- `Area=Finance`
- `Area=Workflow`
- `Area=SchemaMigration`
- `Area=MetadataMigration`
- `Area=Outbox`
- `Area=Outlook`
- `Area=PostCode`
- `Area=Sage`

Tests must be deterministic:

- no calls to LIVE or shared environment services;
- no reliance on current time without an injectable clock or bounded assertion;
- no random GUID assertions where stable identifiers are required;
- no ordering assumptions without an explicit order;
- no hidden dependence on developer machine configuration;
- no destructive cleanup of shared resources.

## 7. Detailed implementation phases

### R1 - Test foundation and immediate safety net

1. Add `CymBuild.Architecture.Tests`.
2. Add `Concursus.Common.Shared.Tests`.
3. Expand `Concursus.API.Tests` with finance eligibility, payload, idempotency and outbox parser tests.
4. Add `Concursus.EF.Tests` for `GridInternalsComparer` and other pure deterministic logic.
5. Add `coverlet.collector` to existing/new .NET test projects.
6. Remove the unused EF reference and redundant package duplication from `Concursus.PWA.Tests`, after a verified build.
7. Add a repository test script that runs fast tests only.
8. Record a baseline test/coverage report without imposing an unrealistic global threshold.

R1 should not change production behaviour or database schema.

### R2 - FormHelper and metadata-driven UI

1. Add a reusable test `CallInvoker` so generated gRPC clients can be exercised without changing the UI boundary.
2. Test FormHelper request defaults, GUID handling, mapping and error propagation.
3. Introduce bUnit tests for `V2FormRenderer`, `V2FieldEditor`, `FilteredDynamicGridViewV2`, and authentication expiry handling.
4. Add characterization tests before extracting logic from large Razor/code-behind files.
5. Keep all business decisions outside the UI; tests should verify delegation to FormHelper rather than duplicate business rules in components.

### R3 - API service orchestration and workers

1. Test transaction-to-Sage eligibility comprehensively.
2. Test idempotency claim outcomes: claimed, active claim, completed, retryable failure and permanent failure.
3. Test submission orchestration and safe failure recording.
4. Test Sage inbound sync hashing, polling and duplicate protection.
5. Test invoice automation run locking, trigger ledger behaviour and retries.
6. Test outbox claim/mark-published/mark-failed behaviour and payload parsing.
7. Test hosted workers for cancellation, retry delay and scope creation.

### R4 - Real SQL Server platform tests

Create a disposable SQL Server per test collection or pipeline run and deploy only source-controlled schema.

Mandatory database assertions:

1. entity insert and `SCore.DataObjects` creation are atomic;
2. `EntityTypeId`, `Guid`, `RowStatus`, and `RowVersion` are correct;
3. failed entity insert leaves no orphan DataObject;
4. status transitions go through `SCore.DataObjectTransitionUpsert`;
5. latest active transition resolves current state;
6. outbox rows are idempotent and retry-safe;
7. active-row queries exclude row statuses 0 and 254;
8. stored procedures are rerunnable and deterministic;
9. repository mappings use explicit columns and preserve null semantics;
10. locking and claim timeout behaviour is verified with concurrent connections.

### R5 - Schema and metadata migration tests

Use two isolated databases: source and target.

Schema migration coverage:

- create run;
- compare deterministic definitions;
- default safe plan;
- persistent source-authoritative exclusions;
- target synchronisation and unexclude tombstones;
- validation invalidation after policy change;
- R40 `CYB_CONSTRAINT_V2` deterministic snapshots;
- FK/check/default/PK/unique create/replace/remove;
- target-only destructive removal requires explicit selection;
- PK/unique duplicate/null preflight blocking;
- FK/check `WITH NOCHECK` historical-data policy;
- materialisation stop-before-apply behaviour;
- `-SkipSourceMaterialization` immutable promotion path;
- retry and audit completion;
- second run produces no unintended difference.

Metadata migration coverage:

- Create Run -> Stage -> Validate -> Identity Map -> Review/Override -> Select -> Preview -> Apply -> Verify/Audit;
- Grid -> View -> Columns order;
- stable GUID idempotency;
- ignored records and reversible policy;
- no duplicate metadata;
- DataObjects created for metadata inserts;
- second apply is a no-op.

### R6 - External subsystem tests

Create controlled HTTP/Graph/Sage/Jira/Postcode adapters where missing. Test with fake handlers or local stub servers only.

- Outlook: Graph request construction, paging, token errors, filing paths and retry behaviour.
- AI error service: sanitisation, ADF conversion, Jira mapping, AI response parsing and transient errors.
- Postcode: normalisation, cache semantics, provider failures and fallback responses.
- Sage microservice: auth token cache, API retries, validation, repository queries, health and controller contracts.

### R7 - End-to-end release tests

After containerisation is available, add Playwright smoke/regression tests for:

- interactive sign-in and expired-session redirect;
- metadata-driven menu/navigation;
- record open/read/update through FormHelper/gRPC;
- workflow action and resulting transition;
- dynamic grid/filter/export basics;
- V2 form rendering and validation;
- schema/metadata workbench review flows without browser DDL;
- finance/invoice operational smoke paths using controlled test data.

## 8. Coverage policy

Do not set an immediate blanket 80% repository threshold. That would reward low-value DTO/property tests and make the first CI adoption unstable.

Use a ratchet model:

1. collect and publish the baseline;
2. require all new or materially changed deterministic business logic to have tests;
3. require no reduction in covered lines for changed projects;
4. initially set project-specific thresholds only for newly established fast-test projects;
5. exclude generated gRPC code, EF migrations, designer output, DTO-only files and `Program.cs` bootstrap from percentage gates;
6. increase thresholds after each tranche stabilises.

Suggested initial quality targets:

- pure business services/helpers: 80%+ branch coverage;
- FormHelper mapping: 70%+ branch coverage for changed methods;
- migration comparison/planning engines: 80%+ branch coverage plus SQL integration tests;
- Razor pages: behaviour-focused component tests rather than line-percentage chasing;
- database code: scenario/invariant coverage rather than source-line coverage.

## 9. First concrete test cases

The first implementation tranche should include at least:

### Finance/API

- every `TransactionToSageEligibilityFailureReason` branch;
- active/inactive lines and negative totals;
- existing Sage reference and already-submitted handling;
- payload factory mapping and safe defaults;
- transient versus permanent gateway failures;
- idempotency repository delegation and cancellation;
- outbox payload parsing for workflow and job events.

### Common shared

- `ApprovedTransactionForSageReadModel.ActiveLines`;
- `HasLines` and preferred external reference;
- line usability validation;
- decimal/VAT totals and null handling;
- data-property conversion;
- SQL data reader conversion edge cases.

### EF metadata validation

- unmanaged severity QA/UAT/LIVE;
- null manifest arrays mean not-managed-yet;
- missing rows fail only when managed;
- unmanaged rows receive correct severity;
- differing properties fail;
- unresolved label/query/widget references fail;
- stable ordering of validation issues.

### Architecture

- PWA references only `Concursus.Components.Shared` as its project boundary;
- Components.Shared references API.Client, not EF/API;
- API.Client references Common.Shared, not the server project;
- API references EF/Common.Shared;
- no active production project is silently absent from the authoritative build solution;
- test projects never reference environment-specific appsettings secrets.

## 10. Source changes likely needed for testability

The following should be small, behaviour-preserving changes made only with characterization tests:

- expose `Program` as `public partial class Program` for hosted API tests;
- introduce narrow interfaces around external HTTP/Graph/Jira/Sage/Postcode clients where concrete clients prevent isolation;
- move pure schema/metadata comparison logic out of very large gRPC partial classes into internal deterministic services;
- introduce a clock abstraction for workers and retry schedules;
- introduce factories for SQL connections where concurrency/claim behaviour needs controlled tests;
- use `InternalsVisibleTo` only for focused deterministic internals, not as a substitute for good boundaries.

Do not refactor the large `Core`, `CoreService`, FormHelper, or Razor files wholesale before characterization tests exist.

## 11. Validation limitation of this analysis

The archive was structurally and source analysed successfully. The execution environment used for this review does not contain the .NET SDK, so the current projects and proposed changes were not compiled or executed here. The first implementation patch must therefore include local repository validation commands and should not be accepted until `dotnet restore`, `dotnet build`, and `dotnet test` pass on the CymBuild development machine.

## 12. R0 foundation and recommended next patch

R0 establishes shared test configuration, deterministic discovery, baseline reporting, and a fast-test runner without adding substantive test coverage. After R0 has passed locally, create a short-path patch named **`CYB_TEST_R1`** containing only:

- `CymBuild.Architecture.Tests`;
- `Concursus.Common.Shared.Tests`;
- `Concursus.EF.Tests` pure comparer tests;
- expanded `Concursus.API.Tests` finance tests;
- coverage collector setup;
- a fast-test PowerShell runner;
- solution entries required for those tests;
- patch notes and an apply script with baseline hashes.

No production behaviour, schema, metadata, workflow, or environment configuration should change in R1.
