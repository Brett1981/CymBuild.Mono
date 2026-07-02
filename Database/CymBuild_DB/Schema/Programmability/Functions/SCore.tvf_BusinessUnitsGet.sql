SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_BusinessUnitsGet]
	(
		@UserId INT
	)
RETURNS TABLE
--WITH SCHEMABINDING
AS
RETURN 
	SELECT DISTINCT
		org2.Name AS BusinessUnit,
		org2.ID,
		org2.Guid,
		org2.RowStatus,
		org2.RowVersion
	FROM SCore.OrganisationalUnits org 
	JOIN SCore.OrganisationalUnits org2 ON (org.ParentID = org2.ID)
	
	WHERE 
			(org.RowStatus NOT IN (0,254))
		AND EXISTS
		(
			SELECT 1
			FROM SCore.ObjectSecurityForUser_CanRead(org.Guid, @UserId) AS oscr
		)
GO