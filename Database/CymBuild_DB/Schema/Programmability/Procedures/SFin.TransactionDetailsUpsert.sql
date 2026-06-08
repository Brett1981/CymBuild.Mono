SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SFin].[TransactionDetailsUpsert]')
GO
CREATE PROCEDURE [SFin].[TransactionDetailsUpsert]
(
      @TransactionGuid          UNIQUEIDENTIFIER
    , @MilestoneGuid            UNIQUEIDENTIFIER
    , @ActivityGuid             UNIQUEIDENTIFIER
    , @Net                      DECIMAL(9, 2)
    , @Vat                      DECIMAL(9, 2)
    , @Gross                    DECIMAL(9, 2)
    , @VatRate                  DECIMAL(9, 2)
    , @Description              NVARCHAR(2000)
    , @JobPaymentStageGuid      UNIQUEIDENTIFIER
    , @Guid                     UNIQUEIDENTIFIER
    , @RIBAStageGuid            UNIQUEIDENTIFIER
    , @InvoiceRequestItemGuid   UNIQUEIDENTIFIER = NULL
    , @Qty                      DECIMAL(18, 4) = 1
    , @VatCodeGuid              UNIQUEIDENTIFIER = NULL
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
          @TransactionID              BIGINT
        , @MilestoneID                BIGINT = -1
        , @ActivityID                 BIGINT = -1
        , @JobPaymentStageID          INT    = -1
        , @RIBAStageID                INT    = -1
        , @InvoiceRequestItemID       BIGINT = -1
        , @VatCodeID                  INT
        , @ResolvedVatRate            DECIMAL(9, 4)
        , @IsInsert                   BIT
        , @JobNumber                  NVARCHAR(2000)
        , @JobDescription             NVARCHAR(2000)
        , @JobType                    NVARCHAR(2000)
        , @UprnFormattedAddressComma  NVARCHAR(2000);

    IF @Guid IS NULL OR @Guid = '00000000-0000-0000-0000-000000000000'
    BEGIN
        ;THROW 60070, N'A valid Guid is required for SFin.TransactionDetailsUpsert.', 1;
    END;

    IF @TransactionGuid IS NULL OR @TransactionGuid = '00000000-0000-0000-0000-000000000000'
    BEGIN
        ;THROW 60071, N'A valid TransactionGuid is required for SFin.TransactionDetailsUpsert.', 1;
    END;

    IF @VatCodeGuid IS NULL OR @VatCodeGuid = '00000000-0000-0000-0000-000000000000'
    BEGIN
        ;THROW 60072, N'A valid VatCodeGuid is required for SFin.TransactionDetailsUpsert.', 1;
    END;

    IF @Qty IS NULL OR @Qty <= 0
    BEGIN
        SET @Qty = 1;
    END;

    SELECT
        @TransactionID = t.ID
    FROM SFin.Transactions AS t
    WHERE t.Guid = @TransactionGuid
      AND t.RowStatus NOT IN (0, 254);

    IF @TransactionID IS NULL
    BEGIN
        ;THROW 60073, N'Transaction could not be resolved for SFin.TransactionDetailsUpsert.', 1;
    END;

    IF @MilestoneGuid IS NOT NULL
       AND @MilestoneGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @MilestoneID = m.ID
        FROM SJob.Milestones AS m
        WHERE m.Guid = @MilestoneGuid
          AND m.RowStatus NOT IN (0, 254);
    END;

    IF @ActivityGuid IS NOT NULL
       AND @ActivityGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @ActivityID = a.ID
        FROM SJob.Activities AS a
        WHERE a.Guid = @ActivityGuid
          AND a.RowStatus NOT IN (0, 254);
    END;

    IF @RIBAStageGuid IS NOT NULL
       AND @RIBAStageGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @RIBAStageID = rs.ID
        FROM SJob.RibaStages AS rs
        WHERE rs.Guid = @RIBAStageGuid
          AND rs.RowStatus NOT IN (0, 254);
    END;

    IF @JobPaymentStageGuid IS NOT NULL
       AND @JobPaymentStageGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @JobPaymentStageID = jps.ID
        FROM SJob.JobPaymentStages AS jps
        WHERE jps.Guid = @JobPaymentStageGuid
          AND jps.RowStatus NOT IN (0, 254);
    END;

    IF @InvoiceRequestItemGuid IS NOT NULL
       AND @InvoiceRequestItemGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT
            @InvoiceRequestItemID = iri.ID
        FROM SFin.InvoiceRequestItems AS iri
        WHERE iri.Guid = @InvoiceRequestItemGuid
          AND iri.RowStatus NOT IN (0, 254);
    END;

    SELECT
          @VatCodeID = vc.ID
        , @ResolvedVatRate = vc.VatPercentage
    FROM SFin.VatCodes AS vc
    WHERE vc.Guid = @VatCodeGuid
      AND vc.RowStatus NOT IN (0, 254)
      AND vc.Active = 1;

    IF @VatCodeID IS NULL
    BEGIN
        ;THROW 60074, N'VatCode could not be resolved for SFin.TransactionDetailsUpsert.', 1;
    END;

    IF @ResolvedVatRate IS NULL
    BEGIN
        ;THROW 60075, N'VatCode selected does not contain a valid VAT percentage for SFin.TransactionDetailsUpsert.', 1;
    END;

    /*
        VAT rate is now owned by the selected VatCode.
        Ignore caller-supplied @VatRate / @Vat / @Gross and recalculate deterministically.
    */
    SET @VatRate = CONVERT(DECIMAL(9, 2), @ResolvedVatRate);
    SET @Vat = ROUND(@Net * (@ResolvedVatRate / 100.0), 2);
    SET @Gross = ROUND(@Net + @Vat, 2);

	DECLARE @JobGuid UNIQUEIDENTIFIER;
	DECLARE @RemainingAmount DECIMAL(19,2);

	SELECT @JobGuid = j.Guid
	FROM SFin.Transactions AS root_hobt
	LEFT JOIN SJob.Jobs AS j ON (root_hobt.JobID = j.ID)
	WHERE root_hobt.ID = @TransactionID

	SELECT
		@RemainingAmount = ISNULL(fd.Remaining, 0)
	FROM SJob.Job_FeeDrawdown fd
	INNER JOIN SJob.Jobs j
		ON j.ID = fd.JobId
	WHERE j.Guid = @JobGuid
	  AND fd.StageLabel = N'Total (inc. Fee Cap)';


	IF(@Net > @RemainingAmount)
	BEGIN 

		DECLARE @ErrorMessageDirect NVARCHAR(500);

		SET @ErrorMessageDirect =
                    N'Cannot save this transaction because only the total of £'
                    + CONVERT(NVARCHAR(50), @RemainingAmount)
                    + N' remains'
                    + N',but the transaction Net is £'
                    + CONVERT(NVARCHAR(50), @Net)
                    + N'.';

				THROW 51003, @ErrorMessageDirect, 1;
	END;

    EXEC SCore.UpsertDataObject
          @Guid       = @Guid
        , @SchemeName = N'SFin'
        , @ObjectName = N'TransactionDetails'
        , @IsInsert   = @IsInsert OUTPUT;

    IF @IsInsert = 1
    BEGIN
        SELECT
              @JobNumber = j.Number
            , @JobDescription = j.JobDescription
            , @JobType = jt.Name
            , @UprnFormattedAddressComma = p.FormattedAddressComma
        FROM SJob.Jobs AS j
        INNER JOIN SJob.JobTypes AS jt
            ON jt.ID = j.JobTypeID
        INNER JOIN SJob.Assets AS p
            ON p.ID = j.UprnID
        INNER JOIN SFin.Transactions AS t
            ON t.JobID = j.ID
        WHERE t.Guid = @TransactionGuid
          AND j.RowStatus NOT IN (0, 254)
          AND jt.RowStatus NOT IN (0, 254)
          AND p.RowStatus NOT IN (0, 254)
          AND t.RowStatus NOT IN (0, 254);

        IF @@ROWCOUNT > 0
        BEGIN
            SET @Description =
                ISNULL(@Description, N'')
                + N'
Our project ref.: ' + ISNULL(@JobNumber, N'')
                + N'
Project description: ' + ISNULL(@JobDescription, N'')
                + N'
Property: ' + ISNULL(@UprnFormattedAddressComma, N'')
                + N'
Appointed role: ' + ISNULL(@JobType, N'');
        END;

        SET @Description = REPLACE(@Description, CHAR(34), CHAR(39));

        INSERT INTO SFin.TransactionDetails
        (
              RowStatus
            , Guid
            , TransactionID
            , MilestoneID
            , ActivityID
            , Net
            , Vat
            , Gross
            , VatRate
            , Description
            , JobPaymentStageId
            , InvoiceRequestItemId
            , RIBAStageId
            , Qty
            , VatCodeID
        )
        VALUES
        (
              1
            , @Guid
            , @TransactionID
            , ISNULL(@MilestoneID, -1)
            , ISNULL(@ActivityID, -1)
            , @Net
            , @Vat
            , @Gross
            , @VatRate
            , ISNULL(@Description, N'')
            , ISNULL(@JobPaymentStageID, -1)
            , ISNULL(@InvoiceRequestItemID, -1)
            , ISNULL(@RIBAStageID, -1)
            , @Qty
            , @VatCodeID
        );
    END
    ELSE
    BEGIN
        UPDATE td
        SET
              td.MilestoneID = ISNULL(@MilestoneID, -1)
            , td.ActivityID = ISNULL(@ActivityID, -1)
            , td.Net = @Net
            , td.Vat = @Vat
            , td.Gross = @Gross
            , td.VatRate = @VatRate
            , td.Description = ISNULL(@Description, N'')
            , td.JobPaymentStageId = ISNULL(@JobPaymentStageID, -1)
            , td.InvoiceRequestItemId = ISNULL(@InvoiceRequestItemID, -1)
            , td.RIBAStageId = ISNULL(@RIBAStageID, -1)
            , td.Qty = @Qty
            , td.VatCodeID = @VatCodeID
        FROM SFin.TransactionDetails AS td
        WHERE td.Guid = @Guid
          AND td.RowStatus NOT IN (0, 254);
    END;
END;
GO