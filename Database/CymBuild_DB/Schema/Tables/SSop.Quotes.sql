SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SSop].[Quotes]')
GO
CREATE TABLE [SSop].[Quotes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Quotes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Quotes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Number] [nvarchar](50) NOT NULL CONSTRAINT [DF_Quotes_Number] DEFAULT (0),
  [RevisionNumber] [int] NOT NULL CONSTRAINT [DF_Quotes_RevisionNumber] DEFAULT (0),
  [OriginalQuoteId] [int] NOT NULL CONSTRAINT [DF_Quotes_OriginalQuoteId] DEFAULT (-1),
  [EnquiryServiceID] [int] NOT NULL CONSTRAINT [DF_Quotes_EnquiryServiceID] DEFAULT (-1),
  [QuotingUserId] [int] NOT NULL CONSTRAINT [DF_Quotes_QuoteingUserId] DEFAULT (-1),
  [QuotingConsultantId] [int] NOT NULL CONSTRAINT [DF_Quotes_QuotingConsultantId] DEFAULT (-1),
  [IsFinal] [bit] NOT NULL CONSTRAINT [DF_Quotes_IsFinal] DEFAULT (0),
  [FeeCap] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Quotes_FeeCap] DEFAULT (0),
  [AppointmentFromRibaStageId] [int] NOT NULL CONSTRAINT [DF_Quotes_AppointedFromRibaStageId] DEFAULT (-1),
  [Date] [date] NOT NULL CONSTRAINT [DF_Quotes_Date] DEFAULT (getdate()),
  [ExpiryDate] [date] NOT NULL CONSTRAINT [DF_Quotes_ExpiryDate] DEFAULT (getdate()),
  [DateSent] [date] NULL,
  [DateAccepted] [date] NULL,
  [DateRejected] [date] NULL,
  [DeadDate] [date] NULL,
  [RejectionReason] [nvarchar](max) NOT NULL CONSTRAINT [DF_Quotes_RejectionReason] DEFAULT (''),
  [ExclusionsAndLimitations] [nvarchar](max) NOT NULL CONSTRAINT [DF_Quotes_ExclusionsAndLimitations] DEFAULT (''),
  [OrganisationalUnitID] [int] NOT NULL CONSTRAINT [DF_Quotes_OrganisationalUnitID] DEFAULT (-1),
  [ContractID] [int] NOT NULL CONSTRAINT [DF_Quotes_ContractID] DEFAULT (-1),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL CONSTRAINT [DF_Quotes_LegacySystem] DEFAULT (-1),
  [UprnId] [int] NOT NULL CONSTRAINT [DF_Quotes_UprnId] DEFAULT (-1),
  [ClientAccountId] [int] NOT NULL CONSTRAINT [DF_Quotes_ClientAccountId] DEFAULT (-1),
  [ClientAddressId] [int] NOT NULL CONSTRAINT [DF_Quotes_CLientAddressId] DEFAULT (-1),
  [ClientContactId] [int] NOT NULL CONSTRAINT [DF_Quotes_ClientContactId] DEFAULT (-1),
  [Overview] [nvarchar](max) NOT NULL CONSTRAINT [DF_Quotes_Overview] DEFAULT (''),
  [QuoteSourceId] [int] NOT NULL CONSTRAINT [DF_Quotes_QuoteSourceId] DEFAULT (-1),
  [IsSubjectToNDA] [bit] NOT NULL CONSTRAINT [DF_Quotes_IsSubjectToNDA] DEFAULT (0),
  [AgentAccountId] [int] NOT NULL CONSTRAINT [DF_Quotes_AgentAccountId] DEFAULT (-1),
  [AgentAddressId] [int] NOT NULL CONSTRAINT [DF_Quotes_AgentAddressId] DEFAULT (-1),
  [AgentContactId] [int] NOT NULL CONSTRAINT [DF_Quotes_AgentContactId] DEFAULT (-1),
  [ExternalReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Quotes_ExternalReference] DEFAULT (''),
  [ChaseDate1] [date] NULL,
  [ChaseDate2] [date] NULL,
  [SendInfoToClient] [bit] NOT NULL CONSTRAINT [DF_Quotes_SendInfoToClient] DEFAULT (0),
  [SendInfoToAgent] [bit] NOT NULL CONSTRAINT [DF_Quotes_SendInfoToAgent] DEFAULT (0),
  [CurrentRibaStageId] [int] NOT NULL CONSTRAINT [DF_Quotes_CurrentRibaStageId] DEFAULT (-1),
  [ProjectId] [int] NOT NULL CONSTRAINT [DF_Quotes_ProjectId] DEFAULT (-1),
  [ValueOfWork] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Quotes_ValueOfWork] DEFAULT (0),
  [DateDeclinedToQuote] [date] NULL,
  [DeclinedToQuoteReason] [nvarchar](4000) NOT NULL CONSTRAINT [DF_Quotes_Declined] DEFAULT (''),
  [DescriptionOfWorks] [nvarchar](4000) NOT NULL CONSTRAINT [DF_Quotes_Description] DEFAULT (''),
  [FullNumber] AS ([Number]+case when [RevisionNumber]>(0) then (N' ('+CONVERT([nvarchar](50),[RevisionNumber]))+N')' else N'' end) PERSISTED,
  [AgentContractID] [int] NOT NULL CONSTRAINT [DF_Quotes_AgentContractId] DEFAULT (-1),
  [SectorId] [int] NOT NULL CONSTRAINT [DF_Quotes_SectorId] DEFAULT (-1),
  [MarketId] [int] NOT NULL CONSTRAINT [DF_Quotes_MarketId] DEFAULT (-1)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Quotes] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [PK_Quotes] PRIMARY KEY CLUSTERED ([ID]) WITH (PAD_INDEX = ON, FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_Quote_Status] on table [SSop].[Quotes]')
GO
CREATE UNIQUE INDEX [IX_Quote_Status]
  ON [SSop].[Quotes] ([ID])
  INCLUDE ([IsFinal], [ExpiryDate], [DateSent], [DateAccepted], [DateRejected], [DeadDate], [DateDeclinedToQuote])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Quotes_DateAccepted] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_DateAccepted]
  ON [SSop].[Quotes] ([DateAccepted], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Quotes_DW] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_DW]
  ON [SSop].[Quotes] ([DateSent])
  INCLUDE ([OrganisationalUnitID], [QuotingUserId], [UprnId], [ClientAccountId], [DateAccepted], [DateRejected], [AgentAccountId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Quotes_EnquiryService] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_EnquiryService]
  ON [SSop].[Quotes] ([EnquiryServiceID], [DateSent], [DateRejected], [DateAccepted])
  INCLUDE ([RevisionNumber])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Quotes_EnquiryServiceId_RowStatus_Dates] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_EnquiryServiceId_RowStatus_Dates]
  ON [SSop].[Quotes] ([EnquiryServiceID], [RowStatus])
  INCLUDE ([DateSent])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Quotes_EnquiryServiceId_StatusDates] on table [SSop].[Quotes]')
GO
CREATE INDEX [IX_Quotes_EnquiryServiceId_StatusDates]
  ON [SSop].[Quotes] ([EnquiryServiceID])
  INCLUDE ([DateAccepted], [DateDeclinedToQuote], [DateRejected], [DateSent])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Quotes_Guid] on table [SSop].[Quotes]')
GO
CREATE UNIQUE INDEX [IX_UQ_Quotes_Guid]
  ON [SSop].[Quotes] ([Guid])
  INCLUDE ([RowStatus])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [Quotes_Number] on table [SSop].[Quotes]')
GO
CREATE INDEX [Quotes_Number]
  ON [SSop].[Quotes] ([Number] DESC, [RevisionNumber], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_Quotes_AccountAddresses] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_AccountAddresses] FOREIGN KEY ([ClientAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_AccountAddresses1] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_AccountAddresses1] FOREIGN KEY ([AgentAddressId]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_AccountContacts] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_AccountContacts] FOREIGN KEY ([AgentContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_AccountContacts1] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_AccountContacts1] FOREIGN KEY ([ClientContactId]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Accounts] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Accounts] FOREIGN KEY ([ClientAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Accounts1] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Accounts1] FOREIGN KEY ([AgentAccountId]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_AgentContractID] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_AgentContractID] FOREIGN KEY ([AgentContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Contracts] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Contracts] FOREIGN KEY ([ContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_DataObjects] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid]) ON DELETE CASCADE
GO

PRINT (N'Disable foreign key [FK_Quotes_DataObjects] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes]
  NOCHECK CONSTRAINT [FK_Quotes_DataObjects]
GO

PRINT (N'Create foreign key [FK_Quotes_EnquiryServices] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_EnquiryServices] FOREIGN KEY ([EnquiryServiceID]) REFERENCES [SSop].[EnquiryServices] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Identities] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Identities] FOREIGN KEY ([QuotingUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Identities1] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Identities1] FOREIGN KEY ([QuotingConsultantId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Markets] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Markets] FOREIGN KEY ([MarketId]) REFERENCES [SCore].[Markets] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_OrganisationalUnits] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitID]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Projects] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Projects] FOREIGN KEY ([ProjectId]) REFERENCES [SSop].[Projects] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Properties] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Properties] FOREIGN KEY ([UprnId]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_QuoteSources] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_QuoteSources] FOREIGN KEY ([QuoteSourceId]) REFERENCES [SSop].[QuoteSources] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_RibaStages] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_RibaStages] FOREIGN KEY ([AppointmentFromRibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_RibaStages1] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_RibaStages1] FOREIGN KEY ([CurrentRibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_RowStatus] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Quotes_Sectors] on table [SSop].[Quotes]')
GO
ALTER TABLE [SSop].[Quotes] WITH NOCHECK
  ADD CONSTRAINT [FK_Quotes_Sectors] FOREIGN KEY ([SectorId]) REFERENCES [SCore].[Sectors] ([ID])
GO