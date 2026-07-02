SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SSop].[tvf_Projects]')
GO
CREATE FUNCTION [SSop].[tvf_Projects]
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
		p.Number,
		p.ExternalReference, 
		p.ProjectDescription,
		org.Name AS Department,
		org2.Name AS BusinessUnit
FROM    SSop.Projects p
JOIN SSop.Enquiries AS e ON (p.ID = e.ProjectId)
JOIN SCore.OrganisationalUnits AS org ON (org.ID = e.OrganisationalUnitID) 
JOIN SCore.OrganisationalUnits AS org2 ON (org2.ID = org.ParentID)
WHERE   (p.RowStatus NOT IN (0, 254))
	AND	(p.ID > 0)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (p.guid, @UserId) oscr
			)
		)
GO