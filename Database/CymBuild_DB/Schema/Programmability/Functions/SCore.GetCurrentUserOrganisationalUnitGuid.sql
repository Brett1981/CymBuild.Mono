SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE FUNCTION [SCore].[GetCurrentUserOrganisationalUnitGuid]
	()
RETURNS UNIQUEIDENTIFIER
AS
BEGIN

	RETURN
		 (
			 SELECT		TOP (1) ou.Guid
			 FROM		SCore.Identities AS i
			 JOIN		SCore.OrganisationalUnits ou ON (ou.ID = i.OriganisationalUnitId)
			 WHERE		(i.ID = ISNULL (   CONVERT (   INT,
													   SESSION_CONTEXT (N'user_id')
												   ),
										   -1
									   )
						)
			 ORDER BY	i.ID
		 );


END;
GO