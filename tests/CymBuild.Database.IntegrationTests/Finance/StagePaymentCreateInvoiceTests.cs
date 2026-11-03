using CymBuild.Database.IntegrationTests.Infrastructure;
using System.Data;

namespace CymBuild.Database.IntegrationTests.Finance;

/// <summary>
/// CYB-572 follow-up: the Job Payment Stage "Create Invoice" query (SFin.StagePaymentCreateInvoice)
/// called SFin.TransactionsUpsert without @Batched/@ExpectedDate and SFin.TransactionDetailsUpsert
/// without @RIBAStageGuid or the VAT code it now requires, so it could not run. It now creates a
/// batched invoice (never queued for Sage) with one Standard UK VAT line for the stage value.
/// </summary>
public sealed class StagePaymentCreateInvoiceTests
{
    private static readonly Guid TestIdentityGuid = Guid.Parse("D4D00004-0000-4000-8000-000000000001");
    private static readonly Guid StandardUkVatGuid = Guid.Parse("A5D9D80F-2F8A-4E65-83B6-1A10D267A201");

    [Fact]
    public async Task StagePaymentCreateInvoice_CreatesABatchedStandardVatInvoiceForTheStage()
    {
        var database = SqlTestDatabase.FromEnvironment();
        await using var connection = await database.OpenConnectionAsync();
        await using var transaction = (SqlTransaction)await connection.BeginTransactionAsync();

        try
        {
            await SqlTestDatabase.DisableAuditTriggersAsync(connection, transaction);
            var stageGuid = await InsertPaymentStageFixtureAsync(connection, transaction, stageValue: 100m);

            await using (var create = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                "SFin.StagePaymentCreateInvoice",
                new[] { new SqlParameter("@Guid", SqlDbType.UniqueIdentifier) { Value = stageGuid } }))
            {
                create.CommandType = CommandType.StoredProcedure;
                await create.ExecuteNonQueryAsync();
            }

            const string sql = """
SELECT t.Batched, t.ExpectedDate, t.RowStatus, t.Number, td.Net, td.Vat, td.Gross, vc.Guid AS VatCodeGuid,
       (SELECT COUNT(*) FROM SFin.TransactionSageSubmissionStatus AS s WHERE s.TransactionID = t.ID) AS SageSubmissions
FROM SFin.TransactionDetails AS td
JOIN SJob.JobPaymentStages AS jps ON jps.ID = td.JobPaymentStageId
JOIN SFin.Transactions AS t ON t.ID = td.TransactionID
JOIN SFin.VatCodes AS vc ON vc.ID = td.VatCodeID
WHERE jps.Guid = @StageGuid;
""";
            await using var command = SqlTestDatabase.CreateCommand(
                connection,
                transaction,
                sql,
                new[] { new SqlParameter("@StageGuid", SqlDbType.UniqueIdentifier) { Value = stageGuid } });
            await using var reader = await command.ExecuteReaderAsync();

            Assert.True(await reader.ReadAsync(), "Create Invoice did not create a transaction line for the payment stage.");
            Assert.True(reader.GetBoolean(0), "A new stage-payment invoice must be batched.");
            Assert.True(reader.IsDBNull(1), "A new stage-payment invoice has no expected date.");
            Assert.Equal(1, reader.GetByte(2));
            Assert.Equal("CYB572-", reader.GetString(3)[..7]);
            Assert.Equal(100m, reader.GetDecimal(4));
            Assert.Equal(20m, reader.GetDecimal(5));
            Assert.Equal(120m, reader.GetDecimal(6));
            Assert.Equal(StandardUkVatGuid, reader.GetGuid(7));
            Assert.Equal(0, reader.GetInt32(8));
            Assert.False(await reader.ReadAsync(), "Create Invoice created more than one line for the payment stage.");
        }
        finally
        {
            await transaction.RollbackAsync();
        }
    }

    /// <summary>
    /// Inserts the "Invoice" transaction type and Standard UK VAT code if the shared fixtures lack
    /// them, then a coded finance account, a prefixed org unit, a Job with fee headroom and one
    /// payment stage. Everything rolls back with the test transaction.
    /// </summary>
    private static async Task<Guid> InsertPaymentStageFixtureAsync(
        SqlConnection connection,
        SqlTransaction transaction,
        decimal stageValue)
    {
        var jobGuid = Guid.NewGuid();
        var stageGuid = Guid.NewGuid();

        const string sql = """
IF NOT EXISTS (SELECT 1 FROM SFin.TransactionTypes WHERE Name = N'Invoice')
    INSERT INTO SFin.TransactionTypes (Name, IsActive, IsBank, IsNegated) VALUES (N'Invoice', 1, 0, 0);

IF NOT EXISTS (SELECT 1 FROM SFin.VatCodes WHERE Guid = @StandardUkVatGuid)
    INSERT INTO SFin.VatCodes (RowStatus, Guid, SageVatNo, VatPercentage, Active) VALUES (1, @StandardUkVatGuid, N'10', 20, 1);

DECLARE @CreditTermsId int = (SELECT TOP (1) ID FROM SFin.CreditTerms WHERE RowStatus NOT IN (0, 254) ORDER BY ID);
DECLARE @SurveyorId int = (SELECT ID FROM SCore.Identities WHERE Guid = @SurveyorGuid);
DECLARE @AccountId int, @OrgUnitId int, @JobId int;

INSERT INTO SCrm.Accounts (RowStatus, Name, Code, DefaultCreditTermsId)
VALUES (1, N'CYB-572 stage invoice account', N'CYB572', @CreditTermsId);
SET @AccountId = SCOPE_IDENTITY();

INSERT INTO SCore.OrganisationalUnits (RowStatus, Name, DepartmentPrefix)
VALUES (1, N'CYB-572 stage invoice org unit', N'CYB572-');
SET @OrgUnitId = SCOPE_IDENTITY();

INSERT INTO SJob.Jobs (RowStatus, Guid, Number, SurveyorID, JobDescription, FinanceAccountID, OrganisationalUnitId, PurchaseOrderNumber, AgreedFee)
VALUES (1, @JobGuid, N'CYB572-STAGE', @SurveyorId, N'CYB-572 stage invoice fixture', @AccountId, @OrgUnitId, N'PO-CYB572', 1000);
SET @JobId = SCOPE_IDENTITY();

INSERT INTO SJob.JobPaymentStages (RowStatus, Guid, JobId, StagedDate, Value)
VALUES (1, @StageGuid, @JobId, '2026-10-06', @StageValue);
""";
        await using var command = SqlTestDatabase.CreateCommand(
            connection,
            transaction,
            sql,
            new[]
            {
                new SqlParameter("@StandardUkVatGuid", SqlDbType.UniqueIdentifier) { Value = StandardUkVatGuid },
                new SqlParameter("@SurveyorGuid", SqlDbType.UniqueIdentifier) { Value = TestIdentityGuid },
                new SqlParameter("@JobGuid", SqlDbType.UniqueIdentifier) { Value = jobGuid },
                new SqlParameter("@StageGuid", SqlDbType.UniqueIdentifier) { Value = stageGuid },
                new SqlParameter("@StageValue", SqlDbType.Decimal) { Value = stageValue, Precision = 18, Scale = 2 }
            });
        await command.ExecuteNonQueryAsync();

        await SqlTestData.ExecuteUpsertDataObjectAsync(connection, transaction, jobGuid, "SJob", "Jobs");

        return stageGuid;
    }
}
