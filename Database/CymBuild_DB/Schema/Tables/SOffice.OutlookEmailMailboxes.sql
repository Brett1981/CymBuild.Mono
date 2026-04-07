CREATE TABLE [SOffice].[OutlookEmailMailboxes] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_OutlookEmaiMailboxes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_OutlookEmaiMailboxes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_OutlookEmaiMailboxes_Name] DEFAULT (''),
  CONSTRAINT [PK_OutlookEmaiMailboxes] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_OutlookEmailMailboxes_Name]
  ON [SOffice].[OutlookEmailMailboxes] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SOffice].[OutlookEmailMailboxes]
  ADD CONSTRAINT [FK_EntityTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SOffice].[OutlookEmailMailboxes]
  ADD CONSTRAINT [FK_OutlookEmaiMailboxes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO