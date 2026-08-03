PRINT (N'Create table [SMigration].[Onboarding_RunEntitySelections]')
GO
PRINT (N'Create table [SMigration].[Onboarding_RunEntitySelections]')
GO
CREATE TABLE [SMigration].[Onboarding_RunEntitySelections] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Onboarding_RunEntitySelections_RowStatus] DEFAULT (1),
  [RunGuid] [uniqueidentifier] NOT NULL,
  [EntityScopeGuid] [uniqueidentifier] NOT NULL,
  [EntityCode] [nvarchar](100) NOT NULL,
  [IsSelected] [bit] NOT NULL CONSTRAINT [DF_Onboarding_RunEntitySelections_IsSelected] DEFAULT (1),
  [SelectionSource] [nvarchar](30) NOT NULL CONSTRAINT [DF_Onboarding_RunEntitySelections_SelectionSource] DEFAULT (N'Default'),
  [SelectedByUserId] [int] NOT NULL CONSTRAINT [DF_Onboarding_RunEntitySelections_SelectedByUserId] DEFAULT (-1),
  [SelectedOnUtc] [datetime2](3) NOT NULL CONSTRAINT [DF_Onboarding_RunEntitySelections_SelectedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Onboarding_RunEntitySelections] on table [SMigration].[Onboarding_RunEntitySelections]')
GO
ALTER TABLE [SMigration].[Onboarding_RunEntitySelections] WITH NOCHECK
  ADD CONSTRAINT [PK_Onboarding_RunEntitySelections] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Onboarding_RunEntitySelections_Guid] on table [SMigration].[Onboarding_RunEntitySelections]')
GO
ALTER TABLE [SMigration].[Onboarding_RunEntitySelections] WITH NOCHECK
  ADD CONSTRAINT [UQ_Onboarding_RunEntitySelections_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Onboarding_RunEntitySelections_Run_Entity] on table [SMigration].[Onboarding_RunEntitySelections]')
GO
ALTER TABLE [SMigration].[Onboarding_RunEntitySelections] WITH NOCHECK
  ADD CONSTRAINT [UQ_Onboarding_RunEntitySelections_Run_Entity] UNIQUE ([RunGuid], [EntityCode]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Onboarding_RunEntitySelections_RunGuid] on table [SMigration].[Onboarding_RunEntitySelections]')
GO
CREATE INDEX [IX_Onboarding_RunEntitySelections_RunGuid]
  ON [SMigration].[Onboarding_RunEntitySelections] ([RunGuid], [EntityCode], [IsSelected])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Onboarding_RunEntitySelections_RunGuid] on table [SMigration].[Onboarding_RunEntitySelections]')
GO