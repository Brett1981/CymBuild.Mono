PRINT (N'Create table [SMigration].[Onboarding_Identities]')
GO
CREATE TABLE [SMigration].[Onboarding_Identities] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [IdentityGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [FullName] [nvarchar](250) NOT NULL,
  [EmailAddress] [nvarchar](150) NOT NULL,
  [UserGuid] [uniqueidentifier] NOT NULL,
  [JobTitle] [nvarchar](50) NOT NULL,
  [OrganisationalUnitGuid] [uniqueidentifier] NOT NULL,
  [IsActive] [bit] NOT NULL,
  [ContactGuid] [uniqueidentifier] NOT NULL,
  [BillableRate] [decimal](19, 2) NOT NULL,
  [Signature] [varbinary](max) NOT NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_Identities] on table [SMigration].[Onboarding_Identities]')
GO
ALTER TABLE [SMigration].[Onboarding_Identities] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_Identities] PRIMARY KEY CLUSTERED ([RunGuid], [IdentityGuid]) WITH (FILLFACTOR = 80)
GO