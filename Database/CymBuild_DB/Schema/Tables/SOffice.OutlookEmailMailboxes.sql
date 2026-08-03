PRINT (N'Create table [SOffice].[OutlookEmailMailboxes]')
GO
PRINT (N'Create table [SOffice].[OutlookEmailMailboxes]')
GO
CREATE TABLE [SOffice].[OutlookEmailMailboxes] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_OutlookEmaiMailboxes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_OutlookEmaiMailboxes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_OutlookEmaiMailboxes_Name] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_OutlookEmaiMailboxes] on table [SOffice].[OutlookEmailMailboxes]')
GO
ALTER TABLE [SOffice].[OutlookEmailMailboxes] WITH NOCHECK
  ADD CONSTRAINT [PK_OutlookEmaiMailboxes] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_OutlookEmailMailboxes_Name] on table [SOffice].[OutlookEmailMailboxes]')
GO
CREATE UNIQUE INDEX [IX_UQ_OutlookEmailMailboxes_Name]
  ON [SOffice].[OutlookEmailMailboxes] ([Name], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_EntityTypes_RowStatus] on table [SOffice].[OutlookEmailMailboxes]')
GO
ALTER TABLE [SOffice].[OutlookEmailMailboxes] WITH NOCHECK
  ADD CONSTRAINT [FK_EntityTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_OutlookEmaiMailboxes_RowStatus] on table [SOffice].[OutlookEmailMailboxes]')
GO
ALTER TABLE [SOffice].[OutlookEmailMailboxes] WITH NOCHECK
  ADD CONSTRAINT [FK_OutlookEmaiMailboxes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO