PRINT (N'Create table [SFin].[InvoiceRequestItems]')
GO
PRINT (N'Create table [SFin].[InvoiceRequestItems]')
GO
CREATE TABLE [SFin].[InvoiceRequestItems] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DEFAULT_InvoiceRequestItems_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_InvoiceRequestItems_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [InvoiceRequestId] [int] NOT NULL CONSTRAINT [DF_InvoiceRequestItems_InvoiceRequestItems] DEFAULT (-1),
  [MilestoneId] [bigint] NULL,
  [ActivityId] [bigint] NULL,
  [Net] [decimal](19, 2) NOT NULL CONSTRAINT [DF_InvoiceRequestItems_Net] DEFAULT (0),
  [LegacyId] [int] NULL,
  [LegacySystemID] [int] NOT NULL DEFAULT (-1),
  [ShortDescription] [nvarchar](200) NOT NULL DEFAULT (N''),
  [RIBAStageId] [int] NOT NULL CONSTRAINT [DF_InvoiceRequestItems_RIBAStageId] DEFAULT (-1),
  CONSTRAINT [PK_InvoiceRequestItems] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_InvoiceRequestItems_InvoiceRequest]
  ON [SFin].[InvoiceRequestItems] ([InvoiceRequestId], [Net], [RowStatus])
  INCLUDE ([ActivityId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_InvoiceRequestItems_Guid]
  ON [SFin].[InvoiceRequestItems] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_Activities] FOREIGN KEY ([ActivityId]) REFERENCES [SJob].[Activities] ([ID])
GO

ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SFin].[InvoiceRequestItems]
  NOCHECK CONSTRAINT [FK_InvoiceRequestItems_DataObjects]
GO

ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_InvoiceRequests] FOREIGN KEY ([InvoiceRequestId]) REFERENCES [SFin].[InvoiceRequests] ([ID])
GO

ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_Milestones] FOREIGN KEY ([MilestoneId]) REFERENCES [SJob].[Milestones] ([ID])
GO

ALTER TABLE [SFin].[InvoiceRequestItems]
  ADD CONSTRAINT [FK_InvoiceRequestItems_RibaStages] FOREIGN KEY ([RIBAStageId]) REFERENCES [SJob].[RibaStages] ([ID])
GO

ALTER TABLE [SFin].[InvoiceRequestItems] WITH NOCHECK
  ADD CONSTRAINT [FK_InvoiceRequestItems_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO