SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SProd].[tvf_Products]')
GO
CREATE FUNCTION [SProd].[tvf_Products]
(
	@UserId INT
)
RETURNS TABLE
                  --WITH SCHEMABINDING
AS RETURN	
SELECT  p.ID,
        p.RowStatus,
        p.RowVersion,
        p.Guid,
        p.Code,
        p.Description,
		p.Code + N' - ' + p.Description AS ListName,
		p.CreatedJobType,
		ou.Name AS Department,
		ou2.Name AS BusinessUnit
FROM    SProd.Products p
JOIN	SJob.JobTypes AS jt ON (jt.ID = p.CreatedJobType)
JOIN	SCore.OrganisationalUnits AS ou ON jt.OrganisationalUnitID = ou.ID
JOIN	SCore.OrganisationalUnits as ou2 ON ou.ParentID = ou2.ID
WHERE   (p.RowStatus NOT IN (0, 254))
	AND	(p.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(p.Guid, @UserId) oscr
			)
		)
GO