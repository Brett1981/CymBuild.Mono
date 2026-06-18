SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[JobRibaStageFees_UpsertFromCreatedQuoteItems]')
GO

CREATE PROCEDURE [SJob].[JobRibaStageFees_UpsertFromCreatedQuoteItems]
(
    @JobID INT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SJob.Jobs AS j
        WHERE j.ID = @JobID
          AND j.RowStatus NOT IN (0,254)
    )
    BEGIN
        ;THROW 60000, N'Cannot upsert dynamic job RIBA stage fees because the supplied JobID is not active.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.EntityHobts AS eh
        JOIN SCore.EntityTypes AS et
            ON et.ID = eh.EntityTypeID
        WHERE eh.SchemaName = N'SJob'
          AND eh.ObjectName = N'JobRibaStageFees'
          AND eh.RowStatus NOT IN (0,254)
          AND et.RowStatus NOT IN (0,254)
    )
    BEGIN
        ;THROW 60000, N'SJob.JobRibaStageFees metadata is missing. Deploy the source-controlled HoBT/EntityType metadata before running CYB-339.', 1;
    END;

    DECLARE @CurrentUserID INT = ISNULL(CONVERT(INT, SESSION_CONTEXT(N'user_id')), -1);
    DECLARE @GuidList SCore.GuidUniqueList;
    DECLARE @IsInsert BIT = 0;

    DECLARE @StageFees TABLE
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        JobID INT NOT NULL,
        RibaStageID INT NOT NULL,
        CreatedFromQuoteItemID INT NOT NULL PRIMARY KEY,
        AgreedFee DECIMAL(19, 2) NOT NULL
    );

    INSERT INTO @StageFees
    (
        Guid,
        JobID,
        RibaStageID,
        CreatedFromQuoteItemID,
        AgreedFee
    )
    SELECT
        ISNULL(existing.Guid, NEWID()) AS Guid,
        @JobID AS JobID,
        CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END AS RibaStageID,
        qi.ID AS CreatedFromQuoteItemID,
        qit.LineNet AS AgreedFee
    FROM SSop.QuoteItems AS qi
    JOIN SSop.QuoteItemTotals AS qit
        ON qit.ID = qi.ID
    LEFT JOIN SJob.JobRibaStageFees AS existing
        ON existing.CreatedFromQuoteItemID = qi.ID
       AND existing.RowStatus NOT IN (0,254)
    WHERE qi.CreatedJobId = @JobID
      AND qi.RowStatus NOT IN (0,254)
      AND qi.Quantity > 0
      AND CASE WHEN qi.ProvideAtStageID = -1 THEN 2 ELSE qi.ProvideAtStageID END > 0;

	  --Check for custom RIBA stages specified for Month configuration.
	  --Need to ensure they are displayed in the fee drawdown table (with agreed fee = 0)
	  IF(EXISTS
			(
				SELECT 1
				FROM SFin.InvoiceSchedules root_hobt 
				JOIN SFin.InvoiceScheduleMonthConfiguration AS invmonthconfig ON (invmonthconfig.InvoiceScheduleId = root_hobt.ID)
				JOIN SSop.QuoteItems AS qi ON (qi.InvoicingSchedule = root_hobt.ID)
				JOIN SJob.RibaStages AS Riba ON (Riba.ID = invmonthconfig.RIBAStageId)

				WHERE 
						(root_hobt.RowStatus NOT IN (0,254))
					AND (qi.CreatedJobId = @JobId)
					AND (Riba.IsCustomStage = 1)
			)
		)
		BEGIN

		   INSERT INTO @StageFees
			(
				Guid,
				JobID,
				RibaStageID,
				CreatedFromQuoteItemID,
				AgreedFee
			)
			SELECT 
					NEWID() AS Guid,
					@JobId AS JobId,
					Riba.ID AS RibaStageID,
					invmonthconfig.ID AS CreatedFromQuoteItemID,
					0.0 AS AgreedFee								--For now it's just 0. 
			FROM SFin.InvoiceSchedules root_hobt
			JOIN SSop.Quotes AS q ON (q.ID = root_hobt.QuoteId)
			JOIN SSop.QuoteItems AS qi ON (qi.InvoicingSchedule = root_hobt.ID)
			JOIN SSop.QuoteItemTotals AS qit ON qit.ID = qi.ID
			JOIN SJob.Jobs AS J ON (J.ID = qi.CreatedJobId)
			JOIN SFin.InvoiceScheduleMonthConfiguration AS invmonthconfig ON (invmonthconfig.InvoiceScheduleId = root_hobt.ID)
			JOIN SJob.RibaStages AS Riba ON (Riba.ID = invmonthconfig.RIBAStageId)
			WHERE 
					(qi.CreatedJobId = @JobId)
				AND (root_hobt.RowStatus NOT IN (0,254))
				
		END;

	  --Same thing for the percetnage as the month configuration.
	  --We need to ensure it is present in the fee drawdown grid.
	  IF(EXISTS
			(
				SELECT 1
				FROM SFin.InvoiceSchedules root_hobt 
				JOIN SFin.InvoiceSchedulePercentageConfiguration AS invpercconfig ON (invpercconfig.InvoiceScheduleId = root_hobt.ID)
				JOIN SSop.QuoteItems AS qi ON (qi.InvoicingSchedule = root_hobt.ID)
				JOIN SJob.RibaStages AS Riba ON (Riba.ID = invpercconfig.RIBAStageId)

				WHERE 
						(root_hobt.RowStatus NOT IN (0,254))
					AND (qi.CreatedJobId = @JobId)
					AND (Riba.IsCustomStage = 1)
			)
		)
		BEGIN

		   INSERT INTO @StageFees
			(
				Guid,
				JobID,
				RibaStageID,
				CreatedFromQuoteItemID,
				AgreedFee
			)
			SELECT 
					NEWID() AS Guid,
					@JobId AS JobId,
					Riba.ID AS RibaStageID,
					invpercconfig.ID AS CreatedFromQuoteItemID,
					0.0 AS AgreedFee --For now, 
			FROM SFin.InvoiceSchedules root_hobt
			JOIN SSop.Quotes AS q ON (q.ID = root_hobt.QuoteId)
			JOIN SSop.QuoteItems AS qi ON (qi.InvoicingSchedule = root_hobt.ID)
			JOIN SSop.QuoteItemTotals AS qit ON qit.ID = qi.ID
			JOIN SJob.Jobs AS J ON (J.ID = qi.CreatedJobId)
			JOIN SFin.InvoiceSchedulePercentageConfiguration AS invpercconfig ON (invpercconfig.InvoiceScheduleId = root_hobt.ID)
			JOIN SJob.RibaStages AS Riba ON (Riba.ID = invpercconfig.RIBAStageId)
			WHERE 
					(qi.CreatedJobId = @JobId)
				AND (root_hobt.RowStatus NOT IN (0,254))
				
		END;

    IF NOT EXISTS (SELECT 1 FROM @StageFees)
    BEGIN
        RETURN;
    END;

    INSERT INTO @GuidList (GuidValue)
    SELECT sf.Guid
    FROM @StageFees AS sf
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SCore.DataObjects AS d
        WHERE d.Guid = sf.Guid
    );

    IF EXISTS (SELECT 1 FROM @GuidList)
    BEGIN
        EXEC SCore.DataObjectBulkUpsert
             @GuidList   = @GuidList,
             @SchemeName = N'SJob',
             @ObjectName = N'JobRibaStageFees',
             @IsInsert   = @IsInsert OUTPUT;
    END;

    UPDATE target
    SET
        target.RowStatus = 1,
        target.JobID = sf.JobID,
        target.RibaStageID = sf.RibaStageID,
        target.AgreedFee = sf.AgreedFee,
        target.LastUpdatedDateTimeUTC = SYSUTCDATETIME(),
        target.LastUpdatedByUserID = @CurrentUserID
    FROM SJob.JobRibaStageFees AS target
    JOIN @StageFees AS sf
        ON sf.CreatedFromQuoteItemID = target.CreatedFromQuoteItemID
    WHERE target.RowStatus NOT IN (0,254)
      AND
      (
             target.JobID <> sf.JobID
          OR target.RibaStageID <> sf.RibaStageID
          OR target.AgreedFee <> sf.AgreedFee
      );

    INSERT INTO SJob.JobRibaStageFees
    (
        RowStatus,
        Guid,
        JobID,
        RibaStageID,
        CreatedFromQuoteItemID,
        AgreedFee,
        CreatedDateTimeUTC,
        CreatedByUserID,
        LastUpdatedDateTimeUTC,
        LastUpdatedByUserID
    )
    SELECT
        1,
        sf.Guid,
        sf.JobID,
        sf.RibaStageID,
        sf.CreatedFromQuoteItemID,
        sf.AgreedFee,
        SYSUTCDATETIME(),
        @CurrentUserID,
        NULL,
        NULL
    FROM @StageFees AS sf
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SJob.JobRibaStageFees AS existing
        WHERE existing.CreatedFromQuoteItemID = sf.CreatedFromQuoteItemID
          AND existing.RowStatus NOT IN (0,254)
    );
END;
GO