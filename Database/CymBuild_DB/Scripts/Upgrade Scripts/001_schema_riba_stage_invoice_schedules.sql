/*
    CymBuild – CYB RIBA Stage Support for Invoice Schedule Items and Automated Invoice Requests

    Deployment model:
    1. Apply schema through source-controlled SQL deployment.
    2. Apply metadata/entity-property manifests through CI/CD after schema deployment.
    3. Do not manually edit QA/UAT/LIVE metadata or promote DB changes manually.

    Behaviour:
    - RIBA Stage remains optional.
    - Existing rows remain NULL and keep existing behaviour.
    - Automation carries schedule item RIBA Stage to InvoiceRequests and InvoiceRequestItems.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Monthly schedule item RIBA Stage */
IF COL_LENGTH(N'SFin.InvoiceScheduleMonthConfiguration', N'RIBAStageId') IS NULL
BEGIN
    ALTER TABLE SFin.InvoiceScheduleMonthConfiguration
        ADD RIBAStageId INT NULL;
END;
GO

IF OBJECT_ID(N'SFin.FK_InvoiceScheduleMonthConfiguration_RibaStages', N'F') IS NULL
BEGIN
    ALTER TABLE SFin.InvoiceScheduleMonthConfiguration WITH CHECK
        ADD CONSTRAINT FK_InvoiceScheduleMonthConfiguration_RibaStages
        FOREIGN KEY (RIBAStageId)
        REFERENCES SJob.RibaStages (ID);
END;
GO

/* Percentage schedule item RIBA Stage */
IF COL_LENGTH(N'SFin.InvoiceSchedulePercentageConfiguration', N'RIBAStageId') IS NULL
BEGIN
    ALTER TABLE SFin.InvoiceSchedulePercentageConfiguration
        ADD RIBAStageId INT NULL;
END;
GO

IF OBJECT_ID(N'SFin.FK_InvoiceSchedulePercentageConfiguration_RibaStages', N'F') IS NULL
BEGIN
    ALTER TABLE SFin.InvoiceSchedulePercentageConfiguration WITH CHECK
        ADD CONSTRAINT FK_InvoiceSchedulePercentageConfiguration_RibaStages
        FOREIGN KEY (RIBAStageId)
        REFERENCES SJob.RibaStages (ID);
END;
GO

/* Header convenience RIBA Stage. Item-level remains source of truth for line attribution. */
IF COL_LENGTH(N'SFin.InvoiceRequests', N'RIBAStageId') IS NULL
BEGIN
    ALTER TABLE SFin.InvoiceRequests
        ADD RIBAStageId INT NULL;
END;
GO

IF OBJECT_ID(N'SFin.FK_InvoiceRequests_RibaStages', N'F') IS NULL
BEGIN
    ALTER TABLE SFin.InvoiceRequests WITH CHECK
        ADD CONSTRAINT FK_InvoiceRequests_RibaStages
        FOREIGN KEY (RIBAStageId)
        REFERENCES SJob.RibaStages (ID);
END;
GO

/* Item-level RIBA must be nullable to preserve existing behaviour and allow mixed/non-RIBA lines. */
IF COL_LENGTH(N'SFin.InvoiceRequestItems', N'RIBAStageId') IS NOT NULL
   AND EXISTS
   (
       SELECT 1
       FROM sys.columns AS c
       WHERE c.object_id = OBJECT_ID(N'SFin.InvoiceRequestItems')
         AND c.name = N'RIBAStageId'
         AND c.is_nullable = 0
   )
BEGIN
    DECLARE @DropDefaultSql NVARCHAR(MAX) = N'';

    SELECT @DropDefaultSql =
        N'ALTER TABLE SFin.InvoiceRequestItems DROP CONSTRAINT ' + QUOTENAME(dc.name) + N';'
    FROM sys.default_constraints AS dc
    JOIN sys.columns AS c
        ON c.object_id = dc.parent_object_id
       AND c.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = OBJECT_ID(N'SFin.InvoiceRequestItems')
      AND c.name = N'RIBAStageId';

    IF NULLIF(@DropDefaultSql, N'') IS NOT NULL
    BEGIN
        EXEC sys.sp_executesql @DropDefaultSql;
    END;

    ALTER TABLE SFin.InvoiceRequestItems
        ALTER COLUMN RIBAStageId INT NULL;
END;
GO

/* TransactionDetails must also allow NULL when the invoice item has no RIBA Stage. */
IF COL_LENGTH(N'SFin.TransactionDetails', N'RIBAStageId') IS NOT NULL
   AND EXISTS
   (
       SELECT 1
       FROM sys.columns AS c
       WHERE c.object_id = OBJECT_ID(N'SFin.TransactionDetails')
         AND c.name = N'RIBAStageId'
         AND c.is_nullable = 0
   )
BEGIN
    DECLARE @DropTransactionDefaultSql NVARCHAR(MAX) = N'';

    SELECT @DropTransactionDefaultSql =
        N'ALTER TABLE SFin.TransactionDetails DROP CONSTRAINT ' + QUOTENAME(dc.name) + N';'
    FROM sys.default_constraints AS dc
    JOIN sys.columns AS c
        ON c.object_id = dc.parent_object_id
       AND c.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = OBJECT_ID(N'SFin.TransactionDetails')
      AND c.name = N'RIBAStageId';

    IF NULLIF(@DropTransactionDefaultSql, N'') IS NOT NULL
    BEGIN
        EXEC sys.sp_executesql @DropTransactionDefaultSql;
    END;

    ALTER TABLE SFin.TransactionDetails
        ALTER COLUMN RIBAStageId INT NULL;
END;
GO
