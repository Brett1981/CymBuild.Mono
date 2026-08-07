using Concursus.API.Client.Models;
using Sage200Microservice.API.Protos.Invoice;

namespace Concursus.API.Client.Tests.FormHelper;

internal static class FormHelperTestFactory
{
    public static Concursus.API.Client.FormHelper Create(
        RecordingCallInvoker callInvoker,
        UserService? userService = null,
        string? entityTypeGuid = null)
    {
        var coreClient = new global::Concursus.API.Core.Core.CoreClient(callInvoker);
        var sageClient = new InvoiceService.InvoiceServiceClient(callInvoker);

        return new Concursus.API.Client.FormHelper(
            coreClient,
            sageClient,
            entityTypeGuid ?? Guid.Empty.ToString(),
            userService ?? new UserService());
    }
}
