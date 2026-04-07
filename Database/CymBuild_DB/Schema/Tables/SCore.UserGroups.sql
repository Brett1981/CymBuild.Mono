CREATE TABLE [SCore].[UserGroups] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_UserGroups_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_UserGroups_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [IdentityID] [int] NOT NULL CONSTRAINT [DF_UserGroups_UserID] DEFAULT (-1),
  [GroupID] [int] NOT NULL CONSTRAINT [DF_UserGroups_GroupID] DEFAULT (-1),
  CONSTRAINT [PK_UserGroups] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_UserGroups_Guid]
  ON [SCore].[UserGroups] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_UserGroups_Identity_Group]
  ON [SCore].[UserGroups] ([IdentityID], [GroupID], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

ALTER TABLE [SCore].[UserGroups] WITH NOCHECK
  ADD CONSTRAINT [FK_UserGroups_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SCore].[UserGroups]
  NOCHECK CONSTRAINT [FK_UserGroups_DataObjects]
GO

ALTER TABLE [SCore].[UserGroups]
  ADD CONSTRAINT [FK_UserGroups_Groups] FOREIGN KEY ([GroupID]) REFERENCES [SCore].[Groups] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SCore].[UserGroups]
  ADD CONSTRAINT [FK_UserGroups_Identities] FOREIGN KEY ([IdentityID]) REFERENCES [SCore].[Identities] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SCore].[UserGroups]
  ADD CONSTRAINT [FK_UserGroups_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'The mapping between Users and their Groups', 'SCHEMA', N'SCore', 'TABLE', N'UserGroups'
GO