SET QUOTED_IDENTIFIER, ANSI_NULLS ON
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
		p.ProjectDescription
FROM    SSop.Projects p
WHERE   (p.RowStatus NOT IN (0, 254))
	AND	(p.ID > 0)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (p.guid, @UserId) oscr
			)
		)
GO