SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SSop].[Quote_MergeInfo]
AS
SELECT		q.ID,
			q.RowStatus,
			q.RowVersion,
			q.Guid,
			q.Number																					 AS QuoteNumber,
			e.DescriptionOfWorks																		 AS QuoteOverview,
			q.Date																						 AS QuoteDate,
			q.FeeCap,
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
			CASE
				WHEN q.SendInfoToClient = 1 THEN cacc.Name
				ELSE aacc.Name
			END																							 AS RecipientName,			-- was [Label] or [Title]
			CASE
				WHEN q.SendInfoToClient = 1 THEN cacc.CompanyRegistrationNumber
				ELSE aacc.CompanyRegistrationNumber
			END																							 AS RecipientCompanyRegNo,
			CASE
				WHEN q.SendInfoToClient = 1 THEN cadd.AddressLine1
				ELSE aadd.AddressLine1
			END																							 AS RecipientAddressLine1,	-- was ClientAddress1
			CASE
				WHEN q.SendInfoToClient = 1 THEN cadd.AddressLine2
				ELSE aadd.AddressLine2
			END																							 AS RecipientAddressLine2,	-- was ClientAddress2
			CASE
				WHEN q.SendInfoToClient = 1 THEN cadd.AddressLine3
				ELSE aadd.AddressLine3
			END																							 AS RecipientAddressLine3,	-- was ClientAddress3
			CASE
				WHEN q.SendInfoToClient = 1 THEN cadd.Town
				ELSE aadd.Town
			END																							 AS RecipientTown,
			CASE
				WHEN q.SendInfoToClient = 1 THEN caddc.Name
				ELSE aaddc.Name
			END																							 AS RecipientCounty,
			CASE
				WHEN q.SendInfoToClient = 1 THEN cadd.Postcode
				ELSE aadd.Postcode
			END																							 AS RecipientPostcode,
			CASE
				WHEN q.SendInfoToClient = 1 THEN cadd.FormattedAddressComma
				ELSE aadd.FormattedAddressComma
			END																							 AS RecipientAddress,		-- was AddressClient
			CASE
				WHEN q.SendInfoToClient = 1 THEN cadd.FormattedAddressCR
				ELSE aadd.FormattedAddressCR
			END																							 AS RecipientAddressBlock,
			CASE
				WHEN q.SendInfoToClient = 1 THEN ccon.DisplayName
				ELSE acon.DisplayName
			END																							 AS RecipientContactName,
			CASE
				WHEN q.SendInfoToClient = 1 THEN ccon.FirstName
				ELSE acon.FirstName
			END																							 AS RecipientFirstName,
			CASE
				WHEN q.SendInfoToClient = 1 THEN ccon.Surname
				ELSE ccon.Surname
			END																							 AS RecipientSurname,
			CASE
				WHEN q.SendInfoToClient = 1 THEN ccon.Email
				ELSE ccon.Email
			END																							 AS RecipientEmail,
			CASE
				WHEN q.SendInfoToClient = 1 THEN ccon.Phone
				ELSE ccon.Phone
			END																							 AS RecipientPhone,
			CASE
				WHEN q.SendInfoToClient = 1 THEN ccon.Mobile
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
																																	/* Fee Drawdown*/
			DrawDown.Stage1Net,
			DrawDown.Stage2Net,
			DrawDown.Stage3Net,
			DrawDown.Stage4Net,
			DrawDown.Stage5Net,
			DrawDown.Stage6Net,
			DrawDown.Stage7Net,
			DrawDown.PreConstruction,
			DrawDown.Construction,
			DrawDown.Stage1Net + DrawDown.Stage2Net + DrawDown.Stage3Net + DrawDown.Stage4Net + DrawDown.Stage5Net
			+ DrawDown.Stage6Net + DrawDown.Stage7Net + DrawDown.PreConstruction + DrawDown.Construction AS TotalNetFees,

																																	/* Quoting User */
			quconm.Email																				 AS QuotingUserEmail,
			qu.FullName																					 AS QuotingUserName,
			qu.FullName + N' ' + COALESCE (	  qucon.PostNominals,
											  ''
										  )																 AS QuotingUserPostNominals,
			qucon.Initials																				 AS QuotingUserInitials,
			qu.JobTitle																					 AS QuotingUserJobTitle,
			qcconm.Email																				 AS QuotingConsultantEmail,
			qc.FullName																					 AS QuotingConsultantName,
			qc.FullName + N' ' + COALESCE (	  qccon.PostNominals,
											  ''
										  )																 AS QuotingConsultantPostNominals,
			qccon.Initials																				 AS QuotingConsultantInitials,
			qc.JobTitle																					 AS QuotingConsultantJobTitle,

			aacc.Name				AS AgentAccountName,
			aacon.DisplayName		AS AgentContact,
			aaconadd.AddressLine1   AS AgentAddressLineOne,
			aaconadd.AddressLine2   AS AgentAddressLineTwo,
			aaconadd.AddressLine3   AS AgentAddressLineThree,
			aaconadd.Postcode		AS AgentPostcode,
		    
			cacc.Name				AS ClientAccountName,
			cacon.DisplayName       AS ClientContact,
			caconadd.AddressLine1   AS ClientAddressLineOne,
			caconadd.AddressLine2   AS ClientAddressLineTwo,
			caconadd.AddressLine3   AS ClientAddressLineThree
		


FROM		SSop.Quotes				  AS q
JOIN		SSop.EnquiryServices	  AS es ON (es.ID = q.EnquiryServiceID)
JOIN		SSop.Enquiries			  AS e ON (e.ID = es.EnquiryId)
JOIN		SCore.OrganisationalUnits AS ou ON (ou.ID = q.OrganisationalUnitID)
JOIN		SCrm.Contact_MergeInfo	  AS offcon ON (offcon.ID = ou.OfficialContactId)
JOIN		SCrm.Addresses			  AS offa ON (offa.ID = ou.OfficialAddressId)
JOIN		SCrm.Counties			  AS offac ON (offac.ID = offa.CountyID)
JOIN		SJob.Assets			  AS uprn ON (uprn.ID = e.PropertyId)
JOIN		SCrm.Counties			  AS uprnc ON (uprnc.ID = uprn.CountyId)
JOIN		SCrm.Accounts			  AS cacc ON (cacc.ID = e.ClientAccountId)
JOIN		SCrm.AccountAddresses	  AS caad ON (caad.ID = e.ClientAddressId)
JOIN		SCrm.Addresses			  AS cadd ON (cadd.ID = caad.AddressID)
JOIN		SCrm.AccountContacts	  AS cac ON (cac.ID = e.ClientAccountContactId)
JOIN		SCrm.Contact_MergeInfo	  AS ccon ON (ccon.ID = cac.ContactID)
JOIN		SCrm.Counties			  AS caddc ON (caddc.ID = cadd.CountyID)
JOIN		SCore.Identities		  AS qu ON (qu.ID = q.QuotingUserId)
JOIN		SCrm.Accounts			  AS aacc ON (aacc.ID = e.AgentAccountId)
JOIN		SCrm.AccountAddresses	  AS aaad ON (aaad.ID = e.AgentAddressId)
JOIN		SCrm.Addresses			  AS aadd ON (aadd.ID = aaad.AddressID)
JOIN		SCrm.AccountContacts	  AS aac ON (aac.ID = e.AgentAccountContactId)
JOIN		SCrm.Contact_MergeInfo	  AS acon ON (acon.ID = aac.ContactID)
JOIN		SCrm.Counties			  AS aaddc ON (aaddc.ID = aadd.CountyID)
LEFT JOIN	SCrm.Contacts			  AS qucon ON (qucon.ID = qu.ContactId)
LEFT JOIN	SCrm.Contact_MergeInfo	  AS quconm ON (quconm.ID = qucon.ID)
JOIN		SCore.Identities		  AS qc ON (qc.ID = q.QuotingConsultantId)
LEFT JOIN	SCrm.Contacts			  AS qccon ON (qccon.ID = qc.ContactId)
LEFT JOIN	SCrm.Contact_MergeInfo	  AS qcconm ON (qcconm.ID = qccon.ID)
JOIN        SCrm.Contacts	  AS aacon ON (aacon.ID = aac.ContactID)
JOIN		SCrm.Addresses    AS aaconadd ON (aaconadd.ID = aaad.AddressID)
JOIN        SCrm.Contacts	  AS cacon ON (cacon.ID = cac.ContactID)
JOIN		SCrm.Addresses    AS caconadd ON (caconadd.ID = caad.AddressID)
OUTER APPLY
			(
				SELECT	ID,
						ISNULL (   [1],
								   0
							   ) AS Stage1Net,
						ISNULL (   [2],
								   0
							   ) AS Stage2Net,
						ISNULL (   [3],
								   0
							   ) AS Stage3Net,
						ISNULL (   [4],
								   0
							   ) AS Stage4Net,
						ISNULL (   [5],
								   0
							   ) AS Stage5Net,
						ISNULL (   [6],
								   0
							   ) AS Stage6Net,
						ISNULL (   [7],
								   0
							   ) AS Stage7Net,
						ISNULL (   [99],
								   0
							   ) AS PreConstruction,
						ISNULL (   [999],
								   0
							   ) AS Construction
				FROM
						(
							SELECT	ID,
									Stage,
									Quoted
							FROM	SSop.tvf_QuoteFeeDrawdown (	  q.QuotingUserId,
																  q.Guid
															  )
						) AS d
				PIVOT
					(
						MIN(Quoted)
						FOR Stage IN ([1], [2], [3], [4], [5], [6], [7], [99], [999])
					) AS qfd
			)						  AS DrawDown;
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'Quote Merge Fields', 'SCHEMA', N'SSop', 'VIEW', N'Quote_MergeInfo'
GO