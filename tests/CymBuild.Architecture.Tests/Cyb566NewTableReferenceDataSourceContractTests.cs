using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-566: a selected table that is MissingInTarget used to be refused by the schema runner
// ("Source-controlled SQL file not found for Table"), blocking the whole run - and with it every
// constraint and index row belonging to that table. The runner now generates the canonical
// create file itself: CREATE TABLE (columns + named defaults), the -1 row always, and the source
// rows only when "Copy reference data" is ticked (off by default). The runner never connects to
// the source, so the API captures the new table (column order, and rows when ticked) read-only at
// selection save and carries it through the accepted plan.
public sealed class Cyb566NewTableReferenceDataSourceContractTests
{
    [Fact]
    public void SelectionTable_CarriesTheChoiceAndCaptureAsSelfHealingNullableColumns()
    {
        var canonical = ReadSchemaFile("Tables", "SMigration.Schema_RunSelections.sql");
        var bootstrap = ReadSchemaFile("Migrations", "CYB361", "SMigration.SchemaWorkbench.Bootstrap.sql");

        Assert.Contains("[CopyReferenceData] [bit] NULL,", canonical, StringComparison.Ordinal);
        Assert.Contains("[NewTableCaptureJson] [nvarchar](max) NULL", canonical, StringComparison.Ordinal);

        // Nullable, so an existing workbench self-heals them in place rather than failing 51353.
        Assert.Contains("(N'Schema_RunSelections', N'CopyReferenceData', N'bit', 1, 1, 0),", bootstrap, StringComparison.Ordinal);
        Assert.Contains("(N'Schema_RunSelections', N'NewTableCaptureJson', N'nvarchar', -1, 1, 0);", bootstrap, StringComparison.Ordinal);
        Assert.Contains("[CopyReferenceData] BIT NULL,", bootstrap, StringComparison.Ordinal);
    }

    [Fact]
    public void EveryLivePlanProcedureCopy_ReturnsTheChoiceAndCapture()
    {
        foreach (var sql in new[]
        {
            ReadSchemaFile("Programmability", "Procedures", "SMigration.SchemaDeploymentPlan_Get.sql"),
            ReadSchemaFile("Migrations", "CYB361", "SMigration.SchemaExclusions.Bootstrap.sql")
        })
        {
            Assert.Contains("ISNULL(selectionState.[CopyReferenceData], CONVERT(BIT, 0)) AS [CopyReferenceData],", sql, StringComparison.Ordinal);
            Assert.Contains("selectionState.[NewTableCaptureJson]", sql, StringComparison.Ordinal);
            Assert.Contains("selection.[NewTableCaptureJson]", sql, StringComparison.Ordinal);
        }

        var workbench = ReadSchemaFile("Migrations", "CYB361", "SMigration.SchemaWorkbench.Bootstrap.sql");
        Assert.Contains("ISNULL(sel.[CopyReferenceData], CONVERT(BIT, 0)) AS [CopyReferenceData],", workbench, StringComparison.Ordinal);
        Assert.Contains("rs.[NewTableCaptureJson]", workbench, StringComparison.Ordinal);
    }

    [Fact]
    public void CompareGrid_FitsViewportAndUsesSharedEdgeScrollAndStickyHeader()
    {
        var ui = NormaliseNewLines(ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "SchemaMigration.razor"));
        var css = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "SchemaMigration.razor.css");
        var js = ReadRepositoryFile("apps", "Concursus.PWA", "wwwroot", "schemaMigrationWorkbench.js");

        // The tick sits beside Migrate so it cannot be pushed off the right edge.
        Assert.Contains("<th>Migrate</th>\n                                        <th class=\"schema-copy-data-col\"", ui, StringComparison.Ordinal);

        // A `1fr` track grows to its content's min-content width (wide code diff); clamp it.
        Assert.Contains(".schema-compare-layout,\n.schema-definition-grid {\n    grid-template-columns: minmax(0, 1fr);", NormaliseNewLines(css), StringComparison.Ordinal);
        Assert.Contains(".schema-table thead th {\n    position: sticky;", NormaliseNewLines(css), StringComparison.Ordinal);

        // Reuses the CYB-524 shared edge-hover scroll rather than a second implementation.
        Assert.Contains("window.cymbuildGridEdgeAutoScroll", js, StringComparison.Ordinal);
        Assert.Contains("InvokeVoidAsync(\"attachGridEdgeAutoScroll\", WorkbenchRootElement)", ui, StringComparison.Ordinal);
    }

    [Fact]
    public void CopyReferenceData_FollowsUiFormHelperGrpcSqlBoundaryAndDefaultsOff()
    {
        var ui = ReadRepositoryFile("apps", "Concursus.PWA", "Pages", "Admin", "SchemaMigration.razor");
        var models = ReadRepositoryFile("libs", "Concursus.API.Client", "Models", "SchemaMigration", "SchemaMigrationModels.cs");
        var formHelper = ReadRepositoryFile("libs", "Concursus.API.Client", "FormHelper.SchemaMigration.cs");
        var proto = ReadRepositoryFile("services", "Concursus.API", "Protos", "core.proto");
        var service = MigrationBootstrapSourceContractTests.ReadSchemaMigrationSource();

        Assert.Contains("bool copyReferenceData = 16;", proto, StringComparison.Ordinal);
        Assert.Contains("bool copyReferenceData = 7;", proto, StringComparison.Ordinal);
        Assert.Contains("CopyReferenceData = selection.CopyReferenceData", formHelper, StringComparison.Ordinal);
        Assert.Contains("CopyReferenceData = message.CopyReferenceData", formHelper, StringComparison.Ordinal);

        // Offered only on a new table, only once it is selected; bool defaults to false.
        Assert.Contains("DifferenceType.Equals(\"MissingInTarget\", StringComparison.OrdinalIgnoreCase);", models, StringComparison.Ordinal);
        Assert.Contains("@if (row.IsNewTable)", ui, StringComparison.Ordinal);
        Assert.Contains("disabled=\"@(!row.IsDeployable || !row.IsSelected)\"", ui, StringComparison.Ordinal);
        Assert.Contains("CopyReferenceData = effective.IsSelected && effective.CopyReferenceData && row.IsNewTable", ui, StringComparison.Ordinal);

        // The server re-derives it: never honoured for anything but a selected new table.
        Assert.Matches(@"CopyReferenceData = isSelected\s+&& IsNewTableComparison\(row\.ObjectType, row\.DifferenceType\)\s+&& copyReferenceDataComparisonGuids\.Contains\(comparisonGuid\)", service);
    }

    [Fact]
    public void SelectionSave_CapturesNewTablesReadOnlyAndRefusesAnythingThatIsNotSmallReferenceData()
    {
        var service = MigrationBootstrapSourceContractTests.ReadSchemaMigrationSource();

        Assert.Contains("if (selections.Any(x => x.IsSelected && x.IsNewTable))", service, StringComparison.Ordinal);
        Assert.Contains("private static async Task<string> ReadSchemaNewTableCaptureJsonAsync(", service, StringComparison.Ordinal);
        Assert.Contains("internal const int SchemaReferenceDataMaxRows = 5000;", service, StringComparison.Ordinal);
        Assert.Contains("FOR JSON PATH, INCLUDE_NULL_VALUES", service, StringComparison.Ordinal);
        Assert.Contains("ORDER BY c.column_id;", service, StringComparison.Ordinal);

        // Binary/xml/spatial/sql_variant etc. are refused rather than approximated.
        Assert.Contains("internal static readonly HashSet<string> SchemaReferenceDataSupportedTypes", service, StringComparison.Ordinal);
        Assert.DoesNotContain("\"varbinary\"", service[service.IndexOf("SchemaReferenceDataSupportedTypes", StringComparison.Ordinal)..service.IndexOf("private static async Task<string> ReadSchemaNewTableCaptureJsonAsync(", StringComparison.Ordinal)], StringComparison.Ordinal);

        Assert.Contains("CopyReferenceData,\n    NewTableCaptureJson\n)", NormaliseNewLines(service), StringComparison.Ordinal);
    }

    [Fact]
    public void Runner_GeneratesNewTablesInsteadOfRefusingThem()
    {
        var runner = ReadRepositoryFile("tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("function New-MaterializedNewTableSourceFile {", runner, StringComparison.Ordinal);
        Assert.Contains("$newTableMaterialization = New-MaterializedNewTableSourceFile -Row $Row -AllowCreate $sourceWriteAllowed -RequireDefinitionMatch $sourceMatchRequired", runner, StringComparison.Ordinal);

        // The new branch sits before the generic "source file not found" fall-through, and a
        // hand-written canonical create file is still honoured.
        var branch = runner.IndexOf("$newTableMaterialization = New-MaterializedNewTableSourceFile", StringComparison.Ordinal);
        Assert.True(branch > 0 && branch < runner.IndexOf("Source-controlled SQL file not found for $objectType", StringComparison.Ordinal));
        Assert.Contains("if (-not $newTableMaterialization.UseExistingFile) {", runner, StringComparison.Ordinal);
        Assert.Contains("Existing hand-written canonical create file was resolved.", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void Runner_NewTableFileCreatesThenSeedsTheMinusOneRowAndOptionalReferenceData()
    {
        var runner = ReadRepositoryFile("tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        // Column order comes from the capture (the declarative snapshot excludes ordinal) and must
        // describe exactly the compared columns.
        Assert.Contains("$columnOrder = @($capture.ColumnOrder | ForEach-Object { [string]$_ })", runner, StringComparison.Ordinal);
        Assert.Contains("no longer match the compared definition", runner, StringComparison.Ordinal);

        // Named defaults inline, so table verification matches with or without DEFAULT rows.
        Assert.Contains("$declaration += \" CONSTRAINT $(Quote-CymBuildSqlIdentifier -Value $defaultName) DEFAULT $defaultDefinition\"", runner, StringComparison.Ordinal);

        // -1 row always; zero Guid; NOT NULL integer without default takes -1; anything else stops.
        Assert.Contains("-- The -1 sentinel row: ID -1, zero Guid, every other column its default.", runner, StringComparison.Ordinal);
        Assert.Contains("'00000000-0000-0000-0000-000000000000'", runner, StringComparison.Ordinal);
        Assert.Contains("return @(\"bigint\", \"int\", \"smallint\")", runner, StringComparison.Ordinal);
        Assert.Contains("has no default. Give it a default in DEV, or make it nullable", runner, StringComparison.Ordinal);

        // Reference rows only when ticked, embedded verbatim, keyed on Guid/ID, identity preserved.
        Assert.Contains("$hasRows = $copyReferenceData -and $null -ne $rows", runner, StringComparison.Ordinal);
        Assert.Contains("SET IDENTITY_INSERT $tableIdentifier ON;", runner, StringComparison.Ordinal);
        Assert.Contains("FROM OPENJSON(@CymBuildReferenceRows)", runner, StringComparison.Ordinal);

        // DataObjects rows resolved from the target registration, never guessed.
        Assert.Contains("FROM [SCore].[EntityHobts] AS eh", runner, StringComparison.Ordinal);
        Assert.Contains("has no SCore.EntityHobts registration; SCore.DataObjects rows were not created", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void Runner_PlanFingerprintPinsTheChoiceAndCapture()
    {
        var runner = ReadRepositoryFile("tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1");

        Assert.Contains("(Get-DataRowText -Row $row -ColumnName \"CopyReferenceData\"),", runner, StringComparison.Ordinal);
        Assert.Contains("(Get-TextSha256 -Text (Get-DataRowText -Row $row -ColumnName \"NewTableCaptureJson\"))", runner, StringComparison.Ordinal);
        Assert.Contains("CYB566_NEW_TABLE_V1", runner, StringComparison.Ordinal);
    }

    [Fact]
    public void Runner_DataRowTextReadsTrueBitColumns()
    {
        // 2026-09-24 QA: "$value -eq [DBNull]::Value" coerces DBNull to the left operand's type and
        // [bool][DBNull]::Value is $true, so a ticked CopyReferenceData (BIT 1) read as NULL and the
        // new table was generated with only its -1 row. The null test must be a type test.
        var runner = NormaliseNewLines(ReadRepositoryFile("tools", "SchemaDeployment", "Invoke-CymBuildSchemaDeployment.ps1"));
        var start = runner.IndexOf("function Get-DataRowText {", StringComparison.Ordinal);
        Assert.True(start >= 0);
        var body = runner[start..runner.IndexOf("\n}\n", start, StringComparison.Ordinal)];

        Assert.Contains("$Row[$ColumnName] -is [System.DBNull]", body, StringComparison.Ordinal);
        Assert.DoesNotContain("-eq [DBNull]::Value", body, StringComparison.Ordinal);
    }

    private static string NormaliseNewLines(string text) => text.Replace("\r\n", "\n", StringComparison.Ordinal);

    private static string ReadRepositoryFile(params string[] segments) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(segments));

    private static string ReadSchemaFile(params string[] segments) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(["Database", "CymBuild_DB", "Schema", .. segments]));
}
