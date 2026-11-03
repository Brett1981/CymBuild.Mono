# .NET repository guidance

Apply this guidance when the repository contains a `.sln`, `.slnx`, `.csproj`,
`.fsproj`, `.vbproj`, `global.json`, `Directory.Build.props` or
`Directory.Packages.props`.
Repository-local instructions and the most specific nested `AGENTS.md`,
`CLAUDE.md` or `llm.md` take precedence.

## Establish the repository contract

Before changing code:

- Read the repository `README`, `CONTRIBUTING` and applicable agent instruction
  files.
- Inspect `global.json`, `Directory.Build.*`, `Directory.Packages.props`,
  `NuGet.config`, the solution and the affected project files.
- Use the SDK, package versions, build scripts and test commands already chosen
  by the repository. Do not upgrade them unless the request requires it.
- Confirm whether the solution uses SDK-style .NET or classic .NET Framework.
  Do not assume the `dotnet` CLI can build a solution that requires MSBuild or
  Visual Studio Build Tools.
- Identify the affected application, service, library and test projects. Preserve
  their existing responsibilities and dependency direction.
- Confirm database, migration and deployment conventions from source. Never
  assume that one .NET repository follows another repository's architecture.

## Implementation and validation

- Keep business rules, presentation, service coordination and persistence in
  their established layers.
- Follow the repository's existing dependency injection, configuration,
  nullable-reference, async, cancellation, logging and disposal patterns.
- Do not put credentials or environment-specific secrets in source, tests,
  example configuration, logs or commands.
- Extend the existing test projects and fixtures rather than creating a parallel
  test framework without evidence that one is needed.
- Run the smallest affected test project first. Then run the repository's
  documented wider checks when the change requires them.
- Treat `dotnet restore`, `dotnet build` and `dotnet test` examples as starting
  points only. Use solution filters or repository scripts when the source says
  they are authoritative.
- Report the exact commands and results. State which checks were not run and why.
