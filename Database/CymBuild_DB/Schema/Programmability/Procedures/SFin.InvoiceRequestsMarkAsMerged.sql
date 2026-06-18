SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SFin].[InvoiceRequestsMarkAsMerged]')
GO

CREATE PROCEDURE [SFin].[InvoiceRequestsMarkAsMerged]
	@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	 SET NOCOUNT ON;

    UPDATE SFin.InvoiceRequests
    SET IsMerged = 1
    WHERE [Guid] = @Guid;
END;
GO