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

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SJob].[Jobs]')
GO
CREATE TABLE [SJob].[Jobs] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Jobs_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Jobs_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [OrganisationalUnitID] [int] NOT NULL CONSTRAINT [DF_Jobs_OrganisationalUnitID] DEFAULT (-1),
  [JobTypeID] [int] NOT NULL CONSTRAINT [DF_Jobs_JobTypeID] DEFAULT (-1),
  [Number] [nvarchar](50) NOT NULL CONSTRAINT [DF_Jobs_Number] DEFAULT (0),
  [UprnID] [int] NOT NULL CONSTRAINT [DF_Jobs_UprnID] DEFAULT (-1),
  [ClientAccountID] [int] NOT NULL CONSTRAINT [DF_Jobs_ClientAccountID] DEFAULT (-1),
  [ClientAddressID] [int] NOT NULL CONSTRAINT [DF_Jobs_ClientAddressID] DEFAULT (-1),
  [ClientContactID] [int] NOT NULL CONSTRAINT [DF_Jobs_ClientContactID] DEFAULT (-1),
  [AgentAccountID] [int] NOT NULL CONSTRAINT [DF_Jobs_AgentAccountID] DEFAULT (-1),
  [AgentAddressID] [int] NOT NULL CONSTRAINT [DF_Jobs_AgentAddressID] DEFAULT (-1),
  [AgentContactID] [int] NOT NULL CONSTRAINT [DF_Jobs_AgentContactID] DEFAULT (-1),
  [FinanceAccountID] [int] NOT NULL CONSTRAINT [DF_Jobs_FinanceAccountID] DEFAULT (-1),
  [FinanceAddressID] [int] NOT NULL CONSTRAINT [DF_Jobs_FinanceAddressID] DEFAULT (-1),
  [FinanceContactID] [int] NOT NULL CONSTRAINT [DF_Jobs_FinanceContactID] DEFAULT (-1),
  [SurveyorID] [int] NOT NULL CONSTRAINT [DF_Jobs_SurveyorID] DEFAULT (-1),
  [JobDescription] [nvarchar](1000) NOT NULL CONSTRAINT [DF_Jobs_JobDescription] DEFAULT (''),
  [IsSubjectToNDA] [bit] NOT NULL CONSTRAINT [DF_Jobs_IsSubjectToNDA] DEFAULT (0),
  [JobStarted] [datetime2] NULL,
  [JobCompleted] [datetime2] NULL,
  [JobCancelled] [datetime2] NULL,
  [ValueOfWorkID] [smallint] NOT NULL CONSTRAINT [DF_Jobs_ValueOfWorkID] DEFAULT (-1),
  [RibaStage1Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage1Fee] DEFAULT (0),
  [RibaStage2Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage2Fee] DEFAULT (0),
  [RibaStage3Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage3Fee] DEFAULT (0),
  [RibaStage4Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage4Fee] DEFAULT (0),
  [RibaStage5Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage5Fee] DEFAULT (0),
  [RibaStage6Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage6Fee] DEFAULT (0),
  [RibaStage7Fee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_RibaStage7Fee] DEFAULT (0),
  [PreConstructionStageFee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_PreConstructionStageFee] DEFAULT (0),
  [ConstructionStageFee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_ConstructionStageFee] DEFAULT (0),
  [AgreedFee] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_AgreedFee] DEFAULT (0),
  [FeeCap] [decimal](19, 2) NOT NULL CONSTRAINT [DF_Jobs_FeeCap] DEFAULT (0),
  [ArchiveReferenceLink] [nvarchar](500) NOT NULL CONSTRAINT [DF_Jobs_ArchiveReferenceLink] DEFAULT (''),
  [ArchiveBoxReference] [nvarchar](100) NOT NULL CONSTRAINT [DF_Jobs_ArchiveBoxReference] DEFAULT (''),
  [CreatedByUserID] [int] NOT NULL CONSTRAINT [DF_Jobs_CreatedByUserID] DEFAULT (-1),
  [CreatedOn] [datetime2] NULL,
  [ExternalReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Jobs_ExternalReference] DEFAULT (''),
  [VersionID] [int] NOT NULL CONSTRAINT [DF_Jobs_VersionID] DEFAULT (-1),
  [IsCompleteForReview] [bit] NOT NULL CONSTRAINT [DF_Jobs_IsCompleteForReview] DEFAULT (0),
  [ReviewedByUserID] [int] NOT NULL CONSTRAINT [DF_Jobs_ReviewedByUserID] DEFAULT (-1),
  [ReviewedDateTimeUTC] [datetime2] NULL,
  [LegacyID] [int] NULL,
  [ContractID] [int] NOT NULL CONSTRAINT [DF_Jobs_ContractID] DEFAULT (-1),
  [AppFormReceived] [bit] NOT NULL CONSTRAINT [DF_Jobs_AppFormReceived] DEFAULT (0),
  [CurrentRibaStageId] [int] NOT NULL CONSTRAINT [DF_Jobs_CurrentRibaStageId] DEFAULT (-1),
  [AppointedFromStageId] [int] NOT NULL CONSTRAINT [DF_Jobs_AppointedFromStageId] DEFAULT (-1),
  [JobDormant] [datetime2] NULL,
  [PurchaseOrderNumber] [nvarchar](28) NOT NULL CONSTRAINT [DF_Jobs_PurchaseOrderNumber] DEFAULT (''),
  [ProjectId] [int] NOT NULL CONSTRAINT [DF_Jobs_ProjectId] DEFAULT (-1),
  [ValueOfWork] [decimal](19, 2) NOT NULL CONSTRAINT [DF__Jobs__ValueOfWor__58F2C25C] DEFAULT (0),
  [ClientAppointmentReceived] [bit] NOT NULL CONSTRAINT [DF__Jobs__ClientAppo__78015961] DEFAULT (0),
  [DeadDate] [date] NULL,
  [IsActive] AS (CONVERT([bit],case when [JobCompleted] IS NULL AND [JobCancelled] IS NULL AND [JobDormant] IS NULL AND [DeadDate] IS NULL then (1) else (0) end)) PERSISTED,
  [IsComplete] AS (CONVERT([bit],case when [JobCompleted] IS NOT NULL OR [JobCancelled] IS NOT NULL OR [DeadDate] IS NOT NULL then (1) else (0) end)) PERSISTED,
  [IsCancelled] AS (CONVERT([bit],case when [JobCancelled] IS NOT NULL then (1) else (0) end)) PERSISTED,
  [IsPendingCompletion] AS (CONVERT([bit],case when [IsCompleteForReview]=(1) OR [ReviewedByUserID]>(0) then (1) else (0) end)) PERSISTED,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [BillingInstruction] [nvarchar](max) NULL CONSTRAINT [DF_Jobs_BillingInstruction] DEFAULT (''),
  [CannotBeInvoiced] [bit] NOT NULL CONSTRAINT [DF_Jobs_CannotBeInvoiced] DEFAULT (0),
  [CannotBeInvoicedReason] [nvarchar](max) NOT NULL CONSTRAINT [DF_Jobs_CannotBeInvoicedReason] DEFAULT (''),
  [AgentContractID] [int] NOT NULL CONSTRAINT [DF_Jobs_AgentContractID] DEFAULT (-1),
  [CompletedForReviewDate] [datetime] NULL CONSTRAINT [DF_Jobs_CompletedForReviewDate] DEFAULT (NULL),
  [SectorId] [int] NOT NULL CONSTRAINT [DF_Jobs_SectorId] DEFAULT (-1),
  [MarketId] [int] NOT NULL CONSTRAINT [DF_Jobs_MarketId] DEFAULT (-1),
  [ManualInvoicingEnabled] [bit] NOT NULL CONSTRAINT [DF_Jobs_ManualInvoicingEnabled] DEFAULT (0)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Jobs] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [PK_Jobs] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Jobs_Finance] on table [SJob].[Jobs]')
GO
CREATE INDEX [IX_Jobs_Finance]
  ON [SJob].[Jobs] ([FinanceAccountID], [Guid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Jobs_Status] on table [SJob].[Jobs]')
GO
CREATE INDEX [IX_Jobs_Status]
  ON [SJob].[Jobs] ([IsActive], [IsComplete], [IsCancelled], [IsPendingCompletion], [RowStatus])
  INCLUDE ([UprnID], [SurveyorID], [Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Jobs_Surveyor] on table [SJob].[Jobs]')
GO
CREATE INDEX [IX_Jobs_Surveyor]
  ON [SJob].[Jobs] ([SurveyorID], [RowStatus])
  INCLUDE ([Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Jobs_Guid] on table [SJob].[Jobs]')
GO
CREATE UNIQUE INDEX [IX_UQ_Jobs_Guid]
  ON [SJob].[Jobs] ([Guid])
  INCLUDE ([RowStatus])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_Jobs_Number] on table [SJob].[Jobs]')
GO
CREATE UNIQUE INDEX [IX_UQ_Jobs_Number]
  ON [SJob].[Jobs] ([Number], [RowStatus])
  WHERE ([RowStatus]<>(0))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_Jobs_Accounts] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Accounts] FOREIGN KEY ([AgentAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Accounts1] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Accounts1] FOREIGN KEY ([ClientAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Accounts2] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Accounts2] FOREIGN KEY ([FinanceAccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Addresses] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Addresses] FOREIGN KEY ([ClientAddressID]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Addresses1] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Addresses1] FOREIGN KEY ([AgentAddressID]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Addresses2] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Addresses2] FOREIGN KEY ([FinanceAddressID]) REFERENCES [SCrm].[AccountAddresses] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_AgentContractID] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_AgentContractID] FOREIGN KEY ([AgentContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Contacts] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Contacts] FOREIGN KEY ([AgentContactID]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Contacts1] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Contacts1] FOREIGN KEY ([ClientContactID]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Contacts3] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Contacts3] FOREIGN KEY ([FinanceContactID]) REFERENCES [SCrm].[AccountContacts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Contracts] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Contracts] FOREIGN KEY ([ContractID]) REFERENCES [SSop].[Contracts] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_DataObjects] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Jobs_DataObjects] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs]
  NOCHECK CONSTRAINT [FK_Jobs_DataObjects]
GO

PRINT (N'Create foreign key [FK_Jobs_Identities] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Identities] FOREIGN KEY ([SurveyorID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Identities1] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Identities1] FOREIGN KEY ([CreatedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Identities2] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Identities2] FOREIGN KEY ([ReviewedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_JobTypes] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_JobTypes] FOREIGN KEY ([JobTypeID]) REFERENCES [SJob].[JobTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Markets] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Markets] FOREIGN KEY ([MarketId]) REFERENCES [SCore].[Markets] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_OrganisationalUnits] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitID]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Projects] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Projects] FOREIGN KEY ([ProjectId]) REFERENCES [SSop].[Projects] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Properties] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Properties] FOREIGN KEY ([UprnID]) REFERENCES [SJob].[Assets] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_RibaStages] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_RibaStages] FOREIGN KEY ([CurrentRibaStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_RibaStages1] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_RibaStages1] FOREIGN KEY ([AppointedFromStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_RowStatus] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Sectors] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Sectors] FOREIGN KEY ([SectorId]) REFERENCES [SCore].[Sectors] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_ValuesOfWork] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_ValuesOfWork] FOREIGN KEY ([ValueOfWorkID]) REFERENCES [SJob].[ValuesOfWork] ([ID])
GO

PRINT (N'Create foreign key [FK_Jobs_Versioning] on table [SJob].[Jobs]')
GO
ALTER TABLE [SJob].[Jobs] WITH NOCHECK
  ADD CONSTRAINT [FK_Jobs_Versioning] FOREIGN KEY ([VersionID]) REFERENCES [SCore].[Versioning] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on column [SJob].[Jobs].[JobTypeID]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Job Type', 'SCHEMA', N'SJob', 'TABLE', N'Jobs', 'COLUMN', N'JobTypeID'
GO