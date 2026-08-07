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
