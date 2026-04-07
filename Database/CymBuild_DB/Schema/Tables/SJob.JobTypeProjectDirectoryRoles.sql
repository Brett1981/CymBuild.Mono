CREATE TABLE [SJob].[JobTypeProjectDirectoryRoles] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobTypeProjectDirectoryRoles_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobTypeProjectDirectoryRoles_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [JobTypeID] [int] NOT NULL CONSTRAINT [DF_JobTypeProjectDirectoryRoles_JobTypeID] DEFAULT (-1),
  [ProjectDirectoryRoleID] [int] NOT NULL CONSTRAINT [DF_JobTypeProjectDirectoryRoles_ProjectDirectoryRoleID] DEFAULT (-1),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF_JobTypeProjectDirectoryRoles_SortOrder] DEFAULT (0),
  CONSTRAINT [PK_JobTypeProjectDirectoryRoles] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobTypeProjectDirectoryRoles_Guid]
  ON [SJob].[JobTypeProjectDirectoryRoles] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobTypeProjectDirectoryRoles_JobType_Role]
  ON [SJob].[JobTypeProjectDirectoryRoles] ([JobTypeID], [ProjectDirectoryRoleID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypeProjectDirectoryRoles_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles]
  NOCHECK CONSTRAINT [FK_JobTypeProjectDirectoryRoles_DataObjects]
GO

ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles]
  ADD CONSTRAINT [FK_JobTypeProjectDirectoryRoles_JobTypes] FOREIGN KEY ([JobTypeID]) REFERENCES [SJob].[JobTypes] ([ID])
GO

ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles]
  ADD CONSTRAINT [FK_JobTypeProjectDirectoryRoles_ProjectDirectoryRoles] FOREIGN KEY ([ProjectDirectoryRoleID]) REFERENCES [SJob].[ProjectDirectoryRoles] ([ID])
GO

ALTER TABLE [SJob].[JobTypeProjectDirectoryRoles]
  ADD CONSTRAINT [FK_JobTypeProjectDirectoryRoles_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO