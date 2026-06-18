PRINT (N'Create table [SOffice].[DataProtectionKeys]')
GO
CREATE TABLE [SOffice].[DataProtectionKeys] (
  [Id] [int] IDENTITY,
  [FriendlyName] [nvarchar](max) NULL,
  [Xml] [nvarchar](max) NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_DataProtectionKeys] on table [SOffice].[DataProtectionKeys]')
GO
ALTER TABLE [SOffice].[DataProtectionKeys] WITH NOCHECK
  ADD CONSTRAINT [PK_DataProtectionKeys] PRIMARY KEY CLUSTERED ([Id])
GO