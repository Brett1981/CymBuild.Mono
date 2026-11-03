using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

// LIVE 26.2 fix 8c9eb85c (only partly in release/26.4): a caught exception can already carry
// MessageType/AdditionalInfo/PageMethod (e.g. when it is reported a second time), and
// Exception.Data.Add then throws ArgumentException ("An item with the same key has already been
// added"), which is what wiped the record view in CYB-551. Caught exceptions in ButtonMenu must use
// SetExceptionData, which overwrites an existing key.
public sealed class ButtonMenuExceptionDataSourceContractTests
{
    [Fact]
    public void CaughtExceptions_UseSetExceptionDataInsteadOfDataAdd()
    {
        var source = File.ReadAllText(RepositoryLayout.PathFromRoot(
            ["apps", "Concursus.PWA", "Shared", "ButtonMenu.razor.cs"]));

        Assert.Contains("private static void SetExceptionData(Exception exception, string key, object value)", source, StringComparison.Ordinal);
        Assert.Empty(Regex.Matches(source, @"\bex\.Data\.Add\("));
    }
}
