SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create function [SJob].[tvf_PurchaseOrders]')
GO

CREATE FUNCTION [SJob].[tvf_PurchaseOrders]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
          --WITH SCHEMABINDING
AS RETURN	
SELECT  
		root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Number,
		root_hobt.Description,
		riba.Description AS StageId,
		asset.Name AS SiteId,
		act.Title AS ActivityId,
		root_hobt.Value,
		root_hobt.DateReceived,
		root_hobt.ValidUntilDate
FROM    SJob.PurchaseOrders as root_hobt
JOIN	SJob.Jobs AS j ON (j.ID = root_hobt.JobId)
JOIN	SJob.RibaStages as riba ON (riba.ID = root_hobt.StageId)
JOIN    SJob.Assets as asset ON (asset.ID = root_hobt.SiteId)
JOIN    SJob.Activities AS act ON (act.ID = root_hobt.ActivityId)
WHERE   (root_hobt.RowStatus NOT IN (0, 254))
	AND	(root_hobt.ID > 0)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (root_hobt.guid, @UserId) oscr
			)
		)
GO