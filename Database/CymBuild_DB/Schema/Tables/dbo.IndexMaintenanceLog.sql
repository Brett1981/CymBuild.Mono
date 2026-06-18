PRINT (N'Create table [dbo].[IndexMaintenanceLog]')
GO
CREATE TABLE [dbo].[IndexMaintenanceLog] (
  [LogID] [int] IDENTITY,
  [TableName] [nvarchar](256) NULL,
  [IndexName] [nvarchar](256) NULL,
  [Action] [nvarchar](50) NULL,
  [InitialFragmentation] [float] NULL,
  [FinalFragmentation] [float] NULL,
  [LogDate] [datetime] NULL DEFAULT (getdate())
)
ON [PRIMARY]
GO

PRINT (N'Create primary key on table [dbo].[IndexMaintenanceLog]')
GO
ALTER TABLE [dbo].[IndexMaintenanceLog] WITH NOCHECK
  ADD PRIMARY KEY CLUSTERED ([LogID])
GO