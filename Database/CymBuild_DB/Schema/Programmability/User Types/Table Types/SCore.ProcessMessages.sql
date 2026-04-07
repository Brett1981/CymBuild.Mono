CREATE TYPE [SCore].[ProcessMessages] AS TABLE (
  [ID] [int] IDENTITY,
  [Type] [char](1) NOT NULL DEFAULT (''),
  [Message] [nvarchar](2000) NOT NULL DEFAULT (''),
  PRIMARY KEY CLUSTERED ([ID])
)
GO