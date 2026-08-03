PRINT (N'Create table [SMigration].[Metadata_RunSelections]')
GO
PRINT (N'Create table [SMigration].[Metadata_RunSelections]')
GO
CREATE TABLE [SMigration].[Metadata_RunSelections] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_RunSelections_RowStatus] DEFAULT (1),
  [RunGuid] [uniqueidentifier] NOT NULL,
  [RegistryGuid] [uniqueidentifier] NOT NULL,
  [SourceRowGuid] [uniqueidentifier] NOT NULL,
  [DifferenceType] [nvarchar](30) NOT NULL,
  [SelectionSource] [nvarchar](30) NOT NULL CONSTRAINT [DF_Metadata_RunSelections_SelectionSource] DEFAULT (N'Manual'),
  [SelectedByUserId] [int] NOT NULL CONSTRAINT [DF_Metadata_RunSelections_SelectedByUserId] DEFAULT (-1),
  [SelectedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_Metadata_RunSelections_SelectedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Metadata_RunSelections] on table [SMigration].[Metadata_RunSelections]')
GO
ALTER TABLE [SMigration].[Metadata_RunSelections] WITH NOCHECK
  ADD CONSTRAINT [PK_Metadata_RunSelections] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_RunSelections_Guid] on table [SMigration].[Metadata_RunSelections]')
GO
ALTER TABLE [SMigration].[Metadata_RunSelections] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_RunSelections_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Metadata_RunSelections_Run_Table_Row] on table [SMigration].[Metadata_RunSelections]')
GO
ALTER TABLE [SMigration].[Metadata_RunSelections] WITH NOCHECK
  ADD CONSTRAINT [UQ_Metadata_RunSelections_Run_Table_Row] UNIQUE ([RunGuid], [RegistryGuid], [SourceRowGuid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Metadata_RunSelections_RunGuid] on table [SMigration].[Metadata_RunSelections]')
GO
CREATE INDEX [IX_Metadata_RunSelections_RunGuid]
  ON [SMigration].[Metadata_RunSelections] ([RunGuid], [RegistryGuid], [DifferenceType])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Metadata_RunSelections_RunGuid] on table [SMigration].[Metadata_RunSelections]')
GO