SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SFin].[InvoiceRequestsDelete]
	@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	
	IF(EXISTS
       (
           SELECT 1
           FROM SFin.TransactionDetails td
           INNER JOIN SFin.InvoiceRequestItems iri ON (iri.ID = td.InvoiceRequestItemId)
		   INNER JOIN SFin.InvoiceRequests ir ON (ir.ID = iri.InvoiceRequestId)
           WHERE (iri.InvoiceRequestId = ir.ID) AND ir.Guid = @Guid
       ))
	   BEGIN 
			;THROW 60000, N'Cannot Delete Completed Invoice Requests.', 1
			RETURN
	   END
	   --ELSE
		  -- BEGIN

					EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier

					UPDATE	SFin.InvoiceRequests
					SET		RowStatus = 254
					WHERE	(Guid = @Guid)

		   --END;
END;
GO