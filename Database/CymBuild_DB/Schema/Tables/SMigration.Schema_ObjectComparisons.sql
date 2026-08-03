PRINT (N'Create table [SMigration].[Schema_ObjectComparisons]')
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Schema_ObjectComparisons_Run_Active] on table [SMigration].[Schema_ObjectComparisons]')
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_Schema_ObjectComparisons_Run_Key_Active] on table [SMigration].[Schema_ObjectComparisons]')
GO
PRINT (N'Create table [SMigration].[Schema_ObjectComparisons]')
GO
CREATE TABLE [SMigration].[Schema_ObjectComparisons] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_RowStatus] DEFAULT (1),
  [RunGuid] [uniqueidentifier] NOT NULL,
  [ObjectType] [nvarchar](50) NOT NULL,
  [SchemaName] [nvarchar](128) NOT NULL,
  [ObjectName] [nvarchar](512) NOT NULL,
  [ParentObjectName] [nvarchar](512) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_ParentObjectName] DEFAULT (N''),
  [DifferenceType] [nvarchar](30) NOT NULL,
  [SourceHash] [nvarchar](128) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_SourceHash] DEFAULT (N''),
  [TargetHash] [nvarchar](128) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_TargetHash] DEFAULT (N''),
  [SourceDefinition] [nvarchar](max) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_SourceDefinition] DEFAULT (N''),
  [TargetDefinition] [nvarchar](max) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_TargetDefinition] DEFAULT (N''),
  [IsDeployable] [bit] NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_IsDeployable] DEFAULT (0),
  [IsDestructiveRisk] [bit] NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_IsDestructiveRisk] DEFAULT (0),
  [Notes] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_Notes] DEFAULT (N''),
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Schema_ObjectComparisons_CreatedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Schema_ObjectComparisons] on table [SMigration].[Schema_ObjectComparisons]')
GO
ALTER TABLE [SMigration].[Schema_ObjectComparisons] WITH NOCHECK
  ADD CONSTRAINT [PK_Schema_ObjectComparisons] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Schema_ObjectComparisons_Guid] on table [SMigration].[Schema_ObjectComparisons]')
GO
ALTER TABLE [SMigration].[Schema_ObjectComparisons] WITH NOCHECK
  ADD CONSTRAINT [UQ_Schema_ObjectComparisons_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Schema_ObjectComparisons_Run_Active] on table [SMigration].[Schema_ObjectComparisons]')
GO
CREATE INDEX [IX_Schema_ObjectComparisons_Run_Active]
  ON [SMigration].[Schema_ObjectComparisons] ([RunGuid], [DifferenceType], [ObjectType], [SchemaName], [ObjectName])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_Schema_ObjectComparisons_Run_Key_Active] on table [SMigration].[Schema_ObjectComparisons]')
GO
CREATE UNIQUE INDEX [UX_Schema_ObjectComparisons_Run_Key_Active]
  ON [SMigration].[Schema_ObjectComparisons] ([RunGuid], [ObjectType], [SchemaName], [ObjectName], [ParentObjectName])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO