CREATE TABLE [SOffice].[DataProtectionKeys] (
  [Id] [int] IDENTITY,
  [FriendlyName] [nvarchar](max) NULL,
  [Xml] [nvarchar](max) NULL,
  CONSTRAINT [PK_DataProtectionKeys] PRIMARY KEY CLUSTERED ([Id])
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO