PRINT (N'Create table [SFin].[Transactions]')
GO
CREATE TABLE [SFin].[Transactions] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_Transactions_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_Transactions_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [TransactionTypeID] [smallint] NOT NULL CONSTRAINT [DF_Transactions_TransactionTypeID] DEFAULT (-1),
  [AccountID] [int] NOT NULL CONSTRAINT [DF_Transactions_AccountID] DEFAULT (-1),
  [JobID] [int] NOT NULL CONSTRAINT [DF_Transactions_JobID] DEFAULT (-1),
  [Number] [nvarchar](30) NOT NULL CONSTRAINT [DF_Transactions_Number] DEFAULT (''),
  [Date] [date] NOT NULL CONSTRAINT [DF_Transactions_Date] DEFAULT (getdate()),
  [LegacyId] [decimal](18, 2) NULL,
  [PurchaseOrderNumber] [nvarchar](28) NOT NULL CONSTRAINT [DF_Transactions_PurchaseOrderNumber] DEFAULT (''),
  [SageTransactionReference] [nvarchar](50) NOT NULL CONSTRAINT [DF_Transactions_SageTransactionNumber] DEFAULT (''),
  [OrganisationalUnitId] [int] NOT NULL CONSTRAINT [DF_Transactions_OrganisationalUnit] DEFAULT (-1),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_Transactions_CreatedByUserId] DEFAULT (-1),
  [SurveyorUserId] [int] NOT NULL CONSTRAINT [DF_Transactions_SurveyorUserId] DEFAULT (-1),
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_Transactions_CreatedDateTimeUTC] DEFAULT (getutcdate()),
  [CreditTermsId] [int] NOT NULL CONSTRAINT [DF_Transactions_CreditTermsId] DEFAULT (-1),
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [ExpectedDate] [date] NULL,
  [Batched] [bit] NOT NULL CONSTRAINT [DF_Transactions_Batched] DEFAULT (0),
  CONSTRAINT [PK_Transactions] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_Transactions_Account]
  ON [SFin].[Transactions] ([AccountID], [Date])
  INCLUDE ([RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE INDEX [IX_Transactions_JobId]
  ON [SFin].[Transactions] ([JobID], [RowStatus])
  INCLUDE ([Number])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE INDEX [IX_Transactions_MyInvoicing]
  ON [SFin].[Transactions] ([Date], [RowStatus], [ID])
  INCLUDE ([TransactionTypeID], [AccountID], [JobID], [Guid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [ID]>(0))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE INDEX [IX_Transactions_TransactionType]
  ON [SFin].[Transactions] ([TransactionTypeID], [RowStatus])
  INCLUDE ([CreditTermsId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Transactions_Guid]
  ON [SFin].[Transactions] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_Accounts] FOREIGN KEY ([AccountID]) REFERENCES [SCrm].[Accounts] ([ID])
GO

ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_CreditTerms] FOREIGN KEY ([CreditTermsId]) REFERENCES [SFin].[CreditTerms] ([ID])
GO

ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[Transactions]
  NOCHECK CONSTRAINT [FK_Transactions_DataObjects]
GO

ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_Identities] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_Identities1] FOREIGN KEY ([SurveyorUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_Jobs] FOREIGN KEY ([JobID]) REFERENCES [SJob].[Jobs] ([ID])
GO

ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitId]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SFin].[Transactions] WITH NOCHECK
  ADD CONSTRAINT [FK_Transactions_TransactionTypes] FOREIGN KEY ([TransactionTypeID]) REFERENCES [SFin].[TransactionTypes] ([ID])
GO