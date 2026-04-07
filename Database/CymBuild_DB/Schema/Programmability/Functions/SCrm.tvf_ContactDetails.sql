SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_ContactDetails]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS RETURN	
SELECT  cd.ID,
        cd.RowStatus,
        cd.RowVersion,
        cd.Guid,
		cdt.Name AS DetailTypeName,
		cd.Name,
		cd.Value
FROM    SCrm.ContactDetails cd
JOIN	SCrm.ContactDetailTypes cdt ON (cdt.ID = cd.ContactDetailTypeID)
JOIN	SCrm.Contacts c ON (c.ID = cd.ContactID)
WHERE   (cd.RowStatus NOT IN (0, 254))
	AND	(cd.ID > 0)
	AND	(c.Guid = @ParentGuid)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(cd.Guid, @UserId) oscr
			)
		)
GO