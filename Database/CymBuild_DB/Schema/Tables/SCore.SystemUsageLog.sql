PRINT (N'Create table [SCore].[SystemUsageLog]')
GO
CREATE TABLE [SCore].[SystemUsageLog] (
  [Id] [int] IDENTITY,
  [UserGuid] [uniqueidentifier] NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [FeatureName] [nvarchar](255) NOT NULL DEFAULT (''),
  [Accessed] [datetime2] NOT NULL DEFAULT (getutcdate())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key on table [SCore].[SystemUsageLog]')
GO
ALTER TABLE [SCore].[SystemUsageLog] WITH NOCHECK
  ADD PRIMARY KEY CLUSTERED ([Id]) WITH (FILLFACTOR = 80)
GO