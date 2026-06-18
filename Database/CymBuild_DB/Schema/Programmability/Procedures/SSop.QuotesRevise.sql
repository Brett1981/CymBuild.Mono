SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[QuotesRevise]')
GO


CREATE PROCEDURE [SSop].[QuotesRevise]
    @SourceGuid UNIQUEIDENTIFIER,
    @TargetGuid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @SourceID INT,
        @ID INT,
        @IsInsert BIT;

    SELECT @SourceID = q.ID
    FROM SSop.Quotes AS q
    WHERE q.Guid = @SourceGuid
      AND q.RowStatus NOT IN (0,254);

    IF (@SourceID IS NULL)
        THROW 60000, N'Invalid source Quote', 1;

    IF EXISTS
    (
        SELECT 1
        FROM SSop.Quotes AS q
        WHERE q.Guid = @SourceGuid
          AND q.RowStatus NOT IN (0,254)
          AND q.DateAccepted IS NOT NULL
    )
    BEGIN
        ;THROW 60000, N'You cannot revise an accepted quote', 1;
    END;

    EXEC SCore.UpsertDataObject
        @Guid = @TargetGuid,
        @SchemeName = N'SSop',
        @ObjectName = N'Quotes',
        @IncludeDefaultSecurity = 1,
        @IsInsert = @IsInsert OUTPUT;

    INSERT SSop.Quotes
    (
        RowStatus,
        Guid,
        OrganisationalUnitID,
        QuotingUserId,
        Number,
        UprnId,
        ClientAccountId,
        ClientAddressId,
        ClientContactId,
        ContractID,
        Date,
        Overview,
        ExpiryDate,
        QuoteSourceId,
        IsSubjectToNDA,
        AgentAccountId,
        AgentAddressId,
        AgentContactId,
        ExternalReference,
        FeeCap,
        RevisionNumber,
        OriginalQuoteId,
        EnquiryServiceID,
        DescriptionOfWorks,
        QuotingConsultantId,
        ExclusionsAndLimitations,
        ProjectId,
        AgentContractID,
        MarketId,
        SectorId,
        JobTypeId,
        DataClassificationID,
        SecurityClassificationID
    )
    SELECT
        0,
        @TargetGuid,
        q.OrganisationalUnitID,
        q.QuotingUserId,
        q.Number,
        q.UprnId,
        q.ClientAccountId,
        q.ClientAddressId,
        q.ClientContactId,
        q.ContractID,
        GETDATE(),
        q.Overview,
        DATEADD(MONTH, 6, GETDATE()),
        q.QuoteSourceId,
        q.IsSubjectToNDA,
        q.AgentAccountId,
        q.AgentAddressId,
        q.AgentContactId,
        q.ExternalReference,
        q.FeeCap,
        ISNULL(latest_revision.rev, 0) + 1,
        CASE
            WHEN q.OriginalQuoteId = -1 THEN q.ID
            ELSE q.OriginalQuoteId
        END,
        q.EnquiryServiceID,
        q.DescriptionOfWorks,
        q.QuotingConsultantId,
        q.ExclusionsAndLimitations,
        q.ProjectId,
        q.AgentContractID,
        q.MarketId,
        q.SectorId,
        q.JobTypeId,
        q.DataClassificationID,
        q.SecurityClassificationID
    FROM SSop.Quotes AS q
    OUTER APPLY
    (
        SELECT MAX(q1.RevisionNumber) AS rev
        FROM SSop.Quotes AS q1
        WHERE q1.OriginalQuoteId =
            CASE
                WHEN q.OriginalQuoteId = -1 THEN q.ID
                ELSE q.OriginalQuoteId
            END
          AND q1.RowStatus NOT IN (0,254)
    ) AS latest_revision
    WHERE q.ID = @SourceID;

    SELECT @ID = CONVERT(INT, SCOPE_IDENTITY());

    DECLARE @QuoteItems SCore.TwoGuidUniqueList;

    INSERT @QuoteItems
    (
        GuidValue,
        GuidValueTwo
    )
    SELECT
        qi.Guid,
        NEWID()
    FROM SSop.QuoteItems AS qi
    WHERE qi.QuoteId = @SourceID
      AND qi.RowStatus NOT IN (0,254);

    DECLARE @QuotePaymentStages SCore.TwoGuidUniqueList;

    INSERT @QuotePaymentStages
    (
        GuidValue,
        GuidValueTwo
    )
    SELECT
        qps.Guid,
        NEWID()
    FROM SSop.QuotePaymentStages AS qps
    WHERE qps.QuoteId = @SourceID
      AND qps.RowStatus NOT IN (0,254);

    DECLARE @QuoteMemos SCore.TwoGuidUniqueList;

    INSERT @QuoteMemos
    (
        GuidValue,
        GuidValueTwo
    )
    SELECT
        qm.Guid,
        NEWID()
    FROM SSop.QuoteMemos AS qm
    WHERE qm.QuoteID = @SourceID
      AND qm.RowStatus NOT IN (0,254);

    DECLARE @NewGuidList SCore.GuidUniqueList;

    INSERT @NewGuidList
    (
        GuidValue
    )
    SELECT qi.GuidValueTwo
    FROM @QuoteItems AS qi;

    EXEC SCore.DataObjectBulkUpsert
        @GuidList = @NewGuidList,
        @SchemeName = N'SSop',
        @ObjectName = N'QuoteItems',
        @IsInsert = @IsInsert OUTPUT;

    DELETE FROM @NewGuidList;

    INSERT @NewGuidList
    (
        GuidValue
    )
    SELECT qps.GuidValueTwo
    FROM @QuotePaymentStages AS qps;

    EXEC SCore.DataObjectBulkUpsert
        @GuidList = @NewGuidList,
        @SchemeName = N'SSop',
        @ObjectName = N'QuotePaymentStages',
        @IsInsert = @IsInsert OUTPUT;

    DELETE FROM @NewGuidList;

    INSERT @NewGuidList
    (
        GuidValue
    )
    SELECT qm.GuidValueTwo
    FROM @QuoteMemos AS qm;

    EXEC SCore.DataObjectBulkUpsert
        @GuidList = @NewGuidList,
        @SchemeName = N'SSop',
        @ObjectName = N'QuoteMemos',
        @IsInsert = @IsInsert OUTPUT;

    INSERT SSop.QuoteItems
    (
        RowStatus,
        Guid,
        QuoteId,
        ProductId,
        Details,
        Net,
        VatRate,
        DoNotConsolidateJob,
        SortOrder,
        Quantity
    )
    SELECT
        1,
        qil.GuidValueTwo,
        @ID,
        qi.ProductId,
        qi.Details,
        qi.Net,
        qi.VatRate,
        qi.DoNotConsolidateJob,
        qi.SortOrder,
        qi.Quantity
    FROM SSop.QuoteItems AS qi
    JOIN @QuoteItems AS qil
        ON qil.GuidValue = qi.Guid
    JOIN SSop.QuoteSections AS oqs
        ON oqs.ID = qi.QuoteSectionId;

    INSERT SSop.QuotePaymentStages
    (
        RowStatus,
        Guid,
        QuoteId,
        PaymentFrequencyTypeId,
        PaymentFrequency,
        Value,
        PercentageOfTotal,
        PayAfterStageId
    )
    SELECT
        1,
        qpsl.GuidValueTwo,
        @ID,
        qps.PaymentFrequencyTypeId,
        qps.PaymentFrequency,
        qps.Value,
        qps.PercentageOfTotal,
        qps.PayAfterStageId
    FROM SSop.QuotePaymentStages AS qps
    JOIN @QuotePaymentStages AS qpsl
        ON qps.Guid = qpsl.GuidValue;

    INSERT SSop.QuoteMemos
    (
        RowStatus,
        Guid,
        QuoteID,
        Memo,
        CreatedDateTimeUTC,
        CreatedByUserId
    )
    SELECT
        1,
        qms.GuidValueTwo,
        @ID,
        qm.Memo,
        qm.CreatedDateTimeUTC,
        qm.CreatedByUserId
    FROM SSop.QuoteMemos AS qm
    JOIN @QuoteMemos AS qms
        ON qm.Guid = qms.GuidValue;

    UPDATE SSop.Quotes
    SET RowStatus = 1
    WHERE ID = @ID;

    DECLARE
        @QuoteRevisedStatusGuid UNIQUEIDENTIFIER,
        @QuotingStatusGuid UNIQUEIDENTIFIER,
        @NewTransitionGuid UNIQUEIDENTIFIER;

    SELECT TOP (1)
        @QuoteRevisedStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name IN (N'Quote Revised', N'Revised')
    ORDER BY
        CASE
            WHEN ws.Name = N'Quote Revised' THEN 0
            WHEN ws.Name = N'Revised' THEN 1
            ELSE 2
        END,
        ws.ID;

    SELECT TOP (1)
        @QuotingStatusGuid = ws.Guid
    FROM SCore.WorkflowStatus AS ws
    WHERE ws.RowStatus NOT IN (0,254)
      AND ws.ShowInQuotes = 1
      AND ws.Name = N'Quoting'
    ORDER BY ws.ID;

    IF (@QuoteRevisedStatusGuid IS NULL)
        THROW 60000, N'Could not resolve Quote Revised workflow status. Please confirm the Quote Revised/Revised WorkflowStatus exists and has ShowInQuotes = 1.', 1;

    IF (@QuotingStatusGuid IS NULL)
        THROW 60000, N'Could not resolve Quote Quoting workflow status.', 1;

    SET @NewTransitionGuid = NEWID();

    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @NewTransitionGuid,
        @OldStatusGuid = '00000000-0000-0000-0000-000000000000',
        @StatusGuid = @QuoteRevisedStatusGuid,
        @Comment = N'Quote revised.',
        @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
        @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
        @DataObjectGuid = @TargetGuid,
        @IsImported = 1;

    SET @NewTransitionGuid = NEWID();

    EXEC SCore.DataObjectTransitionUpsert
        @Guid = @NewTransitionGuid,
        @OldStatusGuid = @QuoteRevisedStatusGuid,
        @StatusGuid = @QuotingStatusGuid,
        @Comment = N'Revision opened for quoting.',
        @CreatedByUserGuid = '00000000-0000-0000-0000-000000000000',
        @SurveyorUserGuid = '00000000-0000-0000-0000-000000000000',
        @DataObjectGuid = @TargetGuid,
        @IsImported = 1;
END;
GO