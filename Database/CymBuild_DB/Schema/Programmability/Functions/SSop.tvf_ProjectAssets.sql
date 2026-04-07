SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SSop].[tvf_ProjectAssets]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
          --WITH SCHEMABINDING
AS RETURN	
SELECT  
		asset.ID,
		asset.Guid,
		asset.RowStatus,
		asset.RowVersion,
		asset.Number,
		asset.FormattedAddressComma
FROM	SJob.Assets AS asset
JOIN	SJob.Jobs AS j ON (j.UprnID = asset.ID)
JOIN	SSop.Projects AS p ON (p.ID = j.ProjectId)
WHERE   (j.RowStatus NOT IN (0, 254))
	AND	(p.Guid = @ParentGuid)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)
GO