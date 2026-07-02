SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_QuoteTemplates]')
GO
CREATE FUNCTION [SSop].[tvf_QuoteTemplates]
(
	@UserId INT
)
RETURNS TABLE
                  --WITH SCHEMABINDING
AS RETURN	
SELECT  qt.ID,
        qt.RowStatus,
        qt.RowVersion,
        qt.Guid,
		qt.Number,
		LEFT(qt.Overview, 200) AS Details,
		ou.Name AS Department,
		ou2.Name AS OrganisationalUnit
FROM    SSop.QuoteTemplates qt
JOIN SCore.OrganisationalUnits AS ou ON qt.OrganisationalUnitID = ou.ID
JOIN SCore.OrganisationalUnits AS ou2 ON ou.ParentID = ou2.ID
WHERE   (qt.RowStatus NOT IN (0, 254))
	AND	(qt.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(qt.Guid, @UserId) oscr
			)
		)
GO