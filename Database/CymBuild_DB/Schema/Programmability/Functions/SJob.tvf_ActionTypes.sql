SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[tvf_ActionTypes] 
(
    @UserId INT
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN 
SELECT  root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.SortOrder
FROM    SJob.ActionTypes root_hobt
WHERE   (root_hobt.RowStatus  NOT IN (0, 254))
	AND	(root_hobt.Id > 0)
GO