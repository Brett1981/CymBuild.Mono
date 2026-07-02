SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_DepartmentsGet]
	(
		@UserId INT,
		@BusinessUnitGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
--WITH SCHEMABINDING
AS
RETURN 
SELECT DISTINCT
		org.Name AS Department,
		org.ID,
		org.Guid,
		org.RowStatus,
		org.RowVersion
	FROM SCore.OrganisationalUnits org 
	JOIN SCore.OrganisationalUnits org2 ON (org.ParentID = org2.ID)
	
	WHERE 
			(org.RowStatus NOT IN (0,254))
		AND (org2.Guid =  @BusinessUnitGuid)
		AND EXISTS
			(
				SELECT 1
				FROM SCore.ObjectSecurityForUser_CanRead(org.Guid, @UserId) AS oscr
			)
GO