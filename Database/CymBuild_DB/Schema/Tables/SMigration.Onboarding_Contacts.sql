PRINT (N'Create table [SMigration].[Onboarding_Contacts]')
GO
CREATE TABLE [SMigration].[Onboarding_Contacts] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [ContactGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [PrimaryAccountGuid] [uniqueidentifier] NULL,
  [PrimaryAddressGuid] [uniqueidentifier] NOT NULL,
  [FirstName] [nvarchar](250) NOT NULL,
  [Initials] [nvarchar](10) NOT NULL,
  [Surname] [nvarchar](250) NOT NULL,
  [PostNominals] [nvarchar](250) NOT NULL,
  [TitleGuid] [uniqueidentifier] NULL,
  [DisplayName] [nvarchar](250) NOT NULL,
  [IsPerson] [bit] NOT NULL,
  [PositionGuid] [uniqueidentifier] NULL,
  [LegacySystemID] [int] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_Contacts] on table [SMigration].[Onboarding_Contacts]')
GO
ALTER TABLE [SMigration].[Onboarding_Contacts] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_Contacts] PRIMARY KEY CLUSTERED ([RunGuid], [ContactGuid]) WITH (FILLFACTOR = 80)
GO