SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_ContactTitles]
(
	@UserId INT
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS RETURN	
SELECT  ct.ID,
        ct.RowStatus,
        ct.RowVersion,
        ct.Guid,
		ct.Name
FROM    SCrm.ContactTitles ct
OUTER APPLY SCore.ObjectSecurityForUser(ct.Guid, @UserId) os
WHERE   (ct.RowStatus NOT IN (0, 254))
	AND	(ct.ID > 0)
	AND	(os.CanRead = 1)
GO