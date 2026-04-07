PRINT (N'Create table [SSop].[Enquiries]')
GO
CREATE TABLE [SSop].[Enquiries] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Enquiries_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Enquiries_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [OrganisationalUnitID] [int] NOT NULL CONSTRAINT [DF_Enquiries_OrganisationalUnitID] DEFAULT (-1),
  [Date] [datetime2] NOT NULL CONSTRAINT [DF_Enquiries_Date] DEFAULT (getdate()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_Enquiries_CreatedByUserId] DEFAULT (-1),
  [Number] [nvarchar](50) NOT NULL CONSTRAINT [DF_Enquiries_Number] DEFAULT (0),
  [Revision] [int] NOT NULL CONSTRAINT [DF_Enquiries_Revision] DEFAULT (0),
  [OriginalEnquiryId] [int] NOT NULL CONSTRAINT [DF_Enquiries_OriginalEnquiryId] DEFAULT (-1),
  [PropertyId] [int] NOT NULL CONSTRAINT [DF_Enquiries_PropertyId] DEFAULT (-1),
  [PropertyNameNumber] [nvarchar](100) NOT NULL CONSTRAINT [DF_Enquiries_PropertyNameNumber] DEFAULT (''),
  [PropertyAddressLine1] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_PropertyAddressLine1] DEFAULT (''),
  [PropertyAddressLine2] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_PropertyAddressLine2] DEFAULT (''),
  [PropertyAddressLine3] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_PropertyAddressLine3] DEFAULT (''),
  [PropertyTown] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_PropertyTown] DEFAULT (''),
  [PropertyCountyId] [int] NOT NULL CONSTRAINT [DF_Enquiries_PropertyCountyId] DEFAULT (-1),
  [PropertyPostCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_Enquiries_PropertyPostCode] DEFAULT (''),
  [PropertyCountryId] [int] NOT NULL CONSTRAINT [DF_Enquiries_PropertyCountryId] DEFAULT (-1),
  [ClientAccountId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ClientAccountId] DEFAULT (-1),
  [ClientAddressId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressId] DEFAULT (-1),
  [ClientAccountContactId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ClientAccountContactId] DEFAULT (-1),
  [ClientName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Enquiries_ClientName] DEFAULT (''),
  [ClientAddressNameNumber] [nvarchar](100) NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressNameNumber] DEFAULT (''),
  [ClientAddressLine1] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressLine1] DEFAULT (''),
  [ClientAddressLine2] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressLine2] DEFAULT (''),
  [ClientAddressLine3] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressLine3] DEFAULT (''),
  [ClientAddressTown] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_ClientAdressTown] DEFAULT (''),
  [ClientAddressCountyId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressCountyId] DEFAULT (-1),
  [ClientAddressPostCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressPostCode] DEFAULT (''),
  [ClientAddressCountryId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ClientAddressCountryId] DEFAULT (-1),
  [AgentAccountId] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentAccountId] DEFAULT (-1),
  [AgentAddressId] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressId] DEFAULT (-1),
  [AgentAccountContactId] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentAccountContactId] DEFAULT (-1),
  [AgentName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Enquiries_AgentName] DEFAULT (''),
  [AgentAddressNameNumber] [nvarchar](100) NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressNameNumber] DEFAULT (''),
  [AgentAddressLine1] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressLine1] DEFAULT (''),
  [AgentAddressLine2] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressLine2] DEFAULT (''),
  [AgentAddressLine3] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressLine3] DEFAULT (''),
  [AgentTown] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_AgentTown] DEFAULT (''),
  [AgentCountyId] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentCountyId] DEFAULT (-1),
  [AgentAddressPostCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_Enquiries_AgentAddressPostCode] DEFAULT (''),
  [AgentCountryId] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentCountryId] DEFAULT (-1),
  [DescriptionOfWorks] [nvarchar](4000) NOT NULL CONSTRAINT [DF_Enquiries_DescriptionOfWorks] DEFAULT (''),
  [ValueOfWork] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Enquiries_ValueOfWork] DEFAULT (0),
  [CurrentProjectRibaStageID] [int] NOT NULL CONSTRAINT [DF_Enquiries_CurrentProjectRibaStageID] DEFAULT (-1),
  [RibaStage0Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage0Months] DEFAULT (0),
  [RibaStage1Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage1Months] DEFAULT (0),
  [RibaStage2Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage2Months] DEFAULT (0),
  [RibaStage3Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage3Months] DEFAULT (0),
  [RibaStage4Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage4Months] DEFAULT (0),
  [RibaStage5Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage5Months] DEFAULT (0),
  [RibaStage6Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage6Months] DEFAULT (0),
  [RibaStage7Months] [int] NOT NULL CONSTRAINT [DF_Enquiries_RibaStage7Months] DEFAULT (0),
  [PreConstructionStageMonths] [int] NOT NULL CONSTRAINT [DF_Enquiries_PreConstructionStageMonths] DEFAULT (0),
  [ConstructionStageMonths] [int] NOT NULL CONSTRAINT [DF_Enquiries_ConstructionStageMonths] DEFAULT (0),
  [SendInfoToClient] [bit] NOT NULL CONSTRAINT [DF_Enquiries_SendInfoToClient] DEFAULT (0),
  [SendInfoToAgent] [bit] NOT NULL CONSTRAINT [DF_Enquiries_SendInfoToAgent] DEFAULT (0),
  [KeyDates] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Enquiries_KeyDates] DEFAULT (''),
  [ExpectedProcurementRoute] [nvarchar](200) NOT NULL CONSTRAINT [DF_Enquiries_ExpectedProcurementRoute] DEFAULT (''),
  [Notes] [nvarchar](max) NOT NULL CONSTRAINT [DF_Enquiries_Notes] DEFAULT (''),
  [EnquirySourceId] [int] NOT NULL CONSTRAINT [DF_Enquiries_EnquirySourceId] DEFAULT (-1),
  [IsReadyForQuoteReview] [bit] NOT NULL CONSTRAINT [DF_Enquiries_IsReadyForQuoteReview] DEFAULT (0),
  [QuotingDeadlineDate] [date] NULL,
  [DeclinedToQuoteDate] [date] NULL,
  [DeclinedToQuoteReason] [nvarchar](4000) NOT NULL CONSTRAINT [DF_Enquiries_DeclinedToQuoteReason] DEFAULT (''),
  [ExternalReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Enquiries_ExternalReference] DEFAULT (''),
  [ProjectId] [int] NOT NULL CONSTRAINT [DF_Enquiries_ProjectId] DEFAULT (-1),
  [IsSubjectToNDA] [bit] NOT NULL CONSTRAINT [DF_Enquiries_IsSubjectToNDA] DEFAULT (0),
  [DeadDate] [date] NULL,
  [ChaseDate1] [date] NULL,
  [ChaseDate2] [date] NULL,
  [IsClientFinanceAccount] [bit] NOT NULL CONSTRAINT [DF_Enquiries_IsClientFinanceAccount] DEFAULT (0),
  [FinanceAccountId] [int] NOT NULL CONSTRAINT [DF_Enquiries_FinanceAccountId] DEFAULT (-1),
  [FinanceAddressId] [int] NOT NULL CONSTRAINT [DF_Enquiries_FinanceAddressId] DEFAULT (-1),
  [FinanceContactId] [int] NOT NULL CONSTRAINT [DF_Enquiries_FinanceContactId] DEFAULT (-1),
  [FinanceAccountName] [nvarchar](250) NOT NULL CONSTRAINT [DF_Enquiries_FinanceAccountName] DEFAULT (''),
  [FinanceAddressNameNumber] [nvarchar](100) NOT NULL CONSTRAINT [DF_Enquiries_FinanceAddressNameNumber] DEFAULT (''),
  [FinanceAddressLine1] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_FinanceAddressLine1] DEFAULT (''),
  [FinanceAddressLine2] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_FinanceAddressLine2] DEFAULT (''),
  [FinanceAddressLine3] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_FinanceAddressLine3] DEFAULT (''),
  [FinanceTown] [nvarchar](255) NOT NULL CONSTRAINT [DF_Enquiries_FinanceTown] DEFAULT (''),
  [FinanceCountyId] [int] NOT NULL CONSTRAINT [DF_Enquiries_FinanceCountyId] DEFAULT (-1),
  [FinancePostCode] [nvarchar](30) NOT NULL CONSTRAINT [DF_Enquiries_FinancePostCode] DEFAULT (''),
  [EnterNewClientDetails] [bit] NOT NULL CONSTRAINT [DF_Enquiries_EnterNewClientDetails] DEFAULT (0),
  [EnterNewAgentDetails] [bit] NOT NULL CONSTRAINT [DF_Enquiries_EnterNewAgentDetails] DEFAULT (0),
  [EnterNewFinanceDetails] [bit] NOT NULL CONSTRAINT [DF_Enquiries_EnterNewFinanceDetails] DEFAULT (0),
  [EnterNewStructureDetails] [bit] NOT NULL CONSTRAINT [DF_Enquiries_EntityNewStructureDetails] DEFAULT (0),
  [SignatoryIdentityId] [int] NOT NULL CONSTRAINT [DF_Enquiries_SignatoryIdentityId] DEFAULT (-1),
  [ProposalLetter] [nvarchar](max) NOT NULL CONSTRAINT [DF_Enquiries_ProposalLetter] DEFAULT (''),
  [ClientContactDisplayName] [nvarchar](250) NOT NULL DEFAULT (''),
  [ClientContactDetailType] [smallint] NOT NULL DEFAULT (-1),
  [ClientContactDetailTypeName] [nvarchar](100) NOT NULL DEFAULT (''),
  [ClientContactDetailTypeValue] [nvarchar](250) NOT NULL DEFAULT (''),
  [AgentContactDisplayName] [nvarchar](250) NOT NULL DEFAULT (''),
  [AgentContactDetailType] [smallint] NOT NULL DEFAULT (-1),
  [AgentContactDetailTypeName] [nvarchar](100) NOT NULL DEFAULT (''),
  [AgentContactDetailTypeValue] [nvarchar](250) NOT NULL DEFAULT (''),
  [FinanceContactDisplayName] [nvarchar](250) NOT NULL DEFAULT (''),
  [FinanceContactDetailType] [smallint] NOT NULL DEFAULT (-1),
  [FinanceContactDetailTypeName] [nvarchar](100) NOT NULL DEFAULT (''),
  [FinanceContactDetailTypeValue] [nvarchar](250) NOT NULL DEFAULT (''),
  [ContractID] [int] NOT NULL CONSTRAINT [DF_Enquiries_ContractID] DEFAULT (-1),
  [AgentContractID] [int] NOT NULL CONSTRAINT [DF_Enquiries_AgentContractID] DEFAULT (-1),
  [AssetJSONDetails] [nvarchar](500) NOT NULL CONSTRAINT [DF_Enquiries_AssetJSONDetails] DEFAULT ('')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Enquiries] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [PK_Enquiries] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_Enquiries_Date] on table [SSop].[Enquiries]')
GO
CREATE INDEX [IX_Enquiries_Date]
  ON [SSop].[Enquiries] ([Date] DESC)
  INCLUDE ([OrganisationalUnitID], [Number], [Revision], [PropertyId], [PropertyNameNumber], [PropertyAddressLine1], [ClientAccountId], [AgentAccountId], [ExternalReference])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [Ix_UQ_Enquiries_Guid] on table [SSop].[Enquiries]')
GO
CREATE UNIQUE INDEX [Ix_UQ_Enquiries_Guid]
  ON [SSop].[Enquiries] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_Enquiries_AccountAddresses] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_AccountAddresses] FOREIGN KEY ([FinanceAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_AccountContacts] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_AccountContacts] FOREIGN KEY ([AgentAccountContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_AccountContacts1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_AccountContacts1] FOREIGN KEY ([ClientAccountContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_AccountContacts2] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_AccountContacts2] FOREIGN KEY ([FinanceContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Accounts] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Accounts] FOREIGN KEY ([ClientAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Accounts1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Accounts1] FOREIGN KEY ([AgentAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Accounts2] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Accounts2] FOREIGN KEY ([FinanceAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Addresses] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Addresses] FOREIGN KEY ([ClientAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Addresses1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Addresses1] FOREIGN KEY ([AgentAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_AgentContractID] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_AgentContractID] FOREIGN KEY ([AgentContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_ContractID] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_ContractID] FOREIGN KEY ([ContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Counties] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Counties] FOREIGN KEY ([PropertyCountyId]) REFERENCES [SCrm].[Counties] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Counties1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Counties1] FOREIGN KEY ([ClientAddressCountyId]) REFERENCES [SCrm].[Counties] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Counties2] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Counties2] FOREIGN KEY ([AgentCountyId]) REFERENCES [SCrm].[Counties] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Countries] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Countries] FOREIGN KEY ([PropertyCountryId]) REFERENCES [SCrm].[Countries] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Countries1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Countries1] FOREIGN KEY ([ClientAddressCountryId]) REFERENCES [SCrm].[Countries] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Countries2] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Countries2] FOREIGN KEY ([AgentCountryId]) REFERENCES [SCrm].[Countries] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_DataObjects] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_Enquiries_DataObjects] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries]
  NOCHECK CONSTRAINT [FK_Enquiries_DataObjects]
GO

PRINT (N'Create foreign key [FK_Enquiries_Identities] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Identities1] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Identities1] FOREIGN KEY ([SignatoryIdentityId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_OrganisationalUnits] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitID]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Projects] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Projects] FOREIGN KEY ([ProjectId]) REFERENCES [SSop].[Projects] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_Properties] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_Properties] FOREIGN KEY ([PropertyId]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_QuoteSources] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_QuoteSources] FOREIGN KEY ([EnquirySourceId]) REFERENCES [SSop].[QuoteSources] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_RibaStages] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_RibaStages] FOREIGN KEY ([CurrentProjectRibaStageID]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Enquiries_RowStatus] on table [SSop].[Enquiries]')
GO
ALTER TABLE [SSop].[Enquiries] WITH NOCHECK
  ADD CONSTRAINT [FK_Enquiries_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO