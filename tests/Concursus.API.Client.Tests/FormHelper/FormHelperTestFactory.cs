using Concursus.API.Client.Models;

namespace Concursus.API.Client.Tests.FormHelper;

internal static class FormHelperTestFactory
{
    public static Concursus.API.Client.FormHelper Create(
        RecordingCallInvoker callInvoker,
        UserService? userService = null,
        string? entityTypeGuid = null)
    {
        var coreClient = new global::Concursus.API.Core.Core.CoreClient(callInvoker);
        return new Concursus.API.Client.FormHelper(
            coreClient,
            entityTypeGuid ?? Guid.Empty.ToString(),
            userService ?? new UserService());
    }
}
