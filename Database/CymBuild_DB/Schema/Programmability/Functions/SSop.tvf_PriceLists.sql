SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_PriceLists]
(
	@UserId INT
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS RETURN	
SELECT  pl.ID,
        pl.RowStatus,
        pl.RowVersion,
        pl.Guid,
		pl.Name
FROM    SSop.PriceLists pl
WHERE   (pl.RowStatus NOT IN (0, 254))
	AND	(pl.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(pl.Guid, @UserId) oscr
			)
		)
GO