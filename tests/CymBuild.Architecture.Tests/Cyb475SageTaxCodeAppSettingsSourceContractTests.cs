using System.Text.Json;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-475: standard-rate UK VAT must post to Sage with tax code 10 (20%). Code 22 is the
/// domestic reverse charge code and Sage applied 17.5%. LIVE 26.2 fixed this, but on
/// 13 Oct 2026 appsettings.QA.json was replaced with a copy from the deployed QA site,
/// which still had 22.
/// </summary>
public sealed class Cyb475SageTaxCodeAppSettingsSourceContractTests
{
    [Theory]
    [InlineData("appsettings.Development.json")]
    [InlineData("appsettings.QA.json")]
    [InlineData("appsettings.Test.json")]
    [InlineData("appsettings.Live.json")]
    public void EnvironmentAppSettings_PostStandardVatWithSageTaxCode10(string fileName)
    {
        var path = RepositoryLayout.PathFromRoot("services", "Concursus.API", fileName);
        using var document = JsonDocument.Parse(
            File.ReadAllText(path),
            new JsonDocumentOptions
            {
                CommentHandling = JsonCommentHandling.Skip,
                AllowTrailingCommas = true,
            });

        var taxCodes = new List<int>();
        Collect(document.RootElement, taxCodes);

        Assert.NotEmpty(taxCodes);
        Assert.All(taxCodes, code => Assert.Equal(10, code));
    }

    private static void Collect(JsonElement element, List<int> taxCodes)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            foreach (var property in element.EnumerateObject())
            {
                if (property.NameEquals("DefaultTaxCode") && property.Value.ValueKind == JsonValueKind.Number)
                {
                    taxCodes.Add(property.Value.GetInt32());
                }
                else
                {
                    Collect(property.Value, taxCodes);
                }
            }
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in element.EnumerateArray())
            {
                Collect(item, taxCodes);
            }
        }
    }
}
