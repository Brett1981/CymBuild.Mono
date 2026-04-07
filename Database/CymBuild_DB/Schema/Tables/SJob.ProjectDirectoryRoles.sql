CREATE TABLE [SJob].[ProjectDirectoryRoles] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ProjectDirectoryRoles_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ProjectDirectoryRoles_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_ProjectDirectoryRoles_Name] DEFAULT (''),
  CONSTRAINT [PK_ProjectDirectoryRoles] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ProjectDirectoryRoles_Guid]
  ON [SJob].[ProjectDirectoryRoles] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_ProjectDirectoryRoles_Name]
  ON [SJob].[ProjectDirectoryRoles] ([RowStatus], [Name])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[ProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_ProjectDirectoryRoles_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[ProjectDirectoryRoles]
  NOCHECK CONSTRAINT [FK_ProjectDirectoryRoles_DataObjects]
GO

ALTER TABLE [SJob].[ProjectDirectoryRoles]
  ADD CONSTRAINT [FK_ProjectDirectoryRoles_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO