using Xunit;

namespace CymBuild.Architecture.Tests;

public sealed class SageTransactionRoutingSourceContractTests
{
    [Fact]
    public void ReceiptMaterialisation_FallsBackToMatchedInvoiceDateBeforeUpsert()
    {
        var sql = ReadSql(
            "Procedures",
            "SFin.SageInboundReceiptAndAllocation_Materialise.sql");

        Assert.Contains("CREATE OR ALTER PROCEDURE [SFin].[SageInboundReceiptAndAllocation_Materialise]", sql, StringComparison.Ordinal);
        Assert.Contains("@MatchedInvoiceDate            = t.[Date]", sql, StringComparison.Ordinal);
        Assert.Contains("SET @TransactionDate = COALESCE(@TransactionDate, @MatchedInvoiceDate);", sql, StringComparison.Ordinal);
        Assert.Contains("THROW 60081", sql, StringComparison.Ordinal);

        var fallback = sql.IndexOf("SET @TransactionDate = COALESCE", StringComparison.Ordinal);
        var upsertDate = sql.IndexOf("@Date = @TransactionDate", StringComparison.Ordinal);

        Assert.True(fallback >= 0, "The deterministic receipt-date fallback is missing.");
        Assert.True(upsertDate > fallback, "The receipt date must be resolved before TransactionsUpsert.");
        Assert.DoesNotContain("SELECT *", sql, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ReceiptMaterialisation_PassesVatExclusiveNetWhenSageHasNoTaxSplit()
    {
        // CYB-568: TransactionDetailsUpsert adds VAT on top of @Net, so a
        // VAT-inclusive Sage receipt amount must be converted to net first.
        var sql = ReadSql(
            "Procedures",
            "SFin.SageInboundReceiptAndAllocation_Materialise.sql");

        Assert.Contains("@InvoiceVatPercentage       = vc.VatPercentage", sql, StringComparison.Ordinal);
        Assert.Contains(
            "SET @NetToStore = ROUND(@SageGrossAmount * 100.0 / (100.0 + @InvoiceVatPercentage), 2);",
            sql,
            StringComparison.Ordinal);
        Assert.Contains("@Net = @NetToStore", sql, StringComparison.Ordinal);

        var vatGuard = sql.IndexOf("THROW 60080", StringComparison.Ordinal);
        var netCalculation = sql.IndexOf("SET @NetToStore = ROUND", StringComparison.Ordinal);
        var transactionUpsert = sql.IndexOf("EXECUTE SFin.TransactionsUpsert", StringComparison.Ordinal);

        Assert.True(vatGuard >= 0 && vatGuard < netCalculation, "The invoice VAT code must be resolved before the net is calculated.");
        Assert.True(
            vatGuard < transactionUpsert,
            "The VAT guard must run before the receipt header is created, so a failure cannot leave a receipt without a line.");
    }

    [Fact]
    public void ReceiptMaterialisation_TakeoverOfAFallbackReceiptAlsoTakesItsType()
    {
        // CYB-555: TransactionsUpsert never changes an existing transaction's
        // type, so a Credit Note taking over a type 4 fallback Receipt stayed a Receipt.
        var sql = ReadSql(
            "Procedures",
            "SFin.SageInboundReceiptAndAllocation_Materialise.sql");

        Assert.Contains("CYB-555-TAKEOVER-TYPE", sql, StringComparison.Ordinal);
        Assert.Contains("SET TransactionTypeID = tt.ID", sql, StringComparison.Ordinal);
        Assert.Contains("ON tt.Guid = @MaterialisedTransactionTypeGuid", sql, StringComparison.Ordinal);

        var transactionUpsert = sql.IndexOf("EXECUTE SFin.TransactionsUpsert", StringComparison.Ordinal);
        var typeCorrection = sql.IndexOf("SET TransactionTypeID = tt.ID", StringComparison.Ordinal);
        var allocationUpsert = sql.IndexOf("EXECUTE SFin.TransactionAllocationsUpsert", StringComparison.Ordinal);

        Assert.True(
            transactionUpsert < typeCorrection && typeCorrection < allocationUpsert,
            "The type must be corrected after TransactionsUpsert and before the allocation is written.");
    }

    [Fact]
    public void InvoiceOnlyPayment_CreatesAReceiptUnlessAnExplicitSourceExists()
    {
        // CYB-568: CYB-555 stopped type 4 Invoice rows creating receipts, but the
        // production Sage source only ever flips IsPaid/AllocatedValue on the
        // invoice row, so no receipt or allocation was created at all.
        var service = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "services",
                "Concursus.API",
                "Services",
                "Finance",
                "SageInboundPaymentSyncService.cs"));
        var sql = ReadSql(
            "Procedures",
            "SFin.SageInboundReceiptAndAllocation_Materialise.sql");

        var allocationSource = service.Substring(
            service.IndexOf("var isAllocationSource", StringComparison.Ordinal),
            400);
        Assert.Contains("sageTransactionTypeCode == SageInvoiceTransactionTypeCode", allocationSource, StringComparison.Ordinal);

        Assert.Contains(
            "WHEN 4 THEN CASE WHEN @InvoiceHasDistinctAllocationSource = 0 THEN N'Receipt' ELSE NULL END",
            sql,
            StringComparison.Ordinal);
        Assert.Contains("distinctSource.SageTransactionTypeCode IN (1, 5)", sql, StringComparison.Ordinal);
        Assert.Contains("siblingExt.MatchedTransactionID = @MatchedInvoiceTransactionID", sql, StringComparison.Ordinal);
        // Only a type 4 fallback Receipt is taken over; explicit Credit Note and
        // Receipt rows stay independent allocation sources.
        Assert.Contains("AND siblingExt.SageTransactionTypeCode = 4", sql, StringComparison.Ordinal);

        // The type 4 receipt is the VAT-inclusive cash allocated so far, not the
        // invoice's own net, so a part-paid invoice gets a part receipt.
        var typeFourNet = sql.IndexOf("IF @SageTransactionTypeCode = 4", sql.IndexOf("CYB-568-VAT-EXCLUSIVE-NET", StringComparison.Ordinal), StringComparison.Ordinal);
        Assert.True(typeFourNet > 0, "The type 4 net calculation must follow the CYB-568 marker.");
        Assert.Contains("SET @SageGrossAmount = ISNULL(@AllocatedValue, 0);", sql.Substring(typeFourNet, 500), StringComparison.Ordinal);
    }

    [Fact]
    public void InboundDiagnosticsGet_DeclaresEveryParameterTheRepositorySendsAndReturnsTotalCount()
    {
        // CYB-568: a DEV schema-source sync (20f90463) replaced the paged
        // SFin.SageInboundDiagnostics_Get with an older unpaged copy while the
        // repository kept sending @PaymentFilter/@PageNumber/@PageSize and reading
        // TotalCount, so the screen would fail with "too many arguments".
        var sql = ReadSql("Procedures", "SFin.SageInboundDiagnostics_Get.sql");
        var repository = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "libs",
                "Concursus.EF",
                "Finance",
                "SageInboundDiagnosticsRepository.cs"));

        var callStart = repository.IndexOf("new SqlCommand(\"[SFin].[SageInboundDiagnostics_Get]\"", StringComparison.Ordinal);
        var callEnd = repository.IndexOf("ExecuteReaderAsync", callStart, StringComparison.Ordinal);
        Assert.True(callStart >= 0 && callEnd > callStart, "The SageInboundDiagnostics_Get call was not found in the repository.");

        var parameters = System.Text.RegularExpressions.Regex
            .Matches(repository.Substring(callStart, callEnd - callStart), "new SqlParameter\\(\"(@[A-Za-z]+)\"")
            .Select(m => m.Groups[1].Value)
            .Distinct()
            .ToList();

        Assert.Contains("@PageNumber", parameters);
        foreach (var parameter in parameters)
        {
            Assert.Matches($"(?m)^\\s*{parameter}\\s+[A-Z]", sql);
        }

        Assert.Contains("TotalCount = @TotalCount", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void CorrectionScript_ChecksForAMarkerThatSurvivesDeployment()
    {
        // CYB-568: the correction script refused to run on every environment,
        // because it looked for "CYB-568" in OBJECT_DEFINITION and that text was
        // only in the header comment, which sits in a batch before GO and is not
        // part of the stored procedure definition.
        const string marker = "CYB-568-VAT-EXCLUSIVE-NET";

        var sql = ReadSql(
            "Procedures",
            "SFin.SageInboundReceiptAndAllocation_Materialise.sql");
        var script = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "Database",
                "CymBuild_DB",
                "Scripts",
                "Upgrade Scripts",
                "CYB-568_SageReceipts_CorrectValueAndDate.sql"));

        var procedureStart = sql.IndexOf("CREATE OR ALTER PROCEDURE [SFin].[SageInboundReceiptAndAllocation_Materialise]", StringComparison.Ordinal);
        var markerPosition = sql.IndexOf(marker, StringComparison.Ordinal);

        Assert.True(procedureStart >= 0, "The procedure definition was not found.");
        Assert.True(markerPosition > procedureStart, "The marker must be inside the procedure body, after CREATE OR ALTER PROCEDURE.");
        Assert.Contains($"NOT LIKE N'%{marker}%'", script, StringComparison.Ordinal);
    }

    [Fact]
    public void CorrectionScript_CorrectsType4FallbackReceipts()
    {
        // CYB-568: nearly every Sage receipt is materialised from a type 4
        // Invoice row (the production source never sends a distinct 5/6 row),
        // but the correction script only selected types 5 and 6, so it found
        // nothing to correct on UAT_Test. It must select type 4 and use the
        // procedure's type 4 net rule: AllocatedValue back-calculated at the
        // invoice VAT rate.
        var script = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "Database",
                "CymBuild_DB",
                "Scripts",
                "Upgrade Scripts",
                "CYB-568_SageReceipts_CorrectValueAndDate.sql"));

        Assert.Contains("ext.SageTransactionTypeCode IN (4, 5, 6)", script, StringComparison.Ordinal);
        Assert.DoesNotContain("ext.SageTransactionTypeCode IN (5, 6)", script, StringComparison.Ordinal);
        Assert.Contains(
            "WHEN ext.SageTransactionTypeCode = 4\n                THEN ROUND(ABS(ISNULL(ext.AllocatedValue, 0)) * 100.0 / (100.0 + invVat.VatPercentage), 2)",
            script.Replace("\r\n", "\n"),
            StringComparison.Ordinal);

        // VAT-code safety: the net is back-calculated at one rate, so an
        // invoice whose lines carry more than one VAT rate is skipped and
        // listed rather than corrected.
        Assert.Contains("COUNT(DISTINCT vc2.VatPercentage)", script, StringComparison.Ordinal);
        Assert.Contains("WHERE ISNULL(r.DistinctVatRates, 0) <> 1;", script, StringComparison.Ordinal);
    }

    [Fact]
    public void OutboundSql_QueuesOnlyInvoicesWhileInboundOnlyTypesCompleteTransactionBatch()
    {
        var readyFunction = ReadSql(
            "Functions",
            "SFin.tvf_Transactions_ReadyForSageSubmission.sql");
        var enqueueProcedure = ReadSql(
            "Procedures",
            "SFin.TransactionBatchTransition_EnqueueOutbox.sql");
        var ensureQueuedProcedure = ReadSql(
            "Procedures",
            "SFin.TransactionSageSubmission_EnsureQueued.sql");

        Assert.Contains("tt.IsBank = 0", readyFunction, StringComparison.Ordinal);
        Assert.Contains("= N'INVOICE'", readyFunction, StringComparison.Ordinal);
        Assert.Contains("<> N'INVOICE'", enqueueProcedure, StringComparison.Ordinal);
        Assert.DoesNotContain("IN (N'INVOICE', N'CREDITNOTE')", readyFunction, StringComparison.Ordinal);
        Assert.Contains("@TransactionTypeName AS transactionTypeName", enqueueProcedure, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER PROCEDURE [SFin].[TransactionSageSubmission_EnsureQueued]", ensureQueuedProcedure, StringComparison.Ordinal);
        Assert.Contains("@NormalisedTransactionTypeName <> N'INVOICE'", ensureQueuedProcedure, StringComparison.Ordinal);
        Assert.Contains("@Outcome = N'CompletedWithoutSageSubmission'", ensureQueuedProcedure, StringComparison.Ordinal);
        Assert.Contains("no Sage API submission is required", ensureQueuedProcedure, StringComparison.Ordinal);
        Assert.DoesNotContain("SELECT *", readyFunction, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("SELECT *", enqueueProcedure, StringComparison.OrdinalIgnoreCase);

        var inboundOnlyCompletion = ensureQueuedProcedure.IndexOf(
            "@Outcome = N'CompletedWithoutSageSubmission'",
            StringComparison.Ordinal);
        var finalSubmissionStatusEnsure = ensureQueuedProcedure.LastIndexOf(
            "EXEC SFin.TransactionSageSubmissionStatus_Ensure",
            StringComparison.Ordinal);

        Assert.True(inboundOnlyCompletion >= 0, "The inbound-only Transaction Batch completion branch is missing.");
        Assert.True(
            finalSubmissionStatusEnsure > inboundOnlyCompletion,
            "Inbound-only types must return before the final Sage submission status/outbox requirement.");
    }

    [Fact]
    public void LegacySageExport_ExcludesTransactionsAlreadyCreatedInSage()
    {
        var exportProcedure = ReadSql(
            "Procedures",
            "SFin.TransactionExportsToSageUpsert.sql");

        Assert.Contains(
            "CREATE OR ALTER PROCEDURE [SFin].[TransactionExportsToSageUpsert]",
            exportProcedure,
            StringComparison.Ordinal);
        Assert.Contains(
            "NULLIF(LTRIM(RTRIM(ISNULL(t.SageTransactionReference, N''))), N'') IS NULL",
            exportProcedure,
            StringComparison.Ordinal);
        Assert.Contains(
            "NULLIF(LTRIM(RTRIM(ISNULL(t.SageInvoiceNumber, N''))), N'') IS NULL",
            exportProcedure,
            StringComparison.Ordinal);
        Assert.Contains(
            "NULLIF(LTRIM(RTRIM(ISNULL(t.SageSalesOrderNumber, N''))), N'') IS NULL",
            exportProcedure,
            StringComparison.Ordinal);
        Assert.DoesNotContain("SELECT *", exportProcedure, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void InboundPolling_ExcludesLegacySageExportTransactions()
    {
        var worklist = ReadSql(
            "Procedures",
            "SFin.SageInboundPaymentSync_Worklist.sql");
        var enqueue = ReadSql(
            "Procedures",
            "SFin.SageInboundPaymentSync_Enqueue.sql");
        var readRepository = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "libs",
                "Concursus.EF",
                "Finance",
                "SageInboundPaymentReadRepository.cs"));

        Assert.Contains("[SFin].[SageExportTransactions] AS legacyExport", worklist, StringComparison.Ordinal);
        Assert.Contains("legacyExport.[TransactionID] = s.[TransactionID]", worklist, StringComparison.Ordinal);
        Assert.Contains("legacyExport.[RowStatus] <> 0", worklist, StringComparison.Ordinal);
        Assert.Contains("legacyExport.[RowStatus] <> 254", worklist, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER PROCEDURE [SFin].[SageInboundPaymentSync_Enqueue]", enqueue, StringComparison.Ordinal);
        Assert.Contains("= N'INVOICE'", enqueue, StringComparison.Ordinal);
        Assert.Contains("Legacy SAGE EXPORT transactions cannot be queued", enqueue, StringComparison.Ordinal);
        Assert.Contains("SFin.SageExportTransactions AS legacyExport", readRepository, StringComparison.Ordinal);
        Assert.Contains("legacyExport.TransactionID = s.TransactionID", readRepository, StringComparison.Ordinal);
        Assert.Contains("legacyExport.TransactionID = t.ID", readRepository, StringComparison.Ordinal);
        Assert.DoesNotContain("SELECT *", worklist, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("SELECT *", enqueue, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("SELECT *", readRepository, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ActiveOutboundGateway_IsInvoiceOnlyAndCreditNotesRemainSageManagedInboundOnly()
    {
        var gateway = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "services",
                "Concursus.API",
                "Services",
                "Finance",
                "SageSalesOrderGateway.cs"));
        var validator = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "services",
                "Concursus.API",
                "Services",
                "Finance",
                "TransactionToSageEligibilityValidator.cs"));

        Assert.Contains("new HttpRequestMessage(HttpMethod.Post, \"api/sales-orders\")", gateway, StringComparison.Ordinal);
        Assert.Contains("SageManagedInboundTransactionType", validator, StringComparison.Ordinal);
        Assert.Contains("CreditNote is Sage-managed and inbound-only", validator, StringComparison.Ordinal);
    }

    [Fact]
    public void SageAllocationSources_CreateTypedTransactionsAndReduceInvoiceOutstanding()
    {
        var calculations = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "Database",
                "CymBuild_DB",
                "Schema",
                "Views",
                "SFin.TransactionCalculations.sql"));
        var materialise = ReadSql(
            "Procedures",
            "SFin.SageInboundReceiptAndAllocation_Materialise.sql");
        var autoCorrect = ReadSql(
            "Procedures",
            "SFin.SageInboundReceiptMaterialisation_AutoCorrect.sql");

        Assert.Contains("ta.TargetTransactionID = t.ID", calculations, StringComparison.Ordinal);
        Assert.Contains("ta.SourceTransactionID = t.ID", calculations, StringComparison.Ordinal);
        Assert.Contains("ta.RowStatus NOT IN (0, 254)", calculations, StringComparison.Ordinal);
        Assert.Contains("WHEN 5 THEN N'CreditNote'", materialise, StringComparison.Ordinal);
        Assert.Contains("WHEN 1 THEN N'Receipt'", materialise, StringComparison.Ordinal);
        // SFA (ticket #58103): 6 is an Opening Balance Invoice, not a Receipt.
        Assert.DoesNotContain("WHEN 6 THEN", materialise, StringComparison.Ordinal);
        Assert.Contains("@TransactionTypeGuid = @MaterialisedTransactionTypeGuid", materialise, StringComparison.Ordinal);
        Assert.Contains("SET @AllocatedValue = ABS(ISNULL(@AllocatedValue, 0));", materialise, StringComparison.Ordinal);
        Assert.Contains("@ExistingAllocationMaterialisedGuid", materialise, StringComparison.Ordinal);
        Assert.Contains("SET @AllocationGuid = NULLIF", materialise, StringComparison.Ordinal);
        Assert.Contains("EXECUTE SFin.TransactionAllocationsUpsert", materialise, StringComparison.Ordinal);
        Assert.DoesNotContain("ta.AllocatedAmount = @AllocatedValue", materialise, StringComparison.Ordinal);
        Assert.Contains("ext.SageTransactionTypeCode IN (1, 4, 5)", autoCorrect, StringComparison.Ordinal);

        var typeResolution = materialise.IndexOf(
            "@MaterialisedTransactionTypeGuid = tt.Guid",
            StringComparison.Ordinal);
        var transactionUpsert = materialise.IndexOf("EXECUTE SFin.TransactionsUpsert", StringComparison.Ordinal);

        Assert.True(typeResolution >= 0, "The Sage allocation-source type resolution is missing.");
        Assert.True(transactionUpsert > typeResolution, "The finance type must be resolved before creating the allocation-source transaction.");
    }

    [Fact]
    public void InboundInvoiceSync_RoutesInvoiceCreditNoteAndReceiptCustomerTransactions()
    {
        var service = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "services",
                "Concursus.API",
                "Services",
                "Finance",
                "SageInboundPaymentSyncService.cs"));
        var reconcile = ReadSql(
            "Procedures",
            "SFin.SageInbound_ReconcileInvoiceTransaction.sql");

        Assert.Contains("SageInvoiceTransactionTypeCode = 4", service, StringComparison.Ordinal);
        Assert.Contains("SageCreditNoteTransactionTypeCode = 5", service, StringComparison.Ordinal);
        Assert.Contains("SageReceiptTransactionTypeCode = 1;", service, StringComparison.Ordinal);
        Assert.Contains("sageTransactionTypeCode != SageInvoiceTransactionTypeCode", service, StringComparison.Ordinal);
        Assert.Contains("var isAllocationSource", service, StringComparison.Ordinal);
        Assert.Contains("Math.Abs(aggregateResult.AllocatedValue) > 0m", service, StringComparison.Ordinal);
        Assert.Contains("sageTransactionTypeCode == SageInvoiceTransactionTypeCode", service, StringComparison.Ordinal);
        Assert.Contains("CREATE OR ALTER PROCEDURE [SFin].[SageInbound_ReconcileInvoiceTransaction]", reconcile, StringComparison.Ordinal);
        Assert.Contains("NOT IN (1, 4, 5)", reconcile, StringComparison.Ordinal);
        Assert.Contains("MatchRule = N'UnsupportedSageTransactionType'", reconcile, StringComparison.Ordinal);
    }

    [Fact]
    public void InboundInvoiceSync_IgnoresRowsForAnotherAccountBeforeStoringThem()
    {
        // CYB-555: SFA ignores the account filter, and the reconcile procedure matches
        // on document number alone, so the row must be dropped before it is stored.
        var service = File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "services",
                "Concursus.API",
                "Services",
                "Finance",
                "SageInboundPaymentSyncService.cs"));

        var guard = service.IndexOf(
            "SageAccountReferenceMatcher.IsRequestedAccount(rowAccountReference, target.SageAccountReference)",
            StringComparison.Ordinal);
        var upsert = service.IndexOf("UpsertExternalTransactionAsync(", StringComparison.Ordinal);

        Assert.True(guard >= 0, "The requested-account guard is missing from the inbound sync.");
        Assert.True(guard < upsert, "Rows for another account must be ignored before they are stored.");
    }

    [Fact]
    public void TransactionDelete_AllowsBatchedOrNonBatchedReceiptAndRetiresItsAllocations()
    {
        // CYB-555: Finance can delete a non-batched Receipt (e.g. a credit-note
        // settlement the type 4 fallback recorded as a Receipt). Its allocations
        // must go with it or the invoice still shows as allocated.
        var sql = ReadSql(
            "Procedures",
            "SFin.TransactionBatchDelete.sql");

        Assert.Contains("CYB-555-RECEIPT-DELETE", sql, StringComparison.Ordinal);
        Assert.Contains("UPPER(LTRIM(RTRIM(tt.Name))) = N'RECEIPT'", sql, StringComparison.Ordinal);
        Assert.Contains("IF(@IsBatched = 1)", sql, StringComparison.Ordinal);
        Assert.Contains("ELSE IF(@IsReceipt = 1)", sql, StringComparison.Ordinal);
        Assert.Contains("THROW 51003", sql, StringComparison.Ordinal);
        Assert.Contains("((SourceTransactionID = @TransactionId) OR (TargetTransactionID = @TransactionId))", sql, StringComparison.Ordinal);
        Assert.Contains("UPDATE\tSFin.TransactionDetails", sql, StringComparison.Ordinal);
        Assert.Contains("BEGIN TRANSACTION;", sql, StringComparison.Ordinal);
        Assert.Contains("SET XACT_ABORT ON;", sql, StringComparison.Ordinal);
        Assert.DoesNotContain("SELECT *", sql, StringComparison.OrdinalIgnoreCase);

        var receiptBranch = sql.IndexOf("ELSE IF(@IsReceipt = 1)", StringComparison.Ordinal);
        var refusal = sql.IndexOf("THROW 51003", StringComparison.Ordinal);
        Assert.True(receiptBranch < refusal, "Any other non-batched transaction must still be refused.");
    }

    [Fact]
    public void ReceiptMaterialisation_LeavesAUserDeletedReceiptDeleted()
    {
        // CYB-555: a later poll must not revive a deleted Receipt, nor fail the
        // whole invoice sync because the receipt no longer resolves.
        var sql = ReadSql(
            "Procedures",
            "SFin.SageInboundReceiptAndAllocation_Materialise.sql");

        Assert.Contains("CYB-555-RECEIPT-DELETE", sql, StringComparison.Ordinal);
        Assert.Contains("AND deletedReceipt.RowStatus = 254", sql, StringComparison.Ordinal);
        Assert.Contains("AND siblingReceipt.RowStatus NOT IN (0,254)", sql, StringComparison.Ordinal);

        var deletedGuard = sql.IndexOf("CYB-555-RECEIPT-DELETE", StringComparison.Ordinal);
        var transactionUpsert = sql.IndexOf("EXECUTE SFin.TransactionsUpsert", StringComparison.Ordinal);
        Assert.True(deletedGuard >= 0 && deletedGuard < transactionUpsert, "The deleted-receipt guard must run before TransactionsUpsert.");
    }

    [Fact]
    public void SageApiClient_ReadsTransactionsAndAllocationsFromV2_AndKeepsSalesOrdersOnV1()
    {
        // CYB-555: v1 stays for Client Hub and FormGen (stripped accounts, 0
        // net/tax/gross). CymBuild reads invoices and allocations from v2.
        var client = File.ReadAllText(
            RepositoryLayout.PathFromRoot("services", "Concursus.API", "Sage", "SOAP", "Client", "SageApiClient.cs"));

        Assert.Contains("\"/api/v2/customer-transactions?\"", client, StringComparison.Ordinal);
        Assert.Contains("\"/api/v2/sales-allocations?\"", client, StringComparison.Ordinal);
        Assert.DoesNotContain("\"/api/customer-transactions?\"", client, StringComparison.Ordinal);
        Assert.DoesNotContain("\"/api/sales-allocations?\"", client, StringComparison.Ordinal);
        Assert.Contains("\"/api/sales-orders\"", client, StringComparison.Ordinal);
    }

    [Fact]
    public void ExternalTransactionUpsert_MatchesAccountsWithTheirZerosIgnored_AndStoresTheFormSageHolds()
    {
        var sql = ReadSql("Procedures", "SFin.SageExternalTransaction_Upsert.sql");

        Assert.Contains("CREATE OR ALTER PROCEDURE [SFin].[SageExternalTransaction_Upsert]", sql, StringComparison.Ordinal);
        Assert.Contains("CYB-555-V2-ACCOUNT-ZEROS", sql, StringComparison.Ordinal);
        Assert.Contains(
            "SUBSTRING(ext.SageAccountReference, PATINDEX(N'%[^0]%', ext.SageAccountReference + N'.'), 100) = @StrippedAccountReference",
            sql,
            StringComparison.Ordinal);
        Assert.Contains("SageAccountReference     = @SageAccountReference,", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void RecordAllocation_StoresTheCounterpartOncePerUrn_AndEachAllocationOncePerSessionAndUrn()
    {
        var sql = ReadSql("Procedures", "SFin.SageInbound_RecordAllocation.sql");

        Assert.Contains("CREATE OR ALTER PROCEDURE [SFin].[SageInbound_RecordAllocation]", sql, StringComparison.Ordinal);
        Assert.Contains("SET @CounterpartDocumentNo = N'URN:' + @CounterpartUrn;", sql, StringComparison.Ordinal);
        Assert.Contains("SET @AllocationKey = N'SESSION:' + @AllocationHeaderID + N'|URN:' + @CounterpartUrn;", sql, StringComparison.Ordinal);
        Assert.Contains("ext.SageTransactionTypeCode IN (-1, 1, 5)", sql, StringComparison.Ordinal);
        Assert.Contains("a.SourceHash = @AllocationKey", sql, StringComparison.Ordinal);
        // Every insert creates its SCore.DataObjects row (AGENTS.md).
        Assert.Equal(2, CountOccurrences(sql, "EXEC SCore.UpsertDataObject"));
        Assert.Equal(2, CountOccurrences(sql, "INSERT INTO SFin."));
        Assert.DoesNotContain("SELECT *", sql, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void ReconcileAllocations_MaterialisesOnlyReceiptsAndCreditNotes_InPairMode()
    {
        var sql = ReadSql("Procedures", "SFin.SageInbound_ReconcileAllocations.sql");

        Assert.Contains("CREATE OR ALTER PROCEDURE [SFin].[SageInbound_ReconcileAllocations]", sql, StringComparison.Ordinal);
        Assert.Contains("CYB-555-RECONCILE-PAIR-MODE", sql, StringComparison.Ordinal);
        Assert.Contains("IF @CounterpartTypeCode IN (1, 5)", sql, StringComparison.Ordinal);
        Assert.Contains("@InvoiceExternalTransactionID = @TargetExternalTransactionID", sql, StringComparison.Ordinal);
        // An unresolved counterpart (settled, method unknown) never creates a
        // transaction, and allocations are only ever written by the materialise.
        Assert.DoesNotContain("INSERT INTO SFin.TransactionAllocations", sql, StringComparison.Ordinal);
    }

    [Fact]
    public void ReceiptMaterialisation_PairModeIsKeyedByTheAllocations_AndAllocationsBlockTheFallback()
    {
        var sql = ReadSql("Procedures", "SFin.SageInboundReceiptAndAllocation_Materialise.sql");

        Assert.Contains("@InvoiceExternalTransactionID BIGINT = NULL", sql, StringComparison.Ordinal);
        Assert.Contains("CYB-555-PAIR-MODE", sql, StringComparison.Ordinal);
        Assert.Contains("CYB-555-ALLOCATIONS-BLOCK-FALLBACK", sql, StringComparison.Ordinal);
        Assert.Contains("SELECT @AllocatedValue = SUM(pairAllocation.AllocatedAmount)", sql, StringComparison.Ordinal);
        Assert.Contains("AND @IsPairMode = 0", sql, StringComparison.Ordinal);
        Assert.Contains("claimed.SourceExternalTransactionID <> @ExternalTransactionID", sql, StringComparison.Ordinal);
    }

    private static int CountOccurrences(string text, string value)
    {
        var count = 0;
        for (var index = text.IndexOf(value, StringComparison.Ordinal); index >= 0; index = text.IndexOf(value, index + value.Length, StringComparison.Ordinal))
        {
            count++;
        }

        return count;
    }

    private static string ReadSql(string objectType, string fileName)
    {
        return File.ReadAllText(
            RepositoryLayout.PathFromRoot(
                "Database",
                "CymBuild_DB",
                "Schema",
                "Programmability",
                objectType,
                fileName));
    }
}
