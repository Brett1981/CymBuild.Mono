CREATE TYPE [SCore].[GuidUniqueList] AS TABLE (
  [GuidValue] [uniqueidentifier] NOT NULL,
  PRIMARY KEY CLUSTERED ([GuidValue])
)
GO