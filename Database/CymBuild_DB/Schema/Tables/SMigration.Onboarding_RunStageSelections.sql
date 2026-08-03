PRINT (N'Create table [SMigration].[Onboarding_RunStageSelections]')
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_SMigration_Onboarding_RunStageSelections_Run_Entity_Row] on table [SMigration].[Onboarding_RunStageSelections]')
GO
PRINT (N'Create table [SMigration].[Onboarding_RunStageSelections]')
GO
CREATE TABLE [SMigration].[Onboarding_RunStageSelections] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [RunGuid] [uniqueidentifier] NOT NULL,
  [EntityName] [nvarchar](200) NOT NULL,
  [RowGuid] [uniqueidentifier] NOT NULL,
  [SelectedByUserId] [int] NOT NULL,
  [SelectedOnUtc] [datetime2] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_RunStageSelections] on table [SMigration].[Onboarding_RunStageSelections]')
GO
ALTER TABLE [SMigration].[Onboarding_RunStageSelections] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_RunStageSelections] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_SMigration_Onboarding_RunStageSelections_Run_Entity_Row] on table [SMigration].[Onboarding_RunStageSelections]')
GO
CREATE UNIQUE INDEX [UX_SMigration_Onboarding_RunStageSelections_Run_Entity_Row]
  ON [SMigration].[Onboarding_RunStageSelections] ([RunGuid], [EntityName], [RowGuid])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO