SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO







CREATE PROCEDURE [SSop].[ProjectKeyDatesDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	pkd
	SET		RowStatus = 254
	FROM	SSop.ProjectKeyDates pkd 
	WHERE	(pkd.Guid = @Guid)
	

END;

GO