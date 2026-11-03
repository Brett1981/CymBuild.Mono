using Concursus.API.Client.Models.Finance;
using Concursus.PWA.Shared;
using Xunit;
using Assert = Xunit.Assert;

namespace Concursus.PWA.Tests
{
    /// <summary>
    /// Covers the CYB-279 QA-feedback fix: the Invoice Scheduling "Edit Drawdowns" inline
    /// editor's Stage dropdown always showed "-- None --" instead of the row's previously-saved
    /// stage, because the grid only exposes the stage's plain description (e.g. "Strategic
    /// Definition"), never its RibaStageID, and the fallback name match compared that plain
    /// description against the lookup's formatted option names (e.g.
    /// "Riba Stage 0 - Strategic Definition"), which never matched.
    /// </summary>
    public class DynamicGridViewDrawdownStageTests
    {
        private static readonly List<InvoiceScheduleDrawdownStageLookupModel> StageOptions = new()
        {
            new InvoiceScheduleDrawdownStageLookupModel
            {
                Guid = Guid.Parse("37A7FD49-ABE5-418A-8A9F-9DC6EBD57EA0"),
                Name = "Riba Stage 0 - Strategic Definition"
            },
            new InvoiceScheduleDrawdownStageLookupModel
            {
                Guid = Guid.Parse("B08CBB5C-C93C-461F-ACAC-5071CC48029F"),
                Name = "Riba Stage 3 - Spacial Coordination"
            },
            new InvoiceScheduleDrawdownStageLookupModel
            {
                Guid = Guid.Parse("FB5C4AA2-ABEB-403E-9CFE-16AC1D9D0424"),
                Name = "Fee Stage 99 - Pre-Construction"
            }
        };

        [Fact]
        public void ResolveDrawdownStageGuid_MatchesPlainDescriptionAgainstFormattedOptionSuffix()
        {
            var result = DynamicGridView.ResolveDrawdownStageGuid(
                explicitGuidText: string.Empty,
                stageDescription: "Strategic Definition",
                stageOptions: StageOptions);

            Assert.Equal("37a7fd49-abe5-418a-8a9f-9dc6ebd57ea0", result);
        }

        [Fact]
        public void ResolveDrawdownStageGuid_MatchIsCaseInsensitive()
        {
            var result = DynamicGridView.ResolveDrawdownStageGuid(
                explicitGuidText: null,
                stageDescription: "pre-construction",
                stageOptions: StageOptions);

            Assert.Equal("fb5c4aa2-abeb-403e-9cfe-16ac1d9d0424", result);
        }

        [Fact]
        public void ResolveDrawdownStageGuid_MatchesFullOptionNameExactly()
        {
            var result = DynamicGridView.ResolveDrawdownStageGuid(
                explicitGuidText: string.Empty,
                stageDescription: "Riba Stage 3 - Spacial Coordination",
                stageOptions: StageOptions);

            Assert.Equal("b08cbb5c-c93c-461f-acac-5071cc48029f", result);
        }

        [Fact]
        public void ResolveDrawdownStageGuid_ExplicitGuidTakesPrecedenceOverDescription()
        {
            var explicitGuid = "fb5c4aa2-abeb-403e-9cfe-16ac1d9d0424";

            var result = DynamicGridView.ResolveDrawdownStageGuid(
                explicitGuidText: explicitGuid,
                stageDescription: "Strategic Definition",
                stageOptions: StageOptions);

            Assert.Equal(explicitGuid, result);
        }

        [Fact]
        public void ResolveDrawdownStageGuid_IgnoresExplicitEmptyGuidAndFallsBackToDescription()
        {
            var result = DynamicGridView.ResolveDrawdownStageGuid(
                explicitGuidText: Guid.Empty.ToString(),
                stageDescription: "Strategic Definition",
                stageOptions: StageOptions);

            Assert.Equal("37a7fd49-abe5-418a-8a9f-9dc6ebd57ea0", result);
        }

        [Fact]
        public void ResolveDrawdownStageGuid_ReturnsEmptyWhenDescriptionIsBlank()
        {
            var result = DynamicGridView.ResolveDrawdownStageGuid(
                explicitGuidText: string.Empty,
                stageDescription: "   ",
                stageOptions: StageOptions);

            Assert.Equal(string.Empty, result);
        }

        [Fact]
        public void ResolveDrawdownStageGuid_ReturnsEmptyWhenNoOptionMatches()
        {
            var result = DynamicGridView.ResolveDrawdownStageGuid(
                explicitGuidText: string.Empty,
                stageDescription: "Handover & Close Out",
                stageOptions: StageOptions);

            Assert.Equal(string.Empty, result);
        }
    }
}
