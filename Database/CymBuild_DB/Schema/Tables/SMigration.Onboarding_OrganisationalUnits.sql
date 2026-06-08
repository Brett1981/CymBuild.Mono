PRINT (N'Create table [SMigration].[Onboarding_OrganisationalUnits]')
GO
CREATE TABLE [SMigration].[Onboarding_OrganisationalUnits] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [OrganisationalUnitGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [Name] [nvarchar](250) NOT NULL,
  [ParentOrganisationalUnitGuid] [uniqueidentifier] NULL,
  [AddressGuid] [uniqueidentifier] NOT NULL,
  [ContactGuid] [uniqueidentifier] NOT NULL,
  [OfficialAddressGuid] [uniqueidentifier] NOT NULL,
  [OfficialContactGuid] [uniqueidentifier] NOT NULL,
  [DepartmentPrefix] [nvarchar](10) NOT NULL,
  [CostCentreCode] [nvarchar](50) NOT NULL,
  [DefaultSecurityGroupGuid] [uniqueidentifier] NOT NULL,
  [QuoteThreshold] [decimal](19, 2) NULL,
  [OrgLevel] [int] NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_OrganisationalUnits] on table [SMigration].[Onboarding_OrganisationalUnits]')
GO
ALTER TABLE [SMigration].[Onboarding_OrganisationalUnits] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_OrganisationalUnits] PRIMARY KEY CLUSTERED ([RunGuid], [OrganisationalUnitGuid]) WITH (FILLFACTOR = 80)
GO