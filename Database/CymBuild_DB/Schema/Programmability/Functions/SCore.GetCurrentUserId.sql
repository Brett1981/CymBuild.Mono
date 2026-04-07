SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SCore].[GetCurrentUserId]
	()
RETURNS INT
AS
BEGIN

	RETURN  ISNULL( CONVERT (   INT,
													   SESSION_CONTEXT (N'user_id')
												   ),
										   -1
									   )



END;
GO