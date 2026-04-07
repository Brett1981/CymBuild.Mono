PRINT (N'Create table [SCore].[ObjectSecurity]')
GO
CREATE TABLE [SCore].[ObjectSecurity] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ObjectSecurity_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ObjectSecurity_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ObjectGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ObjectSecurity_RecordGuid] DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [UserId] [int] NOT NULL CONSTRAINT [DF_ObjectSecurity_UserId] DEFAULT (-1),
  [GroupId] [int] NOT NULL CONSTRAINT [DF_ObjectSecurity_GroupId] DEFAULT (-1),
  [CanRead] [bit] NOT NULL CONSTRAINT [DF_ObjectSecurity_CanRead] DEFAULT (0),
  [DenyRead] [bit] NOT NULL CONSTRAINT [DF_ObjectSecurity_DenyRead] DEFAULT (0),
  [CanWrite] [bit] NOT NULL CONSTRAINT [DF_ObjectSecurity_CanWrite] DEFAULT (0),
  [DenyWrite] [bit] NOT NULL CONSTRAINT [DF_ObjectSecurity_DenyWrite] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_ObjectSecurity] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
  ADD CONSTRAINT [PK_ObjectSecurity] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_ObjectSecurity_CanRead] on table [SCore].[ObjectSecurity]')
GO
CREATE INDEX [IX_ObjectSecurity_CanRead]
  ON [SCore].[ObjectSecurity] ([ObjectGuid], [CanRead], [RowStatus])
  INCLUDE ([UserId], [GroupId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_ObjectSecurity_DenyRead] on table [SCore].[ObjectSecurity]')
GO
CREATE INDEX [IX_ObjectSecurity_DenyRead]
  ON [SCore].[ObjectSecurity] ([ObjectGuid], [DenyRead], [RowStatus])
  INCLUDE ([UserId], [GroupId])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_ObjectSecurity_ObjectGuid] on table [SCore].[ObjectSecurity]')
GO
CREATE INDEX [IX_ObjectSecurity_ObjectGuid]
  ON [SCore].[ObjectSecurity] ([ObjectGuid], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_ObjectSecurity_Guid] on table [SCore].[ObjectSecurity]')
GO
CREATE UNIQUE INDEX [IX_UQ_ObjectSecurity_Guid]
  ON [SCore].[ObjectSecurity] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_ObjectSecurity_Setting] on table [SCore].[ObjectSecurity]')
GO
CREATE UNIQUE INDEX [IX_UQ_ObjectSecurity_Setting]
  ON [SCore].[ObjectSecurity] ([ObjectGuid], [UserId], [GroupId], [RowStatus])
  INCLUDE ([CanRead], [DenyRead], [CanWrite], [DenyWrite])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create statistics [stat_ObjectSecurity_CanRead] on table [SCore].[ObjectSecurity]')
GO
CREATE STATISTICS [stat_ObjectSecurity_CanRead]
  ON [SCore].[ObjectSecurity] ([UserId], [GroupId], [DenyRead], [ObjectGuid], [CanRead])
GO

PRINT (N'Create foreign key [FK_ObjectSecurity_DataObjects] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSecurity_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_ObjectSecurity_DataObjects] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity]
  NOCHECK CONSTRAINT [FK_ObjectSecurity_DataObjects]
GO

PRINT (N'Create foreign key [FK_ObjectSecurity_Goups] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSecurity_Goups] FOREIGN KEY ([GroupId]) REFERENCES [SCore].[Groups] ([ID])
GO

PRINT (N'Create foreign key [FK_ObjectSecurity_RowStatus] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSecurity_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_ObjectSecurity_Users] on table [SCore].[ObjectSecurity]')
GO
ALTER TABLE [SCore].[ObjectSecurity] WITH NOCHECK
  ADD CONSTRAINT [FK_ObjectSecurity_Users] FOREIGN KEY ([UserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Add extended property [MS_Description] on table [SCore].[ObjectSecurity]')
GO
EXEC sys.sp_addextendedproperty N'MS_Description', N'Security records for all rows both meta data and user data. ', 'SCHEMA', N'SCore', 'TABLE', N'ObjectSecurity'
GO