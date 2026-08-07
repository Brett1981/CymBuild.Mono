using Concursus.API.Services.Finance;
using Concursus.Common.Shared.Models.Finance;
using Concursus.Common.Shared.Services.Finance;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Concursus.API.Tests.Finance;

public sealed class TransactionSageSubmissionAdminServiceTests
{
    [Fact]
    public void Constructor_NullRepositoryThrowsArgumentNullException()
    {
        Assert.Throws<ArgumentNullException>(() => new TransactionSageSubmissionAdminService(
            null!,
            Mock.Of<ILogger<TransactionSageSubmissionAdminService>>()));
    }

    [Fact]
    public void Constructor_NullLoggerThrowsArgumentNullException()
    {
        Assert.Throws<ArgumentNullException>(() => new TransactionSageSubmissionAdminService(
            Mock.Of<ITransactionSageSubmissionAdminRepository>(),
            null!));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task RequeueAsync_PassesArgumentsAndReturnsRepositoryResult(bool includeNonRetryableFailures)
    {
        var transactionGuids = new[]
        {
            Guid.Parse("55555555-5555-5555-5555-555555555555"),
            Guid.Parse("66666666-6666-6666-6666-666666666666")
        };
        var expected = new TransactionSageSubmissionRequeueResult
        {
            RequeuedTransactionCount = 2,
            ResetOutboxRowCount = 3,
            ResetStatusRowCount = 2,
            Message = "Requeued"
        };
        var repository = new Mock<ITransactionSageSubmissionAdminRepository>();
        repository
            .Setup(x => x.RequeueAsync(
                transactionGuids,
                includeNonRetryableFailures,
                It.IsAny<CancellationToken>()))
            .ReturnsAsync(expected);
        var service = new TransactionSageSubmissionAdminService(
            repository.Object,
            Mock.Of<ILogger<TransactionSageSubmissionAdminService>>());

        var actual = await service.RequeueAsync(transactionGuids, includeNonRetryableFailures);

        Assert.Same(expected, actual);
        repository.Verify(x => x.RequeueAsync(
            transactionGuids,
            includeNonRetryableFailures,
            It.IsAny<CancellationToken>()), Times.Once);
    }
}
