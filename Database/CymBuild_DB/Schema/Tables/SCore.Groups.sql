PRINT (N'Create table [SCore].[Groups]')
GO
CREATE TABLE [SCore].[Groups] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Groups_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_Groups_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [DirectoryId] [nvarchar](100) NOT NULL CONSTRAINT [DF_Groups_DirectoryId] DEFAULT (''),
  [Code] [nvarchar](30) NOT NULL CONSTRAINT [DF_Groups_Code] DEFAULT (''),
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_Groups_Name] DEFAULT (''),
  [Source] [nvarchar](250) NOT NULL CONSTRAINT [DF_Groups_Source] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Groups] on table [SCore].[Groups]')
GO
ALTER TABLE [SCore].[Groups] WITH NOCHECK
  ADD CONSTRAINT [PK_Groups] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_DirectoryID] on table [SCore].[Groups]')
GO
CREATE UNIQUE INDEX [IX_UQ_DirectoryID]
  ON [SCore].[Groups] ([DirectoryId])
  WHERE ([DirectoryId]<>N'')
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_Groups_Guid] on table [SCore].[Groups]')
GO
CREATE UNIQUE INDEX [IX_UQ_Groups_Guid]
  ON [SCore].[Groups] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_Uq_Groups_Name] on table [SCore].[Groups]')
GO
CREATE UNIQUE INDEX [IX_Uq_Groups_Name]
  ON [SCore].[Groups] ([Name])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_Groups_DataObjects] on table [SCore].[Groups]')
GO
ALTER TABLE [SCore].[Groups] WITH NOCHECK
  ADD CONSTRAINT [FK_Groups_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_Groups_DataObjects] on table [SCore].[Groups]')
GO
ALTER TABLE [SCore].[Groups]
  NOCHECK CONSTRAINT [FK_Groups_DataObjects]
GO

PRINT (N'Create foreign key [FK_Groups_RowStatus] on table [SCore].[Groups]')
GO
ALTER TABLE [SCore].[Groups] WITH NOCHECK
  ADD CONSTRAINT [FK_Groups_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[Groups]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Groups of Users', 'SCHEMA', N'SCore', 'TABLE', N'Groups'
GO

PRINT (N'Add extended property [MS_Description] on column [SCore].[Groups].[Source]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Kafka notification source identifier (e.g. cymbuild-fireengineering-authorisation)', 'SCHEMA', N'SCore', 'TABLE', N'Groups', 'COLUMN', N'Source'
GO