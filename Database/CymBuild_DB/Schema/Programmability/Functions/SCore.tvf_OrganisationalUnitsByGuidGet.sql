SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_OrganisationalUnitsByGuidGet]
	(
		@OrgUnitGuid NVARCHAR(100)
	)
RETURNS TABLE
               --WITH SCHEMABINDING
AS
RETURN SELECT		ou.RowStatus,
					ou.RowVersion,
					ou.Guid,
					ou.Name,
					ou.ID,
					ou.IsDivision,
					ou.IsBusinessUnit,
					ou.IsDepartment,
					ou.IsTeam,
					ou2.Guid AS ParentOrganisationalUnitGuid
	   FROM			SCore.OrganisationalUnits ou
	   JOIN			SCore.OrganisationalUnits ou2 ON(ou.ParentID = ou2.ID)
	   --WHERE        (ou.RowStatus NOT IN (0, 254)) AND ou.Name = @OrgUnitGuid;
	   WHERE		(ou.RowStatus NOT IN (0, 254)) AND ou.Guid = @OrgUnitGuid;
GO