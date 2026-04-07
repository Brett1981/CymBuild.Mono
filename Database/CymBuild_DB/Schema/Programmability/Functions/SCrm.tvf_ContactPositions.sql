SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_ContactPositions]
(
	@UserId INT
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS RETURN	
SELECT  cp.ID,
        cp.RowStatus,
        cp.RowVersion,
        cp.Guid,
		cp.Name
FROM    SCrm.ContactPositions cp
WHERE   (cp.RowStatus NOT IN (0, 254))
	AND	(cp.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(cp.Guid, @UserId) oscr
			)
		)
GO