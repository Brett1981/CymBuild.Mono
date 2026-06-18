SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceScheduleMonthConfigurationDelete]')
GO

CREATE PROCEDURE [SFin].[InvoiceScheduleMonthConfigurationDelete]
	@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	
	IF(EXISTS
       (
           SELECT 1
           FROM SCore.DataObjects
           WHERE Guid = @Guid
       ))
	   BEGIN 
			EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier

					UPDATE	[SFin].[InvoiceScheduleMonthConfiguration]
					SET		RowStatus = 254
					WHERE	(Guid = @Guid)
	   END
END;
GO