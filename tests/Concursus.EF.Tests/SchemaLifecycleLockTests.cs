using Xunit;

namespace Concursus.EF.Tests;

/// <summary>
/// The migration bootstrap skips a module whose definition is already current, so it never
/// replaces an unchanged lifecycle procedure while SCore.PostDeploymentScript is running it.
/// </summary>
public sealed class SchemaLifecycleLockTests
{
    [Theory]
    [InlineData("CREATE OR ALTER PROCEDURE [SCore].[SCHEMABINDING]\n(\n  @Apply BIT = 1\n)\nAS\nSELECT 1;", "[SCore].[SCHEMABINDING]")]
    [InlineData("-- leading comment\n/* block\ncomment */\ncreate procedure SMigration.Foo AS SELECT 1;", "SMigration.Foo")]
    [InlineData("﻿ALTER FUNCTION [SCore] . [Fn] () RETURNS INT AS BEGIN RETURN 1 END", "[SCore].[Fn]")]
    [InlineData("CREATE OR ALTER VIEW [SJob].[V] AS SELECT 1 AS A", "[SJob].[V]")]
    [InlineData("CREATE TRIGGER [SJob].[T] ON [SJob].[Jobs] AFTER INSERT AS SELECT 1", "[SJob].[T]")]
    public void TryGetModuleName_RecognisesModuleBatches(string batch, string expected)
    {
        Assert.Equal(expected, SchemaLifecycleLock.TryGetModuleName(batch));
    }

    [Theory]
    [InlineData("PRINT (N'Create procedure [SCore].[SCHEMABINDING]')")]
    [InlineData("SET QUOTED_IDENTIFIER, ANSI_NULLS ON")]
    [InlineData("CREATE TABLE [SMigration].[Schema_Run] ([ID] INT NOT NULL)")]
    [InlineData("IF OBJECT_ID(N'SMigration.Foo') IS NULL EXEC (N'CREATE PROCEDURE SMigration.Foo AS SELECT 1');")]
    [InlineData("CREATE PROCEDURE Foo AS SELECT 1")] // not schema-qualified: never skipped, always executed
    public void TryGetModuleName_IgnoresOtherBatches(string batch)
    {
        Assert.Null(SchemaLifecycleLock.TryGetModuleName(batch));
    }

    [Fact]
    public void NormalizeModuleDefinition_IgnoresLineEndingsAndTrailingWhitespaceOnly()
    {
        const string script = "CREATE OR ALTER PROCEDURE [SCore].[P]\nAS\nBEGIN\n    SELECT 1;\nEND";
        const string stored = "CREATE OR ALTER PROCEDURE [SCore].[P]   \r\nAS\r\nBEGIN\r\n    SELECT 1;\r\nEND\r\n";
        const string changed = "CREATE OR ALTER PROCEDURE [SCore].[P]\nAS\nBEGIN\n    SELECT 2;\nEND";

        Assert.Equal(SchemaLifecycleLock.NormalizeModuleDefinition(script), SchemaLifecycleLock.NormalizeModuleDefinition(stored));
        Assert.NotEqual(SchemaLifecycleLock.NormalizeModuleDefinition(script), SchemaLifecycleLock.NormalizeModuleDefinition(changed));
        Assert.NotEqual(
            SchemaLifecycleLock.NormalizeModuleDefinition(script),
            SchemaLifecycleLock.NormalizeModuleDefinition(script.Replace("    SELECT", "  SELECT", StringComparison.Ordinal)));
    }

    [Fact]
    public void NormalizeModuleDefinition_MatchesHowSqlServerStoresCreateOrAlter()
    {
        // Observed on CymBuild_QA2: sys.sql_modules keeps "CREATE   PROCEDURE" for a CREATE OR ALTER batch.
        const string script = "CREATE OR ALTER PROCEDURE [SCore].[SCHEMABINDING]\n(\n    @Apply BIT = 1\n)\nAS\nSELECT 1;";
        const string stored = "CREATE   PROCEDURE [SCore].[SCHEMABINDING]\r\n(\r\n    @Apply BIT = 1\r\n)\r\nAS\r\nSELECT 1;";
        Assert.Equal(SchemaLifecycleLock.NormalizeModuleDefinition(script), SchemaLifecycleLock.NormalizeModuleDefinition(stored));
    }

    [Theory]
    [InlineData("SCore.SCHEMABINDING.sql", "[SCore].[SCHEMABINDING]")]
    [InlineData("SCore.SchemaBindingApplySingleObject.sql", "[SCore].[SchemaBindingApplySingleObject]")]
    [InlineData("SCore.RebuildRecordHistoryTriggers.sql", "[SCore].[RebuildRecordHistoryTriggers]")]
    [InlineData("SCore.PostDeploymentScript.sql", "[SCore].[PostDeploymentScript]")]
    public void EmbeddedLifecycleProcedures_AreRecognisedSoUnchangedOnesAreSkipped(string file, string expected)
    {
        var text = File.ReadAllText(FindRepoFile("Database", "CymBuild_DB", "Schema", "Programmability", "Procedures", file));
        var batches = System.Text.RegularExpressions.Regex.Split(text, @"^\s*GO\s*$", System.Text.RegularExpressions.RegexOptions.Multiline);
        Assert.Contains(expected, batches.Select(b => SchemaLifecycleLock.TryGetModuleName(b.Trim())));
    }

    [Fact]
    public void WrapLifecycleSql_HoldsTheSharedLockAndReleasesItOnFailure()
    {
        var sql = SchemaLifecycleLock.WrapLifecycleSql("EXEC [SCore].[PostDeploymentScript];");
        Assert.Contains("@Resource = N'CymBuild.SchemaLifecycle', @LockMode = N'Shared', @LockOwner = N'Session'", sql, StringComparison.Ordinal);
        Assert.Contains("BEGIN TRY\nEXEC [SCore].[PostDeploymentScript];\nEND TRY", sql.Replace("\r\n", "\n", StringComparison.Ordinal), StringComparison.Ordinal);
        Assert.Equal(2, System.Text.RegularExpressions.Regex.Matches(sql, "sp_releaseapplock").Count);
        Assert.Contains("THROW;", sql, StringComparison.Ordinal);
    }

    private static string FindRepoFile(params string[] segments)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "CymBuild.Monorepo.sln")))
        {
            directory = directory.Parent;
        }

        return Path.Combine([directory?.FullName ?? throw new InvalidOperationException("Repository root not found."), .. segments]);
    }
}
