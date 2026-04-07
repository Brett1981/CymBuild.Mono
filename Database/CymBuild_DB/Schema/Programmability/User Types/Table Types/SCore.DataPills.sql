CREATE TYPE [SCore].[DataPills] AS TABLE (
  [ID] [int] IDENTITY,
  [Label] [nvarchar](50) NOT NULL DEFAULT (''),
  [Class] [nvarchar](50) NOT NULL DEFAULT (''),
  [SortOrder] [int] NOT NULL DEFAULT (0),
  PRIMARY KEY CLUSTERED ([ID])
)
GO