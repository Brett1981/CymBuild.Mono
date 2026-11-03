using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-584: CYB-333 gave SJob.ActivitiesValidate two more parameters while EntityQuery
/// 'SJob.ActivitiesValidate' still passed 9 arguments. Schema and metadata deployed cleanly to QA and
/// UAT (QA -> UAT reported "nothing-to-do") and every Activity save failed. Query statements are
/// text, so the migration now compares each call with the routine it names
/// (SMigration.MetadataQuerySignature_Check), during validation and after every metadata-auto run.
/// </summary>
public sealed class Cyb584QueryCallSignatureSourceContractTests
{
    private static readonly string[] Procedures = ["Database", "CymBuild_DB", "Schema", "Programmability", "Procedures"];

    [Fact]
    public void SignatureCheck_ComparesFunctionArgumentCountsAndProcedureNamedArguments()
    {
        var check = ReadProcedure("SMigration.MetadataQuerySignature_Check.sql");

        Assert.Contains("CREATE OR ALTER PROCEDURE [SMigration].[MetadataQuerySignature_Check]", check, StringComparison.Ordinal);
        Assert.Contains("IF @ObjectType IN ('FN', 'IF', 'TF')", check, StringComparison.Ordinal);
        Assert.Contains("IF @Depth = 0 AND @ArgumentCount <> @DeclaredCount", check, StringComparison.Ordinal);
        Assert.Contains("ELSE IF @ObjectType = 'P'", check, StringComparison.Ordinal);

        // T-SQL defaults are not in sys.parameters (has_default_value is CLR-only), so a parameter
        // with a default - e.g. CYB-333's @IsPartOfAgreedFee BIT = NULL - must not be reported.
        Assert.Contains("ELSE IF @Depth = 0 AND @Character = N'=' SET @HasDefault = 1;", check, StringComparison.Ordinal);
        Assert.Contains("IF @HasDefault = 0", check, StringComparison.Ordinal);
    }

    [Fact]
    public void SignatureCheck_ChecksTheStateAfterTheRun_NotOnlySelectedRows()
    {
        var check = ReadProcedure("SMigration.MetadataQuerySignature_Check.sql");

        // A selected EntityQueries row is checked as its source payload; every other active
        // query as it is in the target. The broken UAT query was never selected (no difference).
        Assert.Contains("INSERT INTO #SignatureReplaced (QueryGuid)", check, StringComparison.Ordinal);
        Assert.Contains("FROM    SCore.EntityQueries AS eq", check, StringComparison.Ordinal);
        Assert.Contains("NOT EXISTS (SELECT 1 FROM #SignatureReplaced AS r WHERE r.QueryGuid = q.Guid)", check, StringComparison.Ordinal);
        Assert.Contains("Statement NVARCHAR(MAX) N'$.Statement'", check, StringComparison.Ordinal);
        Assert.Contains("N'QueryCallSignatureMismatch'", check, StringComparison.Ordinal);
    }

    [Fact]
    public void Validate_RunsTheCheckAndCountsItAsTargetState_AndApplyRefusesIt()
    {
        var validate = ReadProcedure("SMigration.MetadataValidate_Run.sql");
        var apply = ReadProcedure("SMigration.MetadataApply_Run.sql");

        Assert.Contains("EXEC SMigration.MetadataQuerySignature_Check\n        @RunGuid = @RunGuid,\n        @ReturnResults = 0;", validate, StringComparison.Ordinal);
        Assert.Contains("N'DuplicateQueryParameterName', N'QueryParameterMappingMismatch', N'QueryCallSignatureMismatch')", validate, StringComparison.Ordinal);
        Assert.Contains("N'UnresolvedReference', N'DuplicateQueryParameterName', N'QueryCallSignatureMismatch')", apply, StringComparison.Ordinal);
    }

    [Fact]
    public void MetadataAuto_VerifiesTheTargetAfterEverySuccessfulOutcome()
    {
        var cli = ReadSource("libs", "Concursus.EF", "MigrationCli", "MetadataMigrationCli.cs");

        // ExecuteAsync wraps every path - accepted, created, nothing-to-do - so the verification
        // cannot be skipped by an early return inside MigrateAsync.
        Assert.Contains(
            "var exitCode = await MigrateAsync(target, configuration, o, report, ct).ConfigureAwait(false);\n" +
            "        return exitCode == ExitSuccess\n" +
            "            ? await VerifyQuerySignaturesAsync(target, report, ct).ConfigureAwait(false)\n" +
            "            : exitCode;",
            cli,
            StringComparison.Ordinal);
        Assert.Contains("const string checkProcedure = \"SMigration.MetadataQuerySignature_Check\";", cli, StringComparison.Ordinal);
        Assert.Contains("return Fail(report,", cli[cli.IndexOf("VerifyQuerySignaturesAsync(\n", StringComparison.Ordinal)..], StringComparison.Ordinal);
    }

    [Fact]
    public void Bootstrap_InstallsTheCheckBeforeTheValidateProcThatCallsIt()
    {
        var repository = ReadSource("libs", "Concursus.EF", "MigrationBootstrapRepository.cs");

        Assert.Contains("MetadataProcedure(1197, \"MetadataQuerySignature_Check\")", repository, StringComparison.Ordinal);

        var check = repository.IndexOf("SMigration.MetadataQuerySignature_Check.sql\"", StringComparison.Ordinal);
        var validate = repository.IndexOf("SMigration.MetadataValidate_Run.sql\"", StringComparison.Ordinal);
        Assert.True(check > 0 && check < validate, "The check must converge before MetadataValidate_Run.");
    }

    private static string ReadProcedure(string fileName) =>
        ReadSource([.. Procedures, fileName]);

    private static string ReadSource(params string[] segments) =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(segments)).Replace("\r\n", "\n");
}
