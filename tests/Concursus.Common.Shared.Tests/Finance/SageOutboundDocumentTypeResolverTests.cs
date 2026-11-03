using Concursus.Common.Shared.Models.Finance;
using Xunit;

namespace Concursus.Common.Shared.Tests.Finance;

public sealed class SageOutboundDocumentTypeResolverTests
{
    [Theory]
    [InlineData("Invoice", SageOutboundDocumentType.Invoice)]
    [InlineData(" invoice ", SageOutboundDocumentType.Invoice)]
    [InlineData("CreditNote", SageOutboundDocumentType.CreditNote)]
    [InlineData("Credit Note", SageOutboundDocumentType.CreditNote)]
    [InlineData("credit-note", SageOutboundDocumentType.CreditNote)]
    [InlineData("credit_note", SageOutboundDocumentType.CreditNote)]
    [InlineData("Receipt", SageOutboundDocumentType.Receipt)]
    [InlineData("Payment", SageOutboundDocumentType.Payment)]
    [InlineData("Journal", SageOutboundDocumentType.Unknown)]
    [InlineData("", SageOutboundDocumentType.Unknown)]
    public void Resolve_UsesStableBusinessNameInsteadOfNumericId(
        string name,
        SageOutboundDocumentType expected)
    {
        Assert.Equal(expected, SageOutboundDocumentTypeResolver.Resolve(name));
    }
}
