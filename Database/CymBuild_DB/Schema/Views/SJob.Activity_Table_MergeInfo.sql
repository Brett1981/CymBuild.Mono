SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SJob].[Activity_Table_MergeInfo]
AS
SELECT		a.ID,																	-- was [Job ID]
			a.RowStatus,
			a.RowVersion,
			a.Guid,
			j.Guid AS ParentGuid,
			i.FullName									AS SurveyorName,
			atype.Name									AS ActivityType,
			a.Date										AS ActivityStartDate,
			a.EndDate									AS ActivityEndDate,
			a.Title										AS ActivityTitle,
			a.Notes										AS ActivityNotes
FROM		SJob.Activities			  AS a
JOIN		SJob.ActivityTypes		  AS atype ON (atype.ID = a.ActivityTypeID)
JOIN		SJob.Jobs				  AS j ON (j.ID			  = a.JobID)
JOIN		SJob.JobTypes			  AS jt ON (jt.ID		  = j.JobTypeID)
JOIN		SCore.OrganisationalUnits AS ou ON (ou.ID		  = j.OrganisationalUnitID)
JOIN		SCrm.Contact_MergeInfo	  AS offcon ON (offcon.ID = ou.OfficialContactId)
JOIN		SCrm.Addresses			  AS offa ON (offa.ID	  = ou.OfficialAddressId)
JOIN		SCrm.Counties			  AS offac ON (offac.ID	  = offa.CountyID)
JOIN		SJob.Assets			  AS uprn ON (uprn.ID	  = j.UprnID)
JOIN		SCrm.Counties			  AS paddc ON (paddc.ID	  = uprn.CountyId)
JOIN		SCrm.Accounts			  AS cacc ON (cacc.ID	  = j.ClientAccountID)
JOIN		SCrm.AccountAddresses	  AS caal ON (caal.ID	  = j.ClientAddressID)
JOIN		SCrm.Addresses			  AS cadd ON (cadd.ID	  = caal.AddressID)
JOIN		SCrm.AccountContacts	  AS cconl ON (cconl.ID	  = j.ClientContactID)
JOIN		SCrm.Contact_MergeInfo	  AS ccon ON (ccon.ID	  = cconl.ContactID)
JOIN		SCrm.Counties			  AS caddc ON (caddc.ID	  = cadd.CountyID)
JOIN		SCrm.Accounts			  AS aacc ON (aacc.ID	  = j.AgentAccountID)
JOIN		SCrm.AccountAddresses	  AS aaal ON (aaal.ID	  = j.AgentAddressID)
JOIN		SCrm.Addresses			  AS aadd ON (aadd.ID	  = aaal.AddressID)
JOIN		SCrm.AccountContacts	  AS aconl ON (aconl.ID	  = j.AgentContactID)
JOIN		SCrm.Contact_MergeInfo	  AS acon ON (acon.ID	  = aconl.ContactID)
JOIN		SCrm.Counties			  AS aaddc ON (aaddc.ID	  = aadd.CountyID)
JOIN		SCore.Identities		  AS i ON (i.ID			  = a.SurveyorID)
LEFT JOIN	SCrm.Contacts			  AS icon ON (icon.ID	  = i.ContactId)
LEFT JOIN	SCrm.Contact_MergeInfo	  AS iconm ON (iconm.ID	  = icon.ID)
LEFT JOIN	SCrm.Accounts			  AS la ON (la.ID		  = uprn.LocalAuthorityAccountID);
GO