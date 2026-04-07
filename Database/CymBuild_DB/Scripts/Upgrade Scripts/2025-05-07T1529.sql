/*
Script created by SQL Prompt version 10.16.11.16409 from Red Gate Software Ltd at 07/05/2025 15:28:20
Run this script on Concursus_Dev to perform the Smart Rename refactoring.

Please back up your database before running this script.
*/
-- Summary for the smart rename:
--
-- Action:
-- Drop foreign key [FK_Properties_Accounts] from table [SJob].[Properties]
-- Drop foreign key [FK_Properties_Accounts1] from table [SJob].[Properties]
-- Drop foreign key [FK_Properties_Accounts2] from table [SJob].[Properties]
-- Drop foreign key [FK_Properties_Accounts3] from table [SJob].[Properties]
-- Drop foreign key [FK_Properties_Counties] from table [SJob].[Properties]
-- Drop foreign key [FK_Properties_Countries] from table [SJob].[Properties]
-- Drop foreign key [FK_Properties_DataObjects] from table [SJob].[Properties]
-- Drop foreign key [FK_Properties_Properties] from table [SJob].[Properties]
-- Drop foreign key [FK_Properties_RowStatus] from table [SJob].[Properties]
-- Drop foreign key [FK_Jobs_Properties] from table [SJob].[Jobs]
-- Drop foreign key [FK_Enquiries_Properties] from table [SSop].[Enquiries]
-- Drop foreign key [FK_Quotes_Properties] from table [SSop].[Quotes]
-- Rename table [SJob].[Assets]
-- Refresh view [SJob].[JobStatus]
-- Alter function [SJob].[tvf_AllActiveF10]
-- Refresh view [SJob].[JobMilestoneMetric]
-- Refresh view [SJob].[JobFinance]
-- Alter view [SJob].[Jobs_DWETL]
-- Refresh view [SSop].[EnquiryService_ExtendedInfo]
-- Alter view [SJob].[Activity_Table_MergeInfo]
-- Refresh view [SJob].[GetJobSignatoryInfo]
-- Refresh view [SSop].[Quote_JobsSummary]
-- Alter view [SSop].[Quotes_DWETL]
-- Refresh view [SSop].[EnquiryService_DDL]
-- Refresh view [SSop].[Quote_ExtendedInfo]
-- Alter view [SSop].[Enquiry_MergeInfo]
-- Refresh view [SSop].[EnquiryService_MergeInfo]
-- Refresh view [SSop].[Enquiry_CalculatedFields]
-- Alter function [SSop].[tvf_Enquiries]
-- Alter procedure [SFin].[TransactionDetailsUpsert]
-- Refresh view [SSop].[QuoteItems_MergeInfo]
-- Alter function [SJob].[tvf_Properties]
-- Refresh view [SJob].[Job_FeeDrawdown]
-- Alter function [SSop].[tvf_OpenEnquiries]
-- Alter procedure [SSop].[QuotesUpsert]
-- Alter procedure [SJob].[JobsUpsert]
-- Alter procedure [SSop].[QuoteCreateJobs]
-- Refresh view [SSop].[Quote_CalculatedFields]
-- Alter function [SSop].[tvf_CurrentQuotes]
-- Alter function [SJob].[tvf_CurrentJobs]
-- Alter function [SJob].[tvf_Jobs_CDM_MyProjects]
-- Alter procedure [SJob].[PropertiesUpsert]
-- Alter procedure [SSop].[EnquiryCreateQuotes]
-- Alter function [SJob].[tvf_Property_DataPills]
-- Alter function [SSop].[tvf_Enquiry_DataPills]
-- Refresh view [SSop].[Project_ExtendedInfo]
-- Alter function [SJob].[tvf_Jobs]
-- Refresh view [SJob].[JobPaymentStages_List]
-- Alter procedure [SSop].[EnquiriesUpsert]
-- Alter function [SSop].[tvf_EnquiriesForQuoteReview]
-- Alter function [SSop].[tvf_QuotesReadyToSend]
-- Alter view [SSop].[Quote_MergeInfo]
-- Alter function [SSop].[tvf_ProjectEnquiries]
-- Alter function [SSop].[tvf_ProjectQuotes]
-- Alter view [SJob].[Jobs_Read]
-- Refresh view [SSop].[ScheduleOfClientInfo_MergeInfo]
-- Alter function [SJob].[tvf_PropertyEnquiries]
-- Refresh view [SSop].[EnquiryAcceptanceServices_MergeInfo]
-- Alter function [SCrm].[tvf_AccountEnquiries]
-- Alter view [SJob].[Activity_MergeInfo]
-- Alter function [SJob].[tvf_Jobs_OverdueMilestones]
-- Alter view [SJob].[Job_MergeInfo]
-- Refresh view [SJob].[Job_CDMMergeInfo]
-- Alter function [SSop].[tvf_QuotesNotIssued]
-- Alter function [SSop].[tvf_QuotesSentNoResponse]
-- Alter function [SJob].[tvf_Jobs_IncompleteActivities]
-- Alter function [SJob].[tvf_Jobs_Dormant]
-- Alter function [SJob].[tvf_Jobs_TeamDormant]
-- Alter function [SSop].[tvf_Quotes]
-- Alter function [SJob].[tvf_PropertyQuotes]
-- Alter function [SJob].[tvf_PropertyJobs]
-- Alter procedure [SFin].[InvoiceRequestCreateInvoice]
-- Refresh view [SJob].[Job_ExtendedInfo]
-- Alter function [SJob].[CurrentScheduledWork]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Assets]
-- Add foreign key to [SJob].[Jobs]
-- Add foreign key to [SSop].[Enquiries]
-- Add foreign key to [SSop].[Quotes]
-- Disable foreign key [FK_Properties_DataObjects] on table [SJob].[Assets]
-- Alter trigger [SJob].[tg_Properties_RecordHistory] on [SJob].[Assets]
--
-- No warnings
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO
BEGIN TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping foreign keys from [SJob].[Properties]'
GO
ALTER TABLE [SJob].[Properties] DROP CONSTRAINT [FK_Properties_Accounts]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Properties] DROP CONSTRAINT [FK_Properties_Accounts1]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Properties] DROP CONSTRAINT [FK_Properties_Accounts2]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Properties] DROP CONSTRAINT [FK_Properties_Accounts3]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Properties] DROP CONSTRAINT [FK_Properties_Counties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Properties] DROP CONSTRAINT [FK_Properties_Countries]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Properties] DROP CONSTRAINT [FK_Properties_DataObjects]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Properties] DROP CONSTRAINT [FK_Properties_Properties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [SJob].[Properties] DROP CONSTRAINT [FK_Properties_RowStatus]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping foreign keys from [SJob].[Jobs]'
GO
ALTER TABLE [SJob].[Jobs] DROP CONSTRAINT [FK_Jobs_Properties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping foreign keys from [SSop].[Enquiries]'
GO
ALTER TABLE [SSop].[Enquiries] DROP CONSTRAINT [FK_Enquiries_Properties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Dropping foreign keys from [SSop].[Quotes]'
GO
ALTER TABLE [SSop].[Quotes] DROP CONSTRAINT [FK_Quotes_Properties]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
EXEC sp_rename N'[SJob].[Properties]', N'Assets', N'OBJECT'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[JobStatus]'
GO
EXEC sp_refreshview N'[SJob].[JobStatus]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_AllActiveF10]'
GO

ALTER FUNCTION SJob.tvf_AllActiveF10
	(
		@UserId INT
	)

RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN SELECT		j.ID,
					j.RowStatus,
					j.Guid,
					j.RowVersion,
					i.FullName,
					j.Number,
					j.JobDescription,
					p.FormattedAddressComma,
					m.StartDateTimeUTC,
					ISNULL (   m.DueDateTimeUTC,
							   m.ScheduledDateTimeUTC
						   ) AS NextAction,
					m.Reference,
					js.JobStatus
	   FROM			SJob.Jobs					  AS j
	   JOIN			SJob.JobStatus				  AS js ON (js.ID = j.ID)
	   JOIN			SCore.Identities			  AS i ON (i.ID = j.SurveyorID)
	   JOIN			SJob.Milestones				  AS m ON (m.JobID = j.ID)
	   JOIN			SJob.MilestoneTypes			  AS mt ON (mt.ID = m.MilestoneTypeID)
	   JOIN			SJob.Assets				  AS p ON (p.ID = j.UprnID)
	   WHERE		(mt.Name = N'F10')
				AND (m.RowStatus NOT IN (0, 254))
				AND (m.StartDateTimeUTC IS NOT NULL)
				AND	(j.IsComplete = 0)
				AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[JobMilestoneMetric]'
GO
EXEC sp_refreshview N'[SJob].[JobMilestoneMetric]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[JobFinance]'
GO
EXEC sp_refreshview N'[SJob].[JobFinance]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[Jobs_DWETL]'
GO








ALTER VIEW SJob.Jobs_DWETL
	        --WITH SCHEMABINDING
AS
SELECT	j.ID,
		j.OrganisationalUnitID,
		ou.Name AS OUName,
		j.ClientAccountID,
		j.AgentAccountID,
		j.SurveyorID,
		ISNULL(jf.InvoicedValue, 0) InvoicedValue,
		jt.Name AS JobType,
		CONVERT(DATE, j.JobStarted) RegisteredDate,
		CONVERT(DATE, j.JobCompleted) CompletedDate,
		j.AgreedFee + j.RibaStage1Fee + j.RibaStage2Fee + j.RibaStage3Fee + j.RibaStage4Fee + j.RibaStage5Fee + j.RibaStage6Fee + j.ConstructionStageFee + j.PreConstructionStageFee AS OriginalQuotedValue,
		j.AgreedFee + j.RibaStage1Fee + j.RibaStage2Fee + j.RibaStage3Fee + j.RibaStage4Fee + j.RibaStage5Fee + j.RibaStage6Fee + j.ConstructionStageFee + j.PreConstructionStageFee + ISNULL(FeeAmendment.Total, 0) AS ActualQuotedValue,
		PhysicalInspections.Cnt AS PhysicalInspections,
		TotalInspections.Cnt AS TotalInspections,
		j.Number,
		c.Name AS County,
		p.Postcode
FROM	SJob.Jobs j
JOIN	SJob.JobStatus js ON (js.ID = j.ID)
JOIN	SJob.JobFinance jf ON (jf.ID = j.ID)
JOIN	SCore.Identities i ON (i.ID = j.SurveyorID)
JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
JOIN	SJob.Assets AS p ON (p.ID = j.UprnID)
JOIN	SCrm.Counties AS c ON (c.ID = p.CountyId)
JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID = j.OrganisationalUnitID)
OUTER APPLY	
(
	SELECT	COUNT(1) AS Cnt
	FROM	SJob.Activities a
	JOIN	SJob.ActivityStatus stat ON (stat.ID = a.ActivityStatusID)
	JOIN	SJob.ActivityTypes atype ON (atype.ID = a.ActivityTypeID)
	WHERE	(j.id = a.JobID)
		AND	(stat.Name = N'Complete')
		AND	(atype.IsSiteVisit = 1)
		AND	(a.RowStatus NOT IN (0, 254))
) AS PhysicalInspections
OUTER APPLY	
(
	SELECT	COUNT(1) AS Cnt
	FROM	SJob.Activities a
	JOIN	SJob.ActivityStatus stat ON (stat.ID = a.ActivityStatusID)
	JOIN	SJob.ActivityTypes atype ON (atype.ID = a.ActivityTypeID)
	WHERE	(j.id = a.JobID)
		AND	(stat.Name = N'Complete')
		AND	(a.RowStatus NOT IN (0, 254))
) AS TotalInspections
OUTER APPLY	
(
	SELECT	SUM(fa.RibaStage0Change + fa.RibaStage2Change + fa.RibaStage3Change + fa.RibaStage4Change + fa.RibaStage5Change + fa.RibaStage6Change + fa.RibaStage7Change + fa.ConstructionStageChange + fa.PreConstructionStageChange) AS Total
	FROM	SJob.FeeAmendment fa
	WHERE	(fa.JobID = j.Id)
		AND	(fa.RowStatus NOT IN (0, 254))
) AS FeeAmendment
WHERE	(j.JobCancelled IS NULL)
	AND	(
			(EXISTS
				(
					SELECT	1
					FROM	SCore.RecordHistory rh
					WHERE	(rh.RowGuid = j.Guid)
						AND	(rh.Datetime > DATEADD(MONTH, -1, GETDATE()))
				)
			)
			OR
			(EXISTS
				(
					SELECT	1
					FROM	SCore.RecordHistory rh
					WHERE	(rh.RowGuid = j.Guid)
						AND	(rh.Datetime > DATEADD(MONTH, -1, GETDATE()))
						AND	(EXISTS
								(
									SELECT	1
									FROM	SJob.Activities a
									WHERE	(a.JobID = j.ID)
										AND	(a.Guid = rh.RowGuid)
								)
							)
				)
			)
			OR
			(EXISTS
				(
					SELECT	1
					FROM	SCore.RecordHistory rh
					WHERE	(rh.RowGuid = j.Guid)
						AND	(rh.Datetime > DATEADD(MONTH, -1, GETDATE()))
						AND	(EXISTS
								(
									SELECT	1
									FROM	SFin.Transactions t
									WHERE	(t.JobID = j.ID)
										AND	(t.Guid = rh.RowGuid)
								)
							)
				)
			)
		)

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[EnquiryService_ExtendedInfo]'
GO
EXEC sp_refreshview N'[SSop].[EnquiryService_ExtendedInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[Activity_Table_MergeInfo]'
GO




ALTER VIEW SJob.Activity_Table_MergeInfo
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[GetJobSignatoryInfo]'
GO
EXEC sp_refreshview N'[SJob].[GetJobSignatoryInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[Quote_JobsSummary]'
GO
EXEC sp_refreshview N'[SSop].[Quote_JobsSummary]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[Quotes_DWETL]'
GO



ALTER VIEW SSop.Quotes_DWETL
AS
SELECT	q.ID,
		q.QuotingConsultantId, 
		q.ClientAccountId, 
		q.AgentAccountId,
		uprn.CountyId,
		c.Name AS County,
		SUM(qst.Net) Net,
		q.DateSent AS Date,
		q.DateAccepted,
		q.DateRejected,
		ou.Name AS OrgUnit, 
		q.Number,
		MAX(CASE WHEN ISNULL(jt.Name, N'') <> N'' THEN jt.Name ELSE qjs.JobType END) AS JobType,
		q.QuotingUserId
FROM	SSop.Quotes q
JOIN	SSop.QuoteSections qs ON (qs.QuoteId = q.ID)
JOIN	SSop.QuoteSectionTotals qst ON (qst.ID = qs.ID)
JOIN	SSop.QuoteItems AS qi ON (qi.QuoteSectionId = qs.ID)
JOIN	SJob.Assets uprn ON (uprn.ID = q.UprnId)
JOIN	SCore.OrganisationalUnits ou ON (ou.ID = q.OrganisationalUnitID)
JOIN	SCrm.Counties c ON (c.ID = uprn.CountyId)
LEFT JOIN SSop.Quote_JobsSummary AS qjs ON (qjs.QuoteGuid = q.Guid)
LEFT JOIN SJob.Jobs AS j ON (j.ID = qi.CreatedJobId)
LEFT JOIN	SJob.JobTypes AS jt ON (jt.ID = j.JobTypeID)
WHERE	(q.DateSent IS NOT NULL)
GROUP BY q.Id, q.Number, q.QuotingUserId, q.QuotingConsultantId,  q.UprnId, q.ClientAccountId, q.AgentAccountId, uprn.CountyId, c.Name, q.datesent, q.DateRejected, q.DateAccepted, ou.Name




GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[EnquiryService_DDL]'
GO
EXEC sp_refreshview N'[SSop].[EnquiryService_DDL]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[Quote_ExtendedInfo]'
GO
EXEC sp_refreshview N'[SSop].[Quote_ExtendedInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[Enquiry_MergeInfo]'
GO





ALTER VIEW SSop.Enquiry_MergeInfo
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
			Disciplines.TotalFee
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
OUTER APPLY (
	SELECT	SUM(esei.QuoteNet) AS TotalFee
	FROM	SSop.EnquiryServices AS es
	JOIN	SSop.EnquiryService_ExtendedInfo AS esei ON (esei.id = es.id)
	WHERE	(es.RowStatus NOT IN (0, 254))
		AND	(es.EnquiryId = e.ID)
		
) Disciplines 
		
		

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[EnquiryService_MergeInfo]'
GO
EXEC sp_refreshview N'[SSop].[EnquiryService_MergeInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[Enquiry_CalculatedFields]'
GO
EXEC sp_refreshview N'[SSop].[Enquiry_CalculatedFields]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_Enquiries]'
GO





ALTER FUNCTION SSop.tvf_Enquiries
(
	@UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  e.ID,
        e.RowStatus,
        e.RowVersion,
        e.Guid,
		CASE WHEN e.Revision = 0 THEN e.Number ELSE (e.Number + N' (' + CONVERT(NVARCHAR(2), e.Revision) + N') ') END AS Number,
		e.ExternalReference,
		LEFT(e.DescriptionOfWorks, 200) AS DescriptionOfWorks, 
		CASE WHEN client.Name <> N'' THEN client.Name ELSE e.ClientName END + N' / ' + CASE WHEN agent.Name <> N'' THEN agent.Name ELSE e.AgentName END  AS ClientAgentAccount,
		CASE WHEN uprn.UPRN > 0 THEN uprn.FormattedAddressComma ELSE e.PropertyNameNumber + N' ' + e.PropertyAddressLine1 END AS Property,
		uprn.UPRN,
		ecf.EnquiryStatus,
		ISNULL(p.IsSubjectToNDA, e.IsSubjectToNDA) AS IsSubjectToNDA,
		CASE WHEN ServiceTypes.Name IS NULL THEN N'Multi Discipline' ELSE ServiceTypes.Name END AS Disciplines,
		org.Name AS OrgUnit,
		e.Date 
FROM    SSop.Enquiries e
JOIN	SSop.Enquiry_CalculatedFields AS ecf ON (ecf.ID = e.ID)
JOIN	SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountId)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
JOIN	SSop.Projects AS p ON (p.ID = e.ProjectId)
JOIN	SCore.OrganisationalUnits AS org ON (org.ID = e.OrganisationalUnitID)
OUTER APPLY (
	SELECT	jt.Name
	FROM	SJob.JobTypes AS jt
	JOIN	SSop.EnquiryServices AS es ON (es.JobTypeId = jt.ID)
	WHERE	(es.EnquiryId = e.ID)
		AND	(es.RowStatus NOT IN (0, 254))
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SSop.EnquiryServices es2 
					WHERE	(es2.ID <> es.ID)
						AND	(es2.EnquiryId = es.EnquiryId)
						AND	(es2.RowStatus NOT IN (0, 254))
				)
			)
) AS ServiceTypes
WHERE   (e.RowStatus NOT IN (0, 254))
	AND	(e.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
			)
		)

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SFin].[TransactionDetailsUpsert]'
GO






ALTER PROCEDURE SFin.TransactionDetailsUpsert
(
    @TransactionGuid UNIQUEIDENTIFIER,
	@MilestoneGuid UNIQUEIDENTIFIER,
	@ActivityGuid UNIQUEIDENTIFIER,
	@Net DECIMAL(9,2),
	@Vat DECIMAL(9,2),
	@Gross DECIMAL(9,2),
	@VatRate DECIMAL(9,2),
	@Description nvarchar(2000),
	@JobPaymentStageGuid UNIQUEIDENTIFIER,
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
    DECLARE @TransactionID INT,
			@MilestoneID INT,
			@ActivityId INT,
			@JobPaymentStageId INT

    SELECT  @TransactionID = ID 
    FROM    SFin.Transactions
    WHERE   ([Guid] = @TransactionGuid)

	SELECT  @MilestoneID = ID 
	FROM    SJob.Milestones
	WHERE   ([Guid] = @MilestoneGuid)

	SELECT  @ActivityId = ID 
	FROM    SJob.Activities
	WHERE   ([Guid] = @ActivityGuid)

	SELECT	@JobPaymentStageId = ID
	FROM	SJob.JobPaymentStages AS jps
	WHERE	([jps].[Guid] = @JobPaymentStageGuid)

	/* Check the values */
	IF (@Vat = 0)
	BEGIN 
		SET @Vat = @Net * (@VatRate / 100)
	END

	IF (@Gross = 0)
	BEGIN 
		SET @Gross = @Net + @Vat
	END

    DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SFin',				-- nvarchar(255)
							@ObjectName = N'TransactionDetails',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		DECLARE	@JobNumber NVARCHAR(2000),
				@JobDescription NVARCHAR(2000),
				@JobType NVARCHAR(2000),
				@UprnFormattedAddressComma NVARCHAR(2000)

		SELECT	@JobNumber = j.Number,
				@JobDescription = j.JobDescription,
				@JobType = jt.Name,
				@UprnFormattedAddressComma = p.FormattedAddressComma
		FROM	SJob.Jobs j
		JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
		JOIN	SJob.Assets p ON (p.ID = j.UprnID)
		JOIN	SFin.Transactions t ON (t.JobID = j.ID)
		WHERE	(t.Guid = @TransactionGuid)
		
		IF (@@ROWCOUNT > 0) 
		BEGIN 
			SET @Description = @Description + N'	
Our project ref.: ' + @JobNumber + N'
Project description: ' + @JobDescription + N'
Property: ' + @UprnFormattedAddressComma + N'
Appointed role: ' + @JobType
		END

		SET @Description = REPLACE(@Description, CHAR(34), CHAR(39))

		INSERT SFin.TransactionDetails
			 (RowStatus, Guid, TransactionID, MilestoneID, ActivityID, net, vat, Gross, VatRate, Description, JobPaymentStageId)
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @TransactionID,
				 @MilestoneID, 
				 @ActivityId, 
				 @Net, 
				 @Vat,
				 @Gross, 
				 @VatRate, 
				 @Description,
				 @JobPaymentStageId
			 )
    END
    ELSE
    BEGIN 
        UPDATE  SFin.TransactionDetails
        SET     MilestoneID = @MilestoneID,
				ActivityID = @ActivityId,
				Net = @Net,
				Vat = @Vat,
				Gross = @Gross,
				VatRate = @VatRate,
				Description = @Description,
				JobPaymentStageId = @JobPaymentStageId
        WHERE   ([Guid] = @Guid)
    END
END
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[QuoteItems_MergeInfo]'
GO
EXEC sp_refreshview N'[SSop].[QuoteItems_MergeInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_Properties]'
GO

ALTER FUNCTION SJob.tvf_Properties
	(
		@UserId INT
	)
RETURNS TABLE
       --WITH SCHEMABINDING
AS
RETURN SELECT		prop.ID,
					prop.RowStatus,
					prop.Guid,
					prop.UPRN,
					prop.FormattedAddressComma,
					prop.Name,
					la.Name AS LocalAuthority,
					oa.Name AS OwnerAccount
	   FROM			SJob.Assets				  AS prop
	   JOIN			SCrm.Accounts AS la ON (la.ID = prop.LocalAuthorityAccountID)
	   JOIN			SCrm.Accounts AS oa ON (oa.ID = prop.OwnerAccountID)
	   WHERE		(prop.ID > 0)
				AND (prop.RowStatus NOT IN (0, 254))
				AND	(EXISTS
			(
					SELECT
							1
					FROM
							SCore.ObjectSecurityForUser_CanRead(prop.Guid, @UserId) oscr
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[Job_FeeDrawdown]'
GO
EXEC sp_refreshview N'[SJob].[Job_FeeDrawdown]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_OpenEnquiries]'
GO








ALTER FUNCTION SSop.tvf_OpenEnquiries
(
	@UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  e.ID,
        e.RowStatus,
        e.RowVersion,
        e.Guid,
		e.Number,
		e.QuotingDeadlineDate,
		e.ExternalReference,
		LEFT(e.DescriptionOfWorks, 200) AS DescriptionOfWorks, 
		CASE WHEN client.Name <> N'' THEN client.Name ELSE e.ClientName END + N' / ' + CASE WHEN agent.Name <> N'' THEN agent.Name ELSE e.AgentName END  AS ClientAgentAccount,
		CASE WHEN uprn.UPRN > 0 THEN uprn.FormattedAddressComma ELSE e.PropertyNameNumber + N' ' + e.PropertyAddressLine1 END AS Property,
		ecf.EnquiryStatus
FROM    SSop.Enquiries e
JOIN	SSop.Enquiry_CalculatedFields AS ecf ON (ecf.ID = e.ID)
JOIN	SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountId)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
WHERE   (e.RowStatus NOT IN (0, 254))
	AND	(e.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
			)
		)
	AND	(e.DeclinedToQuoteDate IS NULL)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SSop.EnquiryServices es 
				WHERE	(es.EnquiryId = e.ID)
					AND	(es.RowStatus NOT IN (0, 254))
					AND	(es.QuoteId < 0)
			)
		)
	AND	(e.Date > DATEADD(MONTH, -6, GETDATE()))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[QuotesUpsert]'
GO






ALTER PROCEDURE SSop.QuotesUpsert
	(	@OrganisationalUnitGuid UNIQUEIDENTIFIER,
		@QuotingUserGuid UNIQUEIDENTIFIER,
		@ContractGuid UNIQUEIDENTIFIER,
		@Date DATE,
		@Overview NVARCHAR(MAX),
		@ExpiryDate DATE,
		@DateSent DATE,
		@DateAccepted DATE,
		@DateRejected DATE,
		@RejectionReason NVARCHAR(MAX),
		@FeeCap DECIMAL(19, 2),
		@IsFinal BIT,
		@ExternalReference NVARCHAR(50),
		@QuotingConsultantGuid UNIQUEIDENTIFIER,
		@AppointmentFromRibaStageGuid UNIQUEIDENTIFIER,
		@CurrentStageGuid UNIQUEIDENTIFIER,
		@DeadDate DATE,
		@EnquiryServiceGuid UNIQUEIDENTIFIER,
		@ProjectGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER,
		@JobType UNIQUEIDENTIFIER,
		@DeclinedToQuoteReason NVARCHAR(MAX),
		@DescriptionOfWorks NVARCHAR(MAX),
		@ExclusionsAndLimitations NVARCHAR(MAX)
	)
AS
BEGIN
	DECLARE @OrganisationalUnitId		INT = -1,
			@QuotingUserId				INT,
			@ContractId					INT = -1,
			@IsInsert					BIT = 0,
			@QuoteId					INT,
			@QuoteNumber				INT,
			@QuotingConsultantId		INT,
			@AppointmentFromRibaStageId INT,
			@CurrentStageId				INT,
			@EnquiryServiceID			INT,
			@ProjectID					INT,
			@JobTypeId                  INT; --New

	SELECT	@OrganisationalUnitId = ID
	FROM	SCore.OrganisationalUnits
	WHERE	(Guid = @OrganisationalUnitGuid);

	SELECT	@QuotingUserId = ID
	FROM	SCore.Identities
	WHERE	(Guid = @QuotingUserGuid);

	SELECT	@QuotingConsultantId = ID
	FROM	SCore.Identities
	WHERE	(Guid = @QuotingConsultantGuid);

	SELECT	@ContractId = ID
	FROM	SSop.Contracts
	WHERE	(Guid = @ContractGuid);

	SELECT	@AppointmentFromRibaStageId = ID
	FROM	SJob.RibaStages
	WHERE	(Guid = @AppointmentFromRibaStageGuid);

	SELECT	@EnquiryServiceID = es.ID
	FROM	SSop.EnquiryServices AS es
	WHERE	(es.Guid = @EnquiryServiceGuid);

	SELECT	@CurrentStageId = ID
	FROM	SJob.RibaStages
	WHERE	(Guid = @CurrentStageGuid);


	SELECT	@ProjectID = p.ID
	FROM	SSop.Projects AS p
	WHERE	(p.Guid = @ProjectGuid);

	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SSop',			-- nvarchar(255)
								@ObjectName = N'Quotes',		-- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;	-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SSop.Quotes
			 (RowStatus,
			  Guid,
			  OrganisationalUnitID,
			  QuotingUserId,
			  ContractID,
			  Date,
			  Overview,
			  ExpiryDate,
			  DateSent,
			  DateAccepted,
			  DateRejected,
			  RejectionReason,
			  FeeCap,
			  IsFinal,
			  ExternalReference,
			  QuotingConsultantId,
			  AppointmentFromRibaStageId,
			  CurrentRibaStageId,
			  DeadDate,
			  EnquiryServiceID,
			  ProjectId,
			  DeclinedToQuoteReason,
			  DescriptionOfWorks,
			  ExclusionsAndLimitations)
		VALUES
			 (
				 0,						-- RowStatus - tinyint
				 @Guid,					-- Guid - uniqueidentifier
				 @OrganisationalUnitId, -- OrganisationalUnitID - int
				 @QuotingUserId,		-- QuotingUserId - int
				 @ContractId,			-- ContractID - int
				 @Date,					-- Date - date
				 @Overview,				-- Overview - nvarchar(max)
				 @ExpiryDate,
				 @DateSent,
				 @DateAccepted,
				 @DateRejected,
				 @RejectionReason,
				 @FeeCap,
				 @IsFinal,
				 @ExternalReference,
				 @QuotingConsultantId,
				 @AppointmentFromRibaStageId,
				 @CurrentStageId,
				 @DeadDate,
				 @EnquiryServiceID,
				 @ProjectID,
				 @DeclinedToQuoteReason,
				 @DescriptionOfWorks,
				 @ExclusionsAndLimitations
			 );

		SELECT	@QuoteId = SCOPE_IDENTITY ();

	END;
	ELSE
	BEGIN
		DECLARE @_quotingConsultant INT,
				@_isFinal			BIT,
				@_emailRecipient	NVARCHAR(MAX),
				@_emailBody			NVARCHAR(MAX),
				@_emailSubject		NVARCHAR(MAX),
				@_quoteNumber		NVARCHAR(MAX);

		SELECT	@_quotingConsultant = QuotingConsultantId,
				@_isFinal			= IsFinal,
				@_quoteNumber		= Number
		FROM	SSop.Quotes
		WHERE	(Guid = @Guid);

		UPDATE	SSop.Quotes
		SET		OrganisationalUnitID = @OrganisationalUnitId,
				QuotingUserId = @QuotingUserId,
				ContractID = @ContractId,
				Date = @Date,
				Overview = @Overview,
				ExpiryDate = @ExpiryDate,
				DateSent = @DateSent,
				DateAccepted = @DateAccepted,
				DateRejected = @DateRejected,
				RejectionReason = @RejectionReason,
				FeeCap = @FeeCap,
				IsFinal = @IsFinal,
				ExternalReference = @ExternalReference,
				QuotingConsultantId = @QuotingConsultantId,
				AppointmentFromRibaStageId = @AppointmentFromRibaStageId,
				CurrentRibaStageId = @CurrentStageId,
				DeadDate = @DeadDate,
				EnquiryServiceID = @EnquiryServiceID,
				ProjectId = @ProjectID,
				DeclinedToQuoteReason = @DeclinedToQuoteReason,
				DescriptionOfWorks = @DescriptionOfWorks,
				ExclusionsAndLimitations = @ExclusionsAndLimitations
		WHERE	(Guid = @Guid);

		--Get the ID for the job type
		SELECT @JobTypeId = ID 
		FROM SJob.JobTypes
		Where Guid = @JobType; 


		UPDATE SSop.EnquiryServices
		SET JobTypeId = @JobTypeId
		WHERE (Guid = @EnquiryServiceGuid)


		IF (@QuotingConsultantId <> @_quotingConsultant)
		BEGIN
			SELECT	@_emailRecipient = i.EmailAddress
			FROM	SCore.Identities AS i
			WHERE	(i.ID = @QuotingConsultantId);

			SET @_emailBody = N'You have been assigned as the consultant for quote <a href="'
							  + +SCore.GetCurrentApplicationUrl () + N'/QuoteDetail/' + CONVERT (	NVARCHAR(MAX),
																									@Guid
																								)
							  + N'/%7b%22DataObjectGuid%22%3a%22' + CONVERT (	NVARCHAR(MAX),
																				@Guid
																			)
							  + N'%22%2c%22EntityTypeGuid%22%3a%221c4794c1-f956-4c32-b886-5500ac778a56%22%7d/https%3a%2f%2fbre.socotec.co.uk%3a9602%2f" taget="_blank">'
							  + @_quoteNumber + N'</a>. Please take a moment to review this record.';
			SET @_emailSubject = N'CymBuild: Quote ' + @_quoteNumber + N' assigned to your user.';

			EXEC SAlert.CreateNotification @Recipients = @_emailRecipient,	-- nvarchar(max)
										   @Subject = @_emailSubject,		-- nvarchar(255)
										   @Body = @_emailBody,				-- nvarchar(max)
										   @BodyFormat = N'TEXT',			-- nvarchar(20)
										   @Importance = N'NORMAL';			-- nvarchar(6)
		END;

		IF (@IsFinal <> @_isFinal)
	   AND	(@IsFinal = 1)
	   AND	(@DateSent IS NULL)
		BEGIN
			SELECT	@_emailRecipient = STRING_AGG (	  i.EmailAddress,
													  N';'
												  )
			FROM	SCore.Identities AS i
			JOIN	SCore.UserGroups AS ug ON (ug.IdentityID = i.ID)
			JOIN	SCore.Groups	 AS g ON (g.ID			 = ug.GroupID)
			WHERE	(g.Code = N'CDMSA');

			SET @_emailBody = N'Quote <a href="' + SCore.GetCurrentApplicationUrl () + N'/QuoteDetail/'
							  + CONVERT (	NVARCHAR(MAX),
											@Guid
										) + N'/%7b%22DataObjectGuid%22%3a%22' + CONVERT (	NVARCHAR(MAX),
																							@Guid
																						)
							  + N'%22%2c%22EntityTypeGuid%22%3a%221c4794c1-f956-4c32-b886-5500ac778a56%22%7d/https%3a%2f%2fbre.socotec.co.uk%3a9602%2f" taget="_blank">'
							  + @_quoteNumber
							  + N'</a> has been marked as final. Please review this record and send out the quote.';
			SET @_emailSubject = N'CymBuild: Quote ' + @_quoteNumber + N' ready to send.';

			EXEC SAlert.CreateNotification @Recipients = @_emailRecipient,	-- nvarchar(max)
										   @Subject = @_emailSubject,		-- nvarchar(255)
										   @Body = @_emailBody,				-- nvarchar(max)
										   @BodyFormat = N'TEXT',			-- nvarchar(20)
										   @Importance = N'NORMAL';			-- nvarchar(6)
		END;
	END;

	IF (@IsInsert = 1)
	BEGIN
		SELECT	@QuoteNumber = NEXT VALUE FOR SSop.QuoteNumber;

		UPDATE	SSop.Quotes
		SET		Number = @QuoteNumber,
				RowStatus = 1
		WHERE	(ID = @QuoteId);
	END;

	/* Tempoary addition until have have the System Bus */

	DECLARE @FilingObjectName NVARCHAR(250),
			@FilingLocation	  NVARCHAR(MAX);

	SELECT	@FilingLocation =
		 (
			 SELECT ss.SiteIdentifier,
					spf.FolderPath
			 FROM	SCore.ObjectSharePointFolder AS spf
			 JOIN	SCore.SharepointSites		 AS ss ON (ss.ID = spf.SharepointSiteId)
			 WHERE	(spf.ObjectGuid = @Guid)
			 FOR JSON PATH
		 );

	DECLARE @QuoteNumberString NVARCHAR(30);

	SELECT	@FilingObjectName  = q.Number + N' ' + p.FormattedAddressComma + N' - ' + client.Name + N' / ' + agent.Name
								 + N' - ' + q.Overview,
			@QuoteNumberString = q.Number
	FROM	SSop.Quotes		AS q
	JOIN	SJob.Assets AS p ON (p.ID			= q.UprnId)
	JOIN	SCrm.Accounts	AS client ON (client.ID = q.ClientAccountId)
	JOIN	SCrm.Accounts	AS agent ON (agent.ID	= q.AgentAccountId)
	WHERE	(q.Guid = @Guid);

	EXEC SOffice.TargetObjectUpsert @EntityTypeGuid = N'1c4794c1-f956-4c32-b886-5500ac778a56',	-- uniqueidentifier
									@RecordGuid = @Guid,										-- uniqueidentifier
									@Number = @QuoteNumberString,								-- bigint
									@Name = @FilingObjectName,									-- nvarchar(250)	
									@FilingLocation = @FilingLocation;
END;
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[JobsUpsert]'
GO




ALTER PROCEDURE SJob.JobsUpsert
  @OrganisationalUnitGuid  UNIQUEIDENTIFIER,
  @JobTypeGuid             UNIQUEIDENTIFIER,
  @UprnGuid                UNIQUEIDENTIFIER,
  @ClientAccountGuid       UNIQUEIDENTIFIER,
  @ClientAddressGuid       UNIQUEIDENTIFIER,
  @ClientContactGuid       UNIQUEIDENTIFIER,
  @AgentAccountGuid        UNIQUEIDENTIFIER,
  @AgentAddressGuid        UNIQUEIDENTIFIER,
  @AgentContactGuid        UNIQUEIDENTIFIER,
  @FinanceAccountGuid      UNIQUEIDENTIFIER,
  @FinanceAddressGuid      UNIQUEIDENTIFIER,
  @FinanceContactGuid      UNIQUEIDENTIFIER,
  @SurveyorGuid            UNIQUEIDENTIFIER,
  @JobDescription          NVARCHAR(1000),
  @IsSubjectToNDA          BIT,
  @JobStarted              DATETIME2,
  @JobCompleted            DATETIME2,
  @JobCancelled            DATETIME2,
  @ValueOfWorkGuid         UNIQUEIDENTIFIER,
  @AgreedFee               DECIMAL(19, 2),
  @RibaStage1Fee           DECIMAL(19, 2),
  @RibaStage2Fee           DECIMAL(19, 2),
  @RibaStage3Fee           DECIMAL(19, 2),
  @RibaStage4Fee           DECIMAL(19, 2),
  @RibaStage5Fee           DECIMAL(19, 2),
  @RibaStage6Fee           DECIMAL(19, 2),
  @RibaStage7Fee           DECIMAL(19, 2),
  @PreConstructionStageFee DECIMAL(19, 2),
  @ConstructionStageFee    DECIMAL(19, 2),
  @ArchiveReferenceLink    NVARCHAR(500),
  @ArchiveBoxReference     NVARCHAR(100),
  @CreatedOn               DATETIME2,
  @ExternalReference       NVARCHAR(50),
  @IsCompleteForReview     BIT,
  @ReviewedByUserGuid      UNIQUEIDENTIFIER,
  @ReviewDateTimeUTC       DATETIME2,
  @AppFormReceived         BIT,
  @FeeCap                  DECIMAL(19, 2),
  @CurrentRibaStageGuid    UNIQUEIDENTIFIER,
  @JobDormant              DATETIME2,
  @PurchaseOrderNumber     NVARCHAR(28),
  @ContractGuid            UNIQUEIDENTIFIER,
  @ProjectGuid             UNIQUEIDENTIFIER,
  @ValueOfWork             DECIMAL(19, 2),
  @ClientAppointmentReceived  BIT,
  @AppointedFromStageGuid	UNIQUEIDENTIFIER,
  @DeadDate					DATE,
  @Guid                    UNIQUEIDENTIFIER OUT,
  @BillingInstruction	   NVARCHAR(MAX)
AS
  BEGIN
    DECLARE @OrganisationUnitID INT = -1,
            @JobTypeID          INT = -1,
            @UprnID             INT = -1,
            @ClientAccountID    INT = -1,
            @ClientAddressID    INT = -1,
            @ClientContactID    INT = -1,
            @AgentAccountID     INT = -1,
            @AgentAddressID     INT = -1,
            @AgentContactID     INT = -1,
            @FinanceAccountID   INT = -1,
            @FinanceAddressID   INT = -1,
            @FinanceContactID   INT = -1,
            @SurveyorID         INT = -1,
            @ValueOfWorkID      INT = -1,
            @IsInsert           BIT = 0,
            @JobNumber          INT = 0,
            @JobID              INT,
            @ReviewedByUserID   INT = -1,
            @CurrentRibaStageID INT = -1,
            @VersionId          INT = -1,
            @ContractId         INT = -1,
            @UserID             INT = -1,
			@AppointedFromStageID INT = -1,
            @ProjectId          INT = -1;

    SELECT
            @UserID = ISNULL(CONVERT(INT,
            SESSION_CONTEXT(N'user_id')
            ),
            -1
            );

    SELECT
            @VersionId = ID
    FROM
            SCore.Versioning
    WHERE
            (IsCurrent = 1);

    SELECT
            @OrganisationUnitID = ID
    FROM
            SCore.OrganisationalUnits
    WHERE
            (Guid = @OrganisationalUnitGuid);

    SELECT
            @JobTypeID = ID
    FROM
            SJob.JobTypes
    WHERE
            (Guid = @JobTypeGuid);

    SELECT
            @ProjectId = ID
    FROM
            SSop.Projects
    WHERE
            (Guid = @ProjectGuid)

    SELECT
            @UprnID = ID
    FROM
            SJob.Assets
    WHERE
            (Guid = @UprnGuid);

    SELECT
            @ClientAccountID = ID
    FROM
            SCrm.Accounts
    WHERE
            (Guid = @ClientAccountGuid);

    SELECT
            @ClientAddressID = ID
    FROM
            SCrm.AccountAddresses
    WHERE
            (Guid = @ClientAddressGuid);

    SELECT
            @ClientContactID = ID
    FROM
            SCrm.AccountContacts
    WHERE
            (Guid = @ClientContactGuid);

    SELECT
            @AgentAccountID = ID
    FROM
            SCrm.Accounts
    WHERE
            (Guid = @AgentAccountGuid);

    SELECT
            @AgentAddressID = ID
    FROM
            SCrm.AccountAddresses
    WHERE
            (Guid = @AgentAddressGuid);

    SELECT
            @AgentContactID = ID
    FROM
            SCrm.AccountContacts
    WHERE
            (Guid = @AgentContactGuid);

    SELECT
            @FinanceAccountID = ID
    FROM
            SCrm.Accounts
    WHERE
            (Guid = @FinanceAccountGuid);

    SELECT
            @FinanceAddressID = ID
    FROM
            SCrm.AccountAddresses
    WHERE
            (Guid = @FinanceAddressGuid);

    SELECT
            @FinanceContactID = ID
    FROM
            SCrm.AccountContacts
    WHERE
            (Guid = @FinanceContactGuid);

    SELECT
            @SurveyorID = ID
    FROM
            SCore.Identities
    WHERE
            (Guid = @SurveyorGuid);

    SELECT
            @ReviewedByUserID = ID
    FROM
            SCore.Identities
    WHERE
            (Guid = @ReviewedByUserGuid);

    SELECT
            @ValueOfWorkID = ID
    FROM
            SJob.ValuesOfWork
    WHERE
            (Guid = @ValueOfWorkGuid);

    SELECT
            @CurrentRibaStageID = ID
    FROM
            SJob.RibaStages
    WHERE
            (Guid = @CurrentRibaStageGuid);

    SELECT
            @ContractId = ID
    FROM
            SSop.Contracts
    WHERE
            (Guid = @ContractGuid);

	SELECT
			@AppointedFromStageID = ID
	FROM	
			SJob.RibaStages AS rs
	WHERE	
			(Guid = @AppointedFromStageGuid)

    IF (@CreatedOn IS NULL)
      BEGIN
        SET @CreatedOn = GETUTCDATE();
      END;

    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					-- uniqueidentifier
      @SchemeName = N'SJob',				-- nvarchar(255)
      @ObjectName = N'Jobs',				-- nvarchar(255)
	  @IncludeDefaultSecurity = 1,
      @IsInsert   = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
      BEGIN
        /* Create the basic job record */
        INSERT SJob.Jobs
              (
                RowStatus,
                Guid,
                OrganisationalUnitID,
                JobTypeID,
                UprnID,
                ClientAccountID,
                ClientAddressID,
                ClientContactID,
                AgentAccountID,
                AgentAddressID,
                AgentContactID,
                FinanceAccountID,
                FinanceAddressID,
                FinanceContactID,
                SurveyorID,
                JobDescription,
                IsSubjectToNDA,
                JobStarted,
                JobCompleted,
                JobCancelled,
                ValueOfWorkID,
                RibaStage1Fee,
                RibaStage2Fee,
                RibaStage3Fee,
                RibaStage4Fee,
                RibaStage5Fee,
                RibaStage6Fee,
                RibaStage7Fee,
                PreConstructionStageFee,
                ConstructionStageFee,
                AgreedFee,
                ArchiveReferenceLink,
                ArchiveBoxReference,
                CreatedByUserID,
                CreatedOn,
                ExternalReference,
                VersionID,
                IsCompleteForReview,
                ReviewedByUserID,
                ReviewedDateTimeUTC,
                AppFormReceived,
                FeeCap,
                JobDormant,
                CurrentRibaStageId,
                PurchaseOrderNumber,
                ContractID,
                ProjectId,
                ValueOfWork,
                ClientAppointmentReceived,
				AppointedFromStageId,
				DeadDate,
				BillingInstruction	--[CBLD-521]
              )
        VALUES
                (
                  0,						-- RowStatus - tinyint
                  @Guid,					-- Guid - uniqueidentifier
                  @OrganisationUnitID,	-- OrganisationalUnitID - int
                  @JobTypeID,			-- JobTypeID - int
                  @UprnID,				-- UprnID - int
                  @ClientAccountID,		-- ClientAccountID - int
                  @ClientAddressID,
                  @ClientContactID,		-- ClientContactID - int
                  @AgentAccountID,		-- AgentAccountID - int
                  @AgentAddressID,
                  @AgentContactID,		-- AgentContactID - int
                  @FinanceAccountID,		-- AgentAccountID - int
                  @FinanceAddressID,
                  @FinanceContactID,		-- AgentContactID - int
                  @SurveyorID,			-- SurveyorID - int
                  @JobDescription,		-- JobDescription - nvarchar(1000)
                  @IsSubjectToNDA,		-- IsSubjectToNDA - bit
                  @JobStarted,			-- JobStarted - datetime2(7)
                  @JobCompleted,			-- JobCompleted - datetime2(7)
                  @JobCancelled,			-- JobCancelled - datetime2(7)
                  @ValueOfWorkID,		-- ValueOfWorkID - smallint
                  @RibaStage1Fee,
                  @RibaStage2Fee,
                  @RibaStage3Fee,
                  @RibaStage4Fee,
                  @RibaStage5Fee,
                  @RibaStage6Fee,
                  @RibaStage7Fee,
                  @PreConstructionStageFee,
                  @ConstructionStageFee,
                  @AgreedFee,			-- AgreedFee - decimal(19, 2)
                  @ArchiveReferenceLink, -- ArchiveReferenceLink - nvarchar(500)
                  @ArchiveBoxReference,	-- ArchiveBoxReference - nvarchar(100)
                  @UserID,				-- CreatedByUserID - int
                  @CreatedOn,			-- CreatedOn - datetime2(7)
                  @ExternalReference,	-- ExternalReference - nvarchar(50)
                  @VersionId,			-- VersionID - int
                  @IsCompleteForReview,
                  @ReviewedByUserID,
                  @ReviewDateTimeUTC,
                  @AppFormReceived,
                  @FeeCap,
                  @JobDormant,
                  @CurrentRibaStageID,
                  @PurchaseOrderNumber,
                  @ContractId,
                  @ProjectId,
                  @ValueOfWork,
                  @ClientAppointmentReceived,
				  @AppointedFromStageID,
				  @DeadDate,
				  @BillingInstruction --[CBLD-521]
                );

        SELECT
                @JobID = SCOPE_IDENTITY();
      END;
    ELSE
      BEGIN
        UPDATE  SJob.Jobs
        SET     OrganisationalUnitID = @OrganisationUnitID,
                JobTypeID = @JobTypeID,
                UprnID = @UprnID,
                ClientAccountID = @ClientAccountID,
                ClientAddressID = @ClientAddressID,
                ClientContactID = @ClientContactID,
                AgentAccountID = @AgentAccountID,
                AgentAddressID = @AgentAddressID,
                AgentContactID = @AgentContactID,
                FinanceAccountID = @FinanceAccountID,
                FinanceAddressID = @FinanceAddressID,
                FinanceContactID = @FinanceContactID,
                SurveyorID = @SurveyorID,
                JobDescription = @JobDescription,
                IsSubjectToNDA = @IsSubjectToNDA,
                JobStarted = @JobStarted,
                JobCompleted = @JobCompleted,
                JobCancelled = @JobCancelled,
                ValueOfWorkID = @ValueOfWorkID,
                RibaStage1Fee = @RibaStage1Fee,
                RibaStage2Fee = @RibaStage2Fee,
                RibaStage3Fee = @RibaStage3Fee,
                RibaStage4Fee = @RibaStage4Fee,
                RibaStage5Fee = @RibaStage5Fee,
                RibaStage6Fee = @RibaStage6Fee,
                RibaStage7Fee = @RibaStage7Fee,
                PreConstructionStageFee = @PreConstructionStageFee,
                ConstructionStageFee = @ConstructionStageFee,
                AgreedFee = @AgreedFee,
                ArchiveReferenceLink = @ArchiveReferenceLink,
                ArchiveBoxReference = @ArchiveBoxReference,
                ExternalReference = @ExternalReference,
                IsCompleteForReview = @IsCompleteForReview,
                ReviewedDateTimeUTC = @ReviewDateTimeUTC,
                ReviewedByUserID = @ReviewedByUserID,
                AppFormReceived = @AppFormReceived,
                FeeCap = @FeeCap,
                JobDormant = @JobDormant,
                CurrentRibaStageId = @CurrentRibaStageID,
                PurchaseOrderNumber = @PurchaseOrderNumber,
                ContractID = @ContractId,
                ProjectId = @ProjectId,
                ValueOfWork = @ValueOfWork,
                ClientAppointmentReceived = @ClientAppointmentReceived,
				AppointedFromStageId = @AppointedFromStageID,
				DeadDate = @DeadDate,
				BillingInstruction = @BillingInstruction --[CBLD-521]
        WHERE
          (Guid = @Guid);

        SELECT
                @JobID = ID
        FROM
                SJob.Jobs
        WHERE
                (Guid = @Guid);
      END;

    /* Create the milestones from the template */
    EXEC SJob.JobMilestonesBuildFromTemplate
      @JobID = @JobID;	-- int

    /* Create the project directory from the template */
    EXEC SJob.JobProjectDirectoryBuildFromTemplate
      @JobID = @JobID; -- int

    /* Set the Job number if this is an insert */
    IF (@IsInsert = 1)
      BEGIN
        SELECT
                @JobNumber = NEXT VALUE FOR SJob.JobNumber;

        UPDATE  SJob.Jobs
        SET     Number = @JobNumber,
                RowStatus = 1
        WHERE
          (ID = @JobID);
      END;


    /* Tempoary addition until have have the System Bus */
    DECLARE @FilingObjectName NVARCHAR(250),
            @FilingLocation   NVARCHAR(MAX);

    SELECT
            @FilingLocation =
            (
                SELECT
                        ss.SiteIdentifier,
                        spf.FolderPath
                FROM
                        SCore.ObjectSharePointFolder AS spf
                JOIN
                        SCore.SharepointSites ss ON (ss.ID = spf.SharepointSiteId)
                WHERE
                        (spf.ObjectGuid = @Guid)
                FOR JSON PATH
            );

    DECLARE @JobNumberString NVARCHAR(100)

    SELECT
            @FilingObjectName = j.Number + N' ' + p.FormattedAddressComma + N' - ' + client.Name + N' / '
            + agent.Name + N' - ' + j.JobDescription,
            @JobNumberString  = j.Number
    FROM
            SJob.Jobs AS j
    JOIN
            SJob.Assets AS p ON (p.ID = j.UprnID)
    JOIN
            SCrm.Accounts AS client ON (client.ID = j.ClientAccountID)
    JOIN
            SCrm.Accounts AS agent ON (agent.ID = j.AgentAccountID)
    WHERE
            (j.Guid = @Guid);

    EXEC SOffice.TargetObjectUpsert
      @EntityTypeGuid = N'63542427-46ab-4078-abd1-1d583c24315c',	-- uniqueidentifier
      @RecordGuid     = @Guid,										-- uniqueidentifier
      @Number         = @JobNumberString,										-- bigint
      @Name           = @FilingObjectName,									-- nvarchar(250)	
      @FilingLocation = @FilingLocation
  END;

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[QuoteCreateJobs]'
GO




ALTER PROCEDURE SSop.QuoteCreateJobs
	(@Guid UNIQUEIDENTIFIER)
AS
BEGIN
	SET NOCOUNT ON;


	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SSop.Quotes AS q
		 WHERE	(q.Guid = @Guid)
			AND (q.DateAccepted IS NULL)
	 )
	   )
	BEGIN
		;
		THROW 60000, N'The quote must be accepted first', 1;
	END;


	PRINT N'Passed pre checks';

	/*
		  Build a consolidated list of jobs to create 
	  */
	DECLARE @JobsToCreate TABLE
		(
			ID INT NOT NULL PRIMARY KEY,
			Guid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID (),
			Net DECIMAL(19, 2) NOT NULL,
			RibaStage1Fee DECIMAL(19, 2) NOT NULL,
			RibaStage2Fee DECIMAL(19, 2) NOT NULL,
			RibaStage3Fee DECIMAL(19, 2) NOT NULL,
			RibaStage4Fee DECIMAL(19, 2) NOT NULL,
			RibaStage5Fee DECIMAL(19, 2) NOT NULL,
			RibaStage6Fee DECIMAL(19, 2) NOT NULL,
			RibaStage7Fee DECIMAL(19, 2) NOT NULL,
			PreConstructionStageFee DECIMAL(19, 2) NOT NULL,
			ConstructionStageFee DECIMAL(19, 2) NOT NULL,
			OrganisationalUnitGuid UNIQUEIDENTIFIER NOT NULL,
			JobTypeGuid UNIQUEIDENTIFIER NOT NULL,
			ContractGuid UNIQUEIDENTIFIER NOT NULL,
			IdentityGuid UNIQUEIDENTIFIER NOT NULL,
			QuoteItemId INT NOT NULL,
			ExternalReference NVARCHAR(50) NOT NULL,
			ValueOfWorkGuid UNIQUEIDENTIFIER NOT NULL,
			FeeCap DECIMAL(19, 2) NOT NULL,
			CurrentRibaStageGuid UNIQUEIDENTIFIER NOT NULL,
			TotalFee DECIMAL(19, 2) NOT NULL,
			AppointedFromStageGuid UNIQUEIDENTIFIER NOT NULL,
			CreatedJobID INT NOT NULL DEFAULT ((-1))
			
		);


	DECLARE @JobPaymentStages TABLE
		(
			Guid UNIQUEIDENTIFIER NOT NULL,
			JobId INT NOT NULL,
			StagedDate DATE NULL,
			AfterStageId INT NOT NULL,
			Value DECIMAL(19, 2) NOT NULL DEFAULT (0)
		);


	INSERT	@JobsToCreate
		 (ID,
		  Net,
		  RibaStage1Fee,
		  RibaStage2Fee,
		  RibaStage3Fee,
		  RibaStage4Fee,
		  RibaStage5Fee,
		  RibaStage6Fee,
		  RibaStage7Fee,
		  PreConstructionStageFee,
		  ConstructionStageFee,
		  OrganisationalUnitGuid,
		  JobTypeGuid,
		  ContractGuid,
		  IdentityGuid,
		  QuoteItemId,
		  ExternalReference,
		  ValueOfWorkGuid,
		  FeeCap,
		  CurrentRibaStageGuid,
		  TotalFee,
		  AppointedFromStageGuid)
	SELECT	js.ID,
			js.Net,
			js.RibaStage1Fee,
			js.RibaStage2Fee,
			js.RibaStage3Fee,
			js.RibaStage4Fee,
			js.RibaStage5Fee,
			js.RibaStage6Fee,
			js.RibaStage7Fee,
			js.PreConstructionStageFee,
			js.ConstructionStageFee,
			js.OrganisationalUnitGuid,
			js.JobTypeGuid,
			js.ContractGuid,
			js.IdentityGuid,
			js.QuoteItemId,
			js.ExternalReference,
			'00000000-0000-0000-0000-000000000000',
			js.FeeCap,
			js.CurrentRibaStageGuid,
			js.RibaStage1Fee + js.RibaStage2Fee + js.RibaStage3Fee + js.RibaStage4Fee + js.RibaStage5Fee
			+ js.RibaStage6Fee + js.RibaStage7Fee + js.PreConstructionStageFee + js.ConstructionStageFee,
			js.AppointedRibaStageGuid
	FROM	SSop.Quote_JobsSummary AS js
	WHERE	(js.QuoteGuid = @Guid)
		AND (js.DateAccepted IS NOT NULL);

	DECLARE @ClientAccountGuid	UNIQUEIDENTIFIER,
			@ClientAddressGuid	UNIQUEIDENTIFIER,
			@ClientContactGuid	UNIQUEIDENTIFIER,
			@AgentAccountGuid	UNIQUEIDENTIFIER,
			@AgentAddressGuid	UNIQUEIDENTIFIER,
			@AgentContactGuid	UNIQUEIDENTIFIER,
			@FinanceAccountGuid UNIQUEIDENTIFIER,
			@FinanceAddressGuid UNIQUEIDENTIFIER,
			@FinanceContactGuid UNIQUEIDENTIFIER,
			@StructureGuid		UNIQUEIDENTIFIER,
			@ProjectGuid		UNIQUEIDENTIFIER,
			@Overview			NVARCHAR(1000),
			@ValueOfWork		DECIMAL(19, 2);

	SELECT	@ClientAccountGuid	= ca.Guid,
			@ClientAddressGuid	= caa.Guid,
			@ClientContactGuid	= cac.Guid,
			@AgentAccountGuid	= aa.Guid,
			@AgentAddressGuid	= aaa.Guid,
			@AgentContactGuid	= aac.Guid,
			@FinanceAccountGuid = fa.Guid,
			@FinanceAddressGuid = faa.Guid,
			@FinanceContactGuid = fac.Guid,
			@StructureGuid		= p.Guid,
			@ProjectGuid		= p2.Guid,
			@Overview			= CASE WHEN q.DescriptionOfWorks = '' THEN e.DescriptionOfWorks ELSE q.DescriptionOfWorks END,
			@ValueOfWork		= e.ValueOfWork
	FROM	SSop.Quotes				AS q
	JOIN	SSop.Quote_ExtendedInfo AS qei ON (qei.Id = q.ID)
	JOIN	SCrm.Accounts			AS ca ON (ca.ID	  = qei.ClientAccountID)
	JOIN	SCrm.AccountAddresses	AS caa ON (caa.ID = qei.ClientAddressId)
	JOIN	SCrm.AccountContacts	AS cac ON (cac.ID = qei.ClientAccountContactId)
	JOIN	SCrm.Accounts			AS aa ON (aa.ID	  = qei.AgentAccountID)
	JOIN	SCrm.AccountAddresses	AS aaa ON (aaa.ID = qei.AgentAddressId)
	JOIN	SCrm.AccountContacts	AS aac ON (aac.ID = qei.AgentAccountContactId)
	JOIN	SCrm.Accounts			AS fa ON (fa.ID	  = qei.FinanceAccountId)
	JOIN	SCrm.AccountAddresses	AS faa ON (faa.ID = qei.FinanceAddressId)
	JOIN	SCrm.AccountContacts	AS fac ON (fac.ID = qei.FinanceContactId)
	JOIN	SJob.Assets			AS p ON (p.ID	  = qei.PropertyId)
	JOIN	SSop.Projects			AS p2 ON (p2.ID	  = q.ProjectId)
	JOIN	SSop.EnquiryServices	AS es ON (es.ID	  = q.EnquiryServiceID)
	JOIN	SSop.Enquiries			AS e ON (e.ID	  = es.EnquiryId)
	WHERE	(q.Guid = @Guid);


	DECLARE @ActiveAccountStatusID INT;

	SELECT	@ActiveAccountStatusID = ast.ID
	FROM	SCrm.AccountStatus AS ast
	WHERE	(ast.Name = N'Active');

	-- Make sure the client is active. 
	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SCrm.Accounts	   AS a
		 WHERE	(a.Guid = @ClientAccountGuid)
			AND (a.AccountStatusID = @ActiveAccountStatusID)
			AND	(a.Guid <> '00000000-0000-0000-0000-000000000000')
	 )
	   )
	BEGIN
		UPDATE	SCrm.Accounts
		SET		AccountStatusID = @ActiveAccountStatusID
		WHERE	(Guid = @ClientAccountGuid);
	END;

	-- Make sure the Agent is active. 
	IF (EXISTS
	 (
		  SELECT 1
		 FROM	SCrm.Accounts	   AS a
		 WHERE	(a.Guid = @AgentAccountGuid)
			AND (a.AccountStatusID = @ActiveAccountStatusID)
			AND	(a.Guid <> '00000000-0000-0000-0000-000000000000')
	 )
	   )
	BEGIN
		UPDATE	SCrm.Accounts
		SET		AccountStatusID = @ActiveAccountStatusID
		WHERE	(Guid = @AgentAccountGuid);
	END;

	-- Make sure the Finance Account is active. 
	IF (EXISTS
	 (
		  SELECT 1
		 FROM	SCrm.Accounts	   AS a
		 WHERE	(a.Guid = @FinanceAccountGuid)
			AND (a.AccountStatusID = @ActiveAccountStatusID)
			AND	(a.Guid <> '00000000-0000-0000-0000-000000000000')
	 )
	   )
	BEGIN
		UPDATE	SCrm.Accounts
		SET		AccountStatusID = @ActiveAccountStatusID
		WHERE	(Guid = @FinanceAccountGuid);
	END;



	IF NOT EXISTS
	 (
		 SELECT 1
		 FROM	@JobsToCreate
	 )
	BEGIN
		;
		THROW 60000, N'There were no jobs to create', 1;
	END;

	/*
		  Loop through the list of jobs executing JobsUpsert
	  */
	DECLARE @CreatedDateTime		 DATETIME2 = GETUTCDATE (),
			@JobGuid				 UNIQUEIDENTIFIER,
			@OrganisationalUnitGuid	 UNIQUEIDENTIFIER,
			@JobTypeGuid			 UNIQUEIDENTIFIER,
			@ContractGuid			 UNIQUEIDENTIFIER,
			@ValueOfWorkGuid		 UNIQUEIDENTIFIER,
			@RibaStage1Fee			 DECIMAL(19, 2),
			@RibaStage2Fee			 DECIMAL(19, 2),
			@RibaStage3Fee			 DECIMAL(19, 2),
			@RibaStage4Fee			 DECIMAL(19, 2),
			@RibaStage5Fee			 DECIMAL(19, 2),
			@RibaStage6Fee			 DECIMAL(19, 2),
			@RibaStage7Fee			 DECIMAL(19, 2),
			@PreConstructionStageFee DECIMAL(19, 2),
			@ConstructionStageFee	 DECIMAL(19, 2),
			@ExternalReference		 NVARCHAR(50),
			@MaxID					 INT,
			@CurrentId				 INT,
			@QuoteItemID			 INT,
			@CreatedJobID			 INT,
			@FeeCap					 DECIMAL(19, 2),
			@CurrentRibaStageGuid	 UNIQUEIDENTIFIER,
			@AppointedRibaStageGuid	 UNIQUEIDENTIFIER;


	SELECT	@MaxID	   = MAX (ID),
			@CurrentId = 0
	FROM	@JobsToCreate;

	PRINT N'Creating job(s)';

	WHILE (@CurrentId < @MaxID)
	BEGIN
		SELECT		TOP (1) @CurrentId				 = j.ID,
							@OrganisationalUnitGuid	 = j.OrganisationalUnitGuid,
							@JobTypeGuid			 = j.JobTypeGuid,
							@ContractGuid			 = j.ContractGuid,
							@ExternalReference		 = j.ExternalReference,
							@QuoteItemID			 = j.QuoteItemId,
							@ValueOfWorkGuid		 = j.ValueOfWorkGuid,
							@RibaStage1Fee			 = j.RibaStage1Fee,
							@RibaStage2Fee			 = j.RibaStage2Fee,
							@RibaStage3Fee			 = j.RibaStage3Fee,
							@RibaStage4Fee			 = j.RibaStage4Fee,
							@RibaStage5Fee			 = j.RibaStage5Fee,
							@RibaStage6Fee			 = j.RibaStage6Fee,
							@RibaStage7Fee			 = j.RibaStage7Fee,
							@PreConstructionStageFee = j.PreConstructionStageFee,
							@ConstructionStageFee	 = j.ConstructionStageFee,
							@FeeCap					 = j.FeeCap,
							@CurrentRibaStageGuid	 = j.CurrentRibaStageGuid,
							@AppointedRibaStageGuid	 = j.AppointedFromStageGuid,
							@JobGuid				 = j.Guid
		FROM		@JobsToCreate AS j
		WHERE		(j.ID > @CurrentId)
		ORDER BY	j.ID;

		EXEC SJob.JobsUpsert @OrganisationalUnitGuid = @OrganisationalUnitGuid,				-- uniqueidentifier
							 @JobTypeGuid = @JobTypeGuid,									-- uniqueidentifier
							 @UprnGuid = @StructureGuid,									-- uniqueidentifier
							 @ClientAccountGuid = @ClientAccountGuid,						-- uniqueidentifier
							 @ClientAddressGuid = @ClientAddressGuid,
							 @ClientContactGuid = @ClientContactGuid,						-- uniqueidentifier
							 @AgentAccountGuid = @AgentAccountGuid,							-- uniqueidentifier
							 @AgentAddressGuid = @AgentAddressGuid,
							 @AgentContactGuid = @AgentContactGuid,							-- uniqueidentifier
							 @SurveyorGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
							 @JobDescription = @Overview,									-- nvarchar(1000)
							 @IsSubjectToNDA = 0,								-- bit
							 @JobStarted = @CreatedDateTime,								-- datetime2(7)
							 @JobCompleted = NULL,											-- datetime2(7)
							 @JobCancelled = NULL,											-- datetime2(7)
							 @ValueOfWorkGuid = @ValueOfWorkGuid,							-- uniqueidentifier
							 @RibaStage1Fee = @RibaStage1Fee,
							 @RibaStage2Fee = @RibaStage2Fee,
							 @RibaStage3Fee = @RibaStage3Fee,
							 @RibaStage4Fee = @RibaStage4Fee,
							 @RibaStage5Fee = @RibaStage5Fee,
							 @RibaStage6Fee = @RibaStage6Fee,
							 @RibaStage7Fee = @RibaStage7Fee,
							 @PreConstructionStageFee = @PreConstructionStageFee,
							 @ConstructionStageFee = @ConstructionStageFee,
							 @FeeCap = @FeeCap,
							 @CurrentRibaStageGuid = @CurrentRibaStageGuid,
							 @JobDormant = NULL,
							 @AgreedFee = 0,
							 @AppFormReceived = FALSE,
							 @ArchiveReferenceLink = N'',									-- nvarchar(500)
							 @ArchiveBoxReference = N'',									-- nvarchar(100)
							 @CreatedOn = @CreatedDateTime,									-- datetime2(7)
							 @ExternalReference = @ExternalReference,						-- nvarchar(50)
							 @IsCompleteForReview = 0,										-- bit
							 @ReviewedByUserGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
							 @ReviewDateTimeUTC = NULL,										-- datetime2(7)
							 @FinanceAccountGuid = @FinanceAccountGuid,
							 @FinanceAddressGuid = @FinanceAddressGuid,
							 @FinanceContactGuid = @FinanceContactGuid,
							 @PurchaseOrderNumber = N'',
							 @ContractGuid = @ContractGuid,
							 @ProjectGuid = @ProjectGuid,
							 @ValueOfWork = @ValueOfWork,
							 @ClientAppointmentReceived = 0,
							 @AppointedFromStageGuid = @AppointedRibaStageGuid,
							 @DeadDate = NULL,
							 @Guid = @JobGuid,												-- uniqueidentifier
							 @BillingInstruction = NULL;

		SELECT	@CreatedJobID = ID
		FROM	SJob.Jobs
		WHERE	(Guid = @JobGuid);

		UPDATE	@JobsToCreate
		SET		CreatedJobID = @CreatedJobID
		WHERE	(ID = @CurrentId);

		INSERT INTO @JobPaymentStages
			 (Guid, JobId, StagedDate, AfterStageId, Value)
		SELECT	sps.Guid,
				jtc.CreatedJobID,
				sps.StagedDate,
				sps.AfterStageId,
				sps.Value
		FROM	SSop.Quotes_StagedPaymentSummary (@Guid) AS sps
		JOIN	@JobsToCreate							 AS jtc ON (sps.JobId = jtc.ID)
		WHERE	(jtc.ID = @CurrentId);

		PRINT N'Created job';

		IF (@QuoteItemID > 0)
		BEGIN
			UPDATE	SSop.QuoteItems
			SET		CreatedJobId = @CreatedJobID
			WHERE	(ID = @QuoteItemID);
		END;
		ELSE
		BEGIN
			UPDATE	qi
			SET		qi.CreatedJobId = @CreatedJobID
			FROM	SSop.QuoteItems AS qi
			JOIN	SProd.Products	AS p ON (p.ID			   = qi.ProductId)
			JOIN	SJob.JobTypes	AS jt ON (p.CreatedJobType = jt.ID)
			JOIN	SSop.Quotes		AS q ON (q.ID			   = qi.QuoteId)
			WHERE	(jt.Guid				= @JobTypeGuid)
				AND (q.Guid					= @Guid)
				AND (p.NeverConsolidate		= 0)
				AND (qi.DoNotConsolidateJob = 0)
				AND (qi.RowStatus NOT IN (0, 254));
		END;

		EXEC SJob.JobActivitiesBuildFromTemplate @JobID = @CreatedJobID;
	END;

	DECLARE @GuidList SCore.GuidUniqueList,
			@IsInsert BIT;

	PRINT N'Creating staged payments';

	DELETE	FROM @GuidList;

	INSERT INTO @GuidList
		 (GuidValue)
	SELECT	Guid
	FROM	@JobPaymentStages;

	EXEC SCore.DataObjectBulkUpsert @GuidList = @GuidList,
									@SchemeName = N'SJob',
									@ObjectName = N'JobPaymentStages',
									@IsInsert = @IsInsert;


	INSERT INTO SJob.JobPaymentStages
		 (RowStatus, Guid, JobId, StagedDate, AfterStageId, Value)
	SELECT	1,
			jps.Guid,
			jps.JobId,
			jps.StagedDate,
			jps.AfterStageId,
			jps.Value
	FROM	@JobPaymentStages AS jps;


	PRINT N'Staged Payments Created';

END;
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[Quote_CalculatedFields]'
GO
EXEC sp_refreshview N'[SSop].[Quote_CalculatedFields]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_CurrentQuotes]'
GO
ALTER FUNCTION SSop.tvf_CurrentQuotes
(
	@UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.FullNumber AS Number,
		CASE WHEN q.DescriptionOfWorks <> N'' THEN LEFT(q.DescriptionOfWorks, 200) ELSE LEFT(q.Overview, 200) END AS Details, --[CBLD-640]
		--LEFT(q.Overview, 200) AS Details, 
		acc.Name + N' / ' + agent.Name AS Account,
		uprn.FormattedAddressComma,
		qcf.QuoteStatus,
		i.FullName AS QuotingConsultant,
		q.RevisionNumber,
		ou.Name AS OrganisationalUnitName
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SCrm.Accounts acc ON (acc.ID = q.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = q.AgentAccountId)
JOIN	SJob.Assets uprn ON (uprn.ID = q.UprnId)
JOIN	SCore.Identities i ON (i.ID = q.QuotingConsultantId)
JOIN    SCore.OrganisationalUnits ou ON q.OrganisationalUnitID = ou.ID
WHERE   (q.RowStatus NOT IN (0, 254))
	AND	(q.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
	AND	(
			(q.DateAccepted IS NULL)
			OR 
			(
				(q.DateAccepted IS NOT NULL)
				AND (EXISTS 
						(
							SELECT	1
							FROM	SSop.QuoteItems qi
							JOIN	SSop.QuoteSections qs ON (qs.ID = qi.QuoteSectionId)
							WHERE	(qs.QuoteID = q.ID)
								AND	(qi.RowStatus NOT IN (0, 254))
								AND	(qi.CreatedJobId < 0)
						)
					)
			)
		)
	AND	(q.DateRejected IS NULL)
	AND	(q.ExpiryDate > GETDATE())
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_CurrentJobs]'
GO


ALTER FUNCTION SJob.tvf_CurrentJobs 
(
    @UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS
RETURN 
SELECT  j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        j.JobTypeID,
        jt.Name AS JobTypeName,
		i.Guid SurveyorGuid,
		client.Name + N' / ' + agent.Name AS  ClientAgent,
		i.FullName AS SurveyorName, 
		prop.FormattedAddressComma,
		j.IsSubjectToNDA,
		j.IsComplete,
		js.JobStatus
FROM    SJob.Jobs j
JOIN	SJob.JobStatus js ON (js.ID = j.ID)
JOIN    SJob.JobTypes jt ON (j.JobTypeID = jt.ID)
JOIN    SCore.Identities i ON (j.SurveyorID = i.ID)
JOIN	SJob.Assets prop ON (prop.ID = j.UprnID)
JOIN	SCrm.Accounts client ON (client.ID = j.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = j.AgentAccountID)
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(j.Id > 0)
	AND	(j.IsActive = 1)
	AND	(EXISTS
			(				
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_Jobs_CDM_MyProjects]'
GO
ALTER FUNCTION SJob.tvf_Jobs_CDM_MyProjects
(
    @UserID INT
)
RETURNS TABLE
AS
RETURN
WITH MilestoneData
AS (SELECT JobID,
           MAX(   CASE
                      WHEN MilestoneTypeID = 8 THEN
                          1
                      ELSE
                          0
                  END
              ) AS HasHSFile,
           MAX(   CASE
                      WHEN MilestoneTypeID = 2
                           AND IsComplete = 1 THEN
                          1
                      ELSE
                          0
                  END
              ) AS ClientDutiesIssued,
           MAX(   CASE
                      WHEN MilestoneTypeID = 1
                           AND IsComplete = 1 THEN
                          1
                      ELSE
                          0
                  END
              ) AS CDMStrategyIssued,
           MAX(   CASE
                      WHEN MilestoneTypeID = 11
                           AND IsComplete = 1 THEN
                          1
                      ELSE
                          0
                  END
              ) AS PCICompleted,
           MAX(   CASE
                      WHEN MilestoneTypeID = 7 THEN
                          1
                      ELSE
                          0
                  END
              ) AS F10Applicable,
           MAX(   CASE
                      WHEN MilestoneTypeID = 19 THEN
                          CompletedDateTimeUTC
                  END
              ) AS CPPDateReceived,
           MAX(   CASE
                      WHEN MilestoneTypeID = 17 THEN
                          CompletedDateTimeUTC
                  END
              ) AS CPPReviewed,
           MAX(   CASE
                      WHEN MilestoneTypeID = 8 THEN
                          ReviewedDateTimeUTC
                  END
              ) AS HSFReviewedDate,
           MAX(   CASE
                      WHEN MilestoneTypeID = 8 THEN
                          CompletedDateTimeUTC
                  END
              ) AS HSFCompletedDate,
           -- New aggregated F10 dates
           MAX(   CASE
                      WHEN MilestoneTypeID = 7 THEN
                          CompletedDateTimeUTC
                  END
              ) AS F10IssuedDate,
           MAX(   CASE
                      WHEN MilestoneTypeID = 7 THEN
                          StartDateTimeUTC
                  END
              ) AS F10StartDate,
           MAX(   CASE
                      WHEN MilestoneTypeID = 7 THEN
                          DueDateTimeUTC
                  END
              ) AS F10DueDate,
           MAX(   CASE
                      WHEN MilestoneTypeID = 7 THEN
                          SubmissionExpiryDate
                  END
              ) AS F10ExpiryDate,
           MAX(   CASE
                      WHEN MilestoneTypeID = 11 THEN
                          CompletedDateTimeUTC
                  END
              ) AS PCIDate
    FROM SJob.Milestones
    GROUP BY JobID),
     FeeData
AS (SELECT JobId,
           MAX(   CASE
                      WHEN StageId = -2 THEN
                          Agreed
                  END
              ) AS TotalAgreed,
           MAX(   CASE
                      WHEN StageId = -2 THEN
                          Remaining
                  END
              ) AS TotalRemaining,
           MAX(   CASE
                      WHEN StageId = 10 THEN
                          QuotedMeetings
                  END
              ) AS PreConMeetings,
           MAX(   CASE
                      WHEN StageId = 11 THEN
                          QuotedMeetings
                  END
              ) AS ConMeetings,
           MAX(   CASE
                      WHEN StageId = 10 THEN
                          QuotedMeetings - CompletedMeetings
                  END
              ) AS PreConRemaining,
           MAX(   CASE
                      WHEN StageId = 11 THEN
                          QuotedMeetings - CompletedMeetings
                  END
              ) AS ConRemaining
    FROM SJob.Job_FeeDrawdown
    GROUP BY JobId),
     ActivityData
AS (SELECT JobID,
           COUNT(   CASE
                        WHEN ActivityTypeID = 23 THEN
                            ID
                    END
                ) AS TotalComplianceVisits,
           COUNT(   CASE
                        WHEN ActivityTypeID = 23
                             AND ActivityStatusID = 3 THEN
                            ID
                    END
                ) AS CompletedComplianceVisits,
           MAX(   CASE
                      WHEN ActivityTypeID = 26
                           AND ActivityStatusID = 3 THEN
                          EndDate
                  END
              ) AS DRRLastIssued
    FROM SJob.Activities
    GROUP BY JobID)
SELECT j.ID,
       j.Guid,
       j.RowStatus,
       -- [PROJECT]
       /*CASE 
           WHEN EXISTS(SELECT 1 FROM SSop.Projects p WHERE p.ID = j.ProjectId AND p.ExternalReference = '')
           THEN CAST(j.ProjectId AS NVARCHAR(15))
           ELSE CAST(j.ProjectId AS NVARCHAR(15)) + N' - ' + CAST(j.ExternalReference AS NVARCHAR(50))
       END*/

       j.Number AS projectRef,
       client.Name + N' / ' + agent.Name AS clientAgent,
       p.Name + N' / ' + p.FormattedAddressComma AS propertyName,
       jt.Name AS CDMRole,
       js.JobStatus,
       -- [FINANCE]
       fd.TotalAgreed AS totalAgreed,
       fd.TotalRemaining AS totalRemaining,
       -- [AGREED DELIVERABLES]
       fd.PreConMeetings AS preconMeetings,
       fd.ConMeetings AS conMeetings,
       ad.TotalComplianceVisits AS complianceVisit,
       CASE
           WHEN md.HasHSFile = 1 THEN
               N'Yes'
           ELSE
               N'No'
       END AS hsFile,
       -- [REMAINING DELIVERABLES]
       fd.PreConRemaining AS preconMeetingsRemaining,
       fd.ConRemaining AS conMeetingsRemaining,
       (ad.TotalComplianceVisits - ad.CompletedComplianceVisits) AS compVisitsRemaining,
       CASE
           WHEN EXISTS
                (
                    SELECT 1
                    FROM SJob.Milestones m
                    WHERE m.JobID = j.ID
                          AND m.MilestoneTypeID = 8
                          AND m.IsComplete = 1
                ) THEN
               N'Yes'
           ELSE
               N'No'
       END AS HSIssued,
       -- [CLIENT DUTIES]
       CASE
           WHEN md.ClientDutiesIssued = 1 THEN
               N'Yes'
           ELSE
               N'No'
       END AS clientDutiesIssued,
       CASE
           WHEN md.CDMStrategyIssued = 1 THEN
               N'Yes'
           ELSE
               N'No'
       END AS CDMStrategyIssued,
       -- [PCI]
       CASE
           WHEN md.PCICompleted = 1 THEN
               N'Yes'
           ELSE
               N'No'
       END AS PCIInspectionCompleted,
       CAST(md.PCIDate AS DATE) AS PCIDate,
       -- [RISK]
       CAST(ad.DRRLastIssued AS DATE) AS DRRLastIssued,
       -- [F10]
       CASE
           WHEN md.F10Applicable = 1 THEN
               N'Yes'
           ELSE
               N'No'
       END AS F10Applicable,
       CAST(md.F10IssuedDate AS DATE) AS F10IssuedDate,
       CAST(md.F10StartDate AS DATE) AS F10Start,
       DATEDIFF(WEEK, md.F10StartDate, md.F10DueDate) AS F10WeekDuration,
       CAST(md.F10ExpiryDate AS DATE) AS F10ExpiryDate,
       -- [CPP]
       CAST(md.CPPDateReceived AS DATE) AS CPPDateReceived,
       CAST(md.CPPReviewed AS DATE) AS CPPReviewed,
       -- [H&S FILE]
       CAST(md.HSFReviewedDate AS DATE) AS HSFReviewed,
       CAST(md.HSFCompletedDate AS DATE) AS HSFCompleted
FROM SJob.Jobs j
    JOIN SJob.JobStatus js
        ON js.ID = j.ID
    JOIN SJob.Assets p
        ON p.ID = j.UprnID
    JOIN SJob.JobTypes jt
        ON jt.ID = j.JobTypeID
    JOIN SCrm.Accounts client
        ON client.ID = j.ClientAccountID
    JOIN SCrm.Accounts agent
        ON agent.ID = j.AgentAccountID
    LEFT JOIN MilestoneData md
        ON md.JobID = j.ID
    LEFT JOIN FeeData fd
        ON fd.JobId = j.ID
    LEFT JOIN ActivityData ad
        ON ad.JobID = j.ID
WHERE j.IsActive = 1
      AND j.RowStatus NOT IN ( 0, 254 )
      AND j.SurveyorID = @UserID
      AND j.ID > 0
      AND EXISTS
(
    SELECT 1 FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserID)
);
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[PropertiesUpsert]'
GO
ALTER PROCEDURE SJob.PropertiesUpsert
	(	@ParentPropertyGuid UNIQUEIDENTIFIER,
		@Name NVARCHAR(100),
		@Number NVARCHAR(50),
		@AddressLine1 NVARCHAR(50),
		@AddressLine2 NVARCHAR(50),
		@AddressLine3 NVARCHAR(50),
		@Town NVARCHAR(50),
		@CountyGuid UNIQUEIDENTIFIER,
		@Postcode NVARCHAR(50),
		@CountryGuid UNIQUEIDENTIFIER,
		@LocalAuthorityAccountGuid UNIQUEIDENTIFIER,
		@FireAuthorityAccountGuid UNIQUEIDENTIFIER,
		@WaterAuthorityAccountGuid UNIQUEIDENTIFIER,
		@Latitude DECIMAL(9, 6),
		@Longitude DECIMAL(9, 6),
		@IsHighRiskBuilding BIT,
		@IsComplexBuilding BIT,
		@BuildingHeightInMetres DECIMAL(9,2),
		@OwnerAccountGuid UNIQUEIDENTIFIER,
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @ParentPropertyID		 INT		  = -1,
			@LocalAuthorityAccountID INT,
			@FireAuthorityAccountID	 INT,
			@WaterAuthorityAccountID INT,
			@OwnerAccountID INT,	
			@FormattedAddressComma	 NVARCHAR(600),
			@FormattedAddressCR		 NVARCHAR(600),
			@IsInsert				 BIT		  = 0,
			@UPRN					 INT,
			@CountyID				 INT,
			@CountyName				 NVARCHAR(50),
			@CountryID				 INT;

	SELECT	@ParentPropertyID = ID
	FROM	SJob.Assets
	WHERE	(Guid = @ParentPropertyGuid);

	SELECT	@LocalAuthorityAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @LocalAuthorityAccountGuid);

	SELECT	@FireAuthorityAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @FireAuthorityAccountGuid);

	SELECT	@WaterAuthorityAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @WaterAuthorityAccountGuid);

	SELECT	@OwnerAccountID = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @OwnerAccountGuid);

	SELECT	@CountyID	= ID,
			@CountyName = Name
	FROM	SCrm.Counties
	WHERE	(Guid = @CountyGuid);

	SELECT	@CountryID = ID
	FROM	SCrm.Countries
	WHERE	(Guid = @CountryGuid);

	SELECT	@FormattedAddressComma = SCore.FormatAddress (	 N'',
															 @Number,
															 @AddressLine1,
															 @AddressLine2,
															 @AddressLine3,
															 @Town,
															 @CountyName,
															 @Postcode,
															 N', '
														 ),
			@FormattedAddressCR	   = SCore.FormatAddress (	 N'',
															 @Number,
															 @AddressLine1,
															 @AddressLine2,
															 @AddressLine3,
															 @Town,
															 @CountyName,
															 @Postcode,
															 CHAR (13)
														 );

    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'Properties',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN

		INSERT	SJob.Assets
			 (RowStatus,
			  Guid,
			  ParentPropertyID,
			  Name,
			  Number,
			  AddressLine1,
			  AddressLine2,
			  AddressLine3,
			  Town,
			  CountyId,
			  Postcode,
			  CountryId,
			  LocalAuthorityAccountID,
			  WaterAuthorityAccountID,
			  FireAuthorityAccountID,
			  FormattedAddressComma,
			  FormattedAddressCR,
			  Latitude,
			  Longitude,
			  IsHighRiskBuilding,
			  IsComplexBuilding,
			  BuildingHeightInMetres,
			  OwnerAccountId)
		VALUES
			 (
				 0,
				 @Guid,
				 @ParentPropertyID,
				 @Name,
				 @Number,
				 @AddressLine1,
				 @AddressLine2,
				 @AddressLine3,
				 @Town,
				 @CountyID,
				 @Postcode,
				 @CountryID,
				 @LocalAuthorityAccountID,
				 @WaterAuthorityAccountID,
				 @FireAuthorityAccountID,
				 @FormattedAddressComma,
				 @FormattedAddressCR,
				 @Latitude,
				 @Longitude,
				 @IsHighRiskBuilding,
				 @IsComplexBuilding,
				 @BuildingHeightInMetres,
				 @OwnerAccountID
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.Assets
		SET		ParentPropertyID = @ParentPropertyID,
				Name = @Name,
				Number = @Number,
				AddressLine1 = @AddressLine1,
				AddressLine2 = @AddressLine2,
				AddressLine3 = @AddressLine3,
				Town = @Town,
				CountyId = @CountyID,
				Postcode = @Postcode,
				@CountryID = @CountryID,
				LocalAuthorityAccountID = @LocalAuthorityAccountID,
				WaterAuthorityAccountID = @WaterAuthorityAccountID,
				FireAuthorityAccountID = @FireAuthorityAccountID,
				FormattedAddressComma = @FormattedAddressComma,
				FormattedAddressCR = @FormattedAddressCR,
				Latitude = @Latitude,
				Longitude = @Longitude,
				IsHighRiskBuilding = @IsHighRiskBuilding,
				IsComplexBuilding = @IsComplexBuilding,
				BuildingHeightInMetres = @BuildingHeightInMetres,
				OwnerAccountId = @OwnerAccountID
		WHERE	(Guid = @Guid);
	END;

	IF (@IsInsert = 1)
	BEGIN
		SELECT	@UPRN = NEXT VALUE FOR SJob.UPRN;

		UPDATE	SJob.Assets
		SET		UPRN = @UPRN,
				RowStatus = 1
		WHERE	(Guid = @Guid);
	END;

	/* Tempoary addition until have have the System Bus */

	DECLARE @FilingObjectName NVARCHAR(250),
			@FilingLocation	  NVARCHAR(MAX);

	SELECT	@FilingLocation =
			(
				SELECT ss.SiteIdentifier,
					spf.FolderPath
				FROM	SCore.ObjectSharePointFolder AS spf
				JOIN	SCore.SharepointSites ss ON (ss.ID = spf.SharepointSiteId)
				WHERE	(spf.ObjectGuid = @Guid)
				FOR JSON PATH
			);

	SELECT	@FilingObjectName = p.Name + N' ' + p.FormattedAddressComma,
			@UPRN			  = p.UPRN
	FROM	SJob.Assets AS p
	WHERE	(p.Guid = @Guid);

	EXEC SOffice.TargetObjectUpsert @EntityTypeGuid = N'2cfbff39-93cd-436b-b8ca-b2fcf7609707',	-- uniqueidentifier
									@RecordGuid = @Guid,										-- uniqueidentifier
									@Number = @UPRN,										-- bigint
									@Name = @FilingObjectName,									-- nvarchar(250)
									@FilingLocation = @FilingLocation

END;
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[EnquiryCreateQuotes]'
GO





ALTER PROCEDURE SSop.EnquiryCreateQuotes
	(@Guid UNIQUEIDENTIFIER)
AS
BEGIN

	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SSop.Enquiries AS q
		 WHERE	(q.Guid					 = @Guid)
			AND (q.IsReadyForQuoteReview = 0)
	 )
	   )
	BEGIN
		;
		THROW 60000, N'The enquiry must be marked ready for review first.', 1;
	END;

	IF (NOT EXISTS
	 (
		 SELECT 1
		 FROM	SSop.EnquiryServices AS es
		 JOIN	SSop.Enquiries		 AS e ON (e.ID = es.EnquiryId)
		 WHERE	(e.Guid = @Guid)
			AND (NOT EXISTS
			 (
				 SELECT 1
				 FROM	SSop.Quotes AS q
				 WHERE	(q.EnquiryServiceID = es.ID)
					AND (q.RowStatus NOT IN (0, 254))
			 )
				)
	 )
	   )
	BEGIN
		;
		THROW 60000, N'Nothing to create', 1;
	END;

	/* Get the details of the enquiry. */
	DECLARE @PropertyGuid			   UNIQUEIDENTIFIER,
			@PropertyNameNumber		   NVARCHAR(50),
			@PropertyAddressLine1	   NVARCHAR(50),
			@PropertyAddressLine2	   NVARCHAR(50),
			@PropertyAddressLine3	   NVARCHAR(50),
			@PropertyTown			   NVARCHAR(50),
			@PropertyCountyGuid		   UNIQUEIDENTIFIER,
			@PropertyPostCode		   NVARCHAR(50),
			@PropertyCountryGuid	   UNIQUEIDENTIFIER,
			@ClientAccountGuid		   UNIQUEIDENTIFIER,
			@ClientAddressGuid		   UNIQUEIDENTIFIER,
			@ClientContactGuid		   UNIQUEIDENTIFIER,
			@ClientName				   NVARCHAR(250),
			@ClientAddressNameNumber   NVARCHAR(50),
			@ClientAddressLine1		   NVARCHAR(50),
			@ClientAddressLine2		   NVARCHAR(50),
			@ClientAddressLine3		   NVARCHAR(50),
			@ClientAddressTown		   NVARCHAR(50),
			@ClientAddressCountyGuid   UNIQUEIDENTIFIER,
			@ClientAddressPostCode	   NVARCHAR(50),
			@ClientAddressCountryGuid  UNIQUEIDENTIFIER,
			@AgentAccountGuid		   UNIQUEIDENTIFIER,
			@AgentAddressGuid		   UNIQUEIDENTIFIER,
			@AgentContactGuid		   UNIQUEIDENTIFIER,
			@AgentName				   NVARCHAR(250),
			@AgentAddressNameNumber	   NVARCHAR(50),
			@AgentAddressLine1		   NVARCHAR(50),
			@AgentAddressLine2		   NVARCHAR(50),
			@AgentAddressLine3		   NVARCHAR(50),
			@AgentAddressTown		   NVARCHAR(50),
			@AgentAddressCountyGuid	   UNIQUEIDENTIFIER,
			@AgentAddressPostCode	   NVARCHAR(50),
			@AgentAddressCountryGuid   UNIQUEIDENTIFIER,
			@AccountStatusGuid		   UNIQUEIDENTIFIER,
			@QuotingUserGuid		   UNIQUEIDENTIFIER,
			@FinanceAccountGuid		   UNIQUEIDENTIFIER,
			@FinanceAddressGuid		   UNIQUEIDENTIFIER,
			@FinanceContactGuid		   UNIQUEIDENTIFIER,
			@FinanceName			   NVARCHAR(250),
			@FinanceAddressNameNumber  NVARCHAR(50),
			@FinanceAddressLine1	   NVARCHAR(50),
			@FinanceAddressLine2	   NVARCHAR(50),
			@FinanceAddressLine3	   NVARCHAR(50),
			@FinanceAddressTown		   NVARCHAR(50),
			@FinanceAddressCountyGuid  UNIQUEIDENTIFIER,
			@FinanceAddressPostCode	   NVARCHAR(50),
			@FinanceAddressCountryGuid UNIQUEIDENTIFIER,
			@ProjectGuid			   UNIQUEIDENTIFIER,
			@IsClientFinanceAccount	   BIT,
			@JobTypeId                 INT, --[CBLD-590]
			@BillingInstruction		   NVARCHAR(MAX); --It was missing


	SELECT	@PropertyGuid			   = uprn.Guid,
			@PropertyNameNumber		   = e.PropertyNameNumber,
			@PropertyAddressLine1	   = e.PropertyAddressLine1,
			@PropertyAddressLine2	   = e.PropertyAddressLine2,
			@PropertyAddressLine3	   = e.PropertyAddressLine3,
			@PropertyTown			   = e.PropertyTown,
			@PropertyCountyGuid		   = uprnc.Guid,
			@PropertyPostCode		   = e.PropertyPostCode,
			@PropertyCountryGuid	   = uprncr.Guid,
			@ClientAccountGuid		   = c.Guid,
			@ClientAddressGuid		   = c_add.Guid,
			@ClientContactGuid		   = c_con.Guid,
			@ClientName				   = e.ClientName,
			@ClientAddressNameNumber   = e.ClientAddressNameNumber,
			@ClientAddressLine1		   = e.ClientAddressLine1,
			@ClientAddressLine2		   = e.ClientAddressLine2,
			@ClientAddressLine3		   = e.ClientAddressLine3,
			@ClientAddressTown		   = e.ClientAddressTown,
			@ClientAddressCountyGuid   = c_add_c.Guid,
			@ClientAddressPostCode	   = e.ClientAddressPostCode,
			@ClientAddressCountryGuid  = c_add_cr.Guid,
			@AgentAccountGuid		   = a.Guid,
			@AgentAddressGuid		   = a_add.Guid,
			@AgentContactGuid		   = a_con.Guid,
			@AgentName				   = e.AgentName,
			@AgentAddressNameNumber	   = e.AgentAddressNameNumber,
			@AgentAddressLine1		   = e.AgentAddressLine1,
			@AgentAddressLine2		   = e.AgentAddressLine2,
			@AgentAddressLine3		   = e.AgentAddressLine3,
			@AgentAddressTown		   = e.AgentTown,
			@AgentAddressCountyGuid	   = a_add_c.Guid,
			@AgentAddressPostCode	   = e.AgentAddressPostCode,
			@AgentAddressCountryGuid   = a_add_cr.Guid,
			@FinanceAccountGuid		   = f.Guid,
			@FinanceAddressGuid		   = f_add.Guid,
			@FinanceContactGuid		   = f_con.Guid,
			@FinanceName			   = e.FinanceAccountName,
			@FinanceAddressNameNumber  = e.FinanceAddressNameNumber,
			@FinanceAddressLine1	   = e.FinanceAddressLine1,
			@FinanceAddressLine2	   = e.FinanceAddressLine2,
			@FinanceAddressLine3	   = e.FinanceAddressLine3,
			@FinanceAddressTown		   = e.FinanceTown,
			@FinanceAddressCountyGuid  = f_add_c.Guid,
			@FinanceAddressPostCode	   = e.FinancePostCode,
			@FinanceAddressCountryGuid = f_add_cr.Guid,
			@QuotingUserGuid		   = i.Guid,
			@IsClientFinanceAccount	   = e.IsClientFinanceAccount,
			@ProjectGuid			   = p.Guid
	FROM	SSop.Enquiries			  AS e
	JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID			  = e.OrganisationalUnitID)
	JOIN	SCore.Identities		  AS i ON (i.ID				  = e.CreatedByUserId)
	JOIN	SJob.Assets			  AS uprn ON (uprn.ID		  = e.PropertyId)
	JOIN	SCrm.Counties			  AS uprnc ON (uprnc.ID		  = e.PropertyCountyId)
	JOIN	SCrm.Countries			  AS uprncr ON (uprncr.ID	  = e.PropertyCountryId)
	JOIN	SCrm.Accounts			  AS c ON (c.ID				  = e.ClientAccountId)
	JOIN	SCrm.AccountAddresses	  AS c_add ON (c_add.ID		  = e.ClientAddressId)
	JOIN	SCrm.Counties			  AS c_add_c ON (c_add_c.ID	  = e.ClientAddressCountyId)
	JOIN	SCrm.Countries			  AS c_add_cr ON (c_add_cr.ID = e.ClientAddressCountryId)
	JOIN	SCrm.AccountContacts	  AS c_con ON (c_con.ID		  = e.ClientAccountContactId)
	JOIN	SCrm.Accounts			  AS a ON (a.ID				  = e.AgentAccountId)
	JOIN	SCrm.AccountAddresses	  AS a_add ON (a_add.ID		  = e.AgentAddressId)
	JOIN	SCrm.Counties			  AS a_add_c ON (a_add_c.ID	  = e.AgentCountyId)
	JOIN	SCrm.Countries			  AS a_add_cr ON (a_add_cr.ID = e.AgentCountryId)
	JOIN	SCrm.Accounts			  AS f ON (f.ID				  = e.FinanceAccountId)
	JOIN	SCrm.AccountAddresses	  AS f_add ON (f_add.ID		  = e.FinanceAddressId)
	JOIN	SCrm.Counties			  AS f_add_c ON (f_add_c.ID	  = e.FinanceCountyId)
	JOIN	SCrm.Countries			  AS f_add_cr ON (f_add_cr.ID = f_add_c.CountryID)
	JOIN	SCrm.AccountContacts	  AS f_con ON (f_con.ID		  = e.FinanceContactId)
	JOIN	SCrm.AccountContacts	  AS a_con ON (a_con.ID		  = e.AgentAccountContactId)
	JOIN	SSop.Projects			  AS p ON (p.ID				  = e.ProjectId)
	WHERE	(e.Guid = @Guid);

	/* Convert new structure details */
	IF (@PropertyGuid = '00000000-0000-0000-0000-000000000000')
	BEGIN
		SET @PropertyGuid = NEWID ();

		EXEC SJob.PropertiesUpsert @ParentPropertyGuid = '00000000-0000-0000-0000-000000000000',		-- uniqueidentifier
								   @Name = N'',															-- nvarchar(100)
								   @Number = @PropertyNameNumber,										-- nvarchar(50)
								   @AddressLine1 = @PropertyAddressLine1,								-- nvarchar(50)
								   @AddressLine2 = @PropertyAddressLine2,								-- nvarchar(50)
								   @AddressLine3 = @PropertyAddressLine3,								-- nvarchar(50)
								   @Town = @PropertyTown,												-- nvarchar(50)
								   @CountyGuid = @PropertyCountyGuid,									-- nvarchar(50)
								   @Postcode = @PropertyPostCode,										-- nvarchar(50)
								   @CountryGuid = @PropertyCountryGuid,
								   @LocalAuthorityAccountGuid = '00000000-0000-0000-0000-000000000000', -- uniqueidentifier
								   @FireAuthorityAccountGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
								   @WaterAuthorityAccountGuid = '00000000-0000-0000-0000-000000000000', -- uniqueidentifier
								   @Latitude = 0,														-- decimal(9, 6)
								   @Longitude = 0,														-- decimal(9, 6)
								   @IsHighRiskBuilding = 0,
								   @IsComplexBuilding = 0,
								   @BuildingHeightInMetres = 0,
								   @OwnerAccountGuid = '00000000-0000-0000-0000-000000000000',
								   @Guid = @PropertyGuid;												-- uniqueidentifier

	END;

	SELECT	@AccountStatusGuid = s.Guid
	FROM	SCrm.AccountStatus AS s
	WHERE	(s.Name = N'Prospect');

	/* Convert new client details */
	IF (@ClientAccountGuid = '00000000-0000-0000-0000-000000000000')
   AND	(@ClientName <> N'')
	BEGIN
		SET @ClientAccountGuid = NEWID ();

		EXEC SCrm.AccountsUpsert @Name = @ClientName,											-- nvarchar(250)
								 @Code = N'',													-- nvarchar(10)
								 @AccountStatusGuid = @AccountStatusGuid,						-- uniqueidentifier
								 @ParentAccountGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
								 @IsPurchaseLedger = 0,											-- bit
								 @IsSalesLedger = 1,											-- bit
								 @IsLocalAuthority = 0,											-- bit
								 @IsFireAuthority = 0,											-- bit
								 @IsWaterAuthority = 0,											-- bit
								 @RelationshipManagerUserGuid = @QuotingUserGuid,				-- uniqueidentifier
								 @CompanyRegistrationNumber = N'',								-- nvarchar(50)
								 @MainAccountContactGuid = '00000000-0000-0000-0000-000000000000',
								 @MainAccountAddressGuid = '00000000-0000-0000-0000-000000000000',
								 @Guid = @ClientAccountGuid,									-- uniqueidentifier
								 @BillingInstruction = NULL; --Since it is a new Account record, we can set it to null

	END;

	IF (
		   @ClientAddressGuid = '00000000-0000-0000-0000-000000000000'
	   AND	@ClientAddressNameNumber <> N''
	   )
	BEGIN
		SET @ClientAddressGuid = NEWID ();

		EXEC SCrm.AddressUpsert @AddressNumber = 0,							-- int
								@Name = N'',								-- nvarchar(100)
								@Number = @ClientAddressNameNumber,			-- nvarchar(100)
								@AddressLine1 = @ClientAddressLine1,		-- nvarchar(255)
								@AddressLine2 = @ClientAddressLine2,		-- nvarchar(255)
								@AddressLine3 = @ClientAddressLine3,		-- nvarchar(255)
								@Town = @ClientAddressTown,					-- nvarchar(255)
								@CountyGuid = @ClientAddressCountyGuid,		-- uniqueidentifier
								@Postcode = @ClientAddressPostCode,			-- nvarchar(50)
								@CountryGuid = @ClientAddressCountryGuid,	-- uniqueidentifier
								@Guid = @ClientAddressGuid OUTPUT;			-- uniqueidentifier

		DECLARE @AccountAddressGuid UNIQUEIDENTIFIER = NEWID ();

		EXEC SCrm.AccountAddressesUpsert @AccountGuid = @ClientAccountGuid, -- uniqueidentifier
										 @AddressGuid = @ClientAddressGuid, -- uniqueidentifier
										 @Guid = @AccountAddressGuid;		-- uniqueidentifier

		SET @ClientAddressGuid = @AccountAddressGuid;

		IF (EXISTS
		 (
			 SELECT 1
			 FROM	SCrm.Accounts AS a
			 WHERE	(a.MainAccountAddressId < 0)
				AND (a.Guid					= @ClientAccountGuid)
		 )
		   )
		BEGIN
			UPDATE	a
			SET		a.MainAccountAddressId = aa.ID
			FROM	SCrm.Accounts		  AS a
			JOIN	SCrm.AccountAddresses AS aa ON (aa.AccountID = a.ID)
			WHERE	(a.Guid = @ClientAccountGuid);
		END;
	END;

	IF (@IsClientFinanceAccount = 1)
	BEGIN
		SET @FinanceAccountGuid = @ClientAccountGuid;
		SET @FinanceAddressGuid = @ClientAddressGuid;
		SET @FinanceContactGuid = @ClientContactGuid;
	END;

	/* Convert new agent details */
	IF (@AgentAccountGuid = '00000000-0000-0000-0000-000000000000')
   AND	(@AgentName <> N'')
	BEGIN
		SET @AgentAccountGuid = NEWID ();

		EXEC SCrm.AccountsUpsert @Name = @AgentName,											-- nvarchar(250)
								 @Code = N'',													-- nvarchar(10)
								 @AccountStatusGuid = @AccountStatusGuid,						-- uniqueidentifier
								 @ParentAccountGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
								 @IsPurchaseLedger = 0,											-- bit
								 @IsSalesLedger = 1,											-- bit
								 @IsLocalAuthority = 0,											-- bit
								 @IsFireAuthority = 0,											-- bit
								 @IsWaterAuthority = 0,											-- bit
								 @RelationshipManagerUserGuid = @QuotingUserGuid,				-- uniqueidentifier
								 @CompanyRegistrationNumber = N'',								-- nvarchar(50)
								 @MainAccountAddressGuid = '00000000-0000-0000-0000-000000000000',
								 @MainAccountContactGuid = '00000000-0000-0000-0000-000000000000',
								 @Guid = @AgentAccountGuid,										-- uniqueidentifier
								 @BillingInstruction = NULL; --Same as above --> Since it is new, it can be set to null.

	END;

	IF (
		   @AgentAddressGuid = '00000000-0000-0000-0000-000000000000'
	   AND	@AgentAddressNameNumber <> N''
	   )
	BEGIN
		SET @AgentAddressGuid = NEWID ();

		EXEC SCrm.AddressUpsert @AddressNumber = 0,							-- int
								@Name = N'',								-- nvarchar(100)
								@Number = @AgentAddressNameNumber,			-- nvarchar(100)
								@AddressLine1 = @AgentAddressLine1,			-- nvarchar(255)
								@AddressLine2 = @AgentAddressLine2,			-- nvarchar(255)
								@AddressLine3 = @AgentAddressLine3,			-- nvarchar(255)
								@Town = @AgentAddressTown,					-- nvarchar(255)
								@CountyGuid = @AgentAddressCountyGuid,		-- uniqueidentifier
								@Postcode = @AgentAddressPostCode,			-- nvarchar(50)
								@CountryGuid = @AgentAddressCountryGuid,	-- uniqueidentifier
								@Guid = @AgentAddressGuid OUTPUT;			-- uniqueidentifier

		DECLARE @AgentAccountAddressGuid UNIQUEIDENTIFIER = NEWID ();

		EXEC SCrm.AccountAddressesUpsert @AccountGuid = @AgentAccountGuid,	-- uniqueidentifier
										 @AddressGuid = @AgentAddressGuid,	-- uniqueidentifier
										 @Guid = @AgentAccountAddressGuid;	-- uniqueidentifier

		SET @AgentAddressGuid = @AgentAccountAddressGuid;

		IF (EXISTS
		 (
			 SELECT 1
			 FROM	SCrm.Accounts AS a
			 WHERE	(a.MainAccountAddressId < 0)
				AND (a.Guid					= @AgentAccountGuid)
		 )
		   )
		BEGIN
			UPDATE	a
			SET		a.MainAccountAddressId = aa.ID
			FROM	SCrm.Accounts		  AS a
			JOIN	SCrm.AccountAddresses AS aa ON (aa.AccountID = a.ID)
			WHERE	(a.Guid = @AgentAccountGuid);
		END;
	END;

	/* Convert new finance details */
	IF (@FinanceAccountGuid = '00000000-0000-0000-0000-000000000000')
   AND	(@FinanceName <> N'')
   AND	(@IsClientFinanceAccount = 0)
	BEGIN
		SET @FinanceAccountGuid = NEWID ();

		EXEC SCrm.AccountsUpsert @Name = @FinanceName,											-- nvarchar(250)
								 @Code = N'',													-- nvarchar(10)
								 @AccountStatusGuid = @AccountStatusGuid,						-- uniqueidentifier
								 @ParentAccountGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
								 @IsPurchaseLedger = 0,											-- bit
								 @IsSalesLedger = 1,											-- bit
								 @IsLocalAuthority = 0,											-- bit
								 @IsFireAuthority = 0,											-- bit
								 @IsWaterAuthority = 0,											-- bit
								 @RelationshipManagerUserGuid = @QuotingUserGuid,				-- uniqueidentifier
								 @CompanyRegistrationNumber = N'',								-- nvarchar(50)
								 @MainAccountAddressGuid = '00000000-0000-0000-0000-000000000000',
								 @MainAccountContactGuid = '00000000-0000-0000-0000-000000000000',
								 @Guid = @FinanceAccountGuid,									-- uniqueidentifier
								 @BillingInstruction = NULL; --Same as above -> New record can be set to null
	END;

	IF (
		   @FinanceAddressGuid = '00000000-0000-0000-0000-000000000000'
	   AND	@FinanceAddressNameNumber <> N''
	   AND	(@IsClientFinanceAccount = 0)
	   )
	BEGIN
		SET @FinanceAddressGuid = NEWID ();

		EXEC SCrm.AddressUpsert @AddressNumber = 0,							-- int
								@Name = N'',								-- nvarchar(100)
								@Number = @FinanceAddressNameNumber,		-- nvarchar(100)
								@AddressLine1 = @FinanceAddressLine1,		-- nvarchar(255)
								@AddressLine2 = @FinanceAddressLine2,		-- nvarchar(255)
								@AddressLine3 = @FinanceAddressLine3,		-- nvarchar(255)
								@Town = @FinanceAddressTown,				-- nvarchar(255)
								@CountyGuid = @FinanceAddressCountyGuid,	-- uniqueidentifier
								@Postcode = @FinanceAddressPostCode,		-- nvarchar(50)
								@CountryGuid = @FinanceAddressCountryGuid,	-- uniqueidentifier
								@Guid = @FinanceAddressGuid OUTPUT;			-- uniqueidentifier

		DECLARE @FinanceAccountAddressGuid UNIQUEIDENTIFIER = NEWID ();
		
		
		EXEC SCrm.AddressUpsert @AccountGuid = @FinanceAccountGuid, -- uniqueidentifier
								@AddressGuid = @FinanceAddressGuid, -- uniqueidentifier
								@Guid = @FinanceAccountAddressGuid; -- uniqueidentifier

		

		SET @FinanceAddressGuid = @FinanceAccountAddressGuid;

		IF (EXISTS
		 (
			 SELECT 1
			 FROM	SCrm.Accounts AS a
			 WHERE	(a.MainAccountAddressId < 0)
				AND (a.Guid					= @FinanceAccountGuid)
		 )
		   )
		BEGIN
			UPDATE	a
			SET		a.MainAccountAddressId = aa.ID
			FROM	SCrm.Accounts		  AS a
			JOIN	SCrm.AccountAddresses AS aa ON (aa.AccountID = a.ID)
			WHERE	(a.Guid = @FinanceAccountGuid);
		END;
	END;

	/* Build a consolidated list of quotes to create  */
	DECLARE @QuotesToCreate TABLE
		(
			ID INT NOT NULL PRIMARY KEY,
			Guid UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID (),
			OrganisationalUnitGuid UNIQUEIDENTIFIER NOT NULL,
			EnquiryGuid UNIQUEIDENTIFIER NOT NULL,
			DescriptionOfWorks NVARCHAR(4000) NOT NULL,
			JobTypeName NVARCHAR(100) NOT NULL,
			JobTypeId	INT NOT NULL, 
			SendInfoToClient BIT NOT NULL,
			SendInfoToAgent BIT NOT NULL,
			ExternalReference NVARCHAR(50) NOT NULL,
			ValueOfWork DECIMAL(19, 2) NOT NULL,
			CurrentStageGuid UNIQUEIDENTIFIER NOT NULL,
			AppointmentStageGuid UNIQUEIDENTIFIER NOT NULL,
			IsSubjectToNDA BIT NOT NULL,
			EnquiryServiceGuid UNIQUEIDENTIFIER NOT NULL
		);

	INSERT	@QuotesToCreate
		 (ID,
		  OrganisationalUnitGuid,
		  EnquiryGuid,
		  DescriptionOfWorks,
		  JobTypeName,
		  JobTypeId,
		  SendInfoToClient,
		  SendInfoToAgent,
		  ExternalReference,
		  ValueOfWork,
		  CurrentStageGuid,
		  AppointmentStageGuid,
		  IsSubjectToNDA,
		  EnquiryServiceGuid)
	SELECT	es.ID,
			ou.Guid,
			@Guid,
			e.DescriptionOfWorks,
			jt.Name,
			jt.ID, 
			e.SendInfoToClient,
			e.SendInfoToAgent,
			e.ExternalReference,
			e.ValueOfWork,
			cs.Guid,
			aps.Guid,
			e.IsSubjectToNDA,
			es.Guid
	FROM	SSop.EnquiryServices	  AS es
	JOIN	SSop.Enquiries			  AS e ON (e.ID		= es.EnquiryId)
	JOIN	SJob.JobTypes			  AS jt ON (jt.ID	= es.JobTypeId)
	JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID	= jt.OrganisationalUnitID)
	JOIN	SJob.RibaStages			  AS cs ON (cs.ID	= e.CurrentProjectRibaStageID)
	JOIN	SJob.RibaStages			  AS aps ON (aps.ID = es.StartRibaStageId)
	WHERE	(e.Guid = @Guid)
		AND (es.RowStatus NOT IN (0, 254))
		AND (NOT EXISTS
		(
			SELECT	1
			FROM	SSop.Quotes AS q
			WHERE	(q.EnquiryServiceID = es.ID)
				AND (q.RowStatus NOT IN (0, 254))
		)
			);

	IF NOT EXISTS
	 (
		 SELECT 1
		 FROM	@QuotesToCreate
	 )
	BEGIN
		;
		THROW 60000, N'There were no quotes to create', 1;
	END;

	/*
		  Loop through the list of Quotes executing QuotesUpsert
	  */
	DECLARE @CreatedDateTime		DATETIME2 = GETUTCDATE (),
			@ExpiryDate				DATETIME2 = DATEADD (	MONTH,
															6,
															GETUTCDATE ()
														),
			@OrganisationalUnitGuid UNIQUEIDENTIFIER,
			@DescriptionOfWorks		NVARCHAR(4000),
			@QuoteGuid				UNIQUEIDENTIFIER,
			@MaxID					INT,
			@CurrentId				INT,
			@ExternalReference		NVARCHAR(50),
			@CurrentStageGuid		UNIQUEIDENTIFIER,
			@AppointmentStageGuid	UNIQUEIDENTIFIER,
			@EnquiryServiceGuid		UNIQUEIDENTIFIER;


	SELECT	@MaxID	   = MAX (ID),
			@CurrentId = 0
	FROM	@QuotesToCreate;

	WHILE (@CurrentId < @MaxID)
	BEGIN
		SELECT		TOP (1) @CurrentId				= q.ID,
							@DescriptionOfWorks		= q.JobTypeName + N' -- ' + q.DescriptionOfWorks,
							@QuoteGuid				= q.Guid,
							@OrganisationalUnitGuid = q.OrganisationalUnitGuid,
							@ExternalReference		= q.ExternalReference,
							@CurrentStageGuid		= q.CurrentStageGuid,
							@AppointmentStageGuid	= q.AppointmentStageGuid,
							@EnquiryServiceGuid		= q.EnquiryServiceGuid,
							@JobTypeId = q.JobTypeId
		FROM		@QuotesToCreate AS q
		WHERE		(q.ID > @CurrentId)
		ORDER BY	q.ID;

		EXEC SSop.QuotesUpsert @OrganisationalUnitGuid = @OrganisationalUnitGuid,		-- uniqueidentifier
							   @QuotingUserGuid = @QuotingUserGuid,						-- uniqueidentifier
							   @ContractGuid = '00000000-0000-0000-0000-000000000000',	-- uniqueidentifier
							   @Date = @CreatedDateTime,								-- date
							   @Overview = @DescriptionOfWorks,							-- nvarchar(max)
							   @ExpiryDate = @ExpiryDate,								-- date
							   @DateSent = NULL,										-- date
							   @DateAccepted = NULL,									-- date
							   @DateRejected = NULL,									-- date
							   @RejectionReason = N'',									-- nvarchar(max)
							   @FeeCap = 0,												-- decimal(19, 2)
							   @IsFinal = 0,
							   @ExternalReference = @ExternalReference,
							   @QuotingConsultantGuid = @QuotingUserGuid,
							   @AppointmentFromRibaStageGuid = @AppointmentStageGuid,
							   @CurrentStageGuid = @CurrentStageGuid,
							   @DeadDate = NULL,
							   @EnquiryServiceGuid = @EnquiryServiceGuid,
							   @ProjectGuid = @ProjectGuid,
							   @Guid = @QuoteGuid,
							   @JobType = @EnquiryServiceGuid,	
							   @DescriptionOfWorks = @DescriptionOfWorks,
							   @DeclinedToQuoteReason = N'',
							   @ExclusionsAndLimitations = N'';
							  
	END;

	DECLARE @PropertyID		  INT,
			@ClientID		  INT,
			@AgentID		  INT,
			@FinanceID		  INT,
			@ClientAddressID  INT,
			@AgentAddressID	  INT,
			@FinanceAddressID INT;

	SELECT	@PropertyID = p.ID
	FROM	SJob.Assets AS p
	WHERE	(p.Guid = @PropertyGuid);

	SELECT	@ClientID = a.ID
	FROM	SCrm.Accounts AS a
	WHERE	(a.Guid = @ClientAccountGuid);

	SELECT	@ClientAddressID = a.ID
	FROM	SCrm.AccountAddresses AS a
	WHERE	(a.Guid = @ClientAddressGuid);

	SELECT	@AgentID = a.ID
	FROM	SCrm.Accounts AS a
	WHERE	(a.Guid = @AgentAccountGuid);

	SELECT	@AgentAddressID = a.ID
	FROM	SCrm.AccountAddresses AS a
	WHERE	(a.Guid = @AgentAddressGuid);

	SELECT	@FinanceID = a.ID
	FROM	SCrm.Accounts AS a
	WHERE	(a.Guid = @FinanceAccountGuid);

	SELECT	@FinanceAddressID = a.ID
	FROM	SCrm.AccountAddresses AS a
	WHERE	(a.Guid = @FinanceAddressGuid);

	/* Update the Enquiry with the created records */
	UPDATE	SSop.Enquiries
	SET		PropertyId = @PropertyID,
			ClientAccountId = @ClientID,
			AgentAccountId = @AgentID,
			FinanceAccountId = @FinanceID,
			ClientAddressId = @ClientAddressID,
			AgentAddressId = @AgentAddressID,
			FinanceAddressId = @FinanceAddressID,
			EnterNewClientDetails = 0,
			EnterNewAgentDetails = 0,
			EnterNewFinanceDetails = 0,
			EnterNewStructureDetails = 0
	WHERE	(Guid = @Guid);

END;
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_Property_DataPills]'
GO



ALTER FUNCTION SJob.tvf_Property_DataPills 
(
    @Guid UNIQUEIDENTIFIER,
	@RowStatus TINYINT,
	@Number NVARCHAR(50),
	@AddressLine1 NVARCHAR(50),
	@AddressLine2 NVARCHAR(50),
	@AddressLine3 NVARCHAR(50),
	@Town NVARCHAR(50),
	@CountyGuid UNIQUEIDENTIFIER,
	@PostCode NVARCHAR(50)
)
RETURNS @DataPills TABLE 
(
    [ID] [INT] IDENTITY(1,1) NOT NULL,
	[Label] NVARCHAR(50) NOT NULL,
	[Class] NVARCHAR(50) NOT NULL, 
	[SortOrder] INT NOT NULL
)
AS
BEGIN
	DECLARE @CountyName NVARCHAR(50)

    SELECT  @CountyName = Name
    FROM    SCrm.Counties 
    WHERE   ([Guid] = @CountyGuid)

    IF (@RowStatus = 0)
	BEGIN 
		IF (EXISTS
				(
					SELECT	1				
					FROM	SJob.Assets p
					WHERE	(DIFFERENCE(p.Number, @Number) = 4)
					AND	(
							@AddressLine1 IS NULL OR 
							@AddressLine1 != '' AND 
							p.AddressLine1 != '' AND DIFFERENCE(p.AddressLine1, @AddressLine1) = 4
						)
					AND	(
							@AddressLine2 IS NULL OR 
							@AddressLine2 != '' AND 
							p.AddressLine2 != '' AND DIFFERENCE(p.AddressLine2, @AddressLine2) = 4
						)
					AND	(
							@AddressLine3 IS NULL OR 
							@AddressLine3 != '' AND 
							p.AddressLine3 != '' AND DIFFERENCE(p.AddressLine3, @AddressLine3) = 4
						)
					AND	(
							@Town IS NULL OR 
							@Town != '' AND 
							p.Town != '' AND DIFFERENCE(p.Town, @Town) = 4
						)
					AND	(
							@PostCode IS NULL OR 
							@PostCode != '' AND 
							p.Postcode != '' AND DIFFERENCE(p.Postcode, @PostCode) = 4
						)
					AND	(p.RowStatus NOT IN (0, 254))
					AND	(p.id > 0)				
					AND p.Guid <> @Guid		
				)
			)
		BEGIN 
			INSERT @DataPills
				(
					Label, Class, SortOrder
				)
			VALUES(
					  N'A similar property to this already exists!',	-- Label - nvarchar(50)
					  N'bg-warning',	-- Class - nvarchar(50)
					  1		-- SortOrder - int
				  )
		END
	END

	

    RETURN
END

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_Enquiry_DataPills]'
GO




ALTER FUNCTION SSop.tvf_Enquiry_DataPills
	(
		@Guid UNIQUEIDENTIFIER,
		@RowStatus TINYINT,
		@Number NVARCHAR(50),
		@AddressLine1 NVARCHAR(50),
		@AddressLine2 NVARCHAR(50),
		@AddressLine3 NVARCHAR(50),
		@Town NVARCHAR(50),
		@CountyGuid UNIQUEIDENTIFIER,
		@PostCode NVARCHAR(50),
		@ClientAccountGuid UNIQUEIDENTIFIER,
		@ClientName NVARCHAR(250),
		@AgentAccountGuid UNIQUEIDENTIFIER,
		@AgentName NVARCHAR(250),
		@ProjectGuid UNIQUEIDENTIFIER,
		@IsSubjectToNDA BIT,
		@FinanceAccountGuid UNIQUEIDENTIFIER, -- NEW
		@UseClientAsFinance BIT				  -- NEW
	)
RETURNS @DataPills TABLE
	(
		ID INT IDENTITY(1, 1) NOT NULL,
		Label NVARCHAR(50) NOT NULL,
		Class NVARCHAR(50) NOT NULL,
		SortOrder INT NOT NULL
	)
AS
BEGIN
	DECLARE @CountyName NVARCHAR(50),
			@FTPredicate NVARCHAR(250)

	SELECT	@CountyName = Name
	FROM	SCrm.Counties
	WHERE	(Guid = @CountyGuid);

	IF (
		   @Number <> N''
		OR	@AddressLine1 <> N''
		OR	@AddressLine2 <> N''
		OR	@AddressLine3 <> N''
		OR	@Town <> N''
		OR	@PostCode <> N''
	   )
	BEGIN
		IF (EXISTS
		 (
			 SELECT 1
			 FROM	SJob.Assets AS p
			 WHERE	(DIFFERENCE (	p.Number,
									@Number
								)	   = 4
					)
				AND
					(
						@AddressLine1 IS NULL
					 OR @AddressLine1  <> N''
					AND p.AddressLine1 <> N''
					AND DIFFERENCE (   p.AddressLine1,
									   @AddressLine1
								   )   = 4
					)
				AND
					(
						@AddressLine2 IS NULL
					 OR @AddressLine2  <> N''
					AND p.AddressLine2 <> N''
					AND DIFFERENCE (   p.AddressLine2,
									   @AddressLine2
								   )   = 4
					)
				AND
					(
						@AddressLine3 IS NULL
					 OR @AddressLine3  <> N''
					AND p.AddressLine3 <> N''
					AND DIFFERENCE (   p.AddressLine3,
									   @AddressLine3
								   )   = 4
					)
				AND
					(
						@Town IS NULL
					 OR @Town		   <> N''
					AND p.Town		   <> N''
					AND DIFFERENCE (   p.Town,
									   @Town
								   )   = 4
					)
				AND
					(
						@PostCode IS NULL
					 OR @PostCode	   <> N''
					AND p.Postcode	   <> N''
					AND DIFFERENCE (   p.Postcode,
									   @PostCode
								   )   = 4
					)
				AND (p.RowStatus NOT IN (0, 254))
				AND (p.ID			   > 0)
				AND p.Guid			   <> @Guid
		 )
		   )
		BEGIN
			INSERT	@DataPills
				 (Label, Class, SortOrder)
			VALUES
				 (
					 N'A similar property to this already exists!', -- Label - nvarchar(50)
					 N'bg-warning',									-- Class - nvarchar(50)
					 1												-- SortOrder - int
				 );
		END;
	END;

	IF (
		   @ClientAccountGuid = '00000000-0000-0000-0000-000000000000'
	   AND	@ClientName <> N''
	   )
	BEGIN
		SET @FTPredicate = N'"' + @ClientName + N'"'

		IF (EXISTS
		 (
			 SELECT		1
			 FROM		SCrm.Accounts								   AS a
			 INNER JOIN FREETEXTTABLE
									(SCrm.Accounts, Name, @FTPredicate) AS KEY_TBL ON (KEY_TBL.[KEY] = a.ID)
			 WHERE		(a.RowStatus NOT IN (0, 254))
					AND (a.ID > 0)
		 )
		   )
		BEGIN
			INSERT	@DataPills
				 (Label, Class, SortOrder)
			VALUES
				 (
					 N'A similar account to the client already exists!',	-- Label - nvarchar(50)
					 N'bg-warning',											-- Class - nvarchar(50)
					 1														-- SortOrder - int
				 );
		END;
	END;

	IF (
		   @AgentAccountGuid = '00000000-0000-0000-0000-000000000000'
	   AND	@AgentName <> N''
	   )
	BEGIN
		SET @FTPredicate = N'"' + @AgentName + N'"'

		IF (EXISTS
		 (
			 SELECT		1
			 FROM		SCrm.Accounts								   AS a
			 INNER JOIN FREETEXTTABLE
									(SCrm.Accounts, Name, @FTPredicate) AS KEY_TBL ON (KEY_TBL.[KEY] = a.ID)
			 WHERE		(a.RowStatus NOT IN (0, 254))
					AND (a.ID > 0)
		 )
		   )
		BEGIN
			INSERT	@DataPills
				 (Label, Class, SortOrder)
			VALUES
				 (
					 N'A similar account to the agent already exists!', -- Label - nvarchar(50)
					 N'bg-warning',										-- Class - nvarchar(50)
					 1													-- SortOrder - int
				 );
		END;
	END;

	--IF (@ProjectGuid <> '00000000-0000-0000-0000-000000000000') -- OLD
	--BEGIN
	--	SELECT	@IsSubjectToNDA = p.IsSubjectToNDA
	--	FROM	SSop.Projects AS p
	--	WHERE	(p.Guid = @ProjectGuid);
	--END;

	IF (@ProjectGuid <> '00000000-0000-0000-0000-000000000000' AND @IsSubjectToNDA = 0) -- Added "AND @IsSubjectToNDA = 0) for CBLD-638
	BEGIN
		SELECT	@IsSubjectToNDA = p.IsSubjectToNDA
		FROM	SSop.Projects AS p
		WHERE	(p.Guid = @ProjectGuid);
	END;

	IF (@IsSubjectToNDA = 1)
	BEGIN
		INSERT	@DataPills
			 (Label, Class, SortOrder)
		VALUES
			 (
				 N'NDA',		-- Label - nvarchar(50)
				 N'bg-danger',	-- Class - nvarchar(50)
				 1				-- SortOrder - int
			 );
	END;

	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SCrm.Accounts	   AS a
		 JOIN	SCrm.AccountStatus AS st ON (st.ID = a.AccountStatusID)
		 WHERE	(a.Guid	   = @ClientAccountGuid)
			AND (st.IsHold = 1)
	 )
	   )
	BEGIN
		INSERT	@DataPills
			 (Label, Class, SortOrder)
		VALUES
			 (
				 N'Client Account Hold',	-- Label - nvarchar(50)
				 N'bg-danger',				-- Class - nvarchar(50)
				 1							-- SortOrder - int
			 );
	END;

	IF (EXISTS
	 (
		 SELECT 1
		 FROM	SCrm.Accounts	   AS a
		 JOIN	SCrm.AccountStatus AS st ON (st.ID = a.AccountStatusID)
		 WHERE	(a.Guid	   = @AgentAccountGuid)
			AND (st.IsHold = 1)
	 )
	   )
	BEGIN
		INSERT	@DataPills
			 (Label, Class, SortOrder)
		VALUES
			 (
				 N'Agent Account Hold', -- Label - nvarchar(50)
				 N'bg-danger',			-- Class - nvarchar(50)
				 1						-- SortOrder - int
			 );
	END;

	 -- Finance Account On Credit Hold => "Use Client as Finance Account" is not enabled
	  IF (EXISTS
			(
				SELECT 
						1
				FROM 
						SCrm.Accounts Ac
				WHERE Ac.Guid = @FinanceAccountGuid AND Ac.AccountStatusID = 4
			)	
		)
      BEGIN
        INSERT @DataPills
              (
                Label,
                Class,
                SortOrder
              )
        VALUES
                (
                  N'Credit Hold',	-- Label - nvarchar(50)
                  N'bg-danger',	-- Class - nvarchar(50)
                  1		-- SortOrder - int
                )
      END;

	  -- Finance Account On Credit Hold => "Use Client as Finance Account" is enabled
	  IF @UseClientAsFinance = 1
	  BEGIN
		  IF (EXISTS
				(
					SELECT 
							1
					FROM 
							SCrm.Accounts Ac
					WHERE Ac.Guid = @ClientAccountGuid AND Ac.AccountStatusID = 4
				)	
			)
		  BEGIN
			INSERT @DataPills
				  (
					Label,
					Class,
					SortOrder
				  )
			VALUES
					(
					  N'Credit Hold',	-- Label - nvarchar(50)
					  N'bg-danger',	-- Class - nvarchar(50)
					  1		-- SortOrder - int
					)
		  END;
		END;

	-- Warn if the quote is accepted but jobs haven't been created. 
	DECLARE @JobsToCreate INT;

	SELECT	@JobsToCreate = COUNT (1)
	FROM	SSop.Quote_JobsSummary			 AS js
	JOIN	SSop.Quotes						 AS q ON (q.Guid		  = js.QuoteGuid)
	JOIN	SSop.EnquiryService_ExtendedInfo AS esei ON (esei.QuoteID = q.ID)
	JOIN	SSop.EnquiryServices			 AS es ON (es.ID		  = esei.Id)
	JOIN	SSop.Enquiries					 AS e ON (e.ID			  = es.EnquiryId)
	WHERE	(e.Guid = @Guid)
		AND (q.ID	> 0)
		AND (q.DateAccepted IS NOT NULL)
		AND (EXISTS
		(
			SELECT	1
			FROM	SSop.QuoteItems AS qi
			WHERE	(qi.CreatedJobId < 0)
				AND (qi.RowStatus NOT IN (0, 254))
		)
			);

	IF (@JobsToCreate > 0)
	BEGIN
		INSERT	@DataPills
			 (Label, Class, SortOrder)
		VALUES
			 (
				 CONVERT (	 NVARCHAR(50),
							 @JobsToCreate
						 ) + N' job(s) pending creation.',	-- Label - nvarchar(50)
				 N'bg-warning',								-- Class - nvarchar(50)
				 1											-- SortOrder - int
			 );
	END;

	INSERT	@DataPills
		 (Label, Class, SortOrder)
	SELECT	ecf.EnquiryStatus,	-- Label - nvarchar(50)
			CASE
				WHEN ecf.EnquiryStatus IN (N'Accepted', N'Complete') THEN N'bg-success'
				WHEN ecf.EnquiryStatus IN (N'Part Accepted', N'Deadline Approaching') THEN N'bg-warning'
				WHEN ecf.EnquiryStatus IN (N'Rejected', N'Dead', N'Deadline Missed') THEN N'bg-danger'
				ELSE N'bg-info'
			END,				-- Class - nvarchar(50)
			1					-- SortOrder - int
	FROM	SSop.Enquiries				  AS e
	JOIN	SSop.Enquiry_CalculatedFields AS ecf ON (ecf.ID = e.ID)
	WHERE	(e.Guid = @Guid);

	RETURN;
END;

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[Project_ExtendedInfo]'
GO
EXEC sp_refreshview N'[SSop].[Project_ExtendedInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_Jobs]'
GO


ALTER FUNCTION SJob.tvf_Jobs 
(
    @UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN 
SELECT  j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        j.JobTypeID,
        jt.Name AS JobTypeName,
		i.Guid SurveyorGuid,
		i.FullName AS SurveyorName, 
		prop.FormattedAddressComma,
		client.Name + N' / ' + agent.Name AS  ClientAgent,
		js.IsSubjectToNDA,
		j.IsComplete,
		js.JobStatus,
		org.Name AS OrgUnit,
		j.CreatedOn AS Date
FROM    SJob.Jobs j
JOIN	SJob.JobStatus js ON (js.ID = j.ID)
JOIN    SJob.JobTypes jt ON (j.JobTypeID = jt.ID)
JOIN    SCore.Identities i ON (j.SurveyorID = i.ID)
JOIN	SJob.Assets prop ON (prop.ID = j.UprnID)
JOIN	SCrm.Accounts client ON (client.ID = j.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = j.AgentAccountID)
JOIN    SCore.OrganisationalUnits as org ON (org.ID = j.OrganisationalUnitID)
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(j.Id > 0)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[JobPaymentStages_List]'
GO
EXEC sp_refreshview N'[SJob].[JobPaymentStages_List]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[EnquiriesUpsert]'
GO







ALTER PROCEDURE SSop.EnquiriesUpsert
	(	
		@OrganisationalUnitGuid UNIQUEIDENTIFIER,
		@Date DATETIME2,
		@CreatedByUserGuid UNIQUEIDENTIFIER,
		@PropertyGuid UNIQUEIDENTIFIER,
		@PropertyNameNumber NVARCHAR(100),
		@PropertyAddressLine1 NVARCHAR(255),
		@PropertyAddressLine2 NVARCHAR(255),
		@PropertyAddressLine3 NVARCHAR(255),
		@PropertyCountyGuid UNIQUEIDENTIFIER,
		@PropertyPostCode NVARCHAR(30),
		@PropertyCountryGuid UNIQUEIDENTIFIER,
		@ClientAccountGuid UNIQUEIDENTIFIER,
		@ClientAddressGuid UNIQUEIDENTIFIER,
		@ClientAccountContactGuid UNIQUEIDENTIFIER,
		@ClientName NVARCHAR(250),
		@ClientAddressNameNumber NVARCHAR(100),
		@ClientAddressLine1 NVARCHAR(255),
		@ClientAddressLine2 NVARCHAR(255),
		@ClientAddressLine3 NVARCHAR(255),
		@ClientAddressCountyGuid UNIQUEIDENTIFIER,
		@ClientAddressPostCode NVARCHAR(30),
		@ClientAddressCountryGuid UNIQUEIDENTIFIER,
		@AgentAccountGuid UNIQUEIDENTIFIER,
		@AgentAddressGuid UNIQUEIDENTIFIER,
		@AgentAccountContactGuid UNIQUEIDENTIFIER,
		@AgentName NVARCHAR(250),
		@AgentAddressNameNumber NVARCHAR(100),
		@AgentAddressLine1 NVARCHAR(255),
		@AgentAddressLine2 NVARCHAR(255),
		@AgentAddressLine3 NVARCHAR(255),
		@AgentAddressCountyGuid UNIQUEIDENTIFIER,
		@AgentAddressPostCode NVARCHAR(30),
		@AgentAddressCountryGuid UNIQUEIDENTIFIER,
		@DescriptionOfWorks NVARCHAR(4000),
		@ValueOfWork DECIMAL(19,2),
		@CurrentProjectRobaStageGuid UNIQUEIDENTIFIER,
		@RibaStage0Months INT,
		@RibaStage1Months INT,
		@RibaStage2Months INT,
		@RibaStage3Months INT,
		@RibaStage4Months INT,
		@RibaStage5Months INT,
		@RibaStage6Months INT,
		@RibaStage7Months INT,
		@PreConstructionStageMonths INT, 
		@ConstructionStageMonths INT,
		@SendInfoToClient BIT,
		@SendInfoToAgent BIT,
		@KeyDates NVARCHAR(2000),
		@ExpectedProcurementRoute NVARCHAR(200),
		@Notes NVARCHAR(MAX),
		@EnquirySourceGuid UNIQUEIDENTIFIER,
		@IsReadyForQuoteReview BIT,
		@QuotingDeadlineDate DATE,
		@DeclinedToQuoteDate DATE,
		@DeclinedToQuoteReason NVARCHAR(4000),
		@ExternalReference NVARCHAR(50),
		@ProjectGuid UNIQUEIDENTIFIER,
		@IsSubjectToNDA BIT, 
		@DeadDate DATE,
		@ChaseDate1 DATE, 
		@ChaseDate2 DATE,
		@FinanceAccountGuid UNIQUEIDENTIFIER,
		@FinanceAddressGuid UNIQUEIDENTIFIER,
		@FinanceContactGuid UNIQUEIDENTIFIER,
		@FinanceAccountName NVARCHAR(250),
		@FinanceAddressNameNumber NVARCHAR(100),
		@FinanceAddressLine1 NVARCHAR(255),
		@FinanceAddressLine2 NVARCHAR(255),
		@FinanceAddressLine3 NVARCHAR(255),
		@FinanceCountyGuid UNIQUEIDENTIFIER,
		@FinancePostCode NVARCHAR(30),
		@EnterNewClientDetails BIT,
		@EnterNewAgentDetails BIT,
		@EnterNewFinanceDetails BIT,
		@EnterNewStructureDetails BIT,
		@IsClientFinanceAccount BIT,
		@SignatoryIdentityGuid UNIQUEIDENTIFIER,
		@ProposalLetter NVARCHAR(MAX),
		@Guid UNIQUEIDENTIFIER
	)
AS
BEGIN
	DECLARE @OrganisationalUnitId INT = -1,
			@CreatedByUserId INT = -1,
			@PropertyId INT = -1,
			@PropertyCountyId INT = -1,
			@PropertyCountryId INT = -1,
			@ClientAccountId INT = -1,
			@ClientAddressId INT = -1,
			@ClientAccountContactId INT = -1,
			@ClientAddressCountyId INT = -1,
			@ClientAddressCountryId INT = -1,
			@AgentAccountId INT = -1,
			@AgentAddressId INT = -1,
			@AgentAccountContactId INT = -1,
			@AgentAddressCountyId INT = -1,
			@AgentAddressCountryId INT = -1,
			@FinanceAccountId INT = -1, 
			@FinanceAddressId INT = -1,
			@FinanceAccountContactId INT = -1, 
			@FinanceAddressCountyId INT = -1, 
			@CurrentProjectRibaStageId INT = -1,
			@IsInsert BIT,
			@EnquiryId INT,
			@EnquiryNumber INT,
			@EnquirySourceId INT,
			@ProjectId int = -1,
			@SignatoryIdentityId INT = -1,
			@NewProject bit = 0, 
			@ProjectDescription nvarchar(max) = N'Auto Generated Project for Enquiry ' + N'[[number]] - ' + @DescriptionOfWorks

	SELECT	@OrganisationalUnitId = ID
	FROM	SCore.OrganisationalUnits
	WHERE	(Guid = @OrganisationalUnitGuid);

	IF (@ProjectGuid = '00000000-0000-0000-0000-000000000000')
	BEGIN 
		SET @ProjectGuid = NEWID()
		SET @NewProject = 1

		EXEC SSop.ProjectsUpsert @ExternalReference = N'',					-- nvarchar(50)
								 @ProjectDescription = @ProjectDescription,					-- nvarchar(max)
								 @ProjectProjectedStartDate = NULL, -- date
								 @ProjectProjectedEndDate = NULL,	-- date
								 @ProjectCompleted = NULL,			-- date
								 @IsSubjectToNDA = @IsSubjectToNDA,					-- bit
								 @Guid = @ProjectGuid								-- uniqueidentifier
		
	END

	SELECT	@ProjectId = ID 
	FROM	SSop.Projects 
	WHERE	(Guid = @ProjectGuid)

	SELECT	@SignatoryIdentityId = id
	FROM	SCore.Identities AS i 
	WHERE	(Guid = @SignatoryIdentityGuid)

	SELECT	@CreatedByUserId = ID
	FROM	SCore.Identities
	WHERE	(Guid = @CreatedByUserGuid);

	SELECT	@ClientAccountId = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @ClientAccountGuid);

	SELECT	@ClientAddressId = ID
	FROM	SCrm.AccountAddresses
	WHERE	(Guid = @ClientAddressGuid);

	SELECT	@ClientAccountContactId = ID
	FROM	SCrm.AccountContacts
	WHERE	(Guid = @ClientAccountContactGuid)

	SELECT	@AgentAccountId = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @AgentAccountGuid);

	SELECT	@AgentAddressId = ID
	FROM	SCrm.AccountAddresses
	WHERE	(Guid = @AgentAddressGuid);

	SELECT	@AgentAccountContactID = ID
	FROM	SCrm.AccountContacts 
	WHERE	(Guid = @AgentAccountContactGuid)

	SELECT	@FinanceAccountId = ID
	FROM	SCrm.Accounts
	WHERE	(Guid = @FinanceAccountGuid);

	SELECT	@FinanceAddressId = ID
	FROM	SCrm.AccountAddresses
	WHERE	(Guid = @FinanceAddressGuid);

	SELECT	@FinanceAccountContactID = ID
	FROM	SCrm.AccountContacts 
	WHERE	(Guid = @FinanceContactGuid)

	SELECT	@PropertyId = ID
	FROM	SJob.Assets
	WHERE	(Guid = @PropertyGuid);

	SELECT	@CurrentProjectRibaStageId = ID 
	FROM	SJob.RibaStages
	WHERE	(Guid = @CurrentProjectRobaStageGuid)

	SELECT	@EnquirySourceId = ID 
	FROM	SSop.QuoteSources 
	WHERE	(Guid = @EnquirySourceGuid)

	IF (@EnterNewStructureDetails = 0)
	BEGIN 
		SET @PropertyNameNumber = N''
		SET @PropertyAddressLine1 = N''
		SET @PropertyAddressLine2 = N''
		SET @PropertyAddressLine3 = N''
		SET @PropertyPostCode = N''
		SET @PropertyCountyId = -1
		SET @PropertyCountryId = -1
	END
	ELSE
	BEGIN 
		SELECT	@PropertyCountyId = ID 
		FROM	SCrm.Counties 
		WHERE	(Guid = @PropertyCountyGuid)

		SELECT	@PropertyCountryID = ID 
		FROM	SCrm.Countries
		WHERE	(Guid = @PropertyCountryGuid)
	END

	IF (@EnterNewClientDetails = 0)
	BEGIN 
		SET @ClientName = N''
		SET @ClientAddressNameNumber = N''
		SET @ClientAddressLine1 = N''
		SET @ClientAddressLine2 = N''
		SET @ClientAddressLine3 = N''
		SET @ClientAddressPostCode = N''
		SET @ClientAddressCountyId = -1
		SET @ClientAddressCountryId = -1
	END
	ELSE 
	BEGIN 
		SELECT	@ClientAddressCountyId = ID
		FROM	SCrm.Counties
		WHERE	(Guid = @ClientAddressCountyGuid)

		SELECT	@ClientAddressCountryId = ID
		FROM	SCrm.Countries 
		WHERE	(Guid = @ClientAddressCountryGuid)
	END

	IF (@EnterNewAgentDetails = 0)
	BEGIN 
		SET @AgentName = N''
		SET @AgentAddressNameNumber = N''
		SET @AgentAddressLine1 = N''
		SET @AgentAddressLine2 = N''
		SET @AgentAddressLine3 = N''
		SET @AgentAddressPostCode = N''
		SET @AgentAddressCountyId = -1
		SET @AgentAddressCountryId = -1
	END
	ELSE 
	BEGIN 
		SELECT	@FinanceAddressCountyId = ID
		FROM	SCrm.Counties
		WHERE	(Guid = @FinanceCountyGuid)

		SELECT	@AgentAddressCountryId = ID
		FROM	SCrm.Countries 
		WHERE	(Guid = @AgentAddressCountryGuid)
	END

	IF (@EnterNewFinanceDetails = 0)
	BEGIN 
		SET @FinanceAccountName = N''
		SET @FinanceAddressNameNumber = N''
		SET @FinanceAddressLine1 = N''
		SET @FinanceAddressLine2 = N''
		SET @FinanceAddressLine3 = N''
		SET @FinancePostCode = N''
		SET @FinanceAddressCountyId = -1
	END
	ELSE 
	BEGIN 
		SELECT	@AgentAddressCountyId = ID
		FROM	SCrm.Counties
		WHERE	(Guid = @AgentAddressCountyGuid)
	END
	
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SSop',				-- nvarchar(255)
							@ObjectName = N'Enquiries',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

	IF (@IsInsert = 1)
	BEGIN
		INSERT	SSop.Enquiries
			 (RowStatus,
			  Guid,
			  OrganisationalUnitID,
			  Date,
			  CreatedByUserId,
			  Number,
			  PropertyId,
			  PropertyNameNumber,
			  PropertyAddressLine1,
			  PropertyAddressLine2,
			  PropertyAddressLine3,
			  PropertyCountyId,
			  PropertyPostCode,
			  PropertyCountryId,
			  ClientAccountId,
			  ClientAddressId,
			  ClientAccountContactId,
			  ClientName,
			  ClientAddressNameNumber,
			  ClientAddressLine1,
			  ClientAddressLine2,
			  ClientAddressLine3,
			  ClientAddressCountyId,
			  ClientAddressPostCode,
			  ClientAddressCountryId,
			  AgentAccountId,
			  AgentAddressId,
			  AgentAccountContactId,
			  AgentName,
			  AgentAddressNameNumber,
			  AgentAddressLine1,
			  AgentAddressLine2,
			  AgentAddressLine3,
			  AgentCountyId,
			  AgentAddressPostCode,
			  AgentCountryId,
			  DescriptionOfWorks,
			  ValueOfWork,
			  CurrentProjectRibaStageID,
			  RibaStage0Months,
			  RibaStage1Months,
			  RibaStage2Months,
			  RibaStage3Months,
			  RibaStage4Months,
			  RibaStage5Months,
			  RibaStage6Months,
			  RibaStage7Months,
			  PreConstructionStageMonths,
			  ConstructionStageMonths,
			  SendInfoToClient,
			  SendInfoToAgent,
			  KeyDates,
			  ExpectedProcurementRoute,
			  Notes,
			  IsReadyForQuoteReview,
			  EnquirySourceId,
			  QuotingDeadlineDate,
			  DeclinedToQuoteDate,
			  DeclinedToQuoteReason,
			  ExternalReference,
			  ProjectId,
			  IsSubjectToNDA,
			  DeadDate,
			  ChaseDate1,
			  ChaseDate2,
			  FinanceAccountId,
			  FinanceAddressId,
			  FinanceContactId,
			  FinanceAccountName,
			  FinanceAddressNameNumber,
			  FinanceAddressLine1,
			  FinanceAddressLine2,
			  FinanceAddressLine3,
			  FinanceCountyId,
			  FinancePostCode,
			  EnterNewClientDetails,
			  EnterNewAgentDetails,
			  EnterNewFinanceDetails,
			  EnterNewStructureDetails,
			  IsClientFinanceAccount,
			  SignatoryIdentityId,
			  ProposalLetter
			  )
		VALUES
			 (
				 1,	-- RowStatus - tinyint
				 @Guid,	-- Guid - uniqueidentifier
				 @OrganisationalUnitId,	-- OrganisationalUnitID - int
				 @Date,	-- Date - datetime2(7)
				 @CreatedByUserId,	-- CreatedByUserId - int
				 0,	-- Number - int
				 @PropertyId,	-- PropertyId - int
				 @PropertyNameNumber,	-- PropertyNameNumber - nvarchar(50)
				 @PropertyAddressLine1,	-- PropertyAddressLine1 - nvarchar(50)
				 @PropertyAddressLine2,	-- PropertyAddressLine2 - nvarchar(50)
				 @PropertyAddressLine3,	-- PropertyAddressLine3 - nvarchar(50)
				 @PropertyCountyId,	-- PropertyCountyId - int
				 @PropertyPostCode,	-- PropertyPostCode - nvarchar(50)
				 @PropertyCountryId,	-- PropertyCountryId - int
				 @ClientAccountId,	-- ClientAccountId - int
				 @ClientAddressId,	-- ClientAddressId - int
				 @ClientAccountContactId,
				 @ClientName,	-- ClientName - nvarchar(250)
				 @ClientAddressNameNumber,	-- ClientAddressNameNumber - nvarchar(50)
				 @ClientAddressLine1,	-- ClientAddressLine1 - nvarchar(50)
				 @ClientAddressLine2,	-- ClientAddressLine2 - nvarchar(50)
				 @ClientAddressLine3,	-- ClientAddressLine3 - nvarchar(50)
				 @ClientAddressCountyId,	-- ClientAddressCountyId - int
				 @ClientAddressPostCode,	-- ClientAddressPostCode - nvarchar(50)
				 @ClientAddressCountryId,	-- ClientAddressCountryId - int
				 @AgentAccountId,	-- AgentAccountId - int
				 @AgentAddressId,	-- AgentAddressId - int
				 @AgentAccountContactId,
				 @AgentName,	-- AgentName - nvarchar(250)
				 @AgentAddressNameNumber,	-- AgentAddressNameNumber - nvarchar(50)
				 @AgentAddressLine1,	-- AgentAddressLine1 - nvarchar(50)
				 @AgentAddressLine2,	-- AgentAddressLine2 - nvarchar(50)
				 @AgentAddressLine3,	-- AgentAddressLine3 - nvarchar(50)
				 @AgentAddressCountyId,	-- AgentCountyId - int
				 @AgentAddressPostCode,	-- AgentAddressPostCode - nvarchar(50)
				 @AgentAddressCountryId,	-- AgentCountryId - int
				 @DescriptionOfWorks,	-- DescriptionOfWorks - nvarchar(4000)
				 @ValueOfWork,	-- ValueOfWork - decimal(9, 2)
				 @CurrentProjectRibaStageId,	-- CurrentProjectRibaStageID - int
				 @RibaStage0Months,	-- RibaStage0Months - int
				 @RibaStage1Months,	-- RibaStage1Months - int
				 @RibaStage2Months,	-- RibaStage2Months - int
				 @RibaStage3Months,	-- RibaStage3Months - int
				 @RibaStage4Months,	-- RibaStage4Months - int
				 @RibaStage5Months,	-- RibaStage5Months - int
				 @RibaStage6Months,	-- RibaStage6Months - int
				 @RibaStage7Months,	-- RibaStage7Months - int
				 @PreConstructionStageMonths,
				 @ConstructionStageMonths,
				 @SendInfoToClient,	-- SendInfoToClient - bit
				 @SendInfoToAgent,	-- SendInfoToAgent - bit
				 @KeyDates,	-- KeyDates - nvarchar(2000)
				 @ExpectedProcurementRoute,	-- ExpectedProcurementRoute - nvarchar(200)
				 @Notes,	-- Notes - nvarchar(max)
				 @IsReadyForQuoteReview,
				 @EnquirySourceId,
				 @QuotingDeadlineDate,
				 @DeclinedToQuoteDate,
				 @DeclinedToQuoteReason,
				 @ExternalReference,
				 @ProjectId,
				 @IsSubjectToNDA,
				 @DeadDate,
				 @ChaseDate1, 
				 @ChaseDate2,
				 @FinanceAccountId,
				 @FinanceAddressId,
				 @FinanceAccountContactId,
				 @FinanceAccountName,
				 @FinanceAddressNameNumber,
				 @FinanceAddressLine1,
				 @FinanceAddressLine2,
				 @FinanceAddressLine3,
				 @FinanceAddressCountyId,
				 @FinancePostCode,
				 @EnterNewClientDetails,
				 @EnterNewAgentDetails,
				 @EnterNewFinanceDetails,
				 @EnterNewStructureDetails,
				 @IsClientFinanceAccount,
				 @SignatoryIdentityId,
				 @ProposalLetter
			 )

			 --UPDATE SSop.Projects
			 --SET IsSubjectToNDA = @IsSubjectToNDA
			 --WHERE ID = @ProjectId;

			 SELECT @EnquiryId = SCOPE_IDENTITY()
	END;
	ELSE
	BEGIN
		UPDATE	SSop.Enquiries
		SET		OrganisationalUnitID = @OrganisationalUnitId,
			  PropertyId = @PropertyId,
			  PropertyNameNumber = @PropertyNameNumber,
			  PropertyAddressLine1 = @PropertyAddressLine1,
			  PropertyAddressLine2 = @PropertyAddressLine2,
			  PropertyAddressLine3 = @PropertyAddressLine3,
			  PropertyCountyId = @PropertyCountyId,
			  PropertyPostCode = @PropertyPostCode,
			  PropertyCountryId = @PropertyCountryId,
			  ClientAccountId = @ClientAccountId,
			  ClientAddressId = @ClientAddressId,
			  ClientAccountContactId = @ClientAccountContactId,
			  ClientName = @ClientName,
			  ClientAddressNameNumber = @ClientAddressNameNumber,
			  ClientAddressLine1 = @ClientAddressLine1,
			  ClientAddressLine2 = @ClientAddressLine2,
			  ClientAddressLine3 = @ClientAddressLine3,
			  ClientAddressCountyId = @ClientAddressCountyId,
			  ClientAddressPostCode = @ClientAddressPostCode,
			  ClientAddressCountryId = @ClientAddressCountryId,
			  AgentAccountId = @AgentAccountId,
			  AgentAddressId = @AgentAddressId,
			  AgentAccountContactId = @AgentAccountContactId,
			  AgentName = @AgentName,
			  AgentAddressNameNumber = @AgentAddressNameNumber,
			  AgentAddressLine1 = @AgentAddressLine1,
			  AgentAddressLine2 = @AgentAddressLine2,
			  AgentAddressLine3 = @AgentAddressLine3,
			  AgentCountyId = @AgentAddressCountyId,
			  AgentAddressPostCode = @AgentAddressPostCode,
			  AgentCountryId = @AgentAddressCountryId,
			  DescriptionOfWorks = @DescriptionOfWorks,
			  ValueOfWork = @ValueOfWork,
			  CurrentProjectRibaStageID = @CurrentProjectRibaStageId,
			  RibaStage0Months = @RibaStage0Months,
			  RibaStage1Months = @RibaStage1Months,
			  RibaStage2Months = @RibaStage2Months,
			  RibaStage3Months = @RibaStage3Months,
			  RibaStage4Months = @RibaStage4Months,
			  RibaStage5Months = @RibaStage5Months,
			  RibaStage6Months = @RibaStage6Months,
			  RibaStage7Months = @RibaStage7Months,
			  PreConstructionStageMonths = @PreConstructionStageMonths,
			  ConstructionStageMonths = @ConstructionStageMonths,
			  SendInfoToClient = @SendInfoToClient,
			  SendInfoToAgent = @SendInfoToAgent,
			  KeyDates = @KeyDates,
			  ExpectedProcurementRoute = @ExpectedProcurementRoute,
			  Notes = @Notes,
			  IsReadyForQuoteReview = @IsReadyForQuoteReview,
			  EnquirySourceId = @EnquirySourceId,
			  QuotingDeadlineDate = @QuotingDeadlineDate,
			  DeclinedToQuoteDate = @DeclinedToQuoteDate,
			  DeclinedToQuoteReason = @DeclinedToQuoteReason,
			  ExternalReference = @ExternalReference,
			  ProjectId = @ProjectId,
			  IsSubjectToNDA = @IsSubjectToNDA,
			  DeadDate = @DeadDate,
			  ChaseDate1 = @ChaseDate1,
			  ChaseDate2 = @ChaseDate2,
			  FinanceAccountId = @FinanceAccountId,
			  FinanceAddressId = @FinanceAddressId,
			  FinanceContactId = @FinanceAccountContactId,
			  FinanceAccountName = @FinanceAccountName,
			  FinanceAddressNameNumber = @FinanceAddressNameNumber,
			  FinanceAddressLine1 = @FinanceAddressLine1,
			  FinanceAddressLine2 = @FinanceAddressLine2,
			  FinanceAddressLine3 = @FinanceAddressLine3,
			  FinanceCountyId = @FinanceAddressCountyId,
			  FinancePostCode = @FinancePostCode,
			  EnterNewClientDetails = @EnterNewClientDetails,
			  EnterNewAgentDetails = @EnterNewAgentDetails,
			  EnterNewFinanceDetails = @EnterNewFinanceDetails,
			  EnterNewStructureDetails = @EnterNewStructureDetails,
			  IsClientFinanceAccount = @IsClientFinanceAccount,
			  SignatoryIdentityId = @SignatoryIdentityId,
			  ProposalLetter = @ProposalLetter
		WHERE	(Guid = @Guid);


		
			UPDATE SSop.Projects
			SET IsSubjectToNDA = @IsSubjectToNDA
			WHERE ID = @ProjectId;

	END;

	IF (@IsInsert = 1)
	BEGIN
		SELECT	@EnquiryNumber = NEXT VALUE FOR SSop.EnquiryNumber;

		UPDATE	SSop.Enquiries
		SET		Number = @EnquiryNumber,
				RowStatus = 1
		WHERE	(ID = @EnquiryId);

		IF @NewProject = 1 
		BEGIN 
			UPDATE	SSop.Projects
			SET		ProjectDescription = REPLACE(@ProjectDescription, '[[number]]', CONVERT(NVARCHAR(max), @EnquiryNumber))
			WHERE	(Guid = @ProjectGuid)
		END
	END;

	/* Tempoary addition until have have the System Bus */

	DECLARE @FilingObjectName NVARCHAR(250),
			@FilingLocation	  NVARCHAR(MAX);

	SELECT
			@FilingLocation =
			(
				SELECT
						ss.SiteIdentifier,
						spf.FolderPath
				FROM
						SCore.ObjectSharePointFolder AS spf
				JOIN
						SCore.SharepointSites ss ON (ss.ID = spf.SharepointSiteId)
				WHERE
						(spf.ObjectGuid = @Guid)
				FOR JSON PATH
			);

	DECLARE @EnquiryNumberString NVARCHAR(30)

	SELECT
			@FilingObjectName  = e.Number + N' ' + CASE WHEN p.Id > 0 THEN p.FormattedAddressComma ELSE e.PropertyNameNumber + N' ' + e.PropertyAddressLine1  END + N' - ' + CASE WHEN client.ID > 0 THEN client.Name ELSE e.ClientName END + N' / '
			+ CASE WHEN agent.ID > 0 THEN agent.Name ELSE e.AgentName END + N' - ' + e.DescriptionOfWorks,
			@EnquiryNumberString = e.Number
	FROM
			SSop.Enquiries AS e
	JOIN
			SJob.Assets AS p ON (p.ID = e.PropertyId)
	JOIN
			SCrm.Accounts AS client ON (client.ID = e.ClientAccountId)
	JOIN
			SCrm.Accounts AS agent ON (agent.ID = e.AgentAccountId)
	WHERE
			(e.Guid = @Guid);

	EXEC SOffice.TargetObjectUpsert
		@EntityTypeGuid = N'3B4F2DF9-B6CF-4A49-9EED-2206473867A1',	-- uniqueidentifier
		@RecordGuid		= @Guid,										-- uniqueidentifier
		@Number			= @EnquiryNumberString,										-- bigint
		@Name			= @FilingObjectName,									-- nvarchar(250)	
		@FilingLocation = @FilingLocation
END;


GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_EnquiriesForQuoteReview]'
GO






ALTER FUNCTION SSop.tvf_EnquiriesForQuoteReview
(
	@UserId INT
)
RETURNS TABLE
            --WITH SCHEMABINDING
AS RETURN	
SELECT  e.ID,
        e.RowStatus,
        e.RowVersion,
        e.Guid,
		e.Number,
		e.ExternalReference,
		LEFT(e.DescriptionOfWorks, 200) AS DescriptionOfWorks, 
		CASE WHEN acc.Name <> N'' THEN acc.Name ELSE e.ClientName END AS Account
FROM    SSop.Enquiries e
JOIN	SCrm.Accounts acc ON (acc.ID = e.ClientAccountID)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
WHERE   (e.RowStatus NOT IN (0, 254))
	AND	(e.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
			)
		)
	AND	(e.IsReadyForQuoteReview = 1)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SSop.EnquiryServices es
				WHERE	(es.EnquiryId = e.ID)
					AND	(es.RowStatus NOT IN (0, 254))
					AND	(NOT EXISTS
							(
								SELECT	1
								FROM	SSop.Quotes AS q
								WHERE	(q.EnquiryServiceID = es.ID)
									AND	(q.RowStatus NOT IN (0, 254))
							)
						)
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_QuotesReadyToSend]'
GO





ALTER FUNCTION SSop.tvf_QuotesReadyToSend
(
	@UserId INT
)
RETURNS TABLE
	   --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.FullNumber AS Number,
		LEFT(q.Overview, 200) AS Details, 
		acc.Name + N' / ' + aacc.Name AS Account,
		uprn.FormattedAddressComma
FROM    SSop.Quotes q
JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN	SCrm.Accounts acc ON (acc.ID = e.ClientAccountID)
JOIN	SCrm.Accounts aacc ON (aacc.ID = e.AgentAccountID)
JOIN	SJob.Assets uprn ON (uprn.ID = q.UprnId)
WHERE   (q.RowStatus NOT IN (0, 254))
	AND	(q.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
	AND	(q.IsFinal = 1)
	AND	(q.DateSent IS NULL)
	AND	(q.DateAccepted IS NULL)
	AND	(q.DateRejected IS NULL)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[Quote_MergeInfo]'
GO


ALTER VIEW SSop.Quote_MergeInfo
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
			qc.JobTitle																					 AS QuotingConsultantJobTitle
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_ProjectEnquiries]'
GO

ALTER FUNCTION SSop.tvf_ProjectEnquiries
	(
		@UserId INT,
		@ParentGuid UNIQUEIDENTIFIER
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
RETURN SELECT	e.ID,
				e.RowStatus,
				e.RowVersion,
				e.Guid,
				e.Number,
				e.DescriptionOfWorks,
				uprn.FormattedAddressComma,
				e.ExternalReference,
				CASE
					WHEN e.ClientAccountId < 0 THEN e.ClientName
					ELSE client.Name
				END + N' / ' + CASE
								   WHEN e.AgentAccountId < 0 THEN e.AgentName
								   ELSE agent.Name
							   END AS ClientAgent
	   FROM		SSop.Enquiries						 AS e
	   JOIN		SJob.Assets						 AS uprn ON (uprn.ID	 = e.PropertyId)
	   JOIN		SSop.Projects						 AS p ON (p.ID			 = e.ProjectId)
	   JOIN		SCrm.Accounts						 AS client ON (client.ID = e.ClientAccountId)
	   JOIN		SCrm.Accounts						 AS agent ON (agent.ID	 = e.AgentAccountId)
	   WHERE	(e.RowStatus NOT IN (0, 254))
			AND (p.Guid = @ParentGuid)
			AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (e.guid, @UserId) oscr
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_ProjectQuotes]'
GO
ALTER FUNCTION SSop.tvf_ProjectQuotes
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.Number,
		q.Overview,
		qc.FullName AS Consultant,
		qcf.QuoteStatus,
		uprn.FormattedAddressComma,
		client.Name + N' / ' + agent.Name AS ClientAgent
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN	SCore.Identities qc ON (qc.ID = q.QuotingConsultantId)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
JOIN	SSop.Projects p ON (p.ID = q.ProjectId)
JOIN	SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountID)
WHERE   (q.RowStatus NOT IN (0, 254))
	AND	(p.Guid = @ParentGuid)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (q.guid, @UserId) oscr
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[Jobs_Read]'
GO

ALTER VIEW SJob.Jobs_Read
AS
SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.AgreedFee,
		root_hobt.RibaStage1Fee,
		root_hobt.RibaStage2Fee,
		root_hobt.RibaStage3Fee,
		root_hobt.RibaStage4Fee,
		root_hobt.RibaStage5Fee,
		root_hobt.RibaStage6Fee,
		root_hobt.RibaStage7Fee,
		root_hobt.PreConstructionStageFee,
		root_hobt.ConstructionStageFee,
		root_hobt.ArchiveBoxReference,
		root_hobt.ArchiveReferenceLink,
		root_hobt.CreatedOn,
		root_hobt.ExternalReference,
		root_hobt.IsSubjectToNDA,
		root_hobt.JobCancelled,
		root_hobt.JobCompleted,
		root_hobt.JobDescription,
		root_hobt.JobStarted,
		root_hobt.Number,
		root_hobt.VersionID,
		root_hobt.IsCompleteForReview,
		root_hobt.ReviewedDateTimeUTC,
		root_hobt.LegacyID,
		root_hobt.AppFormReceived,
		root_hobt.FeeCap,
		root_hobt.JobDormant,
		root_hobt.DeadDate,
		root_hobt.PurchaseOrderNumber,
		root_hobt.ClientAppointmentReceived,
		root_hobt.ValueOfWork,
		rs.Guid								   AS CurrentRibaStageId,
		afs.Guid							   AS AppointedFromStageId,
		t.Guid								   AS JobTypeID,
		s.Guid								   AS SurveyorID,
		cb.Guid								   AS CreatedByUserID,
		ca.Guid								   AS ClientAccountID,
		aa.Guid								   AS AgentAccountID,
		fa.Guid								   AS FinanceAccountID,
		cc.Guid								   AS ClientContactID,
		ac.Guid								   AS AgentContactID,
		fc.Guid								   AS FinanceContactID,
		ou.Guid								   AS OrganisationalUnitID,
		'00000000-0000-0000-0000-000000000000' AS QuoteItemID,
		uprn.Guid							   AS UprnId,
		vow.Guid							   AS ValueOfWorkID,
		Rev.Guid							   AS ReviewedByUserID,
		con.Guid							   AS ContractID,
		cad.Guid							   AS ClientAddressID,
		aad.Guid							   AS AgentAddressID,
		fad.Guid							   AS FinanceAddressID,
		proj.Guid							   AS ProjectId,
		root_hobt.BillingInstruction		   AS BillingInstruction -- [CBLD-521]
FROM	SJob.Jobs				  AS root_hobt
JOIN	SJob.JobTypes			  AS t ON (t.ID		  = root_hobt.JobTypeID)
JOIN	SCore.Identities		  AS s ON (s.ID		  = root_hobt.SurveyorID)
JOIN	SCore.Identities		  AS cb ON (cb.ID	  = root_hobt.CreatedByUserID)
JOIN	SCrm.Accounts			  AS ca ON (ca.ID	  = root_hobt.ClientAccountID)
JOIN	SCrm.Accounts			  AS aa ON (aa.ID	  = root_hobt.AgentAccountID)
JOIN	SCrm.Accounts			  AS fa ON (fa.ID	  = root_hobt.FinanceAccountID)
JOIN	SCrm.AccountAddresses	  AS cad ON (cad.ID	  = root_hobt.ClientAddressID)
JOIN	SCrm.AccountAddresses	  AS aad ON (aad.ID	  = root_hobt.AgentAddressID)
JOIN	SCrm.AccountAddresses	  AS fad ON (fad.ID	  = root_hobt.FinanceAddressID)
JOIN	SCrm.AccountContacts	  AS cc ON (cc.ID	  = root_hobt.ClientContactID)
JOIN	SCrm.AccountContacts	  AS ac ON (ac.ID	  = root_hobt.AgentContactID)
JOIN	SCrm.AccountContacts	  AS fc ON (fc.ID	  = root_hobt.FinanceContactID)
JOIN	SJob.Assets			  AS uprn ON (uprn.ID = root_hobt.UprnID)
JOIN	SCore.OrganisationalUnits AS ou ON (ou.ID	  = root_hobt.OrganisationalUnitID)
JOIN	SJob.ValuesOfWork		  AS vow ON (vow.ID	  = root_hobt.ValueOfWorkID)
JOIN	SCore.Identities		  AS Rev ON (Rev.ID	  = root_hobt.ReviewedByUserID)
JOIN	SSop.Contracts			  AS con ON (con.ID	  = root_hobt.ContractID)
JOIN	SJob.RibaStages			  AS rs ON (rs.ID	  = root_hobt.CurrentRibaStageId)
JOIN	SJob.RibaStages			  AS afs ON (afs.ID	  = root_hobt.AppointedFromStageId)
JOIN	SSop.Projects			  AS proj ON (proj.ID = root_hobt.ProjectId)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[ScheduleOfClientInfo_MergeInfo]'
GO
EXEC sp_refreshview N'[SSop].[ScheduleOfClientInfo_MergeInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_PropertyEnquiries]'
GO


ALTER FUNCTION SJob.tvf_PropertyEnquiries
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  e.ID,
        e.RowStatus,
        e.RowVersion,
        e.Guid,
		e.Number,
		e.DescriptionOfWorks,
		e.ExternalReference,
		CASE WHEN e.ClientAccountId < 0 THEN e.ClientName ELSE client.Name END  + N' / ' + CASE WHEN e.AgentAccountId < 0 THEN e.AgentName ELSE  agent.Name END AS ClientAgent
FROM    SSop.Enquiries e 
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
JOIN	SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountID)
WHERE   (e.RowStatus NOT IN (0, 254))
	AND	(uprn.Guid = @ParentGuid)
	AND	(EXISTS
			(					
	SELECT
			1
	FROM
			SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SSop].[EnquiryAcceptanceServices_MergeInfo]'
GO
EXEC sp_refreshview N'[SSop].[EnquiryAcceptanceServices_MergeInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SCrm].[tvf_AccountEnquiries]'
GO


ALTER FUNCTION SCrm.tvf_AccountEnquiries
(
	@UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN
SELECT
		e.ID,
		e.RowStatus,
		e.RowVersion,
		e.Guid,
		e.Number,
		e.DescriptionOfWorks,
		UPRN.FormattedAddressComma,
		e.ExternalReference,
		CASE
				WHEN e.ClientAccountId < 0 THEN
					e.ClientName
				ELSE
				client.Name
		END + N' / ' +
					  CASE
							  WHEN e.AgentAccountId < 0 THEN
								  e.AgentName
							  ELSE
							  agent.Name
					  END AS ClientAgent
FROM
		SSop.Enquiries e
JOIN
		SJob.Assets uprn ON (UPRN.ID = e.PropertyId)
JOIN
		SCrm.Accounts client ON (client.ID = e.ClientAccountID)
JOIN
		SCrm.Accounts agent ON (agent.ID = e.AgentAccountID)
WHERE
		(e.RowStatus NOT IN (0, 254))
		AND (   (client.Guid = @ParentGuid)
				OR (agent.Guid = @ParentGuid))
		AND (EXISTS
		(
			SELECT
					1
			FROM
					SCore.ObjectSecurityForUser_CanRead(e.Guid, @UserId) oscr
		)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[Activity_MergeInfo]'
GO



ALTER VIEW SJob.Activity_MergeInfo
AS
SELECT		a.ID,																	-- was [Job ID]
			a.RowStatus,
			a.RowVersion,
			a.Guid,
			j.Guid AS ParentGuid,
			j.Number									AS JobNumber,				-- was [Job Number]
			j.JobDescription,														-- was [Job Title]
			jt.Name										AS JobType,					-- was Type,
																					/* Activity */
			a.Date										AS ActivityDate,
			a.Title										AS ActivityTitle,
			a.Notes										AS ActivityNotes,
			atype.Name									AS ActivityType,
																					/* UPRN */
			uprn.Number									AS UPRN,
			uprn.AddressLine1							AS PropertyAddressLine1,	-- was PropertyAddress1
			uprn.AddressLine2							AS PropertyAddressLine2,	-- was PropertyAddress2
			uprn.AddressLine3							AS PropertyAddressLine3,	-- was PropertyAddress3
			uprn.Town									AS PropertyTown,
			paddc.Name									AS PropertyCounty,
			uprn.Postcode								AS PropertyPostcode,
			uprn.FormattedAddressComma					AS PropertyAddress,
			uprn.FormattedAddressCR						AS PropertyAddressBlock,
			COALESCE (	 uprn.Name + ' ',
						 ''
					 ) + COALESCE (	  uprn.Number + ' ',
									  ''
								  ) + uprn.AddressLine1 AS PropertyShortAddress,
			la.Name										AS LocalAuthority,
																					/* Client */
			cacc.Name									AS ClientName,				-- was [Label] or [Title]
			cacc.CompanyRegistrationNumber				AS ClientCompanyRegNo,
			cadd.AddressLine1							AS ClientAddressLine1,		-- was ClientAddress1
			cadd.AddressLine2							AS ClientAddressLine2,		-- was ClientAddress2
			cadd.AddressLine3							AS ClientAddressLine3,		-- was ClientAddress3
			cadd.Town									AS ClientTown,
			caddc.Name									AS ClientCounty,
			cadd.Postcode								AS ClientPostcode,
			cadd.FormattedAddressComma					AS ClientAddress,			-- was AddressClient
			cadd.FormattedAddressCR						AS ClientAddressBlock,
			ccon.DisplayName							AS ClientContactName,
			ccon.FirstName								AS ClientFirstName,
			ccon.Surname								AS ClientSurname,
			ccon.Email									AS ClientEmail,
			ccon.Phone									AS ClientPhone,
			ccon.Mobile									AS ClientMobile,
																					/* Agent */
			aacc.Name									AS AgentName,
			aacc.CompanyRegistrationNumber				AS AgentCompanyRegNo,
			aadd.AddressLine1							AS AgentAddressLine1,
			aadd.AddressLine2							AS AgentAddressLine2,
			aadd.AddressLine3							AS AgentAddressLine3,
			aadd.Town									AS AgentTown,
			aaddc.Name									AS AgentCounty,
			aadd.Postcode								AS AgentPostcode,
			aadd.FormattedAddressComma					AS AgentAddress,
			aadd.FormattedAddressCR						AS AgentAddressBlock,
			acon.DisplayName							AS AgentContactName,
			acon.FirstName								AS AgentFirstName,
			acon.Surname								AS AgentSurname,
			acon.Email									AS AgentEmail,
			acon.Phone									AS AgentPhone,
			acon.Mobile									AS AgentMobile,
																					/* Company */
			offa.Name									AS OfficialName,
			offa.AddressLine1							AS OfficialAddressLine1,
			offa.AddressLine2							AS OfficialAddressLine2,
			offa.AddressLine3							AS OfficialAddressLine3,
			offa.Town									AS OfficialTown,
			offac.Name									AS OfficialCounty,
			offa.Postcode								AS OfficialPostcode,
			offcon.Email								AS OfficialEmail,
			offcon.Phone								AS OfficialPhone,
			offcon.Mobile								AS OfficialMobile,
																					/* Surveyor */
			iconm.Email									AS SurveyorEmail,
			i.FullName									AS SurveyorName,
			i.FullName + N' ' + COALESCE (	 icon.PostNominals,
											 ''
										 )				AS SurveyorPostNominals,
			icon.Initials								AS SurveyorInitials,
			i.JobTitle									AS SurveyorJobTitle
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_Jobs_OverdueMilestones]'
GO



ALTER FUNCTION SJob.tvf_Jobs_OverdueMilestones 
(
    @UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN 
SELECT  j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        j.JobTypeID,
        jt.Name AS JobTypeName,
		i.Guid SurveyorGuid,
		i.FullName AS SurveyorName, 
		prop.FormattedAddressComma,
		client.Name + N' / ' + agent.Name AS  ClientAgent,
		js.IsSubjectToNDA,
		j.IsComplete,
		js.JobStatus
FROM    SJob.Jobs j
JOIN	SJob.JobStatus js ON (js.ID = j.ID)
JOIN    SJob.JobTypes jt ON (j.JobTypeID = jt.ID)
JOIN    SCore.Identities i ON (j.SurveyorID = i.ID)
JOIN	SJob.Assets prop ON (prop.ID = j.UprnID)
JOIN	SCrm.Accounts client ON (client.ID = j.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = j.AgentAccountID)
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)
	AND	(j.SurveyorID = @UserId)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SJob.Milestones m
				WHERE	(m.JobID = j.ID)
					AND	(m.RowStatus NOT IN (0, 254))
					AND	(m.IsComplete = 0)
					AND	(
							(ISNULL(m.DueDateTimeUTC, GETUTCDATE()) < GETUTCDATE())
							OR (ISNULL(m.ScheduledDateTimeUTC, GETUTCDATE()) < GETUTCDATE())
						)
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[Job_MergeInfo]'
GO


ALTER VIEW SJob.Job_MergeInfo 
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
        i.JobTitle                                                                               AS SurveyorJobTitle
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
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[Job_CDMMergeInfo]'
GO
EXEC sp_refreshview N'[SJob].[Job_CDMMergeInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_QuotesNotIssued]'
GO






ALTER FUNCTION SSop.tvf_QuotesNotIssued
(
	@UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.FullNumber AS Number,
		LEFT(q.Overview, 200) AS Details, 
		acc.Name + N' / ' + aacc.Name AS Account,
		uprn.FormattedAddressComma,
		qc.FullName AS QuotingConsultant,
		qcf.QuoteStatus
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN	SCrm.Accounts acc ON (acc.ID = e.ClientAccountID)
JOIN	SCrm.Accounts aacc ON (aacc.ID = e.AgentAccountId)
JOIN	SJob.Assets uprn ON (uprn.ID = q.UprnId)
JOIN	SCore.Identities qc ON (qc.ID = q.QuotingConsultantId)
WHERE   (q.RowStatus NOT IN (0, 254))
	AND	(q.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
	AND	(q.DateSent IS NULL)
	AND	(q.DateAccepted IS NULL)
	AND	(q.DateRejected IS NULL)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_QuotesSentNoResponse]'
GO






ALTER FUNCTION SSop.tvf_QuotesSentNoResponse
(
	@UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.FullNumber AS Number,
		LEFT(q.Overview, 200) AS Details, 
		acc.Name + N' / ' + aacc.Name AS Account,
		uprn.FormattedAddressComma,
		qc.FullName AS QuotingConsultant,
		q.DateSent, 
		q.ChaseDate1, 
		q.ChaseDate2,
		qcf.QuoteStatus
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN	SCrm.Accounts acc ON (acc.ID = e.ClientAccountID)
JOIN	SCrm.Accounts aacc ON (aacc.ID = e.AgentAccountID)
JOIN	SJob.Assets uprn ON (uprn.ID = q.UprnId)
JOIN	SCore.Identities qc ON (qc.ID = q.QuotingConsultantId)
WHERE   (q.RowStatus NOT IN (0, 254))
	AND	(q.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
	AND	(q.DateSent IS NOT NULL)
	AND	(q.DateAccepted IS NULL)
	AND	(q.DateRejected IS NULL)
	AND	(GETDATE() < q.ExpiryDate)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_Jobs_IncompleteActivities]'
GO




ALTER FUNCTION SJob.tvf_Jobs_IncompleteActivities 
(
    @UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN 
SELECT  j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        j.JobTypeID,
        jt.Name AS JobTypeName,
		i.Guid SurveyorGuid,
		i.FullName AS SurveyorName, 
		prop.FormattedAddressComma,
		client.Name + N' / ' + agent.Name AS  ClientAgent,
		js.IsSubjectToNDA,
		j.IsComplete,
		js.JobStatus
FROM    SJob.Jobs j
JOIN	SJob.JobStatus js ON (js.ID = j.ID)
JOIN    SJob.JobTypes jt ON (j.JobTypeID = jt.ID)
JOIN    SCore.Identities i ON (j.SurveyorID = i.ID)
JOIN	SJob.Assets prop ON (prop.ID = j.UprnID)
JOIN	SCrm.Accounts client ON (client.ID = j.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = j.AgentAccountID)
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(j.Id > 0)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SCore.ObjectSecurityForUser_CanRead (j.guid, @UserId) oscr
			)
		)
	AND	(j.SurveyorID = @UserId)
	AND	(EXISTS
			(
				SELECT	1
				FROM	SJob.Activities a
				WHERE	(a.JobID = j.ID)
					AND	(a.RowStatus NOT IN (0, 254))
					AND	(ISNULL(a.EndDate, GETUTCDATE()) < GETUTCDATE())
					AND	(EXISTS
							(
								SELECT	1
								FROM	SJob.ActivityStatus ast
								WHERE	(ast.ID = a.ActivityStatusID)
									AND	(ast.IsCompleteStatus = 0)
							)
						)
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_Jobs_Dormant]'
GO



ALTER FUNCTION SJob.tvf_Jobs_Dormant 
(
    @UserId INT
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN 
SELECT  j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        j.JobTypeID,
        jt.Name AS JobTypeName,
		i.Guid SurveyorGuid,
		client.Name + N' / ' + agent.Name AS  ClientAgent,
		i.FullName AS SurveyorName, 
		prop.FormattedAddressComma,
		js.IsSubjectToNDA,
		j.IsComplete,
		js.JobStatus,
		j.JobDormant
FROM    SJob.Jobs j
JOIN	SJob.JobStatus js ON (js.ID = j.ID)
JOIN    SJob.JobTypes jt ON (j.JobTypeID = jt.ID)
JOIN    SCore.Identities i ON (j.SurveyorID = i.ID)
JOIN	SJob.Assets prop ON (prop.ID = j.UprnID)
JOIN	SCrm.Accounts client ON (client.ID = j.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = j.AgentAccountID)
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(j.Id > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
	AND	(j.IsComplete = 0)
	AND	(j.JobDormant IS NOT NULL)
	AND	(j.SurveyorID = @UserId)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_Jobs_TeamDormant]'
GO




ALTER FUNCTION SJob.tvf_Jobs_TeamDormant
	(
		@UserId INT
	)
RETURNS TABLE
   --WITH SCHEMABINDING
AS
RETURN SELECT	j.ID,
				j.RowStatus,
				j.RowVersion,
				j.Guid,
				j.Number,
				j.JobDescription,
				j.JobTypeID,
				jt.Name							  AS JobTypeName,
				i.Guid							  AS SurveyorGuid,
				client.Name + N' / ' + agent.Name AS ClientAgent,
				i.FullName						  AS SurveyorName,
				prop.FormattedAddressComma,
				js.IsSubjectToNDA,
				j.IsComplete,
				js.JobStatus,
				j.JobDormant
	   FROM		SJob.Jobs		 AS j
	   JOIN		SJob.JobStatus	 AS js ON (js.ID = j.ID)
	   JOIN		SJob.JobTypes	 AS jt ON (j.JobTypeID = jt.ID)
	   JOIN		SCore.Identities AS i ON (j.SurveyorID = i.ID)
	   JOIN		SJob.Assets	 AS prop ON (prop.ID = j.UprnID)
	   JOIN		SCrm.Accounts	 AS client ON (client.ID = j.ClientAccountID)
	   JOIN		SCrm.Accounts	 AS agent ON (agent.ID = j.AgentAccountID)
	   CROSS APPLY
				(
					SELECT	ou1.OrgNode
					FROM	SCore.OrganisationalUnits AS ou1
					JOIN	SCore.Identities		  AS i1 ON (i1.OriganisationalUnitId = ou1.ID)
					WHERE	(i1.ID = @UserId)
				)				 AS CurrentUser
	   WHERE	(j.RowStatus NOT IN (0, 254))
			AND (j.ID		   > 0)
			AND (EXISTS
		   (
			   SELECT	1
			   FROM		SCore.ObjectSecurityForUser_CanRead (	j.Guid,
																@UserId
															) AS oscr
		   )
				)
			AND (j.IsComplete = 0)
			AND (j.JobDormant IS NOT NULL)
			AND (EXISTS
		   (
			   SELECT	1
			   FROM		SCore.OrganisationalUnits AS ou2
			   WHERE	(ou2.ID											  = i.OriganisationalUnitId)
					AND (ou2.OrgNode.IsDescendantOf (CurrentUser.OrgNode) = 1)
		   )
				);
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SSop].[tvf_Quotes]'
GO
ALTER FUNCTION SSop.tvf_Quotes
(
	@UserId INT
)
RETURNS TABLE
     --WITH SCHEMABINDING
AS RETURN	
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
		q.FullNumber AS Number,
		CASE WHEN q.DescriptionOfWorks <> N'' THEN LEFT(q.DescriptionOfWorks, 200) ELSE LEFT(q.Overview, 200) END AS Details,
		--LEFT(q.Overview, 200) AS Details, 
		acc.Name + N' / ' + agent.Name AS Account,
		uprn.FormattedAddressComma,
		qcf.QuoteStatus AS QuoteStatus,
		i.FullName AS QuotingConsultant,
		ou.Name AS OrganisationalUnitName,
		jt.Name AS JobType,
		q.Date
FROM    SSop.Quotes q
JOIN	SSop.Quote_CalculatedFields qcf ON (qcf.ID = q.ID)
JOIN	SSop.EnquiryServices AS es ON (es.ID = q.EnquiryServiceID)
JOIN	SSop.Enquiries AS e ON (e.ID = es.EnquiryId)
JOIN	SCrm.Accounts acc ON (acc.ID = e.ClientAccountID)
JOIN	SCrm.Accounts agent ON (agent.ID = e.AgentAccountId)
JOIN	SJob.Assets uprn ON (uprn.ID = e.PropertyId)
JOIN	SCore.Identities i ON (i.ID = q.QuotingConsultantId)
JOIN    SCore.OrganisationalUnits ou ON q.OrganisationalUnitID = ou.ID
JOIN	SJob.JobTypes AS jt ON (jt.ID = es.JobTypeId)
WHERE   (q.ID > 0)
AND	
(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_PropertyQuotes]'
GO





ALTER FUNCTION SJob.tvf_PropertyQuotes 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
    --WITH SCHEMABINDING
AS
RETURN 
SELECT  q.ID,
        q.RowStatus,
        q.RowVersion,
        q.Guid,
        q.Number,
		q.Date,
		LEFT(q.Overview, 200) AS Overview,
		i.Guid QuotingUserGuid,
		i.FullName AS QuotingUserName,
		qc.FullName AS QuotingConsultant
FROM    SSop.Quotes q
JOIN	SJob.Assets p ON (p.ID = q.UprnId)
JOIN    SCore.Identities i ON (q.QuotingUserId = i.ID)
JOIN	SCore.Identities qc ON (qc.ID = q.QuotingConsultantId)
WHERE   (q.RowStatus  NOT IN (0, 254))
	AND	(q.Id > 0)
	AND	(p.ID > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(q.Guid, @UserId) oscr
			)
		)
	AND	(p.Guid = @ParentGuid)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[tvf_PropertyJobs]'
GO



ALTER FUNCTION SJob.tvf_PropertyJobs 
(
    @UserId INT,
	@ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN 
SELECT  j.ID,
        j.RowStatus,
        j.RowVersion,
        j.Guid,
        j.Number,
        j.JobDescription,
        j.JobTypeID,
        jt.Name AS JobTypeName,
		i.Guid SurveyorGuid,
		i.FullName AS SurveyorName
FROM    SJob.Jobs j
JOIN	SJob.Assets p ON (p.ID = j.UprnID)
JOIN    SJob.JobTypes jt ON (j.JobTypeID = jt.ID)
JOIN    SCore.Identities i ON (j.SurveyorID = i.ID)
WHERE   (j.RowStatus  NOT IN (0, 254))
	AND	(j.Id > 0)
AND	(EXISTS
			(
		SELECT
				1
		FROM
				SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) oscr
			)
		)
	AND	(p.Guid = @ParentGuid)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SFin].[InvoiceRequestCreateInvoice]'
GO







ALTER PROCEDURE SFin.InvoiceRequestCreateInvoice
	(
		@Guid UNIQUEIDENTIFIER
	)
AS
	BEGIN
		SET NOCOUNT ON 

		DECLARE	@AccountGuid UNIQUEIDENTIFIER, 
				@JobGuid UNIQUEIDENTIFIER,
				@TransactionTypeGuid UNIQUEIDENTIFIER,
				@Date DATE = GETUTCDATE(), 
				@PurchaseOrderNumber NVARCHAR(28),
				@OrganisationalUnitGuid UNIQUEIDENTIFIER,
				@CreatedByUserGuid UNIQUEIDENTIFIER,
				@SurveyorGuid UNIQUEIDENTIFIER,
				@CreditTermsGuid UNIQUEIDENTIFIER,
				@TransactionGuid UNIQUEIDENTIFIER = NEWID(),
				@InvoiceRequestId INT,
				@TransactionId INT,
				@Description NVARCHAR(MAX) = N'',
				@JobDescription NVARCHAR(MAX),
				@JobNumber NVARCHAR(30),
				@UprnFormattedAddressComma NVARCHAR(MAX),
				@JobType NVARCHAR(MAX)

		SELECT	@AccountGuid = fa.Guid,
				@InvoiceRequestId = ir.ID, 
				@JobGuid = j.Guid,
				@SurveyorGuid = r.Guid,
				@JobDescription = j.JobDescription,
				@JobNumber = j.Number,
				@JobType = jt.Name,
				@PurchaseOrderNumber = j.PurchaseOrderNumber,
				@OrganisationalUnitGuid = ou.Guid,
				@CreditTermsGuid = ct.Guid,
				@UprnFormattedAddressComma = uprn.FormattedAddressComma
		FROM	SFin.InvoiceRequests ir
		JOIN	SJob.Jobs j ON (j.ID = ir.JobId)
		JOIN	SJob.JobTypes jt ON (jt.ID = j.JobTypeID)
		JOIN	SJob.Assets uprn ON (uprn.ID = j.UprnID)
		JOIN	SCrm.Accounts fa ON (fa.ID = j.FinanceAccountID)
		JOIN	SCore.Identities r ON (r.ID = ir.RequesterUserId)
		JOIN	SCore.OrganisationalUnits ou ON (ou.Id = j.OrganisationalUnitID)
		JOIN	SFin.CreditTerms ct on (ct.ID = fa.DefaultCreditTermsId)
		WHERE ir.Guid = @Guid

		IF (NOT EXISTS
		(
			SELECT	1
			FROM	SCrm.Accounts AS a 
			WHERE	(a.Guid = @AccountGuid)
				AND	(a.Code <> N'')
		)
			)
		BEGIN 
			;THROW 60000, N'The finance account on the job is invalid.', 1
		END

		SELECT	@CreatedByUserGuid = SCore.GetCurrentUserGuid()

		SELECT	@TransactionTypeGuid = tt.Guid 
		FROM	SFin.TransactionTypes tt
		WHERE	(tt.Name = N'Invoice')

		-- Create the invoice header
		EXEC SFin.TransactionsUpsert @AccountGuid = @AccountGuid,				-- uniqueidentifier
									 @JobGuid = @JobGuid,					-- uniqueidentifier
									 @TransactionTypeGuid = @TransactionTypeGuid,		-- uniqueidentifier
									 @Date = @Date,				-- date
									 @PurchaseOrderNumber = @PurchaseOrderNumber,		-- nvarchar(28)
									 @SageTransactionReference = N'',	-- nvarchar(50)
									 @OrganisationalUnitGuid = @OrganisationalUnitGuid,	-- uniqueidentifier
									 @CreatedByUserGuid = @CreatedByUserGuid,			-- uniqueidentifier
									 @SurveyorGuid = @SurveyorGuid,				-- uniqueidentifier
									 @CreditTermsGuid = @CreditTermsGuid,			-- uniqueidentifier
									 @Guid = @TransactionGuid						-- uniqueidentifier

		SELECT	@TransactionId = ID
		FROM	SFin.Transactions t
		WHERE	(Guid = @TransactionGuid)

		SET @Description = @Description + N'	
Our project ref.: ' + @JobNumber + N'
Project description: ' + @JobDescription + N'
Property: ' + @UprnFormattedAddressComma + N'
Appointed role: ' + @JobType

		DECLARE	@DetailList SCore.TwoGuidUniqueList,
				@NewDetailRecords SCore.GuidUniqueList

		INSERT	@DetailList
			 (GuidValue, GuidValueTwo)
		SELECT	iri.Guid,
				NEWID()
		FROM	SFin.InvoiceRequestItems iri
		WHERE	(iri.InvoiceRequestId = @InvoiceRequestId)
			AND	(iri.RowStatus NOT IN (0, 254))


		INSERT	@NewDetailRecords (GuidValue)
		SELECT	GuidValueTwo
		FROM	@DetailList

		DECLARE	@IsInsert BIT 

		EXEC SCore.DataObjectBulkUpsert 
			@GuidList = @NewDetailRecords,
			@SchemeName = N'SFin',
			@ObjectName = N'TransactionDetails',
			@IncludeDefaultSecurity = 0,
			@IsInsert = @IsInsert OUT 

		INSERT	SFin.TransactionDetails
			 (RowStatus,
			  Guid,
			  TransactionID,
			  MilestoneID,
			  ActivityID,
			  Net,
			  Vat,
			  Gross,
			  VatRate,
			  Description,
			  LegacyId,
			  JobPaymentStageId,
			  InvoiceRequestItemId)
		SELECT	1,
				dl.GuidValueTwo,
				@TransactionId,
				iri.MilestoneId,
				iri.ActivityId,
				iri.Net,
				iri.Net * 0.2,
				iri.Net * 1.2,
				20,
				@Description, 
				NULL,
				-1,
				iri.Id
		FROM	@DetailList dl
		JOIN	SFin.InvoiceRequestItems iri ON (iri.Guid = dl.GuidValue)
		

	END;
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Refreshing [SJob].[Job_ExtendedInfo]'
GO
EXEC sp_refreshview N'[SJob].[Job_ExtendedInfo]'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering [SJob].[CurrentScheduledWork]'
GO

ALTER FUNCTION SJob.CurrentScheduledWork
(
	@UserId INT
)
RETURNS TABLE
	   --WITH SCHEMABINDING
AS RETURN
SELECT	j.ID,
		j.Guid,
		a.RowVersion,
		a.RowStatus,
		j.Number AS JobNumber,
		client.Name AS ClientName,
		prop.FormattedAddressComma AS PropertyAddress,
		a.Date AS StartDateTime,
		a.EndDate AS EndDateTime,
		a.Title ActivityTitle,
		aty.Name   AS ActivityType,
		ast.Name   AS ActivityStatus,
		i.FullName AS SurveyorName,
		ast.SortOrder AS SortPriority
FROM	SJob.Activities		AS a
JOIN	SJob.ActivityStatus AS ast ON (ast.ID = a.ActivityStatusID)
JOIN	SJob.ActivityTypes	AS aty ON (aty.ID = a.ActivityTypeID)
JOIN	SJob.Jobs			AS j ON (j.ID	  = a.JobID)
JOIN	SJob.Assets prop ON (prop.ID = j.UprnID)
JOIN	SCrm.Accounts client ON (client.ID = j.ClientAccountID)
JOIN	SCore.Identities	AS i ON (i.ID	  = a.SurveyorID)
WHERE	(aty.IsScheduleItem = 1)
	AND (a.SurveyorID = @UserId)
	AND	(a.Date BETWEEN DATEADD (DAY, -7, GETUTCDATE()) AND DATEADD (DAY, +7, GETUTCDATE()))
	AND (a.RowStatus NOT IN (0, 254))

GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] WITH NOCHECK  ADD CONSTRAINT [FK_Properties_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Accounts] FOREIGN KEY ([LocalAuthorityAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Accounts1] FOREIGN KEY ([FireAuthorityAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Accounts2] FOREIGN KEY ([WaterAuthorityAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Accounts3] FOREIGN KEY ([OwnerAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Counties] FOREIGN KEY ([CountyId]) REFERENCES [SCrm].[Counties] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Countries] FOREIGN KEY ([CountryId]) REFERENCES [SCrm].[Countries] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_Properties] FOREIGN KEY ([ParentPropertyID]) REFERENCES [SJob].[Assets] ([ID])
GO
ALTER TABLE [SJob].[Assets] ADD CONSTRAINT [FK_Properties_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SJob].[Jobs]'
GO
ALTER TABLE [SJob].[Jobs] ADD CONSTRAINT [FK_Jobs_Properties] FOREIGN KEY ([UprnID]) REFERENCES [SJob].[Assets] ([ID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SSop].[Enquiries]'
GO
ALTER TABLE [SSop].[Enquiries] ADD CONSTRAINT [FK_Enquiries_Properties] FOREIGN KEY ([PropertyId]) REFERENCES [SJob].[Assets] ([ID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [SSop].[Quotes]'
GO
ALTER TABLE [SSop].[Quotes] ADD CONSTRAINT [FK_Quotes_Properties] FOREIGN KEY ([UprnId]) REFERENCES [SJob].[Assets] ([ID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Disabling constraints on [SJob].[Assets]'
GO
ALTER TABLE [SJob].[Assets] NOCHECK CONSTRAINT [FK_Properties_DataObjects]
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Altering trigger [SJob].[tg_Properties_RecordHistory] on [SJob].[Assets]'
GO
ALTER TRIGGER SJob.tg_Properties_RecordHistory
   ON  SJob.Assets	
   AFTER INSERT, UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
    BEGIN 
        RETURN
    END

	IF (EXISTS
			(
				SELECT	1
				FROM	Inserted
				WHERE	(ID = -1) 
			)
		)
	BEGIN 
		;THROW 60000, N'Data integrity exception: Attempt to alter -1 record', 1
	END

    DECLARE	@PreviousValue NVARCHAR(MAX),
			@NewValue NVARCHAR(MAX),
			@UserID INT = 0,
			@SchemaName NVARCHAR(250) = N'SJob',
			@TableName NVARCHAR(250) = N'Properties',
			@ColumnName NVARCHAR(250),
			@MaxInsertedID BIGINT,
			@CurrentInsertedID BIGINT,
			@CurrentInsertedGuid UNIQUEIDENTIFIER

	SELECT @UserID = ISNULL(CONVERT(int, SESSION_CONTEXT(N'user_id')), -1)

	SELECT	@MaxInsertedID = MAX([ID]),
			@CurrentInsertedID = -1
	FROM	Inserted

	WHILE	(@CurrentInsertedID < @MaxInsertedID)
	BEGIN 
		SELECT	TOP(1) @CurrentInsertedID = i.[ID],
				@CurrentInsertedGuid = i.Guid
		FROM	Inserted i
		WHERE	(i.[ID] > @CurrentInsertedID)
			ORDER BY i.[ID]
		
		
		
		IF (NOT EXISTS 
				(
					SELECT	1
					FROM 	deleted d
					WHERE	(d.[ID] = @CurrentInsertedID)
				)
			)
		BEGIN 
				
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, N'', N'', SYSTEM_USER, -1)
	
			RETURN 
		END
		
		SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RowStatus]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RowStatus]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RowStatus] IS DISTINCT FROM i.[RowStatus])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 248)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[UPRN]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[UPRN]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[UPRN] IS DISTINCT FROM i.[UPRN])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'UPRN', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 251)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ParentPropertyID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ParentPropertyID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ParentPropertyID] IS DISTINCT FROM i.[ParentPropertyID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ParentPropertyID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 252)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CreatedDate]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CreatedDate]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CreatedDate] IS DISTINCT FROM i.[CreatedDate])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CreatedDate', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 253)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Name]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Name]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Name] IS DISTINCT FROM i.[Name])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Name', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 254)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Number]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Number]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Number] IS DISTINCT FROM i.[Number])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Number', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 255)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AddressLine1]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AddressLine1]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AddressLine1] IS DISTINCT FROM i.[AddressLine1])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AddressLine1', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 256)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AddressLine2]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AddressLine2]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AddressLine2] IS DISTINCT FROM i.[AddressLine2])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AddressLine2', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 257)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[AddressLine3]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[AddressLine3]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[AddressLine3] IS DISTINCT FROM i.[AddressLine3])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'AddressLine3', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 258)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Town]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Town]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Town] IS DISTINCT FROM i.[Town])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Town', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 259)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Postcode]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Postcode]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Postcode] IS DISTINCT FROM i.[Postcode])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Postcode', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 261)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[LocalAuthorityAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[LocalAuthorityAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[LocalAuthorityAccountID] IS DISTINCT FROM i.[LocalAuthorityAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'LocalAuthorityAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 262)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FireAuthorityAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FireAuthorityAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FireAuthorityAccountID] IS DISTINCT FROM i.[FireAuthorityAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FireAuthorityAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 263)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[WaterAuthorityAccountID]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[WaterAuthorityAccountID]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[WaterAuthorityAccountID] IS DISTINCT FROM i.[WaterAuthorityAccountID])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'WaterAuthorityAccountID', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 264)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FormattedAddressComma]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FormattedAddressComma]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FormattedAddressComma] IS DISTINCT FROM i.[FormattedAddressComma])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FormattedAddressComma', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 265)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[FormattedAddressCR]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[FormattedAddressCR]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[FormattedAddressCR] IS DISTINCT FROM i.[FormattedAddressCR])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'FormattedAddressCR', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 266)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Latitude]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Latitude]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Latitude] IS DISTINCT FROM i.[Latitude])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Latitude', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 267)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[Longitude]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[Longitude]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[Longitude] IS DISTINCT FROM i.[Longitude])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'Longitude', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 268)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[BuildingHeightInMetres]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[BuildingHeightInMetres]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[BuildingHeightInMetres] IS DISTINCT FROM i.[BuildingHeightInMetres])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'BuildingHeightInMetres', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1027)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CountryId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CountryId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CountryId] IS DISTINCT FROM i.[CountryId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CountryId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1028)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[CountyId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[CountyId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[CountyId] IS DISTINCT FROM i.[CountyId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'CountyId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1029)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsComplexBuilding]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsComplexBuilding]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsComplexBuilding] IS DISTINCT FROM i.[IsComplexBuilding])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsComplexBuilding', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1030)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[IsHighRiskBuilding]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[IsHighRiskBuilding]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[IsHighRiskBuilding] IS DISTINCT FROM i.[IsHighRiskBuilding])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'IsHighRiskBuilding', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1031)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ListLabel]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ListLabel]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ListLabel] IS DISTINCT FROM i.[ListLabel])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ListLabel', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1675)
			END 
			
			SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[OwnerAccountId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[OwnerAccountId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[OwnerAccountId] IS DISTINCT FROM i.[OwnerAccountId])


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'OwnerAccountId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, 1676)
			END 
			
			
			END
		END
		
		
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
COMMIT TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
-- This statement writes to the SQL Server Log so SQL Monitor can show this deployment.
IF HAS_PERMS_BY_NAME(N'sys.xp_logevent', N'OBJECT', N'EXECUTE') = 1
BEGIN
    DECLARE @databaseName AS nvarchar(2048), @eventMessage AS nvarchar(2048)
    SET @databaseName = REPLACE(REPLACE(DB_NAME(), N'\', N'\\'), N'"', N'\"')
    SET @eventMessage = N'Redgate SQL Compare: { "deployment": { "description": "Redgate SQL Compare deployed to ' + @databaseName + N'", "database": "' + @databaseName + N'" }}'
    EXECUTE sys.xp_logevent 55000, @eventMessage
END
GO
DECLARE @Success AS BIT
SET @Success = 1
SET NOEXEC OFF
IF (@Success = 1) PRINT 'The database update succeeded'
ELSE BEGIN
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
	PRINT 'The database update failed'
END
GO
