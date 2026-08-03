PRINT (N'Create table [SMigration].[Schema_RunSelections]')
GO
PRINT (N'Create table [SMigration].[Schema_RunSelections]')
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Schema_RunSelections_Run_Active] on table [SMigration].[Schema_RunSelections]')
GO



SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Schema_RunSelections_Run_Active] on table [SMigration].[Schema_RunSelections]')
GO
PRINT (N'Create table [SMigration].[Schema_RunSelections]')
GO
CREATE TABLE [SMigration].[Schema_RunSelections] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Schema_RunSelections_RowStatus] DEFAULT (1),
  [RunGuid] [uniqueidentifier] NOT NULL,
  [ComparisonGuid] [uniqueidentifier] NULL,
  [ObjectType] [nvarchar](50) NOT NULL,
  [SchemaName] [nvarchar](128) NOT NULL,
  [ObjectName] [nvarchar](512) NOT NULL,
  [ParentObjectName] [nvarchar](512) NOT NULL CONSTRAINT [DF_Schema_RunSelections_ParentObjectName] DEFAULT (N''),
  [IsSelected] [bit] NOT NULL,
  [SelectionNote] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Schema_RunSelections_SelectionNote] DEFAULT (N''),
  [SelectedByUserId] [int] NOT NULL CONSTRAINT [DF_Schema_RunSelections_SelectedByUserId] DEFAULT (-1),
  [SelectedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Schema_RunSelections_SelectedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Schema_RunSelections] on table [SMigration].[Schema_RunSelections]')
GO
ALTER TABLE [SMigration].[Schema_RunSelections] WITH NOCHECK
  ADD CONSTRAINT [PK_Schema_RunSelections] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Schema_RunSelections_Guid] on table [SMigration].[Schema_RunSelections]')
GO
ALTER TABLE [SMigration].[Schema_RunSelections] WITH NOCHECK
  ADD CONSTRAINT [UQ_Schema_RunSelections_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Schema_RunSelections_Run_Active] on table [SMigration].[Schema_RunSelections]')
GO
CREATE INDEX [IX_Schema_RunSelections_Run_Active]
  ON [SMigration].[Schema_RunSelections] ([RunGuid], [ObjectType], [SchemaName], [ObjectName], [ParentObjectName])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO