SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SCrm].[Contact_MergeInfo]
	--WITH SCHEMABINDING
AS
	SELECT
			c.ID,
			c.Guid,
			c.Guid AS ParentGuid,
			c.RowStatus,
			c.RowVersion,
			c.DisplayName,
			c.FirstName,
			c.Surname,
			DefaultEmail.Value  AS Email,
			DefaultPhone.Value  AS Phone,
			DefaultMobile.Value AS Mobile
	FROM
			SCrm.Contacts c
	OUTER APPLY
			(
				SELECT
						cd.Value
				FROM
						SCrm.ContactDetails cd
				JOIN
						SCrm.ContactDetailTypes cdt ON (cdt.ID = cd.ContactDetailTypeID)
				WHERE
						(cd.ContactID = c.ID)
						AND (cdt.Name = N'E-Mail')
						AND (cd.IsDefault = 1)
			) AS DefaultEmail
	OUTER APPLY
			(
				SELECT
						cd.Value
				FROM
						SCrm.ContactDetails cd
				JOIN
						SCrm.ContactDetailTypes cdt ON (cdt.ID = cd.ContactDetailTypeID)
				WHERE
						(cd.ContactID = c.ID)
						AND (cdt.Name = N'Office')
						AND (cd.IsDefault = 1)
			) AS DefaultPhone
	OUTER APPLY
			(
				SELECT
						cd.Value
				FROM
						SCrm.ContactDetails cd
				JOIN
						SCrm.ContactDetailTypes cdt ON (cdt.ID = cd.ContactDetailTypeID)
				WHERE
						(cd.ContactID = c.ID)
						AND (cdt.Name = N'Mobile')
						AND (cd.IsDefault = 1)
			) AS DefaultMobile
GO