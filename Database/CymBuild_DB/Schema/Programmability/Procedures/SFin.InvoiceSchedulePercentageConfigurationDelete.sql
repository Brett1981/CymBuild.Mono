SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceSchedulePercentageConfigurationDelete]')
GO

CREATE PROCEDURE [SFin].[InvoiceSchedulePercentageConfigurationDelete]
    @Guid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM SCore.DataObjects AS d
        WHERE d.Guid = @Guid
    )
    BEGIN
        EXEC SCore.DeleteDataObject
            @Guid = @Guid;

        UPDATE [SFin].[InvoiceSchedulePercentageConfiguration]
        SET RowStatus = 254
        WHERE Guid = @Guid
          AND RowStatus NOT IN (0,254);
    END
END;
GO