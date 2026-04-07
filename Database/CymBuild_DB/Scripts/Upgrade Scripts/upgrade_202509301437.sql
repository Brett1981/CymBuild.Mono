SET LANGUAGE 'British English'
SET DATEFORMAT ymd
SET ARITHABORT, ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER, ANSI_NULLS, NOCOUNT, XACT_ABORT ON
SET NUMERIC_ROUNDABORT, IMPLICIT_TRANSACTIONS OFF
GO

--
-- Start Transaction
--
BEGIN TRANSACTION


UPDATE SCore.EntityQueries
SET Statement = N'EXEC [SSop].[QuoteCreateJobs]  @Guid = @Guid'
where guid = '11E9B80F-CEBD-4C45-831F-9889AAC225A4'

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

UPDATE SCore.EntityQueries
SET Statement = N'SELECT * FROM [SSop].[tvf_QuotesDataPills] ( @Guid, @DateAccepted, @DateRejected, @ProjectGuid, @ContractGuid, @AgentContractGuid) root_hobt'
where guid = 'E3764F3E-450E-4821-8B09-786DF3C38481'

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

UPDATE SCore.EntityQueries
SET Statement = N'SELECT * FROM [SSop].[tvf_QuotesValidate] ( @Guid, @DateSent, @DeadDate, @DateRejected, @IsFinal, @RevisionNumber, @OrganisationalUnitGuid, @DateDeclinedToQuote, @DeclinedToQuoteReason, @ContractGuid, @AgentContractGuid) root_hobt'
where guid = 'EADBB21C-F120-4EC1-9EA7-37881363974E'

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

UPDATE SCore.EntityQueries
SET Statement = N'SELECT * FROM [SSop].[tvf_Enquiry_DataPills] ( @Guid, @RowStatus, @Number, @AddressLine1, @AddressLine2, @AddressLine3, @Town, @CountyGuid, @PostCode, @ClientAccountGuid, @ClientName, @AgentAccountGuid, @AgentName, @ProjectGuid, @IsSubjectToNDA, @FinanceAccountGuid, @UseClientAsFinance, @ContractGuid, @AgentContractGuid) root_hobt'
where guid = '22934EA5-D5D4-4673-9794-AD7FF963CE8A'

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

UPDATE SCore.EntityQueries
SET Statement = N'SELECT * FROM [SSop].[tvf_EnquiriesValidate] ( @Guid, @RowStatus, @PropertyGuid, @ClientAccountGuid, @ClientAddressGuid, @AgentAccountGuid, @AgentAddressGuid, @FinanceAccountGuid, @FinanceAddressGuid, @IsReadyForQuoteReview, @DescriptionOfWorks, @ValueOfWork, @CurrentProjectRibaStageGuid, @PropertyNumber, @PropertyPostCode, @ClientAddressNumber, @ClientAddressPostCode, @AgentAddressNumber, @AgentAddressPostCode, @AgentName, @ClientName, @DeclinedToQuoteDate, @DeclinedToQuoteReason, @KeyDates, @DeadDate, @EnterNewClientDetails, @EnterNewAgentDetails, @EnterNewFinanceDetails, @EnterNewStructureDetails, @IsClientFinanceAccount, @ProjectGuid, @ClientContactDisplayName, @AgentContactDisplayName, @FinanceContactDisplayName, @ClientContactDetailType, @ClientContactDetailTypeName, @ClientContactDetailTypeValue, @AgentContactDetailType, @AgentContactDetailTypeName, @AgentContactDetailTypeValue, @FinanceContactDetailType, @FinanceContactDetailTypeName, @FinanceContactDetailTypeValue, @ContractGuid, @AgentContractGuid) root_hobt'
where guid = '96CC8F3C-5B38-447D-8940-F3224D71EAF2'

IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

UPDATE SCore.EntityQueries
SET Statement = N'EXEC SSop.EnquiryCreateQuotes @Guid = @Guid -- uniqueidentifier'
where guid = '97064C41-349B-49E7-AB8C-3221A7142FF2'


IF @@ERROR<>0 OR @@TRANCOUNT=0 BEGIN IF @@TRANCOUNT>0 ROLLBACK SET NOEXEC ON END
GO

--
-- Commit Transaction
--
IF @@TRANCOUNT>0 COMMIT TRANSACTION
SET NOEXEC OFF
GO