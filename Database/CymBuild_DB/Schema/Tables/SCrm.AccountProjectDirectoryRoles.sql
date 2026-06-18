PRINT (N'Create table [SCrm].[AccountProjectDirectoryRoles]')
GO
CREATE TABLE [SCrm].[AccountProjectDirectoryRoles] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountProjectDirectoryRoles_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountProjectDirectoryRoles_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AccountID] [int] NOT NULL CONSTRAINT [DF_AccountProjectDirectoryRoles_AccountID] DEFAULT (-1),
  [ProjectDirectoryRoleID] [int] NOT NULL CONSTRAINT [DF_AccountProjectDirectoryRoles_ProjectDirectoryRoleID] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_AccountProjectDirectoryRoles] on table [SCrm].[AccountProjectDirectoryRoles]')
GO
ALTER TABLE [SCrm].[AccountProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [PK_AccountProjectDirectoryRoles] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_UQ_AccountProjectDirectoryRoles_Guid] on table [SCrm].[AccountProjectDirectoryRoles]')
GO
CREATE UNIQUE INDEX [IX_UQ_AccountProjectDirectoryRoles_Guid]
  ON [SCrm].[AccountProjectDirectoryRoles] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_AccountProjectDirectoryRoles_DataObjects] on table [SCrm].[AccountProjectDirectoryRoles]')
GO
ALTER TABLE [SCrm].[AccountProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountProjectDirectoryRoles_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_AccountProjectDirectoryRoles_DataObjects] on table [SCrm].[AccountProjectDirectoryRoles]')
GO
ALTER TABLE [SCrm].[AccountProjectDirectoryRoles]
  NOCHECK CONSTRAINT [FK_AccountProjectDirectoryRoles_DataObjects]
GO

PRINT (N'Create foreign key [FK_AccountProjectDirectoryRoles_ProjectDirectoryRole] on table [SCrm].[AccountProjectDirectoryRoles]')
GO
ALTER TABLE [SCrm].[AccountProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountProjectDirectoryRoles_ProjectDirectoryRole] FOREIGN KEY ([ProjectDirectoryRoleID]) REFERENCES [SJob].[ProjectDirectoryRoles] ([ID])
GO

PRINT (N'Create foreign key [FK_AccountProjectDirectoryRoles_ProjectDirectoryRoles] on table [SCrm].[AccountProjectDirectoryRoles]')
GO
ALTER TABLE [SCrm].[AccountProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountProjectDirectoryRoles_ProjectDirectoryRoles] FOREIGN KEY ([ProjectDirectoryRoleID]) REFERENCES [SJob].[ProjectDirectoryRoles] ([ID])
GO

PRINT (N'Create foreign key [FK_AccountProjectDirectoryRoles_RowStatus] on table [SCrm].[AccountProjectDirectoryRoles]')
GO
ALTER TABLE [SCrm].[AccountProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountProjectDirectoryRoles_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO