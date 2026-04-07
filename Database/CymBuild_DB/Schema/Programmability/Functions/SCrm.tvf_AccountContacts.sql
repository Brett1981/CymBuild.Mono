SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_AccountContacts]
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS RETURN	
SELECT  ac.ID,
        ac.RowStatus,
        ac.RowVersion,
        ac.Guid,
		c.DisplayName,
		cp.Name AS Position,
		Email.Value AS Email,
		Mobile.Value AS Mobile,
		Office.Value AS Office
FROM    SCrm.AccountContacts ac
JOIN    SCrm.Contacts c ON (c.ID = ac.ContactID)
JOIN	SCrm.Accounts acc ON (acc.ID = ac.AccountID)
JOIN	SCrm.ContactPositions cp ON (cp.ID = c.PositionID)
OUTER APPLY (
	SELECT	cd.Value
	FROM	SCrm.ContactDetails cd
	JOIN	SCrm.ContactDetailTypes cdt ON (cdt.ID = cd.ContactDetailTypeID)
	WHERE	(cdt.Name = N'E-Mail')
		AND	(cd.ContactID = c.ID)
		AND	(cd.RowStatus NOT IN (0, 254))
) as Email
OUTER APPLY (
	SELECT	cd.Value
	FROM	SCrm.ContactDetails cd
	JOIN	SCrm.ContactDetailTypes cdt ON (cdt.ID = cd.ContactDetailTypeID)
	WHERE	(cdt.Name = N'Mobile')
		AND	(cd.ContactID = c.ID)
		AND	(cd.RowStatus NOT IN (0, 254))
) as Mobile
OUTER APPLY (
	SELECT	cd.Value
	FROM	SCrm.ContactDetails cd
	JOIN	SCrm.ContactDetailTypes cdt ON (cdt.ID = cd.ContactDetailTypeID)
	WHERE	(cdt.Name = N'Office')
		AND	(cd.ContactID = c.ID)
		AND	(cd.RowStatus NOT IN (0, 254))
) as Office
WHERE   (ac.RowStatus NOT IN (0, 254))
	AND	(ac.ID > 0)
	AND	(acc.Guid = @ParentGuid)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(ac.Guid, @UserId) oscr
			)
		)
GO