SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SJob].[Job_MergeInfo] 
AS SELECT
        j.ID,																												-- was [Job ID]
        j.RowStatus,
        j.RowVersion,
		j.Guid,
        j.Guid  AS ParentGuid,
        'Job ID: ' + CONVERT(NVARCHAR(8),
        j.Number
        )                                                                                        AS JobIDString,			-- was [JobID]
        j.Number                                                                                 AS JobNumber,				-- was [Job Number]
        j.JobDescription,																									-- was [Job Title]
        jt.Name                                                                                  AS JobType,				-- was Type,
        j.ClientAppointmentReceived,
        j.AgreedFee,
        j.RibaStage1Fee,
        j.RibaStage2Fee,
        j.RibaStage3Fee,
        j.RibaStage4Fee,
        j.RibaStage5Fee,
        j.RibaStage6Fee,
        j.RibaStage7Fee,
        j.PreConstructionStageFee,
        j.ConstructionStageFee,
        j.AgreedFee + j.RibaStage1Fee + j.RibaStage2Fee + j.RibaStage3Fee + j.RibaStage4Fee + j.RibaStage5Fee
        + j.RibaStage6Fee + j.RibaStage7Fee + j.PreConstructionStageFee + j.ConstructionStageFee AS TotalNetFee,
        /* UPRN */
        uprn.Number                                                                              AS UPRN,
        uprn.AddressLine1                                                                        AS PropertyAddressLine1,	-- was PropertyAddress1
        uprn.AddressLine2                                                                        AS PropertyAddressLine2,	-- was PropertyAddress2
        uprn.AddressLine3                                                                        AS PropertyAddressLine3,	-- was PropertyAddress3
        uprn.Town                                                                                AS PropertyTown,
        paddc.Name                                                                               AS PropertyCounty,
        uprn.Postcode                                                                            AS PropertyPostcode,
        uprn.FormattedAddressComma                                                               AS PropertyAddress,
        uprn.FormattedAddressCR                                                                  AS PropertyAddressBlock,
        COALESCE(uprn.Name + ' ',
        ''
        ) + COALESCE(uprn.Number + ' ',
        ''
        ) + uprn.AddressLine1                                                                    AS PropertyShortAddress,
        la.Name                                                                                  AS LocalAuthority,
        /* Client */
        cacc.Name                                                                                AS ClientName,				-- was [Label] or [Title]
        cacc.CompanyRegistrationNumber                                                           AS ClientCompanyRegNo,
        cadd.AddressLine1                                                                        AS ClientAddressLine1,		-- was ClientAddress1
        cadd.AddressLine2                                                                        AS ClientAddressLine2,		-- was ClientAddress2
        cadd.AddressLine3                                                                        AS ClientAddressLine3,		-- was ClientAddress3
        cadd.Town                                                                                AS ClientTown,
        caddc.Name                                                                               AS ClientCounty,
        cadd.Postcode                                                                            AS ClientPostcode,
        cadd.FormattedAddressComma                                                               AS ClientAddress,			-- was AddressClient
        cadd.FormattedAddressCR                                                                  AS ClientAddressBlock,
        ccon.DisplayName                                                                         AS ClientContactName,
        ccon.FirstName                                                                           AS ClientFirstName,
        ccon.Surname                                                                             AS ClientSurname,
        ccon.Email                                                                               AS ClientEmail,
        ccon.Phone                                                                               AS ClientPhone,
        ccon.Mobile                                                                              AS ClientMobile,
        /* Agent */
        aacc.Name                                                                                AS AgentName,
        aacc.CompanyRegistrationNumber                                                           AS AgentCompanyRegNo,
        aadd.AddressLine1                                                                        AS AgentAddressLine1,
        aadd.AddressLine2                                                                        AS AgentAddressLine2,
        aadd.AddressLine3                                                                        AS AgentAddressLine3,
        aadd.Town                                                                                AS AgentTown,
        aaddc.Name                                                                               AS AgentCounty,
        aadd.Postcode                                                                            AS AgentPostcode,
        aadd.FormattedAddressComma                                                               AS AgentAddress,
        aadd.FormattedAddressCR                                                                  AS AgentAddressBlock,
        acon.DisplayName                                                                         AS AgentContactName,
        acon.FirstName                                                                           AS AgentFirstName,
        acon.Surname                                                                             AS AgentSurname,
        acon.Email                                                                               AS AgentEmail,
        acon.Phone                                                                               AS AgentPhone,
        acon.Mobile                                                                              AS AgentMobile,
        /* Company */
        offa.Name                                                                                AS OfficialName,
        offa.AddressLine1                                                                        AS OfficialAddressLine1,
        offa.AddressLine2                                                                        AS OfficialAddressLine2,
        offa.AddressLine3                                                                        AS OfficialAddressLine3,
        offa.Town                                                                                AS OfficialTown,
        offac.Name                                                                               AS OfficialCounty,
        offa.Postcode                                                                            AS OfficialPostcode,
        offcon.Email                                                                             AS OfficialEmail,
        offcon.Phone                                                                             AS OfficialPhone,
        offcon.Mobile                                                                            AS OfficialMobile,
        /* Surveyor */
        iconm.Email                                                                              AS SurveyorEmail,
        i.FullName                                                                               AS SurveyorName,
        i.FullName + N' ' + COALESCE(icon.PostNominals,
        ''
        )                                                                                        AS SurveyorPostNominals,
        icon.Initials                                                                            AS SurveyorInitials,
        i.JobTitle                                                                               AS SurveyorJobTitle,

		--BRAC
		i.FullName																				 AS LeadConsultant,
		aacc.Name																				 AS AgentAccountName,
		aadd.AddressLine1																		 AS AgentAddressLineOne,
		aadd.AddressLine2																		 AS AgentAddressLineTwo,
		aadd.AddressLine3																		 AS AgentAddressLineThree,
		acon.DisplayName																		 AS AgentContact,
																								 
		cadd.AddressLine1																		 AS ClientAddressLineOne,		
        cadd.AddressLine2																		 AS ClientAddressLineTwo,		
        cadd.AddressLine3																		 AS ClientAddressLineThree,	
		ccon.DisplayName																		 AS ClientContact
FROM
        SJob.Jobs AS j
JOIN
        SJob.JobTypes AS jt ON (jt.ID = j.JobTypeID)
JOIN
        SCore.OrganisationalUnits AS ou ON (ou.ID = j.OrganisationalUnitID)
JOIN
        SCrm.Contact_MergeInfo AS offcon ON (offcon.ID = ou.OfficialContactId)
JOIN
        SCrm.Addresses AS offa ON (offa.ID = ou.OfficialAddressId)
JOIN
        SCrm.Counties AS offac ON (offac.ID = offa.CountyID)
JOIN
        SJob.Assets AS uprn ON (uprn.ID = j.UprnID)
JOIN
        SCrm.Counties AS paddc ON (paddc.ID = uprn.CountyId)
JOIN
        SCrm.Accounts AS cacc ON (cacc.ID = j.ClientAccountID)
JOIN
        SCrm.AccountAddresses AS caal ON (caal.ID = j.ClientAddressID)
JOIN
        SCrm.Addresses AS cadd ON (cadd.ID = caal.AddressID)
JOIN
        SCrm.AccountContacts AS cconl ON (cconl.ID = j.ClientContactID)
JOIN
        SCrm.Contact_MergeInfo AS ccon ON (ccon.ID = cconl.ContactID)
JOIN
        SCrm.Counties AS caddc ON (caddc.ID = cadd.CountyID)
JOIN
        SCrm.Accounts AS aacc ON (aacc.ID = j.AgentAccountID)
JOIN
        SCrm.AccountAddresses AS aaal ON (aaal.ID = j.AgentAddressID)
JOIN
        SCrm.Addresses AS aadd ON (aadd.ID = aaal.AddressID)
JOIN
        SCrm.AccountContacts AS aconl ON (aconl.ID = j.AgentContactID)
JOIN
        SCrm.Contact_MergeInfo AS acon ON (acon.ID = aconl.ContactID)
JOIN
        SCrm.Counties AS aaddc ON (aaddc.ID = aadd.CountyID)
JOIN
        SCore.Identities AS i ON (i.ID = j.SurveyorID)
LEFT JOIN
        SCrm.Contacts AS icon ON (icon.ID = i.ContactId)
LEFT JOIN
        SCrm.Contact_MergeInfo AS iconm ON (iconm.ID = icon.ID)
LEFT JOIN
        SCrm.Accounts AS la ON (la.ID = uprn.LocalAuthorityAccountID)
GO