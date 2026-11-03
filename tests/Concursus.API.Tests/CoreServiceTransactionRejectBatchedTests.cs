using Concursus.API.Core;
using Xunit;

namespace Concursus.API.Tests;

/// <summary>
/// CoreService.TransactionRejectBatched calls _serviceBase._entityFramework once past its
/// input-validation guard, so only the guard-clause branch is safe to exercise via
/// CoreServiceTestFactory (which never opens a real connection) - the success/failure
/// passthrough branch needs a real SQL Server-backed integration test instead, which does not
/// currently exist for this method (mirrors CoreService.SchemaMigration.cs's situation).
/// </summary>
public sealed class CoreServiceTransactionRejectBatchedTests
{
    [Theory]
    [InlineData("")]
    [InlineData("not-a-guid")]
    [InlineData("00000000-0000-0000-0000-000000000000")]
    public async Task TransactionRejectBatched_RejectsInvalidTransactionGuidWithoutTouchingEntityFramework(
        string transactionGuid)
    {
        var (service, _) = CoreServiceTestFactory.Create();

        var response = await service.TransactionRejectBatched(
            new TransactionRejectBatchedRequest
            {
                TransactionGuid = transactionGuid,
                RejectionReason = "Duplicate entry"
            },
            TestServerCallContext.Create());

        Assert.False(response.Success);
        Assert.Equal(
            "A valid Transaction Guid is required to reject a batched transaction.",
            response.ErrorReturned);
    }
}
