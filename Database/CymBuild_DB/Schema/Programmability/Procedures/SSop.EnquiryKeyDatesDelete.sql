SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE PROCEDURE [SSop].[EnquiryKeyDatesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	SSop.EnquiryKeyDates
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO