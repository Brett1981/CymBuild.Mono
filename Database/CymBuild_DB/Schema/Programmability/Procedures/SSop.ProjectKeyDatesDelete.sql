SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SSop].[ProjectKeyDatesDelete]')
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