SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SJob].[tvf_AssetClientProjects]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
          --WITH SCHEMABINDING
AS RETURN	
SELECT	p.ID,
		p.RowStatus,
		p.RowVersion,
		p.Guid,
		p.Number,
		p.ProjectDescription,
		p.ExternalReference
FROM    SSop.Projects p
JOIN	SJob.Jobs AS j ON (j.ProjectId = p.ID)
JOIN    Assets AS uprn ON (j.UprnID = uprn.ID)
WHERE   (p.RowStatus NOT IN (0, 254))
	AND	(uprn.Guid = @ParentGuid)
	AND	(EXISTS
			(					
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(p.Guid, @UserId) oscr
			)
		)
GO