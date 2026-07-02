SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[QuoteItemsUpsert]')
GO
PRINT (N'Create procedure [SSop].[QuoteItemsUpsert]')
GO

CREATE PROCEDURE [SSop].[QuoteItemsUpsert]
(
    @QuoteGuid              UNIQUEIDENTIFIER,
    @ProductGuid            UNIQUEIDENTIFIER,
    @Details                NVARCHAR(2000),
    @Net                    DECIMAL(19, 2),
    @VatRate                DECIMAL(9, 2),
    @DoNotConsolidateJob    BIT,
    @SortOrder              INT,
    @Quantity               DECIMAL(9, 2),
    @ProvidedAtStageGuid    UNIQUEIDENTIFIER,
    @Guid                   UNIQUEIDENTIFIER,
    @NumberOfSiteVisits     INT,
    @NumberOfMeetings       INT,
    @InvoicingScheduleGuid  UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @QuoteId                    INT,
            @ProductId                  INT,
            @ProvidedAtStageId          INT = -1,
            @InvoicingScheduleId        INT = -1,
            @IsInsert                   BIT,
            @ProductCreatedJobTypeId    INT = -1,
            @EffectiveQuoteJobTypeId    INT = -1;

    SELECT @QuoteId = q.ID
    FROM SSop.Quotes AS q
    WHERE q.Guid = @QuoteGuid
      AND q.RowStatus NOT IN (0,254);

    SELECT @ProvidedAtStageId = rs.ID
    FROM SJob.RibaStages AS rs
    WHERE rs.Guid = @ProvidedAtStageGuid
      AND rs.RowStatus NOT IN (0,254);

    SET @ProvidedAtStageId = ISNULL(@ProvidedAtStageId, -1);

    SELECT
        @ProductId = p.ID,
        @ProductCreatedJobTypeId = ISNULL(p.CreatedJobType, -1)
    FROM SProd.Products AS p
    WHERE p.Guid = @ProductGuid
      AND p.RowStatus NOT IN (0,254);

    SELECT @InvoicingScheduleId = inv.ID
    FROM SFin.InvoiceSchedules AS inv
    WHERE inv.Guid = @InvoicingScheduleGuid
      AND inv.RowStatus NOT IN (0,254);

    SET @InvoicingScheduleId = ISNULL(@InvoicingScheduleId, -1);

    IF ISNULL(@QuoteId, -1) <= 0
    BEGIN
        ;THROW 604170, N'CYB-416: Quote item cannot be saved because the parent quote could not be resolved.', 1;
    END;

    IF ISNULL(@ProductId, -1) <= 0
    BEGIN
        ;THROW 604171, N'CYB-416: Quote item cannot be saved because the selected product could not be resolved.', 1;
    END;

    SELECT @EffectiveQuoteJobTypeId =
        COALESCE
        (
            NULLIF(NULLIF(q.JobTypeId, 0), -1),
            NULLIF(NULLIF(es.JobTypeId, 0), -1),
            -1
        )
    FROM SSop.Quotes AS q
    LEFT JOIN SSop.EnquiryServices AS es
        ON es.ID = q.EnquiryServiceID
       AND es.RowStatus NOT IN (0,254)
    WHERE q.ID = @QuoteId
      AND q.RowStatus NOT IN (0,254);

    IF ISNULL(@ProductCreatedJobTypeId, -1) <> -1
       AND
       (
            ISNULL(@EffectiveQuoteJobTypeId, -1) <= 0
         OR @ProductCreatedJobTypeId <> @EffectiveQuoteJobTypeId
       )
    BEGIN
        ;THROW 604172, N'CYB-416: The selected product is not valid for the quote job type.', 1;
    END;

    EXEC SCore.UpsertDataObject
        @Guid       = @Guid,
        @SchemeName = N'SSop',
        @ObjectName = N'QuoteItems',
        @IsInsert   = @IsInsert OUTPUT;

    IF (@IsInsert = 1)
    BEGIN
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
            Quantity,
            ProvideAtStageID,
            NumberOfMeetings,
            NumberOfSiteVisits,
            InvoicingSchedule
        )
        VALUES
        (
            1,
            @Guid,
            @QuoteId,
            @ProductId,
            @Details,
            @Net,
            @VatRate,
            @DoNotConsolidateJob,
            @SortOrder,
            @Quantity,
            @ProvidedAtStageId,
            @NumberOfMeetings,
            @NumberOfSiteVisits,
            @InvoicingScheduleId
        );
    END;
    ELSE
    BEGIN
        UPDATE SSop.QuoteItems
        SET QuoteId = @QuoteId,
            ProductId = @ProductId,
            Details = @Details,
            Net = @Net,
            VatRate = @VatRate,
            DoNotConsolidateJob = @DoNotConsolidateJob,
            SortOrder = @SortOrder,
            Quantity = @Quantity,
            ProvideAtStageID = @ProvidedAtStageId,
            NumberOfMeetings = @NumberOfMeetings,
            NumberOfSiteVisits = @NumberOfSiteVisits,
            InvoicingSchedule = @InvoicingScheduleId
        WHERE Guid = @Guid
          AND RowStatus NOT IN (0,254);
    END;

    IF
    (
        EXISTS
        (
            SELECT 1
            FROM SSop.QuoteItems AS root_hobt
            WHERE root_hobt.QuoteId = @QuoteId
              AND root_hobt.Guid <> @Guid
              AND root_hobt.RowStatus NOT IN (0,254)
              AND root_hobt.DoNotConsolidateJob = 0
              AND root_hobt.ProductId = @ProductId
              AND root_hobt.CreatedJobId = -1
        )
        AND ISNULL(@DoNotConsolidateJob, 0) = 0
    )
    BEGIN
        UPDATE SSop.QuoteItems
        SET InvoicingSchedule = @InvoicingScheduleId
        WHERE QuoteId = @QuoteId
          AND Guid <> @Guid
          AND RowStatus NOT IN (0,254)
          AND ProductId = @ProductId
          AND DoNotConsolidateJob = 0
          AND CreatedJobId = -1;
    END;
END;
GO