PRINT (N'Create table [SMigration].[Metadata_TableRegistry]')
GO
CREATE TABLE [SMigration].[Metadata_TableRegistry] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_TableRegistry_RowStatus] DEFAULT (1),
  [SchemaName] [sysname] NOT NULL,
  [TableName] [sysname] NOT NULL,
  [GuidColumnName] [sysname] NOT NULL CONSTRAINT [DF_Metadata_TableRegistry_GuidColumnName] DEFAULT (N'Guid'),
  [PrimaryKeyColumnName] [sysname] NOT NULL CONSTRAINT [DF_Metadata_TableRegistry_PrimaryKeyColumnName] DEFAULT (N'ID'),
  [ApplyOrder] [int] NOT NULL,
  [IsEnabled] [bit] NOT NULL CONSTRAINT [DF_Metadata_TableRegistry_IsEnabled] DEFAULT (1),
  [IsDataObjectBacked] [bit] NOT NULL CONSTRAINT [DF_Metadata_TableRegistry_IsDataObjectBacked] DEFAULT (1),
  [IsRetirable] [bit] NOT NULL CONSTRAINT [DF_Metadata_TableRegistry_IsRetirable] DEFAULT (1),
  [IsEnvironmentSpecific] [bit] NOT NULL CONSTRAINT [DF_Metadata_TableRegistry_IsEnvironmentSpecific] DEFAULT (0),
  [NaturalKeyJson] [nvarchar](max) NOT NULL CONSTRAINT [DF_Metadata_TableRegistry_NaturalKeyJson] DEFAULT (N'[]'),
  [ParentDependencyJson] [nvarchar](max) NOT NULL CONSTRAINT [DF_Metadata_TableRegistry_ParentDependencyJson] DEFAULT (N'[]'),
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_TableRegistry_CreatedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Metadata_TableRegistry] on table [SMigration].[Metadata_TableRegistry]')
GO
ALTER TABLE [SMigration].[Metadata_TableRegistry] WITH NOCHECK
  ADD CONSTRAINT [PK_Metadata_TableRegistry] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_TableRegistry_Guid] on table [SMigration].[Metadata_TableRegistry]')
GO
ALTER TABLE [SMigration].[Metadata_TableRegistry] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_TableRegistry_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_TableRegistry_Table] on table [SMigration].[Metadata_TableRegistry]')
GO
ALTER TABLE [SMigration].[Metadata_TableRegistry] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_TableRegistry_Table] UNIQUE ([SchemaName], [TableName]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Metadata_TableRegistry_ApplyOrder] on table [SMigration].[Metadata_TableRegistry]')
GO
CREATE INDEX [IX_Metadata_TableRegistry_ApplyOrder]
  ON [SMigration].[Metadata_TableRegistry] ([ApplyOrder], [SchemaName], [TableName])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [IsEnabled]=(1))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO