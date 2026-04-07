SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCrm].[tvf_Contacts]
(
	@UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS RETURN	
SELECT  c.ID,
        c.RowStatus,
        c.RowVersion,
        c.Guid,
		c.DisplayName,
		acc.Name AS PrimaryAccount,
		Email.Value AS Email,
		Mobile.Value AS Mobile,
		Office.Value AS Office,
		ad.FormattedAddressCR AS PrimaryAddress
FROM    SCrm.Contacts c
JOIN	SCrm.Accounts acc ON (acc.ID = c.PrimaryAccountID)
JOIN	SCrm.Addresses ad ON (ad.ID = c.PrimaryAddressID)
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
WHERE   (c.RowStatus NOT IN (0, 254))
	AND	(c.ID > 0)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (c.guid, @UserId) oscr
			)
		)
GO