using System.Text.Json;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-461: the RecordExpiry worker skips every tick when its ServiceUserGuid is
/// empty. QA ran like that from 06 Oct 2026 because the section was dropped when the
/// environment appsettings were replaced with copies from the deployed sites.
/// </summary>
public sealed class Cyb461RecordExpiryAppSettingsSourceContractTests
{
    private const string ExpectedServiceUserGuid = "1E7A4894-54AA-4CB4-9E54-C697ABB32F74";

    [Theory]
    [InlineData("appsettings.Development.json")]
    [InlineData("appsettings.QA.json")]
    [InlineData("appsettings.Test.json")]
    [InlineData("appsettings.Live.json")]
    public void EnvironmentAppSettings_ConfigureRecordExpiry(string fileName)
    {
        var path = RepositoryLayout.PathFromRoot("services", "Concursus.API", fileName);
        using var document = JsonDocument.Parse(
            File.ReadAllText(path),
            new JsonDocumentOptions
            {
                CommentHandling = JsonCommentHandling.Skip,
                AllowTrailingCommas = true,
            });

        Assert.True(
            document.RootElement.TryGetProperty("RecordExpiry", out var section),
            $"{fileName} has no RecordExpiry section.");

        Assert.True(section.GetProperty("Enabled").GetBoolean(), $"{fileName}: RecordExpiry.Enabled");
        Assert.Equal(3600, section.GetProperty("IntervalSeconds").GetInt32());
        Assert.Equal(
            Guid.Parse(ExpectedServiceUserGuid),
            Guid.Parse(section.GetProperty("ServiceUserGuid").GetString()!));
        Assert.Equal(500, section.GetProperty("MaxRecordsPerRun").GetInt32());
        Assert.Equal(7, section.GetProperty("NotifyWithinDays").GetInt32());
        Assert.Equal(600, section.GetProperty("CommandTimeoutSeconds").GetInt32());
    }
}
