using Concursus.PWA.Classes;
using Xunit;
using Assert = Xunit.Assert;

namespace Concursus.PWA.Tests
{
    /// <summary>
    /// Renaming an Account straight after creating it re-armed "You must validate before you can
    /// save", but a saved record has no Validate button, so Save silently did nothing until the page
    /// was reloaded (release/26.4 UI run on CymBuild_Dev264, Account 77430). Only a new record may be
    /// re-armed; the same rule is shared by the Account, Contact and Structure pages.
    /// </summary>
    public class DuplicateCheckRevalidationTests
    {
        private static readonly string NewRecordGuid = Guid.Empty.ToString();
        private const string SavedRecordGuid = "61db0cb8-3100-461c-80a9-e73cad1e1041";

        [Fact]
        public void ShouldRearm_NewRecord_WhenAConfirmedIdentifyingFieldChanges() =>
            Assert.True(DuplicateCheckRevalidation.ShouldRearm(validationConfirmed: true, isIdentifyingField: true, NewRecordGuid));

        [Fact]
        public void ShouldNotRearm_SavedRecord_BecauseItHasNoValidateButton() =>
            Assert.False(DuplicateCheckRevalidation.ShouldRearm(validationConfirmed: true, isIdentifyingField: true, SavedRecordGuid));

        [Theory]
        [InlineData(false, true)]
        [InlineData(true, false)]
        [InlineData(false, false)]
        public void ShouldNotRearm_NewRecord_UnlessConfirmedAndIdentifying(bool validationConfirmed, bool isIdentifyingField) =>
            Assert.False(DuplicateCheckRevalidation.ShouldRearm(validationConfirmed, isIdentifyingField, NewRecordGuid));

        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("00000000-0000-0000-0000-000000000000")]
        public void IsNewRecord_TreatsMissingOrEmptyGuidAsNew(string? recordGuid) =>
            Assert.True(DuplicateCheckRevalidation.IsNewRecord(recordGuid));
    }
}
