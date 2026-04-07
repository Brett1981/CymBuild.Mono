SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_ContractType]
(
	@UserId INT
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS RETURN	
SELECT 
		ctrt.ID,
		ctrt.RowStatus,
		ctrt.RowVersion,
		ctrt.Guid,
		ctrt.Code,
		ctrt.Name,
		ctrt.IsActive
FROM    SSop.ContractTypes ctrt
WHERE   (ctrt.RowStatus NOT IN (0, 254))
	AND	(ctrt.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(ctrt.Guid, @UserId) oscr
			)
		)
GO