PRINT (N'Create table [SMigration].[Metadata_ApplyIdentityMap]')
GO
CREATE TABLE [SMigration].[Metadata_ApplyIdentityMap] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_ApplyIdentityMap_RowStatus] DEFAULT (1),
  [RunGuid] [uniqueidentifier] NOT NULL,
  [RegistryGuid] [uniqueidentifier] NOT NULL,
  [SchemaName] [sysname] NOT NULL,
  [TableName] [sysname] NOT NULL,
  [SourceRowGuid] [uniqueidentifier] NOT NULL,
  [SourceRowId] [bigint] NULL,
  [TargetRowId] [bigint] NULL,
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_ApplyIdentityMap_CreatedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Metadata_ApplyIdentityMap] on table [SMigration].[Metadata_ApplyIdentityMap]')
GO
ALTER TABLE [SMigration].[Metadata_ApplyIdentityMap] WITH NOCHECK
  ADD CONSTRAINT [PK_Metadata_ApplyIdentityMap] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_ApplyIdentityMap_Guid] on table [SMigration].[Metadata_ApplyIdentityMap]')
GO
ALTER TABLE [SMigration].[Metadata_ApplyIdentityMap] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_ApplyIdentityMap_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_ApplyIdentityMap_Run_Table_Row] on table [SMigration].[Metadata_ApplyIdentityMap]')
GO
ALTER TABLE [SMigration].[Metadata_ApplyIdentityMap] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_ApplyIdentityMap_Run_Table_Row] UNIQUE ([RunGuid], [RegistryGuid], [SourceRowGuid]) WITH (FILLFACTOR = 80)
GO