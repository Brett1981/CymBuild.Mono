SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SCore].[GetCurrentUserGuid]')
GO

CREATE FUNCTION [SCore].[GetCurrentUserGuid]
	()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN

	RETURN ISNULL (   CONVERT (   UNIQUEIDENTIFIER,
													   SESSION_CONTEXT (N'user_guid')
												   ),
										   '00000000-0000-0000-0000-000000000000'
									   )
						


END;
GO