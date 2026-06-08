PRINT (N'Create table [SMigration].[Onboarding_Addresses]')
GO
CREATE TABLE [SMigration].[Onboarding_Addresses] (
  [RunGuid] [uniqueidentifier] NOT NULL,
  [AddressGuid] [uniqueidentifier] NOT NULL,
  [RowStatus] [tinyint] NOT NULL,
  [AddressNumber] [int] NOT NULL,
  [Name] [nvarchar](100) NOT NULL,
  [Number] [nvarchar](50) NOT NULL,
  [AddressLine1] [nvarchar](255) NOT NULL,
  [AddressLine2] [nvarchar](255) NOT NULL,
  [AddressLine3] [nvarchar](255) NOT NULL,
  [Town] [nvarchar](255) NOT NULL,
  [CountyGuid] [uniqueidentifier] NULL,
  [Postcode] [nvarchar](50) NOT NULL,
  [CountryGuid] [uniqueidentifier] NULL,
  [LegacySystemID] [int] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SMigration_Onboarding_Addresses] on table [SMigration].[Onboarding_Addresses]')
GO
ALTER TABLE [SMigration].[Onboarding_Addresses] WITH NOCHECK
  ADD CONSTRAINT [PK_SMigration_Onboarding_Addresses] PRIMARY KEY CLUSTERED ([RunGuid], [AddressGuid]) WITH (FILLFACTOR = 80)
GO