# CYB_TEST_R0C test foundation

R0 is the non-production foundation for the CymBuild automated test programme. It does not alter production logic, database objects, metadata, workflow transitions, integration events, or environment configuration.

## Corrections incorporated

R0C replaces R0, R0A, and R0B and includes all earlier corrections:

- optional MSBuild XML nodes are handled through namespace-safe XPath and empty collections;
- `ExtractLastHttps` characterization matches complete `https://` matching;
- navigation tests reflect authoritative `ReturnUrl` behaviour and the empty-return fallback separately;
- JavaScript tests use a recording `IJSRuntime` rather than mocking the wrong generic invocation;
- direct `ShoreInput` characterization initializes generated navigation and interaction-tracker injections;
- the local `BL0005` suppression remains limited to the legacy `ShoreInput` test file;
- Windows PowerShell captures native test exit codes and parses TRX results before failing.

## R0 outcomes

- Existing test package versions are centralised in `tests/CymBuild.Testing.props`.
- VSTest remains the explicit execution model used by the current xUnit v3 projects.
- Coverlet collection is available through the shared run settings without a global threshold.
- `Invoke-CymBuildFastTests.ps1` discovers and executes fast test projects while excluding integration and end-to-end suites.
- Each fast-test JSON result includes project exit code, TRX path, counts, and failed-test details.
- `Get-CymBuildTestBaseline.ps1` records project inventory, solution membership, source counts, and source-level test attributes.
- Test taxonomy, determinism rules, environment protections, strategy, and proposed project matrix are source controlled.

## Acceptance

R0 is accepted only when the patch applies cleanly and both existing test projects restore, build, and pass in Release configuration using:

```powershell
.\tools\Testing\Invoke-CymBuildFastTests.ps1 -Configuration Release
```

The generated baseline reports must exist under `TestResults\baseline` and the fast-test run summary beneath `TestResults\fast\<UTC-run-time>\fast-test-run.json`.

R0 sets no repository-wide coverage threshold. R1 begins substantive coverage with architecture, common shared, EF comparer, and expanded API finance tests.

## 2026-09-15 correction: VSTest execution model retired

The "VSTest remains the explicit execution model" outcome above no longer holds. The .NET 10
SDK's `Microsoft.Testing.Platform.MSBuild` package stopped supporting `dotnet test` VSTest mode
for Microsoft.Testing.Platform (MTP) projects, which made every xUnit v3 fast-test project fail
to build with "Testing with VSTest target is no longer supported". All fast-test projects now run
on MTP instead:

- `global.json` sets `test.runner` to `Microsoft.Testing.Platform` for the whole repo.
- `tests/CymBuild.Testing.props` pins xunit.v3/xunit.runner.visualstudio to the 4.x line (must stay
  version-aligned with the Microsoft.Testing.Platform extensions it also references) and adds
  `Microsoft.Testing.Extensions.TrxReport` / `Microsoft.Testing.Extensions.CodeCoverage` in place of
  `coverlet.collector`.
- `tests/CymBuild.Testing.runsettings` keeps its filename but now holds the CodeCoverage extension's
  own `<Configuration>` schema, not a VSTest RunSettings document; it's passed via the coverage
  settings option, not the old VSTest settings option.
- `Invoke-CymBuildFastTests.ps1` and `Invoke-CymBuildSqlIntegrationTests.ps1` invoke `dotnet test`
  with MTP-native options (project selection, TRX report, coverage) instead of the VSTest-era
  `--settings`/`--collect`/`--logger` flags.

Coverlet collection via shared run settings is retired along with VSTest mode.
