PRINT (N'Create table [SOffice].[TargetObjects]')
GO
CREATE TABLE [SOffice].[TargetObjects] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_TargetObjects_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_TargetObjects_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_TargetObjects_Name] DEFAULT (''),
  [Number] [nvarchar](100) NOT NULL CONSTRAINT [DF_TargetObjects_Number] DEFAULT (''),
  [EntityTypeId] [int] NOT NULL CONSTRAINT [DF_TargetObjects_EntityTypeId] DEFAULT (-1),
  [FilingLocation] [nvarchar](max) NOT NULL CONSTRAINT [DF_TargetObjects_FilingUrl] DEFAULT ('')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_TargetObjects] on table [SOffice].[TargetObjects]')
GO
ALTER TABLE [SOffice].[TargetObjects] WITH NOCHECK
  ADD CONSTRAINT [PK_TargetObjects] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_TargetObjects_EntityType] on table [SOffice].[TargetObjects]')
GO
CREATE INDEX [IX_TargetObjects_EntityType]
  ON [SOffice].[TargetObjects] ([EntityTypeId])
  INCLUDE ([Guid], [Name], [Number])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_TargetObjects_Guid] on table [SOffice].[TargetObjects]')
GO
CREATE UNIQUE INDEX [IX_UQ_TargetObjects_Guid]
  ON [SOffice].[TargetObjects] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_TargetObjects_EntityTypes] on table [SOffice].[TargetObjects]')
GO
ALTER TABLE [SOffice].[TargetObjects] WITH NOCHECK
  ADD CONSTRAINT [FK_TargetObjects_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SOffice].[EntityTypes] ([ID])
GO