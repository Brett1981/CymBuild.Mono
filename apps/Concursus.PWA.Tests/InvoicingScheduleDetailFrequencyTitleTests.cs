using Concursus.PWA.Pages;
using Xunit;
using Assert = Xunit.Assert;

namespace Concursus.PWA.Tests
{
    /// <summary>
    /// Covers the CYB-279 frequency-persistence feature: the "Monthly Drawdowns" heading above
    /// the Invoice Scheduling grid should reflect the frequency last used to generate the
    /// series (e.g. "Quarterly Drawdowns"), falling back to the generic "Monthly Drawdowns"
    /// label when no series has been generated yet.
    /// </summary>
    public class InvoicingScheduleDetailFrequencyTitleTests
    {
        [Theory]
        [InlineData(null, "Monthly Drawdowns")]
        [InlineData("", "Monthly Drawdowns")]
        [InlineData("   ", "Monthly Drawdowns")]
        [InlineData("Monthly", "Monthly Drawdowns")]
        [InlineData("Quarterly", "Quarterly Drawdowns")]
        [InlineData("Bi-monthly", "Bi-monthly Drawdowns")]
        [InlineData("Bi-annual", "Bi-annual Drawdowns")]
        public void FormatMonthlyDrawdownsTitle_ReflectsPersistedFrequency(string? frequency, string expected)
        {
            var result = InvoicingScheduleDetail.FormatMonthlyDrawdownsTitle(frequency);

            Assert.Equal(expected, result);
        }
    }
}
