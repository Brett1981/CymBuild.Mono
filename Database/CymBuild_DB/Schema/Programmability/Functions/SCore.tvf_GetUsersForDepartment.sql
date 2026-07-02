SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_GetUsersForDepartment]
	(
		@DepartmentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
--WITH SCHEMABINDING
AS
RETURN 
SELECT 
		i.FullName,
		i.ID,
		i.Guid,
		i.EmailAddress,
		i.JobTitle,
		i.BillableRate,
		i.Signature
	FROM SCore.Identities i 
	JOIN SCore.OrganisationalUnits org ON (org.ID = i.OriganisationalUnitId)
	WHERE 
			(org.RowStatus NOT IN (0,254))
		AND (i.RowStatus NOT IN (0,254))
		AND (org.Guid = @DepartmentGuid)
		
GO