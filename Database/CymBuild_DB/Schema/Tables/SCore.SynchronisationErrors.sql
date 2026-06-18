PRINT (N'Create table [SCore].[SynchronisationErrors]')
GO
CREATE TABLE [SCore].[SynchronisationErrors] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_SychronisationErrors_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_SychronisationErrors_Guid] DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [EntityPropertyID] [int] NOT NULL CONSTRAINT [DF_SychronisationErrors_EntityPropertyID] DEFAULT (-1),
  [RecordID] [bigint] NOT NULL CONSTRAINT [DF_SychronisationErrors_RecordID] DEFAULT (-1),
  [ProposedValue] [varbinary](max) NOT NULL CONSTRAINT [DF_SychronisationErrors_ProposedValue] DEFAULT (0x00),
  [ProposedByUserID] [int] NOT NULL CONSTRAINT [DF_SychronisationErrors_ProposedByUserID] DEFAULT (-1),
  [ProposedDateTime] [datetime2] NOT NULL CONSTRAINT [DF_SychronisationErrors_ProposedDateTime] DEFAULT (getutcdate()),
  [IsResolved] [bit] NOT NULL CONSTRAINT [DF_SychronisationErrors_IsResolved] DEFAULT (0)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SychronisationErrors] on table [SCore].[SynchronisationErrors]')
GO
ALTER TABLE [SCore].[SynchronisationErrors] WITH NOCHECK
  ADD CONSTRAINT [PK_SychronisationErrors] PRIMARY KEY CLUSTERED ([ID])
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_UQ_SychronisationErrors_Guid] on table [SCore].[SynchronisationErrors]')
GO
CREATE UNIQUE INDEX [IX_UQ_SychronisationErrors_Guid]
  ON [SCore].[SynchronisationErrors] ([Guid])
  WHERE ([RowStatus]<>(0))
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_SychronisationErrors_EntityPropertyID] on table [SCore].[SynchronisationErrors]')
GO
ALTER TABLE [SCore].[SynchronisationErrors] WITH NOCHECK
  ADD CONSTRAINT [FK_SychronisationErrors_EntityPropertyID] FOREIGN KEY ([EntityPropertyID]) REFERENCES [SCore].[EntityProperties] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_SychronisationErrors_ProposedUserID] on table [SCore].[SynchronisationErrors]')
GO
ALTER TABLE [SCore].[SynchronisationErrors] WITH NOCHECK
  ADD CONSTRAINT [FK_SychronisationErrors_ProposedUserID] FOREIGN KEY ([ProposedByUserID]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_SynchronisationErrors_RowStatus] on table [SCore].[SynchronisationErrors]')
GO
ALTER TABLE [SCore].[SynchronisationErrors] WITH NOCHECK
  ADD CONSTRAINT [FK_SynchronisationErrors_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO