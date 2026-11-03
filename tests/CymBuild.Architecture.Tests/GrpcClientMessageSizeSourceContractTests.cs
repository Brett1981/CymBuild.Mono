using System.Text.RegularExpressions;
using Xunit;

namespace CymBuild.Architecture.Tests;

/// <summary>
/// CYB-512: Grpc.Net.Client defaults MaxReceiveMessageSize to 4 MB. The PWA's CoreClient
/// channel was never configured, so any Core-service response over 4 MB failed client-side
/// with "Received message exceeds the maximum configured message size", even though the
/// server (services\Concursus.API\Program.cs AddGrpc()) already accepted up to 16 MB. This
/// guards the client and server limits staying in lock-step and above the gRPC default.
/// </summary>
public sealed class GrpcClientMessageSizeSourceContractTests
{
    private const long DefaultGrpcReceiveMessageSizeBytes = 4L * 1024 * 1024;

    [Fact]
    public void CoreClient_ChannelMessageSizeLimits_MatchServerAndExceedGrpcDefault()
    {
        var pwaProgram = File.ReadAllText(
            RepositoryLayout.PathFromRoot("apps", "Concursus.PWA", "Program.cs"));
        var apiProgram = File.ReadAllText(
            RepositoryLayout.PathFromRoot("services", "Concursus.API", "Program.cs"));

        var coreClientBlock = ExtractRegistrationBlock(
            pwaProgram,
            "AddGrpcClient<Concursus.API.Core.Core.CoreClient>",
            "AddGrpcClient<Concursus.API.TranslationService.TranslationServiceClient>");

        Assert.Contains("ConfigureChannel(", coreClientBlock, StringComparison.Ordinal);

        var clientReceive = ExtractMessageSizeBytes(coreClientBlock, "MaxReceiveMessageSize");
        var clientSend = ExtractMessageSizeBytes(coreClientBlock, "MaxSendMessageSize");
        var serverReceive = ExtractMessageSizeBytes(apiProgram, "MaxReceiveMessageSize");
        var serverSend = ExtractMessageSizeBytes(apiProgram, "MaxSendMessageSize");

        Assert.True(
            clientReceive > DefaultGrpcReceiveMessageSizeBytes,
            "CoreClient's MaxReceiveMessageSize must be raised above the Grpc.Net.Client default (4 MB) - "
            + "see CYB-512, where an unconfigured CoreClient channel rejected legitimate Core-service responses.");

        Assert.Equal(serverReceive, clientReceive);
        Assert.Equal(serverSend, clientSend);
    }

    private static string ExtractRegistrationBlock(string source, string startToken, string endToken)
    {
        var start = source.IndexOf(startToken, StringComparison.Ordinal);
        Assert.True(start >= 0, $"Could not find '{startToken}' in Program.cs.");

        var end = source.IndexOf(endToken, start, StringComparison.Ordinal);
        Assert.True(end > start, $"Could not find '{endToken}' after '{startToken}' in Program.cs.");

        return source[start..end];
    }

    private static long ExtractMessageSizeBytes(string source, string optionName)
    {
        var match = Regex.Match(
            source,
            Regex.Escape(optionName) + @"\s*=\s*(\d+)\s*\*\s*(\d+)\s*\*\s*(\d+)\s*;");

        Assert.True(
            match.Success,
            $"Could not find a '{optionName} = a * b * c;' assignment in the given source block.");

        long product = 1;
        for (var i = 1; i <= 3; i++)
        {
            product *= long.Parse(match.Groups[i].Value);
        }

        return product;
    }
}
