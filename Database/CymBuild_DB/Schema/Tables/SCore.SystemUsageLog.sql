CREATE TABLE [SCore].[SystemUsageLog] (
  [Id] [int] IDENTITY,
  [UserGuid] [uniqueidentifier] NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [FeatureName] [nvarchar](255) NOT NULL DEFAULT (''),
  [Accessed] [datetime2] NOT NULL DEFAULT (getutcdate()),
  PRIMARY KEY CLUSTERED ([Id]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO