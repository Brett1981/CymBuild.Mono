using Concursus.API.Core;
using Concursus.PWA.Classes;
using Xunit;
using static Concursus.PWA.Shared.MessageDisplay;
using Assert = Xunit.Assert;

namespace Concursus.PWA.Tests
{
    /// <summary>
    /// Tasks -> "Create Quote(s) from enquiry" on an enquiry with Value Of Work = 0 did nothing:
    /// the pre-save returned "An enquiry cannot be reviewed until there is a value of work." but the
    /// action reported a blank message (release/26.4 UI run on CymBuild_Dev264, Enquiry 4233).
    /// </summary>
    public class ActionBlockedByValidationMessageTests
    {
        private const string ValueOfWorkMessage = "An enquiry cannot be reviewed until there is a value of work.";

        [Fact]
        public void BuildsAWarningNamingTheActionAndTheValidationMessage()
        {
            var message = PWAFunctions.BuildActionBlockedByValidationMessage(
                "Create Quote(s) from enquiry",
                new[] { new ValidationResults { IsInvalid = true, Message = ValueOfWorkMessage } });

            Assert.Equal(
                "'Create Quote(s) from enquiry' was not run. Fix the following first: " + ValueOfWorkMessage,
                message.Message);
            Assert.Equal(ShowMessageType.Warning, message.Data["MessageType"]);
            Assert.Equal(message.Message, message.Data["AdditionalInfo"]);
        }

        [Fact]
        public void ListsEachDistinctMessageOnceAndSkipsBlankOnes()
        {
            var message = PWAFunctions.BuildActionBlockedByValidationMessage(
                "Create Jobs",
                new[]
                {
                    new ValidationResults { Message = "First problem." },
                    new ValidationResults { Message = "  " },
                    new ValidationResults { Message = "First problem." },
                    new ValidationResults { Message = "Second problem." }
                });

            Assert.Equal("'Create Jobs' was not run. Fix the following first: First problem. Second problem.", message.Message);
        }

        [Fact]
        public void FallsBackToAGenericReasonWhenNoMessageWasReturned()
        {
            var message = PWAFunctions.BuildActionBlockedByValidationMessage("Revise Quote", Array.Empty<ValidationResults>());

            Assert.Equal(
                "'Revise Quote' was not run because the record has validation errors. Fix the highlighted fields and try again.",
                message.Message);
        }
    }
}
