SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_OrganisationalUnitsGet]
	(
		@UserId INT
	)
RETURNS TABLE
               --WITH SCHEMABINDING
AS
RETURN SELECT		ou.RowStatus,
					ou.RowVersion,
					ou.Guid,
					ou.Name,
					ou.ID,
					ou2.Guid AS ParentOrganisationalUnitGuid
	   FROM			SCore.OrganisationalUnits ou
	   JOIN			SCore.OrganisationalUnits ou2 ON(ou.ParentID = ou2.ID)
	   OUTER APPLY	SCore.ObjectSecurityForUser(ou.Guid, @UserId) os
	   WHERE		(ou.RowStatus NOT IN (0, 254));
GO