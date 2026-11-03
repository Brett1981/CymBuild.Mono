using CymBuild_Outlook_API.Services;
using Xunit;

namespace CymBuild_Outlook_API.Tests;

public sealed class BlueGenServicePromptTests
{
    [Fact]
    public void BuildDescriptionPrompt_WithoutAttachmentName_BuildsEmailPrompt()
    {
        var prompt = BlueGenService.BuildDescriptionPrompt("Quote follow-up", "Please see attached.", attachmentName: null);

        Assert.Contains("Subject: Quote follow-up", prompt);
        Assert.Contains("Body: Please see attached.", prompt);
        Assert.Contains("for this email to be used when filing it", prompt);
        Assert.DoesNotContain("Attachment file name", prompt);
    }

    [Fact]
    public void BuildDescriptionPrompt_WithAttachmentName_BuildsAttachmentPrompt()
    {
        var prompt = BlueGenService.BuildDescriptionPrompt("Quote follow-up", "Please see attached.", attachmentName: "Quote-1234.pdf");

        Assert.Contains("Attachment file name: Quote-1234.pdf", prompt);
        Assert.Contains("Email subject: Quote follow-up", prompt);
        Assert.Contains("for this email attachment to be used when filing it", prompt);
        Assert.Contains("you do not have the attachment's contents", prompt);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void BuildDescriptionPrompt_TreatsBlankAttachmentNameAsEmailPrompt(string? attachmentName)
    {
        var prompt = BlueGenService.BuildDescriptionPrompt("Subject", "Body", attachmentName);

        Assert.DoesNotContain("Attachment file name", prompt);
    }

    [Fact]
    public void BuildDescriptionPrompt_TruncatesLongBody()
    {
        var longBody = new string('x', 2000);

        var prompt = BlueGenService.BuildDescriptionPrompt("Subject", longBody, attachmentName: null);

        Assert.Contains(new string('x', 1000) + "...", prompt);
        Assert.DoesNotContain(longBody, prompt);
    }
}
