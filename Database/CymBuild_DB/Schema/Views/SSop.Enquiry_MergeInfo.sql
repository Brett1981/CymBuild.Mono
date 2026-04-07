SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[Enquiry_MergeInfo]
	--WITH SCHEMABINDING
AS
SELECT		e.ID,
			e.RowStatus,
			e.RowVersion,
			e.Guid AS ParentGuid,
			e.Guid AS Guid,
			e.Number																					 AS EnquiryNumber,
			e.ProposalLetter,
			e.DescriptionOfWorks,
			e.Date																						 AS EnquiryDate,
																																	/* UPRN */
			uprn.Number																					 AS UPRN,
			uprn.AddressLine1																			 AS PropertyAddressLine1,	-- was PropertyAddress1
			uprn.AddressLine2																			 AS PropertyAddressLine2,	-- was PropertyAddress2
			uprn.AddressLine3																			 AS PropertyAddressLine3,	-- was PropertyAddress3
			uprn.Town																					 AS PropertyTown,
			uprnc.Name																					 AS PropertyCounty,
			uprn.Postcode																				 AS PropertyPostcode,
			uprn.FormattedAddressComma																	 AS PropertyAddress,
			uprn.FormattedAddressCR																		 AS PropertyAddressBlock,
			COALESCE (	 uprn.Name + ' ',
						 ''
					 ) + COALESCE (	  uprn.Number + ' ',
									  ''
								  ) + uprn.AddressLine1													 AS PropertyShortAddress,
																																	/* Client */
			cacc.Name																					 AS ClientName,				-- was [Label] or [Title]
			cacc.CompanyRegistrationNumber																 AS ClientCompanyRegNo,
			cadd.AddressLine1																			 AS ClientAddressLine1,		-- was ClientAddress1
			cadd.AddressLine2																			 AS ClientAddressLine2,		-- was ClientAddress2
			cadd.AddressLine3																			 AS ClientAddressLine3,		-- was ClientAddress3
			cadd.Town																					 AS ClientTown,
			caddc.Name																					 AS ClientCounty,
			cadd.Postcode																				 AS ClientPostcode,
			cadd.FormattedAddressComma																	 AS ClientAddress,			-- was AddressClient
			cadd.FormattedAddressCR																		 AS ClientAddressBlock,
			ccon.DisplayName																			 AS ClientContactName,
			ccon.FirstName																				 AS ClientFirstName,
			ccon.Surname																				 AS ClientSurname,
			ccon.Email																					 AS ClientEmail,
			ccon.Phone																					 AS ClientPhone,
			ccon.Mobile																					 AS ClientMobile,
			aacc.Name																					 AS AgentName,				-- was [Label] or [Title]
			aacc.CompanyRegistrationNumber																 AS AgentCompanyRegNo,
			aadd.AddressLine1																			 AS AgentAddressLine1,		-- was ClientAddress1
			aadd.AddressLine2																			 AS AgentAddressLine2,		-- was ClientAddress2
			aadd.AddressLine3																			 AS AgentAddressLine3,		-- was ClientAddress3
			aadd.Town																					 AS AgentTown,
			aaddc.Name																					 AS AgentCounty,
			aadd.Postcode																				 AS AgentPostcode,
			aadd.FormattedAddressComma																	 AS AgentAddress,			-- was AddressClient
			aadd.FormattedAddressCR																		 AS AgentAddressBlock,
			acon.DisplayName																			 AS AgentContactName,
			acon.FirstName																				 AS AgentFirstName,
			acon.Surname																				 AS AgentSurname,
			acon.Email																					 AS AgentEmail,
			acon.Phone																					 AS AgentPhone,
			acon.Mobile																					 AS AgentMobile,

			facc.Name																					 AS FinanceName,				-- was [Label] or [Title]
			facc.CompanyRegistrationNumber																 AS FinanceCompanyRegNo,
			fadd.AddressLine1																			 AS FinanceAddressLine1,		-- was ClientAddress1
			fadd.AddressLine2																			 AS FinanceAddressLine2,		-- was ClientAddress2
			fadd.AddressLine3																			 AS FinanceAddressLine3,		-- was ClientAddress3
			fadd.Town																					 AS FinanceTown,
			faddc.Name																					 AS FinanceCounty,
			fadd.Postcode																				 AS FinancePostcode,
			fadd.FormattedAddressComma																	 AS FinanceAddress,			-- was AddressClient
			fadd.FormattedAddressCR																		 AS FinanceAddressBlock,
			fcon.DisplayName																			 AS FinanceContactName,
			fcon.FirstName																				 AS FinanceFirstName,
			fcon.Surname																				 AS FinanceSurname,
			fcon.Email																					 AS FinanceEmail,
			fcon.Phone																					 AS FinancePhone,
			fcon.Mobile																					 AS FinanceMobile,

			CASE
				WHEN e.SendInfoToClient = 1 THEN cacc.Name
				ELSE aacc.Name
			END																							 AS RecipientName,			-- was [Label] or [Title]
			CASE
				WHEN e.SendInfoToClient = 1 THEN cacc.CompanyRegistrationNumber
				ELSE aacc.CompanyRegistrationNumber
			END																							 AS RecipientCompanyRegNo,
			CASE
				WHEN e.SendInfoToClient = 1 THEN cadd.AddressLine1
				ELSE aadd.AddressLine1
			END																							 AS RecipientAddressLine1,	-- was ClientAddress1
			CASE
				WHEN e.SendInfoToClient = 1 THEN cadd.AddressLine2
				ELSE aadd.AddressLine2
			END																							 AS RecipientAddressLine2,	-- was ClientAddress2
			CASE
				WHEN e.SendInfoToClient = 1 THEN cadd.AddressLine3
				ELSE aadd.AddressLine3
			END																							 AS RecipientAddressLine3,	-- was ClientAddress3
			CASE
				WHEN e.SendInfoToClient = 1 THEN cadd.Town
				ELSE aadd.Town
			END																							 AS RecipientTown,
			CASE
				WHEN e.SendInfoToClient = 1 THEN caddc.Name
				ELSE aaddc.Name
			END																							 AS RecipientCounty,
			CASE
				WHEN e.SendInfoToClient = 1 THEN cadd.Postcode
				ELSE aadd.Postcode
			END																							 AS RecipientPostcode,
			CASE
				WHEN e.SendInfoToClient = 1 THEN cadd.FormattedAddressComma
				ELSE aadd.FormattedAddressComma
			END																							 AS RecipientAddress,		-- was AddressClient
			CASE
				WHEN e.SendInfoToClient = 1 THEN cadd.FormattedAddressCR
				ELSE aadd.FormattedAddressCR
			END																							 AS RecipientAddressBlock,
			CASE
				WHEN e.SendInfoToClient = 1 THEN ccon.DisplayName
				ELSE acon.DisplayName
			END																							 AS RecipientContactName,
			CASE
				WHEN e.SendInfoToClient = 1 THEN ccon.FirstName
				ELSE acon.FirstName
			END																							 AS RecipientFirstName,
			CASE
				WHEN e.SendInfoToClient = 1 THEN ccon.Surname
				ELSE ccon.Surname
			END																							 AS RecipientSurname,
			CASE
				WHEN e.SendInfoToClient = 1 THEN ccon.Email
				ELSE ccon.Email
			END																							 AS RecipientEmail,
			CASE
				WHEN e.SendInfoToClient = 1 THEN ccon.Phone
				ELSE ccon.Phone
			END																							 AS RecipientPhone,
			CASE
				WHEN e.SendInfoToClient = 1 THEN ccon.Mobile
				ELSE ccon.Mobile
			END																							 AS RecipientMobile,

																																	/* Company */
			offa.Name																					 AS OfficialName,
			offa.AddressLine1																			 AS OfficialAddressLine1,
			offa.AddressLine2																			 AS OfficialAddressLine2,
			offa.AddressLine3																			 AS OfficialAddressLine3,
			offa.Town																					 AS OfficialTown,
			offac.Name																					 AS OfficialCounty,
			offa.Postcode																				 AS OfficialPostcode,
			offcon.Email																				 AS OfficialEmail,
			offcon.Phone																				 AS OfficialPhone,
			offcon.Mobile																				 AS OfficialMobile,


																																	/* Signatory */
			sigconm.Email																				 AS SignatorytEmail,
			sig.FullName																					 AS SignatoryName,
			sig.FullName + N' ' + COALESCE (	  sigcon.PostNominals,
											  ''
										  )																 AS SignatoryPostNominals,
			sigcon.Initials																				 AS SignatoryInitials,
			sig.JobTitle																					 AS SignatoryJobTitle,
			Disciplines.TotalFee,

			aacc.Name					AS AgentAccountName,
			aacd.DisplayName			AS AgentContact,
			aaca.AddressLine1			AS AgentAddressLineOne,
			aaca.AddressLine2			AS AgentAddressLineTwo,
			aaca.AddressLine3			AS AgentAddressLineThree,
			

			facc.Name					AS ClientAccountName,
			cacd.DisplayName			AS ClientContact,
			caca.AddressLine1			AS ClientAddressLineOne,
			caca.AddressLine2			AS ClientAddressLineTwo,
			caca.AddressLine3			AS ClientAddressLineThree
			


FROM		SSop.Enquiries				  AS e
JOIN		SCore.OrganisationalUnits AS lead_ou ON (lead_ou.ID = e.OrganisationalUnitID)
LEFT JOIN		SCrm.Contact_MergeInfo	  AS offcon ON (offcon.ID = lead_ou.OfficialContactId)
LEFT JOIN		SCrm.Addresses			  AS offa ON (offa.ID = lead_ou.OfficialAddressId)
JOIN		SCrm.Counties			  AS offac ON (offac.ID = offa.CountyID)
JOIN		SJob.Assets			  AS uprn ON (uprn.ID = e.PropertyId)
JOIN		SCrm.Counties			  AS uprnc ON (uprnc.ID = uprn.CountyId)
JOIN		SCrm.Accounts			  AS cacc ON (cacc.ID = e.ClientAccountId)
JOIN		SCrm.AccountAddresses	  AS caad ON (caad.ID = e.ClientAddressId)
JOIN		SCrm.Addresses			  AS cadd ON (cadd.ID = caad.AddressID)
JOIN		SCrm.AccountContacts	  AS cac ON (cac.ID = e.ClientAccountContactId)
JOIN		SCrm.Contact_MergeInfo	  AS ccon ON (ccon.ID = cac.ContactID)
JOIN		SCrm.Counties			  AS caddc ON (caddc.ID = cadd.CountyID)
JOIN		SCrm.Accounts			  AS aacc ON (aacc.ID = e.AgentAccountId)
JOIN		SCrm.AccountAddresses	  AS aaad ON (aaad.ID = e.AgentAddressId)
JOIN		SCrm.Addresses			  AS aadd ON (aadd.ID = aaad.AddressID)
JOIN		SCrm.AccountContacts	  AS aac ON (aac.ID = e.AgentAccountContactId)
JOIN		SCrm.Contact_MergeInfo	  AS acon ON (acon.ID = aac.ContactID)
JOIN		SCrm.Counties			  AS aaddc ON (aaddc.ID = aadd.CountyID)
JOIN		SCrm.Accounts			  AS facc ON (facc.ID = e.ClientAccountId)
JOIN		SCrm.AccountAddresses	  AS faad ON (faad.ID = e.ClientAddressId)
JOIN		SCrm.Addresses			  AS fadd ON (fadd.ID = caad.AddressID)
JOIN		SCrm.AccountContacts	  AS fac ON (fac.ID = e.ClientAccountContactId)
JOIN		SCrm.Contact_MergeInfo	  AS fcon ON (fcon.ID = cac.ContactID)
JOIN		SCrm.Counties			  AS faddc ON (faddc.ID = cadd.CountyID)
JOIN		SCore.Identities		  AS sig ON (sig.ID = e.SignatoryIdentityId)
LEFT JOIN	SCrm.Contacts			  AS sigcon ON (sigcon.ID = sig.ContactId)
LEFT JOIN	SCrm.Contact_MergeInfo	  AS sigconm ON (sigconm.ID = sigcon.ID)
JOIN		Scrm.Addresses	 AS aaca ON (aaca.ID = aaad.AddressID)
JOIN		SCrm.Contacts	 AS aacd ON (aacd.ID = aac.ContactID)
JOIN		SCrm.Contacts	 AS cacd ON (cacd.ID = cac.ContactID)
JOIN		Scrm.Addresses	 AS caca ON (caca.ID = caad.AddressID)
OUTER APPLY (
	SELECT	SUM(esei.QuoteNet) AS TotalFee
	FROM	SSop.EnquiryServices AS es
	JOIN	SSop.EnquiryService_ExtendedInfo AS esei ON (esei.id = es.id)
	WHERE	(es.RowStatus NOT IN (0, 254))
		AND	(es.EnquiryId = e.ID)
		
) Disciplines 
		
		

GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'Enquiry Merge Fields', 'SCHEMA', N'SSop', 'VIEW', N'Enquiry_MergeInfo'
GO