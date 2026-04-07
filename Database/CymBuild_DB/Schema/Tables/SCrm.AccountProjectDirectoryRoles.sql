CREATE TABLE [SCrm].[AccountProjectDirectoryRoles] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_AccountProjectDirectoryRoles_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_AccountProjectDirectoryRoles_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [AccountID] [int] NOT NULL CONSTRAINT [DF_AccountProjectDirectoryRoles_AccountID] DEFAULT (-1),
  [ProjectDirectoryRoleID] [int] NOT NULL CONSTRAINT [DF_AccountProjectDirectoryRoles_ProjectDirectoryRoleID] DEFAULT (-1),
  CONSTRAINT [PK_AccountProjectDirectoryRoles] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_AccountProjectDirectoryRoles_Guid]
  ON [SCrm].[AccountProjectDirectoryRoles] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SCrm].[AccountProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_AccountProjectDirectoryRoles_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCrm].[AccountProjectDirectoryRoles]
  NOCHECK CONSTRAINT [FK_AccountProjectDirectoryRoles_DataObjects]
GO

ALTER TABLE [SCrm].[AccountProjectDirectoryRoles]
  ADD CONSTRAINT [FK_AccountProjectDirectoryRoles_ProjectDirectoryRole] FOREIGN KEY ([ProjectDirectoryRoleID]) REFERENCES [SJob].[ProjectDirectoryRoles] ([ID])
GO

ALTER TABLE [SCrm].[AccountProjectDirectoryRoles]
  ADD CONSTRAINT [FK_AccountProjectDirectoryRoles_ProjectDirectoryRoles] FOREIGN KEY ([ProjectDirectoryRoleID]) REFERENCES [SJob].[ProjectDirectoryRoles] ([ID])
GO

ALTER TABLE [SCrm].[AccountProjectDirectoryRoles]
  ADD CONSTRAINT [FK_AccountProjectDirectoryRoles_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO