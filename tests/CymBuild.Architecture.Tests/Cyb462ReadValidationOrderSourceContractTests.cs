using Xunit;

namespace CymBuild.Architecture.Tests;

// CYB-462: on a Sent quote, Description of Works (Quote_ExtendedInfo) was editable until the first
// edit. ReadEntityHoBT validated each HoBT straight after reading it, so tvf_QuotesValidate ran
// before the Quote_ExtendedInfo properties existed and its locks on them were dropped. Validation
// on read must run once, after every HoBT has been read.
public sealed class Cyb462ReadValidationOrderSourceContractTests
{
    private static string ReadCore() =>
        File.ReadAllText(RepositoryLayout.PathFromRoot(["libs", "Concursus.EF", "Core.cs"]));

    private static string MethodBody(string source, string signatureStart)
    {
        var start = source.IndexOf(signatureStart, StringComparison.Ordinal);
        Assert.True(start >= 0, $"'{signatureStart}' was not found in libs/Concursus.EF/Core.cs.");

        var next = source.IndexOf("\n        private ", start + signatureStart.Length, StringComparison.Ordinal);
        var nextPublic = source.IndexOf("\n        public ", start + signatureStart.Length, StringComparison.Ordinal);
        var end = new[] { next, nextPublic }.Where(i => i > 0).DefaultIfEmpty(source.Length).Min();
        return source[start..end];
    }

    [Fact]
    public void ReadEntityHoBT_DoesNotValidatePerHoBT()
    {
        var body = MethodBody(ReadCore(), "private async Task<DataObject> ReadEntityHoBT(");

        Assert.DoesNotContain("Validation.RunObjectValidation", body, StringComparison.Ordinal);
        Assert.DoesNotContain("Validation.ApplyValidationResults", body, StringComparison.Ordinal);
    }

    [Fact]
    public void DataObjectGet_ValidatesAfterAllHoBTsAreRead()
    {
        var body = MethodBody(ReadCore(), "public async Task<List<DataObject>> DataObjectGet(");

        var readLoop = body.IndexOf("await ReadEntityHoBT(", StringComparison.Ordinal);
        var validate = body.IndexOf("await ValidateReadDataObject(", StringComparison.Ordinal);

        Assert.True(readLoop >= 0, "DataObjectGet no longer reads HoBTs through ReadEntityHoBT.");
        Assert.True(validate > readLoop, "DataObjectGet must validate after the HoBT read loop.");
    }

    [Fact]
    public void ValidateReadDataObject_AppliesAllHoBTResultsInOnePass()
    {
        var body = MethodBody(ReadCore(), "private static async Task<DataObject> ValidateReadDataObject(");

        Assert.Contains("Validation.RunObjectValidation", body, StringComparison.Ordinal);
        Assert.Contains("hobts.Select(h => h.Guid).ToList()", body, StringComparison.Ordinal);
    }
}
