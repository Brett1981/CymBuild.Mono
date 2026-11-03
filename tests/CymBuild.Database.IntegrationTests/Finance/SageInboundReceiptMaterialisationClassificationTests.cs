using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// Credit Note (5) and Receipt (1) rows are the primary allocation sources and
/// different explicit sources remain independent. CYB-568 (restoring CYB-543,
/// reversing CYB-555): an allocated Invoice (4) row also materialises a Receipt
/// while no distinct 1/5 row exists for the invoice, because the production Sage
/// source only ever flips IsPaid/AllocatedValue on the invoice row.
/// </summary>
[Trait("Level", "Database")]
[Trait("Area", "Sage")]
public sealed class SageInboundReceiptMaterialisationClassificationTests
{
    [Fact]
    public async Task Materialise_InvoiceRowWithNoDistinctAllocationSource_CreatesReceipt_ThatALaterReceiptReuses()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var invoice = await InsertMaterialisableInvoiceFixtureAsync(
                connection, transaction, reservedInvoiceNumber: "RES-P555-001");

            // Sage only flipped the Invoice row to allocated, so it is the
            // Receipt source.
            var invoiceExternalTransactionId = await UpsertSageExternalTransactionAsync(
                connection, transaction,
                sageDocumentNo: "RES-P555-001",
                sageTransactionReference: "SI-P555-001",
                sageTransactionTypeCode: 4,
                allocatedValue: 120m,
                matchedTransactionId: invoice.TransactionId);

            await ExecuteMaterialiseAsync(connection, transaction, invoiceExternalTransactionId);

            var invoiceResult = await ReadMaterialisationResultAsync(connection, transaction, invoiceExternalTransactionId);
            Assert.NotNull(invoiceResult.ReceiptTransactionGuid);
            Assert.NotNull(invoiceResult.AllocationGuid);

            Assert.Equal(
                1,
                await CountAllocationSourceTransactionsForInvoiceAsync(connection, transaction, invoice.TransactionId));
            Assert.Equal(
                1,
                await CountAllocationsForInvoiceAsync(connection, transaction, invoice.TransactionId));

            // A later explicit Receipt takes over the same receipt/allocation
            // instead of creating a second one.
            var receiptExternalTransactionId = await UpsertSageExternalTransactionAsync(
                connection, transaction,
                sageDocumentNo: "RES-P555-001",
                sageTransactionReference: "SR-P555-001",
                sageTransactionTypeCode: 1,
                allocatedValue: 120m,
                matchedTransactionId: invoice.TransactionId);

            await ExecuteMaterialiseAsync(connection, transaction, receiptExternalTransactionId);

            var receiptResult = await ReadMaterialisationResultAsync(connection, transaction, receiptExternalTransactionId);
            Assert.Equal(invoiceResult.ReceiptTransactionGuid, receiptResult.ReceiptTransactionGuid);
            Assert.Equal(invoiceResult.AllocationGuid, receiptResult.AllocationGuid);

            Assert.Equal(
                1,
                await CountAllocationSourceTransactionsForInvoiceAsync(connection, transaction, invoice.TransactionId));
            Assert.Equal(
                1,
                await CountAllocationsForInvoiceAsync(connection, transaction, invoice.TransactionId));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task Materialise_InvoiceRowDoesNotCreateSecondSource_WhenReceiptAlreadyMaterialised()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var invoice = await InsertMaterialisableInvoiceFixtureAsync(
                connection, transaction, reservedInvoiceNumber: "RES-P555-002");

            // A genuine Receipt row is matched to the invoice first.
            var receiptExternalTransactionId = await UpsertSageExternalTransactionAsync(
                connection, transaction,
                sageDocumentNo: "RES-P555-002",
                sageTransactionReference: "SR-P555-002",
                sageTransactionTypeCode: 1,
                allocatedValue: 120m,
                matchedTransactionId: invoice.TransactionId);

            await ExecuteMaterialiseAsync(connection, transaction, receiptExternalTransactionId);

            Assert.Equal(
                1,
                await CountAllocationSourceTransactionsForInvoiceAsync(connection, transaction, invoice.TransactionId));

            // Sage also reports the aggregate allocation on the Invoice row. Once
            // a real Receipt exists it must not materialise another transaction.
            var invoiceExternalTransactionId = await UpsertSageExternalTransactionAsync(
                connection, transaction,
                sageDocumentNo: "RES-P555-002",
                sageTransactionReference: "SI-P555-002",
                sageTransactionTypeCode: 4,
                allocatedValue: 120m,
                matchedTransactionId: invoice.TransactionId);

            await ExecuteMaterialiseAsync(connection, transaction, invoiceExternalTransactionId);

            var invoiceRowResult = await ReadMaterialisationResultAsync(connection, transaction, invoiceExternalTransactionId);
            Assert.Null(invoiceRowResult.ReceiptTransactionGuid);
            Assert.Null(invoiceRowResult.AllocationGuid);

            Assert.Equal(
                1,
                await CountAllocationSourceTransactionsForInvoiceAsync(connection, transaction, invoice.TransactionId));
            Assert.Equal(
                1,
                await CountAllocationsForInvoiceAsync(connection, transaction, invoice.TransactionId));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task Materialise_CreditNoteAndReceiptRows_CreateSeparateAllocationSources()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var invoice = await InsertMaterialisableInvoiceFixtureAsync(
                connection, transaction, reservedInvoiceNumber: "RES-P555-003");

            var creditNoteExternalTransactionId = await UpsertSageExternalTransactionAsync(
                connection, transaction,
                sageDocumentNo: "RES-P555-003",
                sageTransactionReference: "SC-P555-003",
                sageTransactionTypeCode: 5,
                allocatedValue: 120m,
                matchedTransactionId: invoice.TransactionId);

            var receiptExternalTransactionId = await UpsertSageExternalTransactionAsync(
                connection, transaction,
                sageDocumentNo: "RES-P555-003",
                sageTransactionReference: "SR-P555-003",
                sageTransactionTypeCode: 1,
                allocatedValue: 120m,
                matchedTransactionId: invoice.TransactionId);

            await ExecuteMaterialiseAsync(connection, transaction, creditNoteExternalTransactionId);
            await ExecuteMaterialiseAsync(connection, transaction, receiptExternalTransactionId);

            var creditNoteResult = await ReadMaterialisationResultAsync(
                connection, transaction, creditNoteExternalTransactionId);
            var receiptResult = await ReadMaterialisationResultAsync(
                connection, transaction, receiptExternalTransactionId);

            Assert.NotNull(creditNoteResult.ReceiptTransactionGuid);
            Assert.NotNull(creditNoteResult.AllocationGuid);
            Assert.NotNull(receiptResult.ReceiptTransactionGuid);
            Assert.NotNull(receiptResult.AllocationGuid);
            Assert.NotEqual(creditNoteResult.ReceiptTransactionGuid, receiptResult.ReceiptTransactionGuid);
            Assert.NotEqual(creditNoteResult.AllocationGuid, receiptResult.AllocationGuid);

            Assert.Equal(
                2,
                await CountAllocationSourceTransactionsForInvoiceAsync(connection, transaction, invoice.TransactionId));
            Assert.Equal(
                2,
                await CountAllocationsForInvoiceAsync(connection, transaction, invoice.TransactionId));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    /// <summary>
    /// CYB-568: a Sage Receipt reports the cash received (VAT-inclusive) as its
    /// netAmount with no tax split. The receipt line must store the VAT-exclusive
    /// net so that TransactionDetailsUpsert's VAT calculation reproduces the
    /// received gross, rather than adding VAT a second time.
    /// </summary>
    [Fact]
    public async Task Materialise_ReceiptWithoutTaxSplit_StoresVatExclusiveNetAndSageDate()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var invoice = await InsertMaterialisableInvoiceFixtureAsync(
                connection, transaction, reservedInvoiceNumber: "RES-P568-001", vatPercentage: 20m);
            var receiptDate = new DateTime(2026, 9, 4);

            // Job 8880 from the ticket: invoice £1200 + VAT = £1440, receipt £1440.
            var receiptExternalTransactionId = await UpsertSageExternalTransactionAsync(
                connection, transaction,
                sageDocumentNo: "RES-P568-001",
                sageTransactionReference: "SR-P568-001",
                sageTransactionTypeCode: 1,
                allocatedValue: 1440m,
                matchedTransactionId: invoice.TransactionId,
                netAmount: 1440m,
                taxAmount: 0m,
                transactionDate: receiptDate);

            await ExecuteMaterialiseAsync(connection, transaction, receiptExternalTransactionId);

            var receiptResult = await ReadMaterialisationResultAsync(connection, transaction, receiptExternalTransactionId);
            Assert.NotNull(receiptResult.ReceiptTransactionGuid);

            const string receiptSql = """
SELECT t.[Date], td.Net, td.Vat, td.Gross
FROM SFin.Transactions AS t
JOIN SFin.TransactionDetails AS td
    ON td.TransactionID = t.ID
   AND td.RowStatus NOT IN (0,254)
WHERE t.Guid = @Guid
  AND t.RowStatus NOT IN (0,254);
""";
            await using var command = SqlTestDatabase.CreateCommand(
                connection, transaction, receiptSql,
                new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = receiptResult.ReceiptTransactionGuid!.Value } });
            await using var reader = await command.ExecuteReaderAsync();

            Assert.True(await reader.ReadAsync(), "The materialised receipt has no active detail line.");
            Assert.Equal(receiptDate, reader.GetDateTime(0));
            Assert.Equal(1200m, reader.GetDecimal(1));
            Assert.Equal(240m, reader.GetDecimal(2));
            Assert.Equal(1440m, reader.GetDecimal(3));
            Assert.False(await reader.ReadAsync(), "The materialised receipt must have exactly one detail line.");
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Theory]
    [InlineData(4, 1)]
    [InlineData(5, 1)]
    [InlineData(1, 1)]
    // SFA: 6 is an Opening Balance Invoice, not a Receipt.
    [InlineData(6, 0)]
    public async Task AutoCorrect_DryRun_SelectsAllocationSourceCandidates(
        int sageTransactionTypeCode,
        int expectedCandidateCount)
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var documentNumber = $"RES-P555-AC-{sageTransactionTypeCode}";
            var invoice = await InsertMaterialisableInvoiceFixtureAsync(
                connection, transaction, reservedInvoiceNumber: documentNumber);
            var externalTransactionId = await UpsertSageExternalTransactionAsync(
                connection, transaction,
                sageDocumentNo: documentNumber,
                sageTransactionReference: $"ST-P555-AC-{sageTransactionTypeCode}",
                sageTransactionTypeCode: sageTransactionTypeCode,
                allocatedValue: 120m,
                matchedTransactionId: invoice.TransactionId);

            var candidateCount = await ReadAutoCorrectDryRunCandidateCountAsync(
                connection, transaction, externalTransactionId);

            Assert.Equal(expectedCandidateCount, candidateCount);
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Theory]
    [InlineData(4)]
    [InlineData(1)]
    public async Task AutoCorrect_Apply_CreatesReceiptAndAllocation(int sageTransactionTypeCode)
    {
        // CYB-568: AutoCorrect (the Inbound Diagnostics "Fix Receipt" action) is the
        // only caller of SageInbound_ReconcileInvoiceTransaction via INSERT ... EXEC.
        // Its result-set table was missing MatchedTransactionGuid, so every real run
        // failed with "Column name or number of supplied values does not match table
        // definition". The dry-run tests never reach that INSERT ... EXEC.
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var documentNumber = $"RES-P568-AC-{sageTransactionTypeCode}";
            var invoice = await InsertMaterialisableInvoiceFixtureAsync(
                connection, transaction, reservedInvoiceNumber: documentNumber);
            var externalTransactionId = await UpsertSageExternalTransactionAsync(
                connection, transaction,
                sageDocumentNo: documentNumber,
                sageTransactionReference: $"ST-P568-AC-{sageTransactionTypeCode}",
                sageTransactionTypeCode: sageTransactionTypeCode,
                allocatedValue: 120m,
                matchedTransactionId: invoice.TransactionId);

            var parameters = new[]
            {
                new SqlParameter("@ExternalTransactionID", SqlDbType.BigInt) { Value = externalTransactionId },
                new SqlParameter("@BatchSize", SqlDbType.Int) { Value = 1 },
                new SqlParameter("@DryRun", SqlDbType.Bit) { Value = false }
            };

            int correctedCount;
            int failedCount;
            var messages = new List<string>();

            await using (var command = SqlTestDatabase.CreateCommand(
                connection, transaction, "SFin.SageInboundReceiptMaterialisation_AutoCorrect",
                parameters, CommandType.StoredProcedure))
            await using (var reader = await command.ExecuteReaderAsync())
            {
                Assert.True(await reader.ReadAsync(), "AutoCorrect did not return its summary result set.");
                correctedCount = reader.GetInt32(reader.GetOrdinal("CorrectedCount"));
                failedCount = reader.GetInt32(reader.GetOrdinal("FailedCount"));

                if (await reader.NextResultAsync())
                {
                    while (await reader.ReadAsync())
                    {
                        messages.Add(reader["Message"]?.ToString() ?? string.Empty);
                    }
                }
            }

            Assert.True(failedCount == 0, string.Join(Environment.NewLine, messages));
            Assert.Equal(1, correctedCount);

            var result = await ReadMaterialisationResultAsync(connection, transaction, externalTransactionId);
            Assert.NotNull(result.ReceiptTransactionGuid);
            Assert.NotNull(result.AllocationGuid);
            Assert.Equal(
                1,
                await CountAllocationsForInvoiceAsync(connection, transaction, invoice.TransactionId));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task ReceiptDelete_RetiresLinesAndAllocations_AndALaterPollLeavesItDeleted()
    {
        // CYB-555: Finance deletes a fallback Receipt that was really a credit-note
        // settlement. The invoice must show as outstanding again, and the next Sage
        // poll must neither revive the Receipt nor fail.
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var invoice = await InsertMaterialisableInvoiceFixtureAsync(
                connection, transaction, reservedInvoiceNumber: "RES-P555-DEL1");

            var externalTransactionId = await UpsertSageExternalTransactionAsync(
                connection, transaction,
                sageDocumentNo: "RES-P555-DEL1",
                sageTransactionReference: "SI-P555-DEL1",
                sageTransactionTypeCode: 4,
                allocatedValue: 120m,
                matchedTransactionId: invoice.TransactionId);

            await ExecuteMaterialiseAsync(connection, transaction, externalTransactionId);

            var materialised = await ReadMaterialisationResultAsync(connection, transaction, externalTransactionId);
            Assert.NotNull(materialised.ReceiptTransactionGuid);
            Assert.Equal(1, await CountAllocationsForInvoiceAsync(connection, transaction, invoice.TransactionId));

            await ExecuteTransactionDeleteAsync(connection, transaction, materialised.ReceiptTransactionGuid.Value);

            var deleted = await ReadReceiptDeleteStateAsync(connection, transaction, materialised.ReceiptTransactionGuid.Value);
            Assert.Equal(254, deleted.TransactionRowStatus);
            Assert.Equal(254, deleted.DataObjectRowStatus);
            Assert.Equal(0, deleted.ActiveLines);
            Assert.Equal(0, deleted.ActiveAllocations);
            Assert.Equal(0, await CountAllocationsForInvoiceAsync(connection, transaction, invoice.TransactionId));

            // The next poll re-runs materialise for the same Sage row.
            await ExecuteMaterialiseAsync(connection, transaction, externalTransactionId);

            var afterPoll = await ReadReceiptDeleteStateAsync(connection, transaction, materialised.ReceiptTransactionGuid.Value);
            Assert.Equal(254, afterPoll.TransactionRowStatus);
            Assert.Equal(0, await CountAllocationsForInvoiceAsync(connection, transaction, invoice.TransactionId));
            Assert.Equal(0, await CountAllocationSourceTransactionsForInvoiceAsync(connection, transaction, invoice.TransactionId));
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    [Fact]
    public async Task TransactionDelete_RefusesANonBatchedTransactionThatIsNotAReceipt()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);

            var creditNote = await InsertMaterialisableInvoiceFixtureAsync(
                connection, transaction, reservedInvoiceNumber: "RES-P555-DEL2");

            const string setTypeSql = """
UPDATE t
SET TransactionTypeID = tt.ID,
    Batched = 0
FROM SFin.Transactions AS t
CROSS APPLY
(
    SELECT TOP (1) tt.ID
    FROM SFin.TransactionTypes AS tt
    WHERE tt.RowStatus NOT IN (0,254)
      AND UPPER(REPLACE(tt.Name, N' ', N'')) = N'CREDITNOTE'
    ORDER BY tt.ID
) AS tt
WHERE t.ID = @TransactionId;
""";
            await using (var setType = SqlTestDatabase.CreateCommand(
                connection, transaction, setTypeSql,
                new[] { new SqlParameter("@TransactionId", SqlDbType.BigInt) { Value = creditNote.TransactionId } }))
            {
                Assert.Equal(1, await setType.ExecuteNonQueryAsync());
            }

            // XACT_ABORT in the procedure rolls the test transaction back with the
            // error, so the refusal itself is the assertion.
            var error = await Assert.ThrowsAsync<SqlException>(
                () => ExecuteTransactionDeleteAsync(connection, transaction, creditNote.TransactionGuid));
            Assert.Equal(51003, error.Number);
            Assert.Contains("Cannot delete transaction", error.Message, StringComparison.Ordinal);
        }
        finally
        {
            if (transaction.Connection is not null)
            {
                await transaction.RollbackAsync();
            }
        }
    }

    private sealed record ReceiptDeleteState(int TransactionRowStatus, int DataObjectRowStatus, int ActiveLines, int ActiveAllocations);

    private static async Task ExecuteTransactionDeleteAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid transactionGuid)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, "SFin.TransactionBatchDelete",
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = transactionGuid } },
            CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<ReceiptDeleteState> ReadReceiptDeleteStateAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        Guid receiptGuid)
    {
        const string sql = """
SELECT
    TransactionRowStatus = CONVERT(INT, t.RowStatus),
    DataObjectRowStatus = ISNULL((SELECT CONVERT(INT, dob.RowStatus) FROM SCore.DataObjects AS dob WHERE dob.Guid = t.Guid), -1),
    ActiveLines = (SELECT COUNT(1) FROM SFin.TransactionDetails AS td WHERE td.TransactionID = t.ID AND td.RowStatus NOT IN (0,254)),
    ActiveAllocations = (SELECT COUNT(1) FROM SFin.TransactionAllocations AS ta
                         WHERE (ta.SourceTransactionID = t.ID OR ta.TargetTransactionID = t.ID)
                           AND ta.RowStatus NOT IN (0,254))
FROM SFin.Transactions AS t
WHERE t.Guid = @Guid;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, sql,
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = receiptGuid } });
        await using var reader = await command.ExecuteReaderAsync();

        Assert.True(await reader.ReadAsync(), "The receipt transaction could not be read back.");
        return new ReceiptDeleteState(reader.GetInt32(0), reader.GetInt32(1), reader.GetInt32(2), reader.GetInt32(3));
    }

    private sealed record InvoiceFixture(long TransactionId, Guid TransactionGuid);

    private sealed record MaterialisationResult(Guid? ReceiptTransactionGuid, Guid? AllocationGuid);

    private static async Task<InvoiceFixture> InsertMaterialisableInvoiceFixtureAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string reservedInvoiceNumber,
        decimal? vatPercentage = null)
    {
        var accountId = await SqlTestData.ReadActiveAccountIdAsync(connection, transaction);

        if (vatPercentage is not null)
        {
            // The shared R4 VatCodes fixture is 0%; a test that needs a specific rate
            // seeds its own active code inside the rolled-back transaction.
            const string vatCodeSql = """
IF NOT EXISTS
(
    SELECT 1
    FROM SFin.VatCodes AS vc
    WHERE vc.RowStatus NOT IN (0,254)
      AND vc.Active = 1
      AND vc.VatPercentage = @VatPercentage
)
BEGIN
    INSERT INTO SFin.VatCodes (RowStatus, SageVatNo, Active, VatPercentage)
    VALUES (1, N'R4TEST-RATE', 1, @VatPercentage);
END;
""";
            await using var vatCodeCommand = SqlTestDatabase.CreateCommand(
                connection, transaction, vatCodeSql,
                new[] { new SqlParameter("@VatPercentage", SqlDbType.Decimal) { Precision = 9, Scale = 4, Value = vatPercentage.Value } });
            await vatCodeCommand.ExecuteNonQueryAsync();
        }

        const string referenceSql = """
SELECT
    (SELECT TOP (1) j.ID FROM SJob.Jobs AS j WHERE j.RowStatus NOT IN (0,254) ORDER BY j.ID) AS JobId,
    (SELECT TOP (1) ou.ID FROM SCore.OrganisationalUnits AS ou WHERE ou.RowStatus NOT IN (0,254) ORDER BY ou.ID) AS OrganisationalUnitId,
    (SELECT TOP (1) i.ID FROM SCore.Identities AS i WHERE i.RowStatus NOT IN (0,254) ORDER BY i.ID) AS SurveyorUserId,
    (SELECT TOP (1) ct.ID FROM SFin.CreditTerms AS ct WHERE ct.RowStatus NOT IN (0,254) ORDER BY ct.ID) AS CreditTermsId,
    (SELECT TOP (1) vc.ID FROM SFin.VatCodes AS vc WHERE vc.RowStatus NOT IN (0,254) AND vc.Active = 1 AND (@VatPercentage IS NULL OR vc.VatPercentage = @VatPercentage) ORDER BY vc.ID) AS VatCodeId;
""";

        int jobId;
        int organisationalUnitId;
        int surveyorUserId;
        int creditTermsId;
        int vatCodeId;

        await using (var referenceCommand = SqlTestDatabase.CreateCommand(
            connection, transaction, referenceSql,
            new[] { new SqlParameter("@VatPercentage", SqlDbType.Decimal) { Precision = 9, Scale = 4, Value = (object?)vatPercentage ?? DBNull.Value } }))
        await using (var reader = await referenceCommand.ExecuteReaderAsync())
        {
            Assert.True(await reader.ReadAsync(), "The reference-lookup query did not return a row.");
            Assert.False(reader.IsDBNull(0), "At least one active SJob.Jobs row is required in the dedicated test database.");
            Assert.False(reader.IsDBNull(1), "At least one active SCore.OrganisationalUnits row is required in the dedicated test database.");
            Assert.False(reader.IsDBNull(2), "At least one active SCore.Identities row is required in the dedicated test database.");
            Assert.False(reader.IsDBNull(3), "At least one active SFin.CreditTerms row is required in the dedicated test database.");
            Assert.False(reader.IsDBNull(4), "At least one active SFin.VatCodes row is required in the dedicated test database.");

            jobId = reader.GetInt32(0);
            organisationalUnitId = reader.GetInt32(1);
            surveyorUserId = reader.GetInt32(2);
            creditTermsId = reader.GetInt32(3);
            vatCodeId = reader.GetInt32(4);
        }

        var transactionGuid = Guid.NewGuid();

        const string insertTransactionSql = """
INSERT INTO SFin.Transactions
    (RowStatus, Guid, AccountID, JobID, OrganisationalUnitId, SurveyorUserId, CreditTermsId, ReservedInvoiceNumber, [Date])
OUTPUT INSERTED.ID
VALUES
    (1, @Guid, @AccountID, @JobID, @OrganisationalUnitId, @SurveyorUserId, @CreditTermsId, @ReservedInvoiceNumber, @Date);
""";
        var transactionParameters = new[]
        {
            new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = transactionGuid },
            new SqlParameter("@AccountID", SqlDbType.Int) { Value = accountId },
            new SqlParameter("@JobID", SqlDbType.Int) { Value = jobId },
            new SqlParameter("@OrganisationalUnitId", SqlDbType.Int) { Value = organisationalUnitId },
            new SqlParameter("@SurveyorUserId", SqlDbType.Int) { Value = surveyorUserId },
            new SqlParameter("@CreditTermsId", SqlDbType.Int) { Value = creditTermsId },
            new SqlParameter("@ReservedInvoiceNumber", SqlDbType.NVarChar, 30) { Value = reservedInvoiceNumber },
            new SqlParameter("@Date", SqlDbType.Date) { Value = DateTime.UtcNow.Date }
        };

        await using var insertCommand = SqlTestDatabase.CreateCommand(connection, transaction, insertTransactionSql, transactionParameters);
        var transactionId = Convert.ToInt64(
            await insertCommand.ExecuteScalarAsync(),
            System.Globalization.CultureInfo.InvariantCulture);

        const string insertDetailSql = """
INSERT INTO SFin.TransactionDetails (RowStatus, TransactionID, Description, Net, Vat, Gross, VatCodeID)
VALUES (1, @TransactionID, @Description, @Net, @Vat, @Gross, @VatCodeID);
""";
        var detailParameters = new[]
        {
            new SqlParameter("@TransactionID", SqlDbType.BigInt) { Value = transactionId },
            new SqlParameter("@Description", SqlDbType.NVarChar, 2000) { Value = "CYB-555 fixture line" },
            new SqlParameter("@Net", SqlDbType.Decimal) { Value = 100m },
            new SqlParameter("@Vat", SqlDbType.Decimal) { Value = 20m },
            new SqlParameter("@Gross", SqlDbType.Decimal) { Value = 120m },
            new SqlParameter("@VatCodeID", SqlDbType.Int) { Value = vatCodeId }
        };

        await using var detailCommand = SqlTestDatabase.CreateCommand(connection, transaction, insertDetailSql, detailParameters);
        await detailCommand.ExecuteNonQueryAsync();

        await SqlTestData.ExecuteUpsertDataObjectAsync(connection, transaction, transactionGuid, "SFin", "Transactions");

        return new InvoiceFixture(transactionId, transactionGuid);
    }

    private static async Task<long> UpsertSageExternalTransactionAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        string sageDocumentNo,
        string sageTransactionReference,
        int sageTransactionTypeCode,
        decimal allocatedValue,
        long matchedTransactionId,
        decimal netAmount = 100m,
        decimal taxAmount = 20m,
        DateTime? transactionDate = null)
    {
        var guidParameter = new SqlParameter("@Guid", SqlDbType.UniqueIdentifier)
        {
            Direction = ParameterDirection.InputOutput,
            Value = DBNull.Value
        };

        var parameters = new[]
        {
            new SqlParameter("@SageDataset", SqlDbType.NVarChar, 30) { Value = "group" },
            new SqlParameter("@SageAccountReference", SqlDbType.NVarChar, 100) { Value = "CYB555TEST" },
            new SqlParameter("@SageDocumentNo", SqlDbType.NVarChar, 100) { Value = sageDocumentNo },
            new SqlParameter("@SageTransactionReference", SqlDbType.NVarChar, 100) { Value = sageTransactionReference },
            new SqlParameter("@SecondReference", SqlDbType.NVarChar, 100) { Value = sageDocumentNo },
            new SqlParameter("@SageTransactionTypeCode", SqlDbType.Int) { Value = sageTransactionTypeCode },
            new SqlParameter("@TransactionDate", SqlDbType.Date) { Value = transactionDate ?? DateTime.UtcNow.Date },
            new SqlParameter("@NetAmount", SqlDbType.Decimal) { Precision = 18, Scale = 2, Value = netAmount },
            new SqlParameter("@TaxAmount", SqlDbType.Decimal) { Precision = 18, Scale = 2, Value = taxAmount },
            new SqlParameter("@GrossAmount", SqlDbType.Decimal) { Value = 120m },
            new SqlParameter("@AllocatedValue", SqlDbType.Decimal) { Value = allocatedValue },
            new SqlParameter("@OutstandingAmount", SqlDbType.Decimal) { Value = 0m },
            new SqlParameter("@DocumentDiscountedValue", SqlDbType.Decimal) { Value = 120m },
            new SqlParameter("@IsPaid", SqlDbType.Bit) { Value = true },
            new SqlParameter("@IsFullyPaid", SqlDbType.Bit) { Value = true },
            new SqlParameter("@PaymentStateCode", SqlDbType.NVarChar, 30) { Value = "Paid" },
            new SqlParameter("@MatchedTransactionID", SqlDbType.BigInt) { Value = matchedTransactionId },
            new SqlParameter("@MatchedInvoiceRequestID", SqlDbType.Int) { Value = -1 },
            new SqlParameter("@MatchedJobID", SqlDbType.Int) { Value = -1 },
            new SqlParameter("@SourceHash", SqlDbType.NVarChar, 128) { Value = Guid.NewGuid().ToString("N") },
            new SqlParameter("@RawPayloadJson", SqlDbType.NVarChar, -1) { Value = "{}" },
            guidParameter
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, "SFin.SageExternalTransaction_Upsert", parameters, CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync();

        const string resolveIdSql = """
SELECT TOP (1) ext.ID
FROM SFin.SageExternalTransactions AS ext
WHERE ext.Guid = @Guid
  AND ext.RowStatus NOT IN (0,254);
""";
        await using var resolveCommand = SqlTestDatabase.CreateCommand(
            connection, transaction, resolveIdSql,
            new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = (Guid)guidParameter.Value } });
        var id = await resolveCommand.ExecuteScalarAsync();

        return Convert.ToInt64(id, System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task ExecuteMaterialiseAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long externalTransactionId)
    {
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, "SFin.SageInboundReceiptAndAllocation_Materialise",
            new[] { new SqlParameter("@ExternalTransactionID", SqlDbType.BigInt) { Value = externalTransactionId } },
            CommandType.StoredProcedure);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task<int> ReadAutoCorrectDryRunCandidateCountAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long externalTransactionId)
    {
        var parameters = new[]
        {
            new SqlParameter("@ExternalTransactionID", SqlDbType.BigInt) { Value = externalTransactionId },
            new SqlParameter("@BatchSize", SqlDbType.Int) { Value = 1 },
            new SqlParameter("@DryRun", SqlDbType.Bit) { Value = true }
        };

        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, "SFin.SageInboundReceiptMaterialisation_AutoCorrect",
            parameters, CommandType.StoredProcedure);
        await using var reader = await command.ExecuteReaderAsync();

        Assert.True(await reader.ReadAsync(), "AutoCorrect did not return its summary result set.");
        return reader.GetInt32(reader.GetOrdinal("ProcessedCount"));
    }

    private static async Task<MaterialisationResult> ReadMaterialisationResultAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long externalTransactionId)
    {
        const string sql = """
SELECT MaterialisedReceiptTransactionGuid, MaterialisedAllocationGuid
FROM SFin.SageExternalTransactions
WHERE ID = @ID;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, sql,
            new[] { new SqlParameter("@ID", SqlDbType.BigInt) { Value = externalTransactionId } });
        await using var reader = await command.ExecuteReaderAsync();

        Assert.True(await reader.ReadAsync(), "The Sage external transaction row could not be read back.");

        var receiptGuidOrdinal = reader.GetOrdinal("MaterialisedReceiptTransactionGuid");
        var allocationGuidOrdinal = reader.GetOrdinal("MaterialisedAllocationGuid");

        return new MaterialisationResult(
            reader.IsDBNull(receiptGuidOrdinal) ? null : reader.GetGuid(receiptGuidOrdinal),
            reader.IsDBNull(allocationGuidOrdinal) ? null : reader.GetGuid(allocationGuidOrdinal));
    }

    private static async Task<int> CountAllocationSourceTransactionsForInvoiceAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long invoiceTransactionId)
    {
        const string sql = """
SELECT COUNT(DISTINCT receiptTran.ID)
FROM SFin.TransactionAllocations AS ta
JOIN SFin.Transactions AS receiptTran
    ON receiptTran.ID = ta.SourceTransactionID
   AND receiptTran.RowStatus NOT IN (0,254)
WHERE ta.RowStatus NOT IN (0,254)
  AND ta.TargetTransactionID = @InvoiceTransactionId;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, sql,
            new[] { new SqlParameter("@InvoiceTransactionId", SqlDbType.BigInt) { Value = invoiceTransactionId } });
        var count = await command.ExecuteScalarAsync();

        return Convert.ToInt32(count, System.Globalization.CultureInfo.InvariantCulture);
    }

    private static async Task<int> CountAllocationsForInvoiceAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        long invoiceTransactionId)
    {
        const string sql = """
SELECT COUNT(1)
FROM SFin.TransactionAllocations AS ta
WHERE ta.RowStatus NOT IN (0,254)
  AND ta.TargetTransactionID = @InvoiceTransactionId;
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection, transaction, sql,
            new[] { new SqlParameter("@InvoiceTransactionId", SqlDbType.BigInt) { Value = invoiceTransactionId } });
        var count = await command.ExecuteScalarAsync();

        return Convert.ToInt32(count, System.Globalization.CultureInfo.InvariantCulture);
    }
}
