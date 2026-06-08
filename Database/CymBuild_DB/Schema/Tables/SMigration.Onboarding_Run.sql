PRINT (N'Create table [SMigration].[Onboarding_Run]')
GO
CREATE TABLE [SMigration].[Onboarding_Run] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [CreatedUtc] [datetime2](3) NOT NULL CONSTRAINT [DF_SMigration_Onboarding_Run_CreatedUtc] DEFAULT (sysutcdatetime()),
  [SourceDatabase] [sysname] NOT NULL,
  [SourceBusinessUnitGroupGuid] [uniqueidentifier] NOT NULL,
  [SourceBusinessUnitOrganisationalUnitGuid] [uniqueidentifier] NULL,
  [Notes] [nvarchar](1000) NOT NULL CONSTRAINT [DF_SMigration_Onboarding_Run_Notes] DEFAULT (N''),
  [CreatedBy] [nvarchar](250) NOT NULL CONSTRAINT [DF_SMigration_Onboarding_Run_CreatedBy] DEFAULT (suser_sname())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_Run] on table [SMigration].[Onboarding_Run]')
GO
ALTER TABLE [SMigration].[Onboarding_Run] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_Run] PRIMARY KEY CLUSTERED ([RunGuid]) WITH (FILLFACTOR = 80)
GO