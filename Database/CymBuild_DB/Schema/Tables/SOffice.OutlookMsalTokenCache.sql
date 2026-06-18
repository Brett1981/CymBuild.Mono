PRINT (N'Create table [SOffice].[OutlookMsalTokenCache]')
GO
CREATE TABLE [SOffice].[OutlookMsalTokenCache] (
  [Id] [nvarchar](449) NOT NULL,
  [Value] [varbinary](max) NOT NULL,
  [ExpiresAtTime] [datetimeoffset] NOT NULL,
  [SlidingExpirationInSeconds] [bigint] NULL,
  [AbsoluteExpiration] [datetimeoffset] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_OutlookMsalTokenCache] on table [SOffice].[OutlookMsalTokenCache]')
GO
ALTER TABLE [SOffice].[OutlookMsalTokenCache] WITH NOCHECK
  ADD CONSTRAINT [PK_OutlookMsalTokenCache] PRIMARY KEY CLUSTERED ([Id]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_OutlookMsalTokenCache_ExpiresAtTime] on table [SOffice].[OutlookMsalTokenCache]')
GO
CREATE INDEX [IX_OutlookMsalTokenCache_ExpiresAtTime]
  ON [SOffice].[OutlookMsalTokenCache] ([ExpiresAtTime])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO