SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_GetWorkflows] 
(
	@UserID INT
)
RETURNS TABLE 
AS
RETURN 
(
SELECT 
		root_hobt.ID,
		root_hobt.Guid,
		root_hobt.Name,
		root_hobt.Description,
		CASE WHEN root_hobt.Enabled = 1 THEN N'Yes' ELSE N'No' END AS Enabled,
		Et.Name AS EntityTypeID,
		CASE WHEN Org.Name = N'' THEN N'All' ELSE Org.Name END AS OrganisationalUnitId,
		root_hobt.RowStatus,
		root_hobt.RowVersion
	FROM 
		SCore.Workflow AS root_hobt 
	JOIN 
		SCore.Identities AS I ON (I.ID = @UserID)
	JOIN
		SCore.OrganisationalUnits AS Org ON (Org.ID = root_hobt.OrganisationalUnitId)
	JOIN 
		SCore.EntityTypes AS Et ON (Et.ID = root_hobt.EntityTypeID)
	WHERE 
		(root_hobt.RowStatus NOT IN (0,254)) AND
		(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (root_hobt.guid, @UserId) oscr
			)
		)

)
GO