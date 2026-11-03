# CymBuild testing strategy

## Test runner: Microsoft.Testing.Platform (MTP), not VSTest

Every `.csproj` under `tests/` and `apps/*.Tests` imports `tests/CymBuild.Testing.props`
and runs on the .NET 10 SDK's native Microsoft.Testing.Platform (MTP) `dotnet test` mode
(`global.json` sets `"test": { "runner": "Microsoft.Testing.Platform" }` for the whole repo).
This replaced VSTest mode on 2026-09-15 after the .NET 10 SDK's `Microsoft.Testing.Platform.MSBuild`
package stopped supporting VSTest mode for MTP projects at all. See
`docs/testing/R0-Test-Foundation.md` ("2026-09-15 correction") for the full history.

Rules that keep new/changed test projects working under MTP:

- **Import `tests/CymBuild.Testing.props`** in every test project and do not override
  `xunit.v3` / `xunit.runner.visualstudio` versions per-project. They must stay
  version-aligned with the `Microsoft.Testing.Extensions.TrxReport` /
  `Microsoft.Testing.Extensions.CodeCoverage` versions the same props file pins — mixing
  major lines (e.g. xunit.v3 3.x with a 2.4.0+ platform extension) throws a runtime
  `TypeLoadException`, not a build error, so it is easy to miss until the suite actually runs.
- **Never add `PrivateAssets`/`IncludeAssets` to a Microsoft.Testing.Extensions.* package
  reference without including `compile`.** Unlike `coverlet.collector` (reflection-loaded,
  compile-free), the MSBuild-generated `SelfRegisteredExtensions.cs` calls these extensions'
  `TestingPlatformBuilderHook` types directly, so the compile-time reference cannot be trimmed.
- **Don't add a hosting/dev-server package (e.g. `Microsoft.AspNetCore.Components.WebAssembly.DevServer`)
  directly to a test project** unless a test actually uses its types. Under MTP, `dotnet test`
  executes the project's own `RunCommand`/`RunArguments` MSBuild properties to launch the test
  host; a dev-server package that overrides those properties (to make `dotnet run` launch itself)
  hijacks the test run into booting the dev server instead. This is invisible under VSTest, which
  never used those properties, so it will not show up by analogy with old behaviour.
- **Run tests with MTP-native `dotnet test` options**, not VSTest-era ones:
  `--project <csproj>` (not a bare positional path), `--report-trx`/`--report-trx-filename`
  (not `--logger trx;...`), `--coverage --coverage-output-format cobertura --coverage-settings
  tests/CymBuild.Testing.runsettings` (not `--collect "XPlat Code Coverage"` / `--settings`).
  `tests/CymBuild.Testing.runsettings` keeps its filename for continuity but now holds the
  CodeCoverage extension's own `<Configuration>` schema, not a VSTest RunSettings document —
  don't add VSTest-style `<RunSettings>`/`<DataCollectionRunSettings>` wrapping back into it,
  and don't put a literal `--` inside an XML comment in that file (illegal XML, breaks the parser
  with an unhelpful exit code 5).
- **A runsettings file cannot set environment variables any more.** `<EnvironmentVariables>` was
  applied by the VSTest host. The xunit.v3 MTP test host does not read runsettings at all (the
  test executable rejects `--settings`), and it ignores `Properties/launchSettings.json` too. To
  run `CymBuild.Database.IntegrationTests` from Visual Studio Test Explorer, set
  `CYMBUILD_SQL_TEST_CONNECTION_STRING` as a Windows user environment variable and restart Visual
  Studio. `Invoke-CymBuildSqlIntegrationTests.ps1` sets it per run, so its `-ConnectionString`
  still wins.
- The coverage extension names its output `<guid>.cobertura.xml`, not coverlet's
  `coverage.cobertura.xml`. Search for `*.cobertura.xml`.
- `Invoke-CymBuildFastTests.ps1` and `Invoke-CymBuildSqlIntegrationTests.ps1` already implement
  all of the above — extend them rather than hand-rolling a new `dotnet test` invocation.

## Existing suite families

The CymBuild programme already has test coverage across these areas and the
agent should extend the applicable project instead of creating a parallel test
framework without evidence:

- `apps/Concursus.PWA.Tests`
- `tests/Concursus.API.Client.Tests`
- `tests/Concursus.API.Tests`
- `tests/Concursus.Common.Shared.Tests`
- `tests/Concursus.Components.Shared.Tests`
- `tests/Concursus.EF.Tests`
- `tests/CymBuild.Architecture.Tests`
- SQL integration tests

Exact commands, target frameworks, packages, naming conventions, and helpers
must be read from the current repository before executable changes are made.

## Layer and risk matrix

| Change evidence | Minimum test impact | Additional coverage when applicable |
|---|---|---|
| `.razor`, renderer, field editor, or shared UI component | Component render, parameters/state, validation, events, accessibility | Metadata instance contract and critical E2E journey |
| FormHelper/API client method | Client unit test proving request mapping, cancellation, errors, and result mapping | E2E journey using the rendered action |
| `.proto`, gRPC service, request/response DTO | Contract/API tests, validation, authorization, backward compatibility | FormHelper mapping and EF/SQL integration |
| EF entity/configuration/repository | Mapping/query tests and controlled database integration | SQL schema/index/constraint coverage |
| Stored procedure/function/view/table/index | SQL contract and repeatability tests; explicit result-shape assertions | API consumer test and metadata/grid consumer test |
| Metadata manifest | Schema validation, stable Guid, dependency graph, duplicate detection, renderer compatibility | Generated screen/form/grid case and selected E2E smoke |
| Workflow change | Transition history/current-state tests; no direct status update | Authorization, retry, concurrency |
| Managed entity insert | Entity plus `SCore.DataObjects` atomicity | Rollback and duplicate/retry behaviour |
| Integration producer/consumer | Outbox atomicity and idempotent retry tests | Controlled external contract test |
| Schema/metadata deployment tooling | WhatIf/preview, apply, second apply, failure recovery, audit verification | Approved-definition/hash drift and concurrency |

## Test layers

### Architecture tests

Fast, broad gates that prevent disallowed dependencies and source patterns.
Candidate rules include:

- PWA does not directly reference server persistence or invoke gRPC outside the
  approved client/FormHelper boundary;
- no direct workflow status updates in application or test helpers;
- managed insert paths have a DataObject creation contract;
- SQL source contains no newly introduced `SELECT *` and follows the active-row
  convention;
- application startup does not run migrations;
- deployment order and required repository assets remain present.

Static checks must be precise. A simple text search is acceptable only when it
has low false-positive risk and verified exclusions. Prefer syntax/semantic or
SQL parser checks when available.

### Unit and component tests

These are the main coverage mechanism for dynamic rendering. Test generic
renderer behaviour with small synthetic metadata fixtures representing each
supported field, validation, visibility, permission, layout, action, and grid
feature. Assert semantic state and events, not fragile HTML snapshots alone.

### FormHelper and gRPC/API tests

Prove the complete request/response mapping and that business decisions remain
server-side. Include validation failures, authorization, not-found/conflict,
cancellation/timeouts where supported, and safe error presentation.

### EF/SQL and deployment integration tests

Run against an isolated or controlled database. Assert schema/result contracts,
DataObjects, transitions, active rows, transactionality, outbox writes,
idempotent reruns, and failure recovery.

### Browser/E2E tests

Use E2E for high-value journeys and deployed-environment confidence, not every
field permutation. Select elements using stable metadata-derived identifiers or
explicit accessibility roles/names whose wording is a tested contract. Do not
use DOM index, generated CSS class, or arbitrary delay as the primary locator or
synchronisation strategy.

## Dynamic coverage model

Coverage is the combination of:

1. **feature coverage** — every renderer capability has component tests;
2. **definition coverage** — every metadata definition passes structural and
   semantic contracts;
3. **binding coverage** — actions and fields map to known FormHelper/gRPC/data
   contracts;
4. **journey coverage** — critical business routes work in a deployed system.

A generated catalog should report all four separately. A screen is not "fully
tested" merely because it rendered once in a browser.

## Execution order

Run the smallest relevant project first, then:

1. format/static/manifest validation;
2. architecture and fast unit/component tests;
3. API client/API/EF tests;
4. SQL integration and migration repeatability tests;
5. browser tests against an approved environment;
6. post-deployment non-destructive smoke verification.

Record the exact commands and results. If a suite cannot be run locally, state
that and rely on the named pipeline gate rather than implying success.
