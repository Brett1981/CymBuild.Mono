SET QUOTED_IDENTIFIER, ANSI_NULLS ON
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
		p.CreatedJobType
FROM    SProd.Products p
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