PRINT (N'Create table [SMigration].[Onboarding_Products]')
GO
CREATE TABLE [SMigration].[Onboarding_Products] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [ProductGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [Code] [nvarchar](30) NOT NULL,
  [Description] [nvarchar](2000) NOT NULL,
  [CreatedJobTypeGuid] [uniqueidentifier] NOT NULL,
  [NeverConsolidate] [bit] NOT NULL,
  [RibaStageGuid] [uniqueidentifier] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_Products] on table [SMigration].[Onboarding_Products]')
GO
ALTER TABLE [SMigration].[Onboarding_Products] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_Products] PRIMARY KEY CLUSTERED ([RunGuid], [ProductGuid]) WITH (FILLFACTOR = 80)
GO