SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SJob].[Job_CDMMergeInfo] 
AS SELECT		mi.ID,
			mi.RowStatus,
			mi.RowVersion,
			mi.Guid,
			mi.ParentGuid,
			mi.JobIDString,
			mi.JobNumber,
			mi.JobDescription,
			mi.JobType,
			mi.UPRN,
			mi.PropertyAddressLine1,
			mi.PropertyAddressLine2,
			mi.PropertyAddressLine3,
			mi.PropertyTown,
			mi.PropertyCounty,
			mi.PropertyPostcode,
			mi.PropertyAddress,
			mi.PropertyAddressBlock,
			mi.PropertyShortAddress,
			mi.LocalAuthority,
			mi.ClientName,
			mi.ClientCompanyRegNo,
			mi.ClientAddressLine1,
			mi.ClientAddressLine2,
			mi.ClientAddressLine3,
			mi.ClientTown,
			mi.ClientCounty,
			mi.ClientPostcode,
			mi.ClientAddress,
			mi.ClientAddressBlock,
			mi.ClientContactName,
			mi.ClientFirstName,
			mi.ClientSurname,
			mi.ClientEmail,
			mi.ClientPhone,
			mi.ClientMobile,
			mi.AgentName,
			mi.AgentCompanyRegNo,
			mi.AgentAddressLine1,
			mi.AgentAddressLine2,
			mi.AgentAddressLine3,
			mi.AgentTown,
			mi.AgentCounty,
			mi.AgentPostcode,
			mi.AgentAddress,
			mi.AgentAddressBlock,
			mi.AgentContactName,
			mi.AgentFirstName,
			mi.AgentSurname,
			mi.AgentEmail,
			mi.AgentPhone,
			mi.AgentMobile,
			mi.OfficialName,
			mi.OfficialAddressLine1,
			mi.OfficialAddressLine2,
			mi.OfficialAddressLine3,
			mi.OfficialTown,
			mi.OfficialCounty,
			mi.OfficialPostcode,
			mi.OfficialEmail,
			mi.OfficialPhone,
			mi.OfficialMobile,
      mi.AgreedFee, 
      mi.RibaStage1Fee,
      mi.RibaStage2Fee,
      mi.RibaStage3Fee,
      mi.RibaStage4Fee,
      mi.RibaStage5Fee,
      mi.RibaStage6Fee,
      mi.RibaStage7Fee,
      mi.PreConstructionStageFee,
      mi.ConstructionStageFee,
      mi.TotalNetFee,
			ISNULL (   pc.Name,
					   N''
				   )						 AS PrincipalContractorName,
			ISNULL (   pc.Phone,
					   N''
				   )						 AS PrincipalContractorPhone,
			ISNULL (   pc.Mobile,
					   N''
				   )						 AS PrincipalContractorMobile,
			ISNULL (   pc.Email,
					   N''
				   )						 AS PrincipalContractorEmail,
			ISNULL (   pc.FormattedAddressComma,
					   N''
				   )						 AS PrincipalContractorAddress,
			WAR.CompletedDateTimeUTC		 AS WrittenAppointmentDate,
			CPP.ReviewedDateTimeUTC			 AS CPPReviewed,
			SiteWork.StartDateTimeUTC		 AS SiteStartDate,
			SiteWork.CompletedDateTimeUTC	 AS SiteCompletionDate,
			PCI.CompletedDateTimeUTC		 AS PCII,
			CDMSTRATEGY.CompletedDateTimeUTC AS StrategyLastUpdated,
			CASE
				WHEN mi.ClientAppointmentReceived = 1 THEN N'appointed '
				ELSE N'instructed '
			END + mi.JobType				 AS AppointedJobType,
			mi.SurveyorEmail,
			mi.SurveyorName,
			mi.SurveyorPostNominals,
			mi.SurveyorInitials,
			mi.SurveyorJobTitle
FROM		SJob.Job_MergeInfo AS mi
OUTER APPLY
			(
				SELECT	acc.Name,
						cmi.Phone,
						cmi.Mobile,
						cmi.Email,
						ad.FormattedAddressComma
				FROM	SJob.ProjectDirectory	   AS pd
				JOIN	SJob.ProjectDirectoryRoles AS pdr ON (pdr.ID	  = pd.ProjectDirectoryRoleID)
				JOIN	SCrm.Accounts			   AS acc ON (acc.ID	  = pd.AccountID)
				JOIN	SCrm.AccountAddresses	   AS aa ON (aa.AccountID = acc.ID)
				JOIN	SCrm.Addresses			   AS ad ON (ad.ID		  = aa.AddressID)
				JOIN	SCrm.Contact_MergeInfo	   AS cmi ON (cmi.ID	  = pd.ContactID)
				WHERE	(pd.JobID  = mi.ID)
					AND (aa.IsMain = 1)
					AND (pdr.Name  = N'Principle Contractor')
			)				   AS pc
OUTER APPLY SJob.JobMileStoneDates (   N'WAR',
									   mi.ID
								   ) AS WAR
OUTER APPLY SJob.JobMileStoneDates (   N'CPPPROD',
									   mi.ID
								   ) AS CPP
OUTER APPLY SJob.JobMileStoneDates (   N'PCI',
									   mi.ID
								   ) AS PCI
OUTER APPLY SJob.JobMileStoneDates (   N'SITEWORK',
									   mi.ID
								   ) AS SiteWork
OUTER APPLY SJob.JobMileStoneDates (   N'CDMSTRATEGY',
									   mi.ID
								   ) AS CDMSTRATEGY
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'CDM Document Merge Fields', 'SCHEMA', N'SJob', 'VIEW', N'Job_CDMMergeInfo'
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'Job ID: {Job Number}', 'SCHEMA', N'SJob', 'VIEW', N'Job_CDMMergeInfo', 'COLUMN', N'JobIDString'
GO