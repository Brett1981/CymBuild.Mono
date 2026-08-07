using Concursus.API.Services.Finance;
using Concursus.Common.Shared.Models.Finance;
using Xunit;

namespace Concursus.API.Tests.Finance;

public sealed class TransactionToSageEligibilityValidatorTests
{
    private readonly TransactionToSageEligibilityValidator _validator = new();

    [Fact]
    public async Task ValidateAsync_NullTransactionReturnsTransactionNotFound()
    {
        var result = await _validator.ValidateAsync(null, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.TransactionNotFound);
    }

    [Fact]
    public async Task ValidateAsync_DisabledIntegrationReturnsSageIntegrationDisabled()
    {
        var result = await _validator.ValidateAsync(CreateValidTransaction(), false, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.SageIntegrationDisabled);
    }

    [Fact]
    public async Task ValidateAsync_InvalidTransitionReturnsTransitionNotFound()
    {
        var transaction = CreateValidTransaction();
        transaction.TransitionGuid = Guid.Empty;

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.TransitionNotFound);
    }

    [Fact]
    public async Task ValidateAsync_InvalidTransactionIdentityReturnsTransactionNotFound()
    {
        var transaction = CreateValidTransaction();
        transaction.TransactionId = 0;

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.TransactionNotFound);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(254)]
    public async Task ValidateAsync_InactiveTransactionReturnsTransactionInactive(byte rowStatus)
    {
        var transaction = CreateValidTransaction();
        transaction.RowStatus = rowStatus;

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.TransactionInactive);
    }

    [Fact]
    public async Task ValidateAsync_BatchedTransactionReturnsTransactionStillBatched()
    {
        var transaction = CreateValidTransaction();
        transaction.Batched = true;

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.TransactionStillBatched);
    }

    [Fact]
    public async Task ValidateAsync_MissingTransactionNumberReturnsExpectedReason()
    {
        var transaction = CreateValidTransaction();
        transaction.TransactionNumber = " ";

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.MissingTransactionNumber);
    }

    [Fact]
    public async Task ValidateAsync_MissingInvoiceNumberReturnsExpectedReason()
    {
        var transaction = CreateValidTransaction();
        transaction.InvoiceNumber = " ";

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.MissingInvoiceNumber);
    }

    [Theory]
    [InlineData(true, "")]
    [InlineData(false, "SAGE-100")]
    public async Task ValidateAsync_ExistingSubmissionReturnsAlreadySubmitted(
        bool alreadySubmitted,
        string existingReference)
    {
        var transaction = CreateValidTransaction();
        transaction.ExistingSageReference = existingReference;

        var result = await _validator.ValidateAsync(transaction, true, alreadySubmitted);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.AlreadySubmitted);
    }

    [Theory]
    [InlineData("", "CUST001")]
    [InlineData("Customer", "")]
    public async Task ValidateAsync_MissingCustomerMappingReturnsExpectedReason(
        string customerName,
        string sageReference)
    {
        var transaction = CreateValidTransaction();
        transaction.CustomerName = customerName;
        transaction.SageCustomerReference = sageReference;

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.MissingCustomerMapping);
    }

    [Fact]
    public async Task ValidateAsync_NoActiveLinesReturnsMissingLines()
    {
        var transaction = CreateValidTransaction();
        transaction.Lines =
        [
            CreateLine(1, rowStatus: 0),
            CreateLine(2, rowStatus: 254)
        ];

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.MissingLines);
    }

    [Theory]
    [InlineData("", 1)]
    [InlineData("Professional services", 0)]
    public async Task ValidateAsync_UnusableActiveLineReturnsInvalidLineData(
        string description,
        int quantity)
    {
        var transaction = CreateValidTransaction();
        transaction.Lines = [CreateLine(1, description: description, quantity: quantity)];

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.InvalidLineData);
    }

    [Fact]
    public async Task ValidateAsync_NegativeLineFinancialValueReturnsInvalidLineData()
    {
        var transaction = CreateValidTransaction();
        transaction.Lines[0].VatAmount = -1m;

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.InvalidLineData);
    }

    [Fact]
    public async Task ValidateAsync_NegativeHeaderTotalReturnsMissingRequiredFinancialData()
    {
        var transaction = CreateValidTransaction();
        transaction.NetAmount = -1m;

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.MissingRequiredFinancialData);
    }

    [Fact]
    public async Task ValidateAsync_NonPositiveGrossTotalReturnsMissingRequiredFinancialData()
    {
        var transaction = CreateValidTransaction();
        transaction.GrossAmount = 0m;

        var result = await _validator.ValidateAsync(transaction, true, false);

        AssertNotEligible(result, TransactionToSageEligibilityFailureReason.MissingRequiredFinancialData);
    }

    [Fact]
    public async Task ValidateAsync_ValidTransactionReturnsEligible()
    {
        var result = await _validator.ValidateAsync(CreateValidTransaction(), true, false);

        Assert.True(result.IsEligible);
        Assert.Equal(TransactionToSageEligibilityFailureReason.None, result.FailureReason);
        Assert.Empty(result.Message);
    }

    [Fact]
    public async Task ValidateAsync_CancelledTokenThrowsBeforeEvaluation()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        await Assert.ThrowsAsync<OperationCanceledException>(() =>
            _validator.ValidateAsync(CreateValidTransaction(), true, false, cancellation.Token));
    }

    private static void AssertNotEligible(
        TransactionToSageEligibilityResult result,
        TransactionToSageEligibilityFailureReason expectedReason)
    {
        Assert.False(result.IsEligible);
        Assert.Equal(expectedReason, result.FailureReason);
        Assert.False(string.IsNullOrWhiteSpace(result.Message));
    }

    private static ApprovedTransactionForSageReadModel CreateValidTransaction()
    {
        return new ApprovedTransactionForSageReadModel
        {
            TransitionGuid = Guid.NewGuid(),
            TransitionId = 10,
            TransactionGuid = Guid.NewGuid(),
            TransactionId = 20,
            TransactionNumber = "TX-100",
            InvoiceNumber = "INV-100",
            RowStatus = 1,
            Batched = false,
            CustomerName = "Customer",
            SageCustomerReference = "CUST001",
            NetAmount = 100m,
            VatAmount = 20m,
            GrossAmount = 120m,
            Lines = [CreateLine(1)]
        };
    }

    private static ApprovedTransactionForSageLineReadModel CreateLine(
        long id,
        byte rowStatus = 1,
        string description = "Professional services",
        decimal quantity = 1m)
    {
        return new ApprovedTransactionForSageLineReadModel
        {
            LineId = id,
            RowStatus = rowStatus,
            Description = description,
            Quantity = quantity,
            UnitPrice = 100m,
            NetAmount = 100m,
            VatAmount = 20m,
            GrossAmount = 120m
        };
    }
}
