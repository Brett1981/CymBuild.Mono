SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SSop].[EnquiryServicesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN

	IF (EXISTS
			(
				SELECT	1
				FROM	SSop.Quotes AS q 
				JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
				WHERE	(es.Guid = @Guid)
					AND	(q.RowStatus <> 254)
			)
		)
	BEGIN 
		;THROW 60000, N'You cannot delete an Enquiry Service that has been converted to a Quote.', 1
	END

	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SSop.EnquiryServices
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO