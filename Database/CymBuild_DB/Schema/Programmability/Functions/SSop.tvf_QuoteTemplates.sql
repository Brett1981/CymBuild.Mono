SET QUOTED_IDENTIFIER, ANSI_NULLS ON
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
		LEFT(qt.Overview, 200) AS Details
FROM    SSop.QuoteTemplates qt
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