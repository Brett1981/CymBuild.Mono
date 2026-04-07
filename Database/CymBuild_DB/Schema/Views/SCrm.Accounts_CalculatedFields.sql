SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCrm].[Accounts_CalculatedFields]
	    --WITH SCHEMABINDING
AS
SELECT	a.ID,
		a.Guid,
		a.RowStatus,
		a.RowVersion,
		ad.FormattedAddressCR MainAddress,
		phone.Value AS MainPhone,
		email.Value AS MainEmail
FROM	SCrm.Accounts a
JOIN	SCrm.AccountAddresses aa ON (aa.ID = a.MainAccountAddressId)
JOIN	SCrm.Addresses ad ON (ad.ID = aa.AddressID)
JOIN	SCrm.AccountContacts ac ON (ac.Id = a.MainAccountContactId)
JOIN	SCrm.Contacts c ON (c.ID = ac.ContactID)
OUTER APPLY 
(
	SELECT	cd.Value 
	FROM	SCrm.ContactDetails cd 
	JOIN	SCrm.ContactDetailTypes cdt ON (cdt.ID = cd.ContactDetailTypeID)
	WHERE	(cd.ContactID = c.ID)
		AND	(cdt.Name = N'Office')
		AND	(
				(cd.IsDefault = 1)
			OR	(NOT EXISTS
					(
						SELECT	1
						FROM	SCrm.ContactDetails cd2
						WHERE	(cd2.ContactDetailTypeID = cdt.ID)
							AND	(cd2.ContactID = c.ID)
							AND	(cd2.ID <> cd.ID)
							AND	(cd2.RowStatus NOT IN (0, 254))
					)
				)
			)
) AS Phone
OUTER APPLY 
(
	SELECT	cd.Value 
	FROM	SCrm.ContactDetails cd 
	JOIN	SCrm.ContactDetailTypes cdt ON (cdt.ID = cd.ContactDetailTypeID)
	WHERE	(cd.ContactID = c.ID)
		AND	(cdt.Name = N'E-Mail')
		AND	(
				(cd.IsDefault = 1)
			OR	(NOT EXISTS
					(
						SELECT	1
						FROM	SCrm.ContactDetails cd2
						WHERE	(cd2.ContactDetailTypeID = cdt.ID)
							AND	(cd2.ContactID = c.ID)
							AND	(cd2.ID <> cd.ID)
							AND	(cd2.RowStatus NOT IN (0, 254))
					)
				)
			)
) AS Email

	
GO