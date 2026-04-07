CREATE TABLE [dbo].[IndexMaintenanceLog] (
  [LogID] [int] IDENTITY,
  [TableName] [nvarchar](256) NULL,
  [IndexName] [nvarchar](256) NULL,
  [Action] [nvarchar](50) NULL,
  [InitialFragmentation] [float] NULL,
  [FinalFragmentation] [float] NULL,
  [LogDate] [datetime] NULL DEFAULT (getdate()),
  PRIMARY KEY CLUSTERED ([LogID])
)
ON [PRIMARY]
GO