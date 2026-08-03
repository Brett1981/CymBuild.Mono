PRINT (N'Create table [SMigration].[Onboarding_EntityScope]')
GO
PRINT (N'Create table [SMigration].[Onboarding_EntityScope]')
GO
PRINT (N'Create table [SMigration].[Onboarding_EntityScope]')
GO
CREATE TABLE [SMigration].[Onboarding_EntityScope] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_RowStatus] DEFAULT (1),
  [Code] [nvarchar](100) NOT NULL,
  [Name] [nvarchar](200) NOT NULL,
  [StageTableName] [sysname] NOT NULL,
  [DisplayOrder] [int] NOT NULL,
  [DefaultSelected] [bit] NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_DefaultSelected] DEFAULT (1),
  [CanDeselect] [bit] NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_CanDeselect] DEFAULT (1),
  [IsRequired] [bit] NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_IsRequired] DEFAULT (0),
  [RequiredDependencyCodes] [nvarchar](1000) NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_RequiredDependencyCodes] DEFAULT (N''),
  [Description] [nvarchar](500) NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_Description] DEFAULT (N''),
  [CreatedUtc] [datetime2](3) NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_CreatedUtc] DEFAULT (sysutcdatetime()),
  [UpdatedUtc] [datetime2](3) NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_UpdatedUtc] DEFAULT (sysutcdatetime()),
  [Category] [nvarchar](80) NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_Category] DEFAULT (N'Operational Configuration'),
  [ScopeType] [nvarchar](40) NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_ScopeType] DEFAULT (N'OnBoardingBucket'),
  [IsImplemented] [bit] NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_IsImplemented] DEFAULT (0),
  [IsSupportData] [bit] NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_IsSupportData] DEFAULT (0),
  [HandlerKey] [nvarchar](100) NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_HandlerKey] DEFAULT (N''),
  [PrimaryEntityTypeGuid] [uniqueidentifier] NULL,
  [SourceSchemaName] [sysname] NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_SourceSchemaName] DEFAULT (N''),
  [SourceTableName] [sysname] NOT NULL CONSTRAINT [DF_Onboarding_EntityScope_SourceTableName] DEFAULT (N'')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_Onboarding_EntityScope] on table [SMigration].[Onboarding_EntityScope]')
GO
ALTER TABLE [SMigration].[Onboarding_EntityScope] WITH NOCHECK
  ADD CONSTRAINT [PK_Onboarding_EntityScope] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Onboarding_EntityScope_Code] on table [SMigration].[Onboarding_EntityScope]')
GO
ALTER TABLE [SMigration].[Onboarding_EntityScope] WITH NOCHECK
  ADD CONSTRAINT [UQ_Onboarding_EntityScope_Code] UNIQUE ([Code]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_Onboarding_EntityScope_Guid] on table [SMigration].[Onboarding_EntityScope]')
GO
ALTER TABLE [SMigration].[Onboarding_EntityScope] WITH NOCHECK
  ADD CONSTRAINT [UQ_Onboarding_EntityScope_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Onboarding_EntityScope_DisplayOrder] on table [SMigration].[Onboarding_EntityScope]')
GO
CREATE INDEX [IX_Onboarding_EntityScope_DisplayOrder]
  ON [SMigration].[Onboarding_EntityScope] ([DisplayOrder], [Code])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO


SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Onboarding_EntityScope_DisplayOrder] on table [SMigration].[Onboarding_EntityScope]')
GO



SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_Onboarding_EntityScope_DisplayOrder] on table [SMigration].[Onboarding_EntityScope]')
GO