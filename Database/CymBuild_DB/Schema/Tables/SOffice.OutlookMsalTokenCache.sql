CREATE TABLE [SOffice].[OutlookMsalTokenCache] (
  [Id] [nvarchar](449) NOT NULL,
  [Value] [varbinary](max) NOT NULL,
  [ExpiresAtTime] [datetimeoffset] NOT NULL,
  [SlidingExpirationInSeconds] [bigint] NULL,
  [AbsoluteExpiration] [datetimeoffset] NULL,
  CONSTRAINT [PK_OutlookMsalTokenCache] PRIMARY KEY CLUSTERED ([Id]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [IX_OutlookMsalTokenCache_ExpiresAtTime]
  ON [SOffice].[OutlookMsalTokenCache] ([ExpiresAtTime])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO