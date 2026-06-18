SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceSchedulePercentageConfigurationUpsert]')
GO
CREATE PROCEDURE [SFin].[InvoiceSchedulePercentageConfigurationUpsert]
(
    @Guid UNIQUEIDENTIFIER,
    @InvoiceScheduleGuid UNIQUEIDENTIFIER,
    @OnDayOfMonth DATE,
    @PeriodNumber INT,
    @Percentage DECIMAL(19,2),
    @Description NVARCHAR(MAX),
    @RibaStageGuid UNIQUEIDENTIFIER = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @InvoiceScheduleId INT,
        @RibaStageId INT = NULL,
        @IsInsert BIT = 0;

    SELECT @InvoiceScheduleId = s.ID 
    FROM SFin.InvoiceSchedules AS s
    WHERE s.Guid = @InvoiceScheduleGuid
      AND s.RowStatus NOT IN (0,254);

    IF @RibaStageGuid IS NOT NULL
       AND @RibaStageGuid <> '00000000-0000-0000-0000-000000000000'
    BEGIN
        SELECT @RibaStageId = rs.ID
        FROM SJob.RibaStages AS rs
        WHERE rs.Guid = @RibaStageGuid
          AND rs.RowStatus NOT IN (0,254);
    END;

    EXEC SCore.UpsertDataObject
        @Guid = @Guid,
        @SchemeName = N'SFin',
        @ObjectName = N'InvoiceSchedulePercentageConfiguration',
        @IsInsert = @IsInsert OUTPUT;

    IF (@IsInsert = 1)
    BEGIN
        INSERT INTO SFin.InvoiceSchedulePercentageConfiguration
        (
            RowStatus,
            Guid,
            InvoiceScheduleId,
            OnDayOfMonth,
            PeriodNumber,
            Percentage,
            Description,
            RibaStageID
        )
        VALUES
        (
            1,
            @Guid,
            @InvoiceScheduleId,
            @OnDayOfMonth,
            @PeriodNumber,
            @Percentage,
            @Description,
            @RibaStageId
        );
    END;
    ELSE
    BEGIN
        UPDATE SFin.InvoiceSchedulePercentageConfiguration
        SET
            InvoiceScheduleId = @InvoiceScheduleId,
            OnDayOfMonth = @OnDayOfMonth,
            PeriodNumber = @PeriodNumber,
            Percentage = @Percentage,
            Description = @Description,
            RibaStageID = @RibaStageId
        WHERE Guid = @Guid
          AND RowStatus NOT IN (0,254);
    END;
END;
GO