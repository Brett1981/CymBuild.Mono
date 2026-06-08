PRINT (N'Create table [SMonitor].[WaitStatsExclusions]')
GO
CREATE TABLE [SMonitor].[WaitStatsExclusions] (
  [WaitType] [sysname] NOT NULL,
  [Reason] [nvarchar](400) NULL,
  [CreatedOnUtc] [datetime2](3) NOT NULL CONSTRAINT [DF_WaitStatsExclusions_CreatedOnUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key on table [SMonitor].[WaitStatsExclusions]')
GO
ALTER TABLE [SMonitor].[WaitStatsExclusions] WITH NOCHECK
  ADD PRIMARY KEY CLUSTERED ([WaitType]) WITH (FILLFACTOR = 80)
GO