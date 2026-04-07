SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_AccountContracts]
(
	@UserId INT,
	@ParentGuid uniqueidentifier
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS RETURN	
SELECT  c.ID,
        c.RowStatus,
        c.RowVersion,
        c.Guid,
		c.StartDate,
		c.EndDate,
		LEFT(c.Details, 200) AS Details
FROM    SSop.Contracts c
JOIN	SCrm.Accounts acc ON (acc.ID = c.AccountID)
WHERE   (c.RowStatus NOT IN (0, 254))
	AND	(c.ID > 0)
	AND	(acc.Guid = @ParentGuid)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(c.Guid, @UserId) oscr
			)
		)
GO