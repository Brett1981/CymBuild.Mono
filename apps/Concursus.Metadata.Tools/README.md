dotnet run --project apps\Concursus.Metadata.Tools\Concursus.Metadata.Tools.csproj -- validate-grids --connection "Data Source=10.100.34.114\general;Initial Catalog=CymBuild_QA;Integrated Security=True;TrustServerCertificate=True;Max Pool Size=200;" --manifest "metadata-manifests/v1/families/grids/grids.json" --allowlist "metadata-manifests/v1/policies/allowlist.grids.json" --environment "QA" --out "metadata-validation-report.json"
dotnet run --project apps\Concursus.Metadata.Tools\Concursus.Metadata.Tools.csproj -- validate-grids --connection "Data Source=10.100.34.114\general;Initial Catalog=CymBuild_QA;Integrated Security=True;TrustServerCertificate=True;Max Pool Size=200;" --manifest "metadata-manifests/v1/families/grids/grids.json" --allowlist "metadata-manifests/v1/policies/allowlist.grids.json" --environment "QA" --out "metadata-validation-report.json" --include-internals true


--- Description ---
--- Example Command Output ---
---To Run in VS Developer PowerShell---

--- QA Database Grid Metadata Validation ---


$dotnetArgs = @(
  "run",
  "--project", "apps\Concursus.Metadata.Tools\Concursus.Metadata.Tools.csproj",
  "--",
  "validate-grids",
  "--connection", "Data Source=10.100.34.114\general;Initial Catalog=CymBuild_QA;Integrated Security=True;TrustServerCertificate=True;Max Pool Size=200;",
  "--manifest", "metadata-manifests/v1/families/grids/grids.json",
  "--allowlist", "metadata-manifests/v1/policies/allowlist.grids.json",
  "--environment", "QA",
  "--out", "metadata-validation-report.json",
  "--include-internals", "true"
)

& dotnet @dotnetArgs




--- UAT Database Grid Metadata Validation ---

$dotnetArgs = @(
  "run",
  "--project", "apps\Concursus.Metadata.Tools\Concursus.Metadata.Tools.csproj",
  "--",
  "validate-grids",
  "--connection", "Data Source=SOC-SQLBRE01\\SQL2022;Initial Catalog=Cymbuild_UAT;Integrated Security=True;TrustServerCertificate=True;Max Pool Size=500;",
  "--manifest", "metadata-manifests/v1/families/grids/grids.json",
  "--allowlist", "metadata-manifests/v1/policies/allowlist.grids.json",
  "--environment", "UAT",
  "--out", "metadata-validation-report.json",
  "--include-internals", "true"
)

& dotnet @dotnetArgs





--- LIVE Database Grid Metadata Validation ---

$dotnetArgs = @(
  "run",
  "--project", "apps\Concursus.Metadata.Tools\Concursus.Metadata.Tools.csproj",
  "--",
  "validate-grids",
  "--connection", "Data Source=SOC-SQLBRE01\\SQL2022;Initial Catalog=Concursus;Integrated Security=True;TrustServerCertificate=True;Max Pool Size=500;",
  "--manifest", "metadata-manifests/v1/families/grids/grids.json",
  "--allowlist", "metadata-manifests/v1/policies/allowlist.grids.json",
  "--environment", "LIVE",
  "--out", "metadata-validation-report.json",
  "--include-internals", "true"
)

& dotnet @dotnetArgs


--- Example Command Output END ---
